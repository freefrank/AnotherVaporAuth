import { describe, expect, it } from 'vitest';
import { afdianSign, createAfdian } from '../src/afdian';

const NOW = 1_800_000_000;

function makeClient(orders: Record<string, object>, opts: { ec?: number } = {}) {
  const requests: { url: string; body: Record<string, unknown> }[] = [];
  const fetcher = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
    requests.push({ url: String(input), body });
    const params = JSON.parse(String(body.params)) as { out_trade_no: string };
    const order = orders[params.out_trade_no];
    return new Response(
      JSON.stringify({ ec: opts.ec ?? 200, data: { list: order ? [order] : [] } }),
    );
  }) as unknown as typeof fetch;
  const client = createAfdian({ userId: 'afd-dev', token: 'secret-token', fetcher, now: () => NOW });
  return { client, requests };
}

describe('afdian queryOrder', () => {
  it('signs the request correctly and maps a paid order', async () => {
    const { client, requests } = makeClient({
      'ord-1': {
        out_trade_no: 'ord-1',
        user_id: 'afd-u1',
        plan_id: 'plan-pro',
        month: 2,
        status: 2,
        create_time: NOW - 60,
      },
    });
    const order = await client.queryOrder('ord-1');
    expect(order).toEqual({
      outTradeNo: 'ord-1',
      userId: 'afd-u1',
      planId: 'plan-pro',
      month: 2,
      paidAt: NOW - 60,
    });
    const req = requests[0];
    expect(req.url).toBe('https://afdian.com/api/open/query-order');
    expect(req.body.user_id).toBe('afd-dev');
    expect(req.body.sign).toBe(
      afdianSign('secret-token', 'afd-dev', String(req.body.params), Number(req.body.ts)),
    );
  });

  it('returns null for missing orders, unpaid orders, and API errors', async () => {
    const { client } = makeClient({});
    expect(await client.queryOrder('nope')).toBeNull();

    const unpaid = makeClient({
      'ord-1': { out_trade_no: 'ord-1', user_id: 'u', plan_id: 'p', month: 1, status: 1 },
    });
    expect(await unpaid.client.queryOrder('ord-1')).toBeNull();

    const apiErr = makeClient(
      { 'ord-1': { out_trade_no: 'ord-1', user_id: 'u', plan_id: 'p', month: 1, status: 2 } },
      { ec: 400 },
    );
    expect(await apiErr.client.queryOrder('ord-1')).toBeNull();
  });

  it('defaults month to 1 when absent', async () => {
    const { client } = makeClient({
      'ord-1': { out_trade_no: 'ord-1', user_id: 'u', plan_id: 'p', status: 2 },
    });
    expect((await client.queryOrder('ord-1'))?.month).toBe(1);
  });
});
