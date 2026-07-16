import { describe, expect, it } from 'vitest';
import { route } from '../src/router';
import { setup } from './helpers';

function post(path: string, body: unknown): Request {
  return new Request(`https://w.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  }) as unknown as Request;
}

describe('router', () => {
  it('404s unknown paths and wrong methods with {error:not_found}', async () => {
    const { deps } = await setup();
    const notFound = await route(
      new Request('https://w.example/nope') as unknown as Request,
      deps,
    );
    expect(notFound.status).toBe(404);
    expect(await notFound.json()).toEqual({ error: 'not_found' });

    const wrongMethod = await route(
      new Request('https://w.example/v1/token/refresh') as unknown as Request,
      deps,
    );
    expect(wrongMethod.status).toBe(404);
  });

  it('400s malformed JSON bodies', async () => {
    const { deps } = await setup();
    const res = await route(post('/v1/token/refresh', '{oops'), deps);
    expect(res.status).toBe(400);
    expect(await res.json()).toEqual({ error: 'bad_request' });
  });

  it('dispatches play verify end-to-end and returns a JSON token', async () => {
    const { deps } = await setup();
    const res = await route(
      post('/v1/play/verify', {
        id_token: 'idtok',
        purchase_token: 'ptok',
        device_id: 'dev-A',
        device_class: 'android',
      }),
      deps,
    );
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toBe('application/json');
    const j = (await res.json()) as { token: string };
    expect(typeof j.token).toBe('string');
  });

  it('dispatches vip claim (404 no_vip when nothing granted)', async () => {
    const { deps } = await setup();
    const res = await route(
      post('/v1/vip/claim', { device_id: 'dev-A', device_class: 'android' }),
      deps,
    );
    expect(res.status).toBe(404);
    expect(await res.json()).toEqual({ error: 'no_vip' });
  });

  it('serves GET /v1/admob/ssv with an empty 200 body', async () => {
    const { deps } = await setup();
    const res = await route(
      new Request(
        'https://w.example/v1/admob/ssv?ad_network=1&transaction_id=t1&user_id=dev-A&signature=s&key_id=1',
      ) as unknown as Request,
      deps,
    );
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('');
  });
});
