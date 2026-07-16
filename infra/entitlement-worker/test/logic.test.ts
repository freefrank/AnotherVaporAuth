import { describe, expect, it } from 'vitest';
import {
  DAY_SECONDS,
  MONTH_SECONDS,
  TOKEN_TTL_SECONDS,
  handleAdmobSsv,
  handleAfdianRedeem,
  handleAfdianWebhook,
  handleBetaRedeem,
  handlePlayVerify,
  handleRefresh,
  handleVipClaim,
  type Res,
} from '../src/logic';
import { NOW, decodeClaims, setup, type TestContext } from './helpers';

function tokenOf(res: Res): string {
  expect(res.status).toBe(200);
  const t = (res.body as Record<string, unknown>).token;
  expect(typeof t).toBe('string');
  return t as string;
}

const PLAY_BODY = {
  id_token: 'idtok',
  purchase_token: 'ptok-1',
  device_id: 'dev-A',
  device_class: 'android',
};

async function playVerified(ctx: TestContext, body: Partial<typeof PLAY_BODY> = {}) {
  return handlePlayVerify({ ...PLAY_BODY, ...body }, ctx.deps);
}

describe('play verify', () => {
  it('issues a token with the full claim set', async () => {
    const ctx = await setup();
    const res = await playVerified(ctx);
    const claims = decodeClaims(tokenOf(res));
    expect(claims).toEqual({
      sub: 'google-sub-1',
      chan: 'play',
      tier: 'pro',
      dev: 'dev-A',
      cls: 'android',
      iat: NOW,
      exp: NOW + TOKEN_TTL_SECONDS,
      pro: NOW + 30 * 86400,
    });
    // token verifies against the service's own key
    expect(await ctx.tokens.verify(tokenOf(res))).not.toBeNull();
  });

  it('stores the purchase token for later refresh re-verification', async () => {
    const ctx = await setup();
    await playVerified(ctx);
    expect(ctx.store.ents[0].playPurchaseToken).toBe('ptok-1');
  });

  it('rejects a bad id_token, an invalid subscription, and a revoked entitlement', async () => {
    const ctx = await setup();
    ctx.deps.google.verifyIdToken = async () => null;
    expect(await playVerified(ctx)).toEqual({ status: 401, body: { error: 'invalid_id_token' } });

    const ctx2 = await setup();
    ctx2.deps.google.getSubscription = async () => ({ valid: false, expiresAt: 0 });
    expect(await playVerified(ctx2)).toEqual({
      status: 403,
      body: { error: 'subscription_invalid' },
    });

    const ctx3 = await setup();
    await playVerified(ctx3);
    ctx3.store.ents[0].revoked = true;
    expect(await playVerified(ctx3)).toEqual({ status: 403, body: { error: 'revoked' } });
  });

  it('rejects an unknown device_class', async () => {
    const ctx = await setup();
    const res = await playVerified(ctx, { device_class: 'ios' as never });
    expect(res).toEqual({ status: 400, body: { error: 'bad_request' } });
  });
});

describe('device slots', () => {
  it('kicks the previous device of the same class; the new one refreshes fine', async () => {
    const ctx = await setup();
    const tokenA = tokenOf(await playVerified(ctx, { device_id: 'dev-A' }));
    const tokenB = tokenOf(await playVerified(ctx, { device_id: 'dev-B' }));

    const kicked = await handleRefresh({ token: tokenA, device_id: 'dev-A' }, ctx.deps);
    expect(kicked).toEqual({ status: 403, body: { error: 'device_revoked' } });

    const fine = await handleRefresh({ token: tokenB, device_id: 'dev-B' }, ctx.deps);
    expect(fine.status).toBe(200);
  });

  it('lets different device classes coexist on one entitlement', async () => {
    const ctx = await setup();
    const android = tokenOf(await playVerified(ctx, { device_id: 'dev-A', device_class: 'android' }));
    const windows = tokenOf(await playVerified(ctx, { device_id: 'dev-W', device_class: 'windows' }));
    expect((await handleRefresh({ token: android, device_id: 'dev-A' }, ctx.deps)).status).toBe(200);
    expect((await handleRefresh({ token: windows, device_id: 'dev-W' }, ctx.deps)).status).toBe(200);
    expect(ctx.store.ents).toHaveLength(1);
  });
});

describe('token refresh', () => {
  it('rotates: a nearly-expired token yields a fresh 24h token', async () => {
    const ctx = await setup();
    const old = tokenOf(await playVerified(ctx));
    ctx.clock.t = NOW + 23 * 3600;
    const res = await handleRefresh({ token: old, device_id: 'dev-A' }, ctx.deps);
    const claims = decodeClaims(tokenOf(res));
    expect(claims.iat).toBe(NOW + 23 * 3600);
    expect(claims.exp).toBe(NOW + 23 * 3600 + TOKEN_TTL_SECONDS);
  });

  it('accepts a token past its exp as long as the signature holds', async () => {
    const ctx = await setup();
    const old = tokenOf(await playVerified(ctx));
    ctx.clock.t = NOW + 5 * 86400; // token exp long gone, pro_until still ahead
    const res = await handleRefresh({ token: old, device_id: 'dev-A' }, ctx.deps);
    expect(res.status).toBe(200);
  });

  it('rejects garbage and foreign-key tokens with invalid_token', async () => {
    const ctx = await setup();
    expect(await handleRefresh({ token: 'garbage', device_id: 'x' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'invalid_token' },
    });
    const other = await setup();
    const foreign = tokenOf(await playVerified(other));
    expect(await handleRefresh({ token: foreign, device_id: 'dev-A' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'invalid_token' },
    });
  });

  it('rejects a device_id that does not match the token binding', async () => {
    const ctx = await setup();
    const token = tokenOf(await playVerified(ctx));
    expect(await handleRefresh({ token, device_id: 'someone-else' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'device_revoked' },
    });
  });

  it('403 revoked when the entitlement is revoked', async () => {
    const ctx = await setup();
    const token = tokenOf(await playVerified(ctx));
    ctx.store.ents[0].revoked = true;
    expect(await handleRefresh({ token, device_id: 'dev-A' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'revoked' },
    });
  });

  it('play channel: expired pro_until re-checks the subscription and extends', async () => {
    const ctx = await setup();
    const token = tokenOf(await playVerified(ctx));
    ctx.clock.t = NOW + 31 * 86400; // past pro_until
    ctx.deps.google.getSubscription = async (pt) => {
      expect(pt).toBe('ptok-1'); // uses the stored purchase token
      return { valid: true, expiresAt: NOW + 61 * 86400 };
    };
    const res = await handleRefresh({ token, device_id: 'dev-A' }, ctx.deps);
    const claims = decodeClaims(tokenOf(res));
    expect(claims.pro).toBe(NOW + 61 * 86400);
    expect(ctx.store.ents[0].proUntil).toBe(NOW + 61 * 86400); // persisted
  });

  it('play channel: expired pro_until with a dead subscription → entitlement_ended', async () => {
    const ctx = await setup();
    const token = tokenOf(await playVerified(ctx));
    ctx.clock.t = NOW + 31 * 86400;
    ctx.deps.google.getSubscription = async () => ({ valid: false, expiresAt: 0 });
    expect(await handleRefresh({ token, device_id: 'dev-A' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'entitlement_ended' },
    });
  });

  it('afdian channel: expired pro_until without a renewal → entitlement_ended', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', {
      outTradeNo: 'ord-1',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: NOW,
    });
    const token = tokenOf(
      await handleAfdianRedeem(
        { order_no: 'ord-1', device_id: 'dev-A', device_class: 'android' },
        ctx.deps,
      ),
    );
    ctx.clock.t = NOW + MONTH_SECONDS + 1;
    expect(await handleRefresh({ token, device_id: 'dev-A' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'entitlement_ended' },
    });
  });

  it('afdian channel: a webhook renewal revives an expired entitlement on refresh', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', {
      outTradeNo: 'ord-1',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: NOW,
    });
    const token = tokenOf(
      await handleAfdianRedeem(
        { order_no: 'ord-1', device_id: 'dev-A', device_class: 'android' },
        ctx.deps,
      ),
    );
    // Renewal lands via webhook after expiry.
    ctx.clock.t = NOW + MONTH_SECONDS + 100;
    ctx.afdianOrders.set('ord-2', {
      outTradeNo: 'ord-2',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: ctx.clock.t,
    });
    await handleAfdianWebhook({ data: { order: { out_trade_no: 'ord-2' } } }, ctx.deps);
    const res = await handleRefresh({ token, device_id: 'dev-A' }, ctx.deps);
    expect(decodeClaims(tokenOf(res)).pro).toBe(ctx.clock.t + MONTH_SECONDS);
  });
});

describe('afdian redeem', () => {
  const order1 = { outTradeNo: 'ord-1', userId: 'afd-u1', planId: 'plan-pro', month: 1, paidAt: NOW };
  const redeemBody = { order_no: 'ord-1', device_id: 'dev-A', device_class: 'android' };

  it('creates the entitlement, records the order, issues an afdian token', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', order1);
    const res = await handleAfdianRedeem(redeemBody, ctx.deps);
    const claims = decodeClaims(tokenOf(res));
    expect(claims.chan).toBe('afdian');
    expect(claims.sub).toBe('afd-u1');
    expect(claims.pro).toBe(NOW + MONTH_SECONDS);
    expect((await ctx.store.getOrder('ord-1'))?.entitlementId).toBe(ctx.store.ents[0].id);
  });

  it('multi-month orders extend proportionally', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', { ...order1, month: 3 });
    const res = await handleAfdianRedeem(redeemBody, ctx.deps);
    expect(decodeClaims(tokenOf(res)).pro).toBe(NOW + 3 * MONTH_SECONDS);
  });

  it('rejects unknown orders and plan mismatches', async () => {
    const ctx = await setup();
    expect(await handleAfdianRedeem(redeemBody, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'order_invalid' },
    });
    ctx.afdianOrders.set('ord-1', { ...order1, planId: 'other-plan' });
    expect(await handleAfdianRedeem(redeemBody, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'order_invalid' },
    });
  });

  it('refuses an order already bound to a different entitlement', async () => {
    const ctx = await setup();
    // Another user's entitlement holds this order.
    const otherEnt = await ctx.store.upsertEntitlement({
      channel: 'afdian',
      subject: 'someone-else',
      tier: 'pro',
      proUntil: NOW + MONTH_SECONDS,
      now: NOW,
    });
    await ctx.store.recordOrder({ ...order1, entitlementId: otherEnt.id });
    ctx.afdianOrders.set('ord-1', order1);
    expect(await handleAfdianRedeem(redeemBody, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'order_bound' },
    });
  });

  it('re-redeeming the same order is idempotent (no double extension)', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', order1);
    await handleAfdianRedeem(redeemBody, ctx.deps);
    const res = await handleAfdianRedeem(redeemBody, ctx.deps);
    expect(decodeClaims(tokenOf(res)).pro).toBe(NOW + MONTH_SECONDS);
    expect(ctx.store.ents[0].proUntil).toBe(NOW + MONTH_SECONDS);
  });

  it('a webhook-first order is bound on redeem and extends exactly once', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', order1);
    await handleAfdianWebhook({ data: { order: { out_trade_no: 'ord-1' } } }, ctx.deps);
    expect((await ctx.store.getOrder('ord-1'))?.entitlementId).toBeNull();
    const res = await handleAfdianRedeem(redeemBody, ctx.deps);
    expect(decodeClaims(tokenOf(res)).pro).toBe(NOW + MONTH_SECONDS);
    expect((await ctx.store.getOrder('ord-1'))?.entitlementId).toBe(ctx.store.ents[0].id);
  });
});

describe('afdian webhook', () => {
  const push = (no: string) => ({ data: { order: { out_trade_no: no } } });

  it('extends an active entitlement from its current end', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', {
      outTradeNo: 'ord-1',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: NOW,
    });
    await handleAfdianRedeem(
      { order_no: 'ord-1', device_id: 'dev-A', device_class: 'android' },
      ctx.deps,
    );
    ctx.afdianOrders.set('ord-2', {
      outTradeNo: 'ord-2',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: NOW + 10,
    });
    const res = await handleAfdianWebhook(push('ord-2'), ctx.deps);
    expect(res).toEqual({ status: 200, body: { ec: 200 } });
    expect(ctx.store.ents[0].proUntil).toBe(NOW + 2 * MONTH_SECONDS);
  });

  it('is idempotent per order and refuses unverifiable pushes', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-1', {
      outTradeNo: 'ord-1',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: NOW,
    });
    await handleAfdianRedeem(
      { order_no: 'ord-1', device_id: 'dev-A', device_class: 'android' },
      ctx.deps,
    );
    ctx.afdianOrders.set('ord-2', {
      outTradeNo: 'ord-2',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 1,
      paidAt: NOW,
    });
    await handleAfdianWebhook(push('ord-2'), ctx.deps);
    await handleAfdianWebhook(push('ord-2'), ctx.deps); // duplicate
    expect(ctx.store.ents[0].proUntil).toBe(NOW + 2 * MONTH_SECONDS);

    // Not verifiable through query-order → 400, nothing recorded.
    const bad = await handleAfdianWebhook(push('ord-fake'), ctx.deps);
    expect(bad.status).toBe(400);
    expect(await ctx.store.getOrder('ord-fake')).toBeNull();
  });

  it('acks other-plan orders without touching entitlements', async () => {
    const ctx = await setup();
    ctx.afdianOrders.set('ord-x', {
      outTradeNo: 'ord-x',
      userId: 'afd-u1',
      planId: 'unrelated',
      month: 1,
      paidAt: NOW,
    });
    expect(await handleAfdianWebhook(push('ord-x'), ctx.deps)).toEqual({
      status: 200,
      body: { ec: 200 },
    });
    expect(ctx.store.ents).toHaveLength(0);
  });
});

describe('beta redeem', () => {
  const body = { code: 'BETA-1', device_id: 'dev-A', device_class: 'android' };

  it('issues a lifetime pro token (pro=0) and marks the code', async () => {
    const ctx = await setup();
    ctx.store.beta.set('BETA-1', { code: 'BETA-1', email: 't@example.com', redeemedBy: null });
    const res = await handleBetaRedeem(body, ctx.deps);
    const claims = decodeClaims(tokenOf(res));
    expect(claims.chan).toBe('beta');
    expect(claims.sub).toBe('BETA-1');
    expect(claims.pro).toBe(0);
    expect(ctx.store.beta.get('BETA-1')?.redeemedBy).toBe('dev-A');
  });

  it('lifetime entitlement refreshes years later without entitlement_ended', async () => {
    const ctx = await setup();
    ctx.store.beta.set('BETA-1', { code: 'BETA-1', email: null, redeemedBy: null });
    const token = tokenOf(await handleBetaRedeem(body, ctx.deps));
    ctx.clock.t = NOW + 5 * 365 * 86400;
    const res = await handleRefresh({ token, device_id: 'dev-A' }, ctx.deps);
    expect(decodeClaims(tokenOf(res)).pro).toBe(0);
  });

  it('same device may re-redeem; another device is refused; unknown code is refused', async () => {
    const ctx = await setup();
    ctx.store.beta.set('BETA-1', { code: 'BETA-1', email: null, redeemedBy: null });
    await handleBetaRedeem(body, ctx.deps);
    expect((await handleBetaRedeem(body, ctx.deps)).status).toBe(200);
    expect(await handleBetaRedeem({ ...body, device_id: 'dev-B' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'code_redeemed' },
    });
    expect(await handleBetaRedeem({ ...body, code: 'NOPE' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'code_invalid' },
    });
  });
});

describe('admob ssv + vip claim', () => {
  const ssvUrl = (txn: string) =>
    new URL(
      `https://w.example/v1/admob/ssv?ad_network=1&ad_unit=2&reward_amount=1&reward_item=vip` +
        `&timestamp=1&transaction_id=${txn}&user_id=dev-A&signature=sig&key_id=1`,
    );

  it('creates a 3-day vip entitlement and returns an empty 200', async () => {
    const ctx = await setup();
    const res = await handleAdmobSsv(ssvUrl('t1'), ctx.deps);
    expect(res).toEqual({ status: 200, body: null });
    const ent = await ctx.store.getEntitlement('play', 'dev-A');
    expect(ent?.tier).toBe('vip');
    expect(ent?.proUntil).toBe(NOW + 3 * DAY_SECONDS);
  });

  it('a second rewarded ad stacks on top of the remaining vip time', async () => {
    const ctx = await setup();
    await handleAdmobSsv(ssvUrl('t1'), ctx.deps);
    await handleAdmobSsv(ssvUrl('t2'), ctx.deps);
    expect((await ctx.store.getEntitlement('play', 'dev-A'))?.proUntil).toBe(
      NOW + 6 * DAY_SECONDS,
    );
  });

  it('replayed transaction_id grants nothing; bad signature → 403', async () => {
    const ctx = await setup();
    await handleAdmobSsv(ssvUrl('t1'), ctx.deps);
    await handleAdmobSsv(ssvUrl('t1'), ctx.deps); // replay
    expect((await ctx.store.getEntitlement('play', 'dev-A'))?.proUntil).toBe(
      NOW + 3 * DAY_SECONDS,
    );
    ctx.deps.admob.verify = async () => false;
    expect(await handleAdmobSsv(ssvUrl('t3'), ctx.deps)).toEqual({
      status: 403,
      body: { error: 'invalid_signature' },
    });
  });

  it('never downgrades an existing pro entitlement with the same subject', async () => {
    const ctx = await setup();
    await ctx.store.upsertEntitlement({
      channel: 'play',
      subject: 'dev-A',
      tier: 'pro',
      proUntil: NOW + 30 * 86400,
      now: NOW,
    });
    const res = await handleAdmobSsv(ssvUrl('t1'), ctx.deps);
    expect(res).toEqual({ status: 200, body: null });
    const ent = await ctx.store.getEntitlement('play', 'dev-A');
    expect(ent?.tier).toBe('pro');
    expect(ent?.proUntil).toBe(NOW + 30 * 86400);
  });

  it('vip claim: 404 before SSV, token after, 404 again once vip lapses', async () => {
    const ctx = await setup();
    const body = { device_id: 'dev-A', device_class: 'android' };
    expect(await handleVipClaim(body, ctx.deps)).toEqual({ status: 404, body: { error: 'no_vip' } });

    await handleAdmobSsv(ssvUrl('t1'), ctx.deps);
    const res = await handleVipClaim(body, ctx.deps);
    const claims = decodeClaims(tokenOf(res));
    expect(claims).toMatchObject({
      sub: 'dev-A',
      chan: 'play',
      tier: 'vip',
      dev: 'dev-A',
      cls: 'android',
      pro: NOW + 3 * DAY_SECONDS,
    });

    // The vip token refreshes while valid…
    ctx.clock.t = NOW + 2 * DAY_SECONDS;
    const refreshed = await handleRefresh(
      { token: tokenOf(res), device_id: 'dev-A' },
      ctx.deps,
    );
    expect(refreshed.status).toBe(200);

    // …and dies with entitlement_ended after pro_until (no renewal source).
    ctx.clock.t = NOW + 4 * DAY_SECONDS;
    expect(await handleRefresh({ token: tokenOf(res), device_id: 'dev-A' }, ctx.deps)).toEqual({
      status: 403,
      body: { error: 'entitlement_ended' },
    });
    expect(await handleVipClaim(body, ctx.deps)).toEqual({
      status: 404,
      body: { error: 'no_vip' },
    });
  });

  it('vip claim never matches a pro entitlement', async () => {
    const ctx = await setup();
    await ctx.store.upsertEntitlement({
      channel: 'play',
      subject: 'dev-A',
      tier: 'pro',
      proUntil: NOW + 30 * 86400,
      now: NOW,
    });
    expect(await handleVipClaim({ device_id: 'dev-A', device_class: 'android' }, ctx.deps)).toEqual(
      { status: 404, body: { error: 'no_vip' } },
    );
  });
});
