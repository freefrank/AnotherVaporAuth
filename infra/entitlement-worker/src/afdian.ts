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

export function createAfdian(cfg: AfdianConfig): { queryOrder(outTradeNo: string): Promise<AfdianOrder | null> } {
  const fetcher = cfg.fetcher ?? ((...args: Parameters<typeof fetch>) => fetch(...args));
  const now = cfg.now ?? (() => Math.floor(Date.now() / 1000));

  async function queryOrder(outTradeNo: string): Promise<AfdianOrder | null> {
    try {
      const ts = now();
      const params = JSON.stringify({ out_trade_no: outTradeNo });
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
        data?: { list?: AfdianApiOrder[] };
      };
      if (j.ec !== 200) return null;
      const order = (j.data?.list ?? []).find((o) => o.out_trade_no === outTradeNo);
      if (!order || !order.user_id || !order.plan_id) return null;
      // TODO(launch): confirm the paid-status value (2) and the paid-time
      // field name against the Afdian docs; query-order may only ever return
      // completed orders, in which case the status check is a no-op.
      if (order.status !== undefined && Number(order.status) !== 2) return null;
      return {
        outTradeNo,
        userId: String(order.user_id),
        planId: String(order.plan_id),
        month: Number(order.month) || 1,
        paidAt: Number(order.create_time) || ts,
      };
    } catch {
      return null;
    }
  }

  return { queryOrder };
}
