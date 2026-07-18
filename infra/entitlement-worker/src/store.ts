// Data-access layer: a Store interface so the business logic never touches
// D1 directly (tests use an in-memory implementation), plus the D1-backed
// production implementation.

export interface EntitlementRow {
  id: number;
  channel: string;
  subject: string;
  tier: string;
  /** Epoch seconds; 0 = lifetime. */
  proUntil: number;
  revoked: boolean;
  createdAt: number;
  /** Play purchase token, kept for re-verification on refresh. */
  playPurchaseToken: string | null;
}

export interface DeviceRow {
  entitlementId: number;
  deviceClass: string;
  deviceId: string;
  activatedAt: number;
}

export interface OrderRow {
  outTradeNo: string;
  userId: string;
  planId: string;
  paidAt: number;
  /** NULL while the order is known (webhook) but not yet redeemed in-app. */
  entitlementId: number | null;
}

export interface BetaRow {
  code: string;
  email: string | null;
  redeemedBy: string | null;
}

export interface UpsertEntitlementInput {
  channel: string;
  subject: string;
  tier: string;
  proUntil: number;
  now: number;
  /** When set, replaces the stored token; when omitted, the stored one is kept. */
  playPurchaseToken?: string;
}

export interface Store {
  getEntitlement(channel: string, subject: string): Promise<EntitlementRow | null>;
  /** Insert or update on (channel, subject). Never resets `revoked` or `created_at`. */
  upsertEntitlement(input: UpsertEntitlementInput): Promise<EntitlementRow>;
  setProUntil(id: number, proUntil: number): Promise<void>;

  getDevice(entitlementId: number, deviceClass: string): Promise<DeviceRow | null>;
  /** REPLACE semantics: the previous holder of this class slot is kicked. */
  claimDevice(entitlementId: number, deviceClass: string, deviceId: string, now: number): Promise<void>;
  /** All class slots of one entitlement, ordered by device_class. */
  listDevices(entitlementId: number): Promise<DeviceRow[]>;
  /** Atomic admission for a bounded slot REPLACE: appends an activation_log
   * row only while the (entitlement, class) count with activated_at > since
   * is below `cap`, in ONE conditional INSERT so concurrent redeems cannot
   * race past the bound. Returns whether the row was written (= admitted);
   * only then may the caller REPLACE the devices slot. Bounded flows only —
   * empty-slot claims and same-device re-claims must not go through here. */
  tryLogActivation(
    entitlementId: number,
    deviceClass: string,
    deviceId: string,
    now: number,
    since: number,
    cap: number,
  ): Promise<boolean>;
  /** activation_log rows for (entitlement, class) with activated_at > since. */
  countRecentActivations(entitlementId: number, deviceClass: string, since: number): Promise<number>;

  getOrder(outTradeNo: string): Promise<OrderRow | null>;
  recordOrder(order: OrderRow): Promise<void>;
  bindOrder(outTradeNo: string, entitlementId: number): Promise<void>;

  getBetaCode(code: string): Promise<BetaRow | null>;
  redeemBetaCode(code: string, redeemedBy: string): Promise<void>;
}

interface EntitlementDbRow {
  id: number;
  channel: string;
  subject: string;
  tier: string;
  pro_until: number;
  revoked: number;
  created_at: number;
  play_purchase_token: string | null;
}

export class D1Store implements Store {
  constructor(private readonly db: D1Database) {}

  private static ent(r: EntitlementDbRow): EntitlementRow {
    return {
      id: r.id,
      channel: r.channel,
      subject: r.subject,
      tier: r.tier,
      proUntil: r.pro_until,
      revoked: r.revoked !== 0,
      createdAt: r.created_at,
      playPurchaseToken: r.play_purchase_token ?? null,
    };
  }

  async getEntitlement(channel: string, subject: string): Promise<EntitlementRow | null> {
    const r = await this.db
      .prepare('SELECT * FROM entitlements WHERE channel = ?1 AND subject = ?2')
      .bind(channel, subject)
      .first<EntitlementDbRow>();
    return r ? D1Store.ent(r) : null;
  }

  async upsertEntitlement(input: UpsertEntitlementInput): Promise<EntitlementRow> {
    const r = await this.db
      .prepare(
        `INSERT INTO entitlements (channel, subject, tier, pro_until, created_at, play_purchase_token)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)
         ON CONFLICT(channel, subject) DO UPDATE SET
           tier = excluded.tier,
           pro_until = excluded.pro_until,
           play_purchase_token = COALESCE(excluded.play_purchase_token, entitlements.play_purchase_token)
         RETURNING *`,
      )
      .bind(
        input.channel,
        input.subject,
        input.tier,
        input.proUntil,
        input.now,
        input.playPurchaseToken ?? null,
      )
      .first<EntitlementDbRow>();
    if (!r) throw new Error('upsertEntitlement returned no row');
    return D1Store.ent(r);
  }

  async setProUntil(id: number, proUntil: number): Promise<void> {
    await this.db
      .prepare('UPDATE entitlements SET pro_until = ?2 WHERE id = ?1')
      .bind(id, proUntil)
      .run();
  }

  async getDevice(entitlementId: number, deviceClass: string): Promise<DeviceRow | null> {
    const r = await this.db
      .prepare('SELECT * FROM devices WHERE entitlement_id = ?1 AND device_class = ?2')
      .bind(entitlementId, deviceClass)
      .first<{ entitlement_id: number; device_class: string; device_id: string; activated_at: number }>();
    return r
      ? {
          entitlementId: r.entitlement_id,
          deviceClass: r.device_class,
          deviceId: r.device_id,
          activatedAt: r.activated_at,
        }
      : null;
  }

  async claimDevice(
    entitlementId: number,
    deviceClass: string,
    deviceId: string,
    now: number,
  ): Promise<void> {
    await this.db
      .prepare(
        `INSERT OR REPLACE INTO devices (entitlement_id, device_class, device_id, activated_at)
         VALUES (?1, ?2, ?3, ?4)`,
      )
      .bind(entitlementId, deviceClass, deviceId, now)
      .run();
  }

  async listDevices(entitlementId: number): Promise<DeviceRow[]> {
    const rs = await this.db
      .prepare('SELECT * FROM devices WHERE entitlement_id = ?1 ORDER BY device_class')
      .bind(entitlementId)
      .all<{ entitlement_id: number; device_class: string; device_id: string; activated_at: number }>();
    return rs.results.map((r) => ({
      entitlementId: r.entitlement_id,
      deviceClass: r.device_class,
      deviceId: r.device_id,
      activatedAt: r.activated_at,
    }));
  }

  async tryLogActivation(
    entitlementId: number,
    deviceClass: string,
    deviceId: string,
    now: number,
    since: number,
    cap: number,
  ): Promise<boolean> {
    // Count and append in one statement: SQLite serializes writes, so at most
    // `cap` concurrent admissions win per (entitlement, class, window).
    const r = await this.db
      .prepare(
        `INSERT INTO activation_log (entitlement_id, device_class, device_id, activated_at)
         SELECT ?1, ?2, ?3, ?4
         WHERE (SELECT COUNT(*) FROM activation_log
                WHERE entitlement_id = ?1 AND device_class = ?2 AND activated_at > ?5) < ?6`,
      )
      .bind(entitlementId, deviceClass, deviceId, now, since, cap)
      .run();
    return r.meta.changes > 0;
  }

  async countRecentActivations(
    entitlementId: number,
    deviceClass: string,
    since: number,
  ): Promise<number> {
    const r = await this.db
      .prepare(
        `SELECT COUNT(*) AS n FROM activation_log
         WHERE entitlement_id = ?1 AND device_class = ?2 AND activated_at > ?3`,
      )
      .bind(entitlementId, deviceClass, since)
      .first<{ n: number }>();
    return r?.n ?? 0;
  }

  async getOrder(outTradeNo: string): Promise<OrderRow | null> {
    const r = await this.db
      .prepare('SELECT * FROM afdian_orders WHERE out_trade_no = ?1')
      .bind(outTradeNo)
      .first<{
        out_trade_no: string;
        user_id: string;
        plan_id: string;
        paid_at: number;
        entitlement_id: number | null;
      }>();
    return r
      ? {
          outTradeNo: r.out_trade_no,
          userId: r.user_id,
          planId: r.plan_id,
          paidAt: r.paid_at,
          entitlementId: r.entitlement_id ?? null,
        }
      : null;
  }

  async recordOrder(order: OrderRow): Promise<void> {
    await this.db
      .prepare(
        `INSERT OR IGNORE INTO afdian_orders (out_trade_no, user_id, plan_id, paid_at, entitlement_id)
         VALUES (?1, ?2, ?3, ?4, ?5)`,
      )
      .bind(order.outTradeNo, order.userId, order.planId, order.paidAt, order.entitlementId)
      .run();
  }

  async bindOrder(outTradeNo: string, entitlementId: number): Promise<void> {
    await this.db
      .prepare('UPDATE afdian_orders SET entitlement_id = ?2 WHERE out_trade_no = ?1')
      .bind(outTradeNo, entitlementId)
      .run();
  }

  async getBetaCode(code: string): Promise<BetaRow | null> {
    const r = await this.db
      .prepare('SELECT * FROM beta_testers WHERE code = ?1')
      .bind(code)
      .first<{ code: string; email: string | null; redeemed_by: string | null }>();
    return r ? { code: r.code, email: r.email ?? null, redeemedBy: r.redeemed_by ?? null } : null;
  }

  async redeemBetaCode(code: string, redeemedBy: string): Promise<void> {
    await this.db
      .prepare('UPDATE beta_testers SET redeemed_by = ?2 WHERE code = ?1 AND redeemed_by IS NULL')
      .bind(code, redeemedBy)
      .run();
  }
}
