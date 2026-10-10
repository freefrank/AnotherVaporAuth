// Afdian open-platform client (query-order). All calls go through an
// injectable fetcher; business logic only sees `queryOrder`.

import type { AfdianOrder } from './logic';
import { md5Hex } from './md5';

const API_QUERY_ORDER = 'https://afdian.com/api/open/query-order';

/**
 * Request signature: md5 of `token` + the request's kv pairs concatenated in
 * alphabetical key order as `key + value` — i.e. md5("{token}params{params}ts{ts}user_id{user_id}").
 * Verified against the live API 2026-07-16 (ping → ec:200 pong, query-order
 * → ec:200) with the production credentials; the error debug.kv_string also
 * echoes exactly this concatenation.
 */
export function afdianSign(token: string, userId: string, params: string, ts: number): string {
  return md5Hex(`${token}params${params}ts${ts}user_id${userId}`);
}

export interface AfdianConfig {
  userId: string;
  token: string;
  fetcher?: typeof fetch;
  now?: () => number;
}

interface AfdianApiOrder {
  out_trade_no?: string;
  user_id?: string;
  plan_id?: string;
  month?: number | string;
  status?: number | string;
  create_time?: number | string;
}

/** One page of the creator's orders, newest first (50 per page). */
export interface AfdianOrderPage {
  /** Paid orders that carry a buyer and a plan; custom-amount orders
   * (empty plan_id) and unpaid ones are left out. */
  orders: AfdianOrder[];
  totalPage: number;
}

export interface AfdianClient {
  queryOrder(outTradeNo: string): Promise<AfdianOrder | null>;
  listOrders(page: number): Promise<AfdianOrderPage | null>;
}

/** A paid order with a buyer and a plan, or null. `status` 2 is "paid" per
 * the developer guide (guide.afdian.com/creator/developer). */
function toOrder(o: AfdianApiOrder, fallbackTs: number): AfdianOrder | null {
  if (!o.out_trade_no || !o.user_id || !o.plan_id) return null;
  if (o.status !== undefined && Number(o.status) !== 2) return null;
  return {
    outTradeNo: String(o.out_trade_no),
    userId: String(o.user_id),
    planId: String(o.plan_id),
    month: Number(o.month) || 1,
    paidAt: Number(o.create_time) || fallbackTs,
  };
}

export function createAfdian(cfg: AfdianConfig): AfdianClient {
  const fetcher = cfg.fetcher ?? ((...args: Parameters<typeof fetch>) => fetch(...args));
  const now = cfg.now ?? (() => Math.floor(Date.now() / 1000));

  /** Signed query-order call; null on any transport or API error. */
  async function call(
    query: Record<string, unknown>,
    ts: number,
  ): Promise<{ list?: AfdianApiOrder[]; total_page?: number | string } | null> {
    const params = JSON.stringify(query);
    const res = await fetcher(API_QUERY_ORDER, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        user_id: cfg.userId,
        params,
        ts,
        sign: afdianSign(cfg.token, cfg.userId, params, ts),
      }),
    });
    if (!res.ok) return null;
    const j = (await res.json()) as {
      ec?: number;
      data?: { list?: AfdianApiOrder[]; total_page?: number | string };
    };
    return j.ec === 200 ? (j.data ?? {}) : null;
  }

  async function queryOrder(outTradeNo: string): Promise<AfdianOrder | null> {
    try {
      const ts = now();
      const data = await call({ out_trade_no: outTradeNo }, ts);
      const order = (data?.list ?? []).find((o) => o.out_trade_no === outTradeNo);
      return order ? toOrder(order, ts) : null;
    } catch {
      return null;
    }
  }

  async function listOrders(page: number): Promise<AfdianOrderPage | null> {
    try {
      const ts = now();
      const data = await call({ page }, ts);
      if (!data) return null;
      const orders: AfdianOrder[] = [];
      for (const o of data.list ?? []) {
        const order = toOrder(o, ts);
        if (order) orders.push(order);
      }
      return { orders, totalPage: Number(data.total_page) || 1 };
    } catch {
      return null;
    }
  }

  return { queryOrder, listOrders };
}
