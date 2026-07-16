// Core business logic. Everything external (DB, Google, Afdian, AdMob,
// config, clock) comes in through `Deps` so vitest can drive every branch
// with in-memory fakes — no fetch happens in this file.

import type { TokenClaims, TokenService } from './jwt';
import type { EntitlementRow, Store } from './store';

export const TOKEN_TTL_SECONDS = 24 * 3600;
// TODO(launch): Afdian sells calendar months; 30 days is an approximation —
// decide whether to switch to calendar arithmetic before launch.
export const MONTH_SECONDS = 30 * 86400;
export const DAY_SECONDS = 86400;

export const DEVICE_CLASSES = ['android', 'windows', 'linux', 'macos'] as const;

export interface AfdianOrder {
  outTradeNo: string;
  userId: string;
  planId: string;
  /** Number of months purchased (Afdian `month` field). */
  month: number;
  /** Epoch seconds. */
  paidAt: number;
}

export interface GoogleSubscription {
  valid: boolean;
  /** Epoch seconds; 0 when unknown. */
  expiresAt: number;
}

export interface Deps {
  store: Store;
  tokens: TokenService;
  google: {
    /** Returns the Google account's `sub`, or null when the id_token is invalid. */
    verifyIdToken(idToken: string): Promise<{ sub: string } | null>;
    getSubscription(purchaseToken: string): Promise<GoogleSubscription>;
  };
  afdian: {
    /** Returns the paid order, or null when missing/unpaid/API failure. */
    queryOrder(outTradeNo: string): Promise<AfdianOrder | null>;
  };
  admob: {
    /** Verifies the AdMob SSV ECDSA signature on the callback URL. */
    verify(url: URL): Promise<boolean>;
  };
  config: {
    afdianPlanId(): string;
    /** VIP days granted per rewarded ad (KV `VIP_DAYS`, default 3). */
    vipDays(): Promise<number>;
  };
  replay: {
    /** True if this SSV transaction_id was already processed; marks it otherwise. */
    seenTransaction(id: string): Promise<boolean>;
  };
  /** Epoch seconds. */
  now(): number;
}

export interface Res {
  status: number;
  /** null → empty body (AdMob SSV wants a bare 200). */
  body: Record<string, unknown> | null;
}

const err = (status: number, error: string): Res => ({ status, body: { error } });
const ok = (body: Record<string, unknown>): Res => ({ status: 200, body });
const BAD_REQUEST = err(400, 'bad_request');

function str(v: unknown): v is string {
  return typeof v === 'string' && v.length > 0;
}

function isDeviceClass(v: unknown): v is (typeof DEVICE_CLASSES)[number] {
  return typeof v === 'string' && (DEVICE_CLASSES as readonly string[]).includes(v);
}

function field(body: unknown, key: string): unknown {
  return typeof body === 'object' && body !== null ? (body as Record<string, unknown>)[key] : undefined;
}

async function issueToken(
  deps: Deps,
  ent: EntitlementRow,
  deviceId: string,
  deviceClass: string,
): Promise<Res> {
  const now = deps.now();
  const claims: TokenClaims = {
    sub: ent.subject,
    chan: ent.channel,
    tier: ent.tier,
    dev: deviceId,
    cls: deviceClass,
    iat: now,
    exp: now + TOKEN_TTL_SECONDS,
    pro: ent.proUntil,
  };
  return ok({ token: await deps.tokens.sign(claims) });
}

/** POST /v1/token/refresh {token, device_id} */
export async function handleRefresh(body: unknown, deps: Deps): Promise<Res> {
  const token = field(body, 'token');
  const deviceId = field(body, 'device_id');
  if (!str(token) || !str(deviceId)) return BAD_REQUEST;

  // Signature must verify; expiry is fine (that's what refresh is for).
  const claims = await deps.tokens.verify(token);
  if (!claims) return err(403, 'invalid_token');
  if (claims.dev !== deviceId) return err(403, 'device_revoked');

  const ent = await deps.store.getEntitlement(claims.chan, claims.sub);
  if (!ent) return err(403, 'entitlement_ended');
  if (ent.revoked) return err(403, 'revoked');

  const active = await deps.store.getDevice(ent.id, claims.cls);
  if (!active || active.deviceId !== deviceId) return err(403, 'device_revoked');

  const now = deps.now();
  let current = ent;
  if (ent.proUntil !== 0 && ent.proUntil <= now) {
    if (ent.channel === 'play' && ent.tier === 'pro' && ent.playPurchaseToken) {
      // Play: the subscription may have auto-renewed since we last looked.
      const sub = await deps.google.getSubscription(ent.playPurchaseToken);
      if (!sub.valid || sub.expiresAt <= now) return err(403, 'entitlement_ended');
      await deps.store.setProUntil(ent.id, sub.expiresAt);
      current = { ...ent, proUntil: sub.expiresAt };
    } else {
      // afdian: the DB value IS the latest (webhook/redeem extend it);
      // beta is lifetime (proUntil 0, never lands here); vip has no renewal source.
      return err(403, 'entitlement_ended');
    }
  }

  return issueToken(deps, current, deviceId, claims.cls);
}

/** POST /v1/play/verify {id_token, purchase_token, device_id, device_class} */
export async function handlePlayVerify(body: unknown, deps: Deps): Promise<Res> {
  const idToken = field(body, 'id_token');
  const purchaseToken = field(body, 'purchase_token');
  const deviceId = field(body, 'device_id');
  const deviceClass = field(body, 'device_class');
  if (!str(idToken) || !str(purchaseToken) || !str(deviceId) || !isDeviceClass(deviceClass)) {
    return BAD_REQUEST;
  }

  const g = await deps.google.verifyIdToken(idToken);
  if (!g) return err(401, 'invalid_id_token');

  const existing = await deps.store.getEntitlement('play', g.sub);
  if (existing?.revoked) return err(403, 'revoked');

  const now = deps.now();
  const sub = await deps.google.getSubscription(purchaseToken);
  if (!sub.valid || sub.expiresAt <= now) return err(403, 'subscription_invalid');

  const ent = await deps.store.upsertEntitlement({
    channel: 'play',
    subject: g.sub,
    tier: 'pro',
    proUntil: sub.expiresAt,
    playPurchaseToken: purchaseToken,
    now,
  });
  await deps.store.claimDevice(ent.id, deviceClass, deviceId, now);
  return issueToken(deps, ent, deviceId, deviceClass);
}

/** POST /v1/afdian/redeem {order_no, device_id, device_class} */
export async function handleAfdianRedeem(body: unknown, deps: Deps): Promise<Res> {
  const orderNo = field(body, 'order_no');
  const deviceId = field(body, 'device_id');
  const deviceClass = field(body, 'device_class');
  if (!str(orderNo) || !str(deviceId) || !isDeviceClass(deviceClass)) return BAD_REQUEST;

  const order = await deps.afdian.queryOrder(orderNo);
  if (!order || order.planId !== deps.config.afdianPlanId()) return err(403, 'order_invalid');

  const now = deps.now();
  const recorded = await deps.store.getOrder(orderNo);
  let ent = await deps.store.getEntitlement('afdian', order.userId);
  if (ent?.revoked) return err(403, 'revoked');

  if (recorded && recorded.entitlementId !== null) {
    // Already applied. Same entitlement → idempotent re-redeem; else refuse.
    if (!ent || recorded.entitlementId !== ent.id) return err(403, 'order_bound');
  } else {
    const base = ent && ent.proUntil > now ? ent.proUntil : now;
    const proUntil = ent && ent.proUntil === 0 ? 0 : base + order.month * MONTH_SECONDS;
    ent = await deps.store.upsertEntitlement({
      channel: 'afdian',
      subject: order.userId,
      tier: 'pro',
      proUntil,
      now,
    });
    if (recorded) {
      // Webhook got here first and left the order unbound.
      await deps.store.bindOrder(orderNo, ent.id);
    } else {
      await deps.store.recordOrder({
        outTradeNo: orderNo,
        userId: order.userId,
        planId: order.planId,
        paidAt: order.paidAt,
        entitlementId: ent.id,
      });
    }
  }

  await deps.store.claimDevice(ent.id, deviceClass, deviceId, now);
  return issueToken(deps, ent, deviceId, deviceClass);
}

/** POST /v1/afdian/webhook — renewal push. Responds {ec:200} on success. */
export async function handleAfdianWebhook(body: unknown, deps: Deps): Promise<Res> {
  const data = field(body, 'data');
  const order = field(data, 'order');
  const outTradeNo = field(order, 'out_trade_no');
  if (!str(outTradeNo)) return BAD_REQUEST;

  // Afdian webhook pushes carry no signature, so authenticate by re-querying
  // the order through the signed open API — that both proves the source and
  // gives us canonical order data.
  const verified = await deps.afdian.queryOrder(outTradeNo);
  if (!verified) return err(400, 'order_unverified');

  // Order for some other plan/creation: acknowledge so Afdian stops retrying.
  if (verified.planId !== deps.config.afdianPlanId()) return ok({ ec: 200 });

  // Duplicate push: already recorded.
  if (await deps.store.getOrder(outTradeNo)) return ok({ ec: 200 });

  const now = deps.now();
  const ent = await deps.store.getEntitlement('afdian', verified.userId);
  if (ent && !ent.revoked) {
    const proUntil =
      ent.proUntil === 0
        ? 0
        : (ent.proUntil > now ? ent.proUntil : now) + verified.month * MONTH_SECONDS;
    await deps.store.setProUntil(ent.id, proUntil);
    await deps.store.recordOrder({
      outTradeNo,
      userId: verified.userId,
      planId: verified.planId,
      paidAt: verified.paidAt,
      entitlementId: ent.id,
    });
  } else {
    // No entitlement yet (user paid before ever redeeming in-app) — remember
    // the order unbound; /v1/afdian/redeem will bind and apply it.
    await deps.store.recordOrder({
      outTradeNo,
      userId: verified.userId,
      planId: verified.planId,
      paidAt: verified.paidAt,
      entitlementId: null,
    });
  }
  return ok({ ec: 200 });
}

/** POST /v1/beta/redeem {code, device_id, device_class} */
export async function handleBetaRedeem(body: unknown, deps: Deps): Promise<Res> {
  const code = field(body, 'code');
  const deviceId = field(body, 'device_id');
  const deviceClass = field(body, 'device_class');
  if (!str(code) || !str(deviceId) || !isDeviceClass(deviceClass)) return BAD_REQUEST;

  const row = await deps.store.getBetaCode(code);
  if (!row) return err(403, 'code_invalid');
  // First redeemer's device_id claims the code; the same device may re-redeem
  // (reinstall), anyone else is refused.
  if (row.redeemedBy !== null && row.redeemedBy !== deviceId) return err(403, 'code_redeemed');

  const existing = await deps.store.getEntitlement('beta', code);
  if (existing?.revoked) return err(403, 'revoked');

  const now = deps.now();
  if (row.redeemedBy === null) await deps.store.redeemBetaCode(code, deviceId);
  const ent = await deps.store.upsertEntitlement({
    channel: 'beta',
    subject: code,
    tier: 'pro',
    proUntil: 0, // lifetime
    now,
  });
  await deps.store.claimDevice(ent.id, deviceClass, deviceId, now);
  return issueToken(deps, ent, deviceId, deviceClass);
}

/** POST /v1/vip/claim {device_id, device_class} — pick up a VIP entitlement
 * created by the AdMob SSV callback (the client may hold no token yet, so it
 * polls this after the rewarded ad finishes). */
export async function handleVipClaim(body: unknown, deps: Deps): Promise<Res> {
  const deviceId = field(body, 'device_id');
  const deviceClass = field(body, 'device_class');
  if (!str(deviceId) || !isDeviceClass(deviceClass)) return BAD_REQUEST;

  const ent = await deps.store.getEntitlement('play', deviceId);
  const now = deps.now();
  if (
    !ent ||
    ent.revoked ||
    ent.tier !== 'vip' ||
    ent.proUntil === 0 || // vip is never lifetime; treat as absent
    ent.proUntil <= now
  ) {
    return err(404, 'no_vip');
  }

  await deps.store.claimDevice(ent.id, deviceClass, deviceId, now);
  return issueToken(deps, ent, deviceId, deviceClass);
}

/** GET /v1/admob/ssv?...&signature=...&key_id=... — server-side verification
 * callback for rewarded ads. `user_id` carries the client's device_id. */
export async function handleAdmobSsv(url: URL, deps: Deps): Promise<Res> {
  const deviceId = url.searchParams.get('user_id');
  if (!deviceId) return BAD_REQUEST;

  if (!(await deps.admob.verify(url))) return err(403, 'invalid_signature');

  // Google retries the callback; don't grant the same transaction twice.
  const txn = url.searchParams.get('transaction_id');
  if (txn && (await deps.replay.seenTransaction(txn))) return { status: 200, body: null };

  const now = deps.now();
  const existing = await deps.store.getEntitlement('play', deviceId);
  // Never touch a revoked row, and never downgrade a real Pro entitlement
  // that happens to share the subject.
  if (existing && (existing.revoked || existing.tier === 'pro')) {
    return { status: 200, body: null };
  }

  const days = await deps.config.vipDays();
  const base = existing && existing.proUntil > now ? existing.proUntil : now;
  const ent = await deps.store.upsertEntitlement({
    channel: 'play',
    subject: deviceId,
    tier: 'vip',
    proUntil: base + days * DAY_SECONDS,
    now,
  });

  // custom_data may carry the device class as JSON; AVA's rewarded ads run on
  // Android, so that's the default.
  let deviceClass = 'android';
  const custom = url.searchParams.get('custom_data');
  if (custom) {
    try {
      const parsed: unknown = JSON.parse(custom);
      const cls = field(parsed, 'device_class');
      if (isDeviceClass(cls)) deviceClass = cls;
    } catch {
      // opaque custom_data — keep the default
    }
  }
  await deps.store.claimDevice(ent.id, deviceClass, deviceId, now);

  return { status: 200, body: null };
}
