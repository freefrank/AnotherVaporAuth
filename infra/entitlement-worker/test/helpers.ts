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
  orders = new Map<string, OrderRow>();
  beta = new Map<string, BetaRow>();
  private nextId = 1;

  async getEntitlement(channel: string, subject: string): Promise<EntitlementRow | null> {
    const e = this.ents.find((e) => e.channel === channel && e.subject === subject);
    return e ? { ...e } : null;
  }

  async upsertEntitlement(i: UpsertEntitlementInput): Promise<EntitlementRow> {
    let e = this.ents.find((e) => e.channel === i.channel && e.subject === i.subject);
    if (e) {
      e.tier = i.tier;
      e.proUntil = i.proUntil;
      if (i.playPurchaseToken !== undefined) e.playPurchaseToken = i.playPurchaseToken;
    } else {
      e = {
        id: this.nextId++,
        channel: i.channel,
        subject: i.subject,
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
      verifyIdToken: async () => ({ sub: 'google-sub-1' }),
      getSubscription: async () => ({ valid: true, expiresAt: clock.t + 30 * 86400 }),
    },
    afdian: {
      queryOrder: async (no) => afdianOrders.get(no) ?? null,
    },
    admob: { verify: async () => true },
    config: { afdianPlanId: () => 'plan-pro', vipDays: async () => 3 },
    replay: {
      seenTransaction: async (id) => {
        if (seenTxns.has(id)) return true;
        seenTxns.add(id);
        return false;
      },
    },
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
