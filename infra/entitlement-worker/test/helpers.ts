// Shared test fixtures: in-memory Store, a real Ed25519 token service
// (Node's WebCrypto supports Ed25519), and a Deps factory with fakes for
// every external call.

import { b64urlToJsonObject, bytesToB64 } from '../src/encoding';
import { createTokenService, importSigningKeys, type TokenService } from '../src/jwt';
import type { AfdianOrder, Deps } from '../src/logic';
import type {
  BetaRow,
  DeviceRow,
  EntitlementRow,
  OrderRow,
  Store,
  UpsertEntitlementInput,
} from '../src/store';

export const NOW = 1_800_000_000; // fixed epoch reference for tests

export class MemoryStore implements Store {
  ents: EntitlementRow[] = [];
  devices = new Map<string, DeviceRow>();
  activationLog: DeviceRow[] = [];
  orders = new Map<string, OrderRow>();
  beta = new Map<string, BetaRow>();
  private nextId = 1;

  async getEntitlement(channel: string, subject: string): Promise<EntitlementRow | null> {
    const e = this.ents.find((e) => e.channel === channel && e.subject === subject);
    return e ? { ...e } : null;
  }

  async getEmailByPurchaseToken(token: string): Promise<string | null> {
    const row = this.ents.find((e) => e.playPurchaseToken === token);
    return row?.subjectEmail ?? null;
  }

  async upsertEntitlement(i: UpsertEntitlementInput): Promise<EntitlementRow> {
    // Models migration 0003's unique index on play_purchase_token. Without it
    // the cross-account reuse tests would pass against a store that is more
    // permissive than production — i.e. for the wrong reason.
    if (i.playPurchaseToken != null) {
      const holder = this.ents.find(
        (e) =>
          e.playPurchaseToken === i.playPurchaseToken &&
          !(e.channel === i.channel && e.subject === i.subject),
      );
      if (holder) {
        throw new Error('D1_ERROR: UNIQUE constraint failed: entitlements.play_purchase_token');
      }
    }
    let e = this.ents.find((e) => e.channel === i.channel && e.subject === i.subject);
    if (e) {
      e.tier = i.tier;
      e.proUntil = i.proUntil;
      if (i.playPurchaseToken !== undefined) e.playPurchaseToken = i.playPurchaseToken;
      if (i.subjectEmail !== undefined) e.subjectEmail = i.subjectEmail;
    } else {
      e = {
        id: this.nextId++,
        channel: i.channel,
        subject: i.subject,
        subjectEmail: i.subjectEmail ?? null,
        tier: i.tier,
        proUntil: i.proUntil,
        revoked: false,
        createdAt: i.now,
        playPurchaseToken: i.playPurchaseToken ?? null,
      };
      this.ents.push(e);
    }
    return { ...e };
  }

  async setProUntil(id: number, proUntil: number): Promise<void> {
    const e = this.ents.find((e) => e.id === id);
    if (e) e.proUntil = proUntil;
  }

  async getDevice(entitlementId: number, deviceClass: string): Promise<DeviceRow | null> {
    const d = this.devices.get(`${entitlementId}:${deviceClass}`);
    return d ? { ...d } : null;
  }

  async claimDevice(
    entitlementId: number,
    deviceClass: string,
    deviceId: string,
    now: number,
  ): Promise<void> {
    this.devices.set(`${entitlementId}:${deviceClass}`, {
      entitlementId,
      deviceClass,
      deviceId,
      activatedAt: now,
    });
  }

  async listDevices(entitlementId: number): Promise<DeviceRow[]> {
    return [...this.devices.values()]
      .filter((d) => d.entitlementId === entitlementId)
      .sort((a, b) => a.deviceClass.localeCompare(b.deviceClass))
      .map((d) => ({ ...d }));
  }

  /** Models D1's single conditional INSERT: no await between the count and
   * the append, so concurrent callers serialize here exactly like SQLite
   * serializes the atomic statement — interleaved redeems cannot both read
   * a below-cap count and both insert. */
  async tryLogActivation(
    entitlementId: number,
    deviceClass: string,
    deviceId: string,
    now: number,
    since: number,
    cap: number,
  ): Promise<boolean> {
    const recent = this.activationLog.filter(
      (a) =>
        a.entitlementId === entitlementId &&
        a.deviceClass === deviceClass &&
        a.activatedAt > since,
    ).length;
    if (recent >= cap) return false;
    this.activationLog.push({ entitlementId, deviceClass, deviceId, activatedAt: now });
    return true;
  }

  async countRecentActivations(
    entitlementId: number,
    deviceClass: string,
    since: number,
  ): Promise<number> {
    return this.activationLog.filter(
      (a) =>
        a.entitlementId === entitlementId &&
        a.deviceClass === deviceClass &&
        a.activatedAt > since,
    ).length;
  }

  async getOrder(outTradeNo: string): Promise<OrderRow | null> {
    const o = this.orders.get(outTradeNo);
    return o ? { ...o } : null;
  }

  async recordOrder(order: OrderRow): Promise<void> {
    if (!this.orders.has(order.outTradeNo)) this.orders.set(order.outTradeNo, { ...order });
  }

  async bindOrder(outTradeNo: string, entitlementId: number): Promise<void> {
    const o = this.orders.get(outTradeNo);
    if (o) o.entitlementId = entitlementId;
  }

  async getBetaCode(code: string): Promise<BetaRow | null> {
    const b = this.beta.get(code);
    return b ? { ...b } : null;
  }

  async redeemBetaCode(code: string, redeemedBy: string): Promise<void> {
    const b = this.beta.get(code);
    if (b && b.redeemedBy === null) b.redeemedBy = redeemedBy;
  }
}

/** Real Ed25519 token service, exercising the same pkcs8-import path as prod. */
export async function makeTokenService(): Promise<TokenService> {
  const kp = (await crypto.subtle.generateKey({ name: 'Ed25519' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(
    (await crypto.subtle.exportKey('pkcs8', kp.privateKey)) as ArrayBuffer,
  );
  const keys = await importSigningKeys(bytesToB64(pkcs8));
  return createTokenService(keys);
}

export interface TestContext {
  deps: Deps;
  store: MemoryStore;
  tokens: TokenService;
  clock: { t: number };
  /** Orders returned by the fake Afdian queryOrder. */
  afdianOrders: Map<string, AfdianOrder>;
}

export async function setup(overrides: Partial<Deps> = {}): Promise<TestContext> {
  const store = new MemoryStore();
  const tokens = await makeTokenService();
  const clock = { t: NOW };
  const afdianOrders = new Map<string, AfdianOrder>();
  const seenTxns = new Set<string>();
  const deps: Deps = {
    store,
    tokens,
    google: {
      verifyIdToken: async () => ({ sub: 'google-sub-1', email: 'buyer.one@gmail.com' }),
      getSubscription: async () => ({
        valid: true,
        expiresAt: clock.t + 30 * 86400,
        productIds: ['ava_pro_monthly'],
      }),
    },
    afdian: {
      queryOrder: async (no) => afdianOrders.get(no) ?? null,
    },
    admob: { verify: async () => true },
    config: {
      afdianPlanId: () => 'plan-pro',
      playProductId: () => 'ava_pro_monthly',
      vipDays: async () => 3,
      activationWindowDays: async () => 90,
      activationCap: async () => 3, // tests pin a small cap (prod default is 5)
    },
    replay: {
      seenTransaction: async (id) => {
        if (seenTxns.has(id)) return true;
        seenTxns.add(id);
        return false;
      },
    },
    // Permissive by default; the router test overrides it to assert the 429.
    rateLimit: { allow: async () => true },
    now: () => clock.t,
    ...overrides,
  };
  return { deps, store, tokens, clock, afdianOrders };
}

/** Decodes a JWT payload without verifying — for asserting issued claims. */
export function decodeClaims(token: string): Record<string, unknown> {
  const payload = b64urlToJsonObject(token.split('.')[1]);
  if (!payload) throw new Error('bad token payload');
  return payload;
}
