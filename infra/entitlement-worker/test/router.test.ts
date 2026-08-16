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

  it('dispatches entitlement status (403 invalid_token on garbage)', async () => {
    const { deps } = await setup();
    const res = await route(post('/v1/entitlement/status', { token: 'garbage' }), deps);
    expect(res.status).toBe(403);
    expect(await res.json()).toEqual({ error: 'invalid_token' });
  });

  it('429s the redeem endpoints once the per-IP budget is spent', async () => {
    const keys: string[] = [];
    const { deps } = await setup({
      rateLimit: {
        allow: async (k) => {
          keys.push(k);
          return false;
        },
      },
    });
    for (const path of ['/v1/beta/redeem', '/v1/afdian/redeem']) {
      const res = await route(post(path, { code: 'AVA-BETA-00000000' }), deps);
      expect(res.status).toBe(429);
      expect(await res.json()).toEqual({ error: 'rate_limited' });
    }
    expect(keys).toEqual(['redeem:unknown', 'redeem:unknown']);
  });

  it('keys the redeem limit on the client IP, and leaves token endpoints alone', async () => {
    const keys: string[] = [];
    const { deps } = await setup({
      rateLimit: {
        allow: async (k) => {
          keys.push(k);
          return true;
        },
      },
    });
    const withIp = (path: string) =>
      new Request(`https://w.example${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'cf-connecting-ip': '203.0.113.7' },
        body: JSON.stringify({ code: 'AVA-BETA-00000000' }),
      }) as unknown as Request;

    await route(withIp('/v1/beta/redeem'), deps);
    expect(keys).toEqual(['redeem:203.0.113.7']);

    // A signature-bearing endpoint is not guessable, so it is not throttled.
    await route(withIp('/v1/token/refresh'), deps);
    expect(keys).toEqual(['redeem:203.0.113.7']);
  });

  it('413s a body larger than the cap, before parsing it', async () => {
    // The per-field checks live downstream of JSON.parse, so without this an
    // unauthenticated caller could spend the isolate's CPU on megabytes.
    const { deps } = await setup();
    const huge = 'x'.repeat(40 * 1024);
    const res = await route(post('/v1/token/refresh', { token: huge }), deps);
    expect(res.status).toBe(413);
    expect(await res.json()).toEqual({ error: 'body_too_large' });
  });

  it('413s on a declared Content-Length over the cap even if the body is small',
    async () => {
      const { deps } = await setup();
      const req = new Request('https://w.example/v1/token/refresh', {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'content-length': '999999' },
        body: JSON.stringify({ token: 'small' }),
      }) as unknown as Request;
      const res = await route(req, deps);
      expect(res.status).toBe(413);
    });

  it('a normal-sized body still gets through', async () => {
    const { deps } = await setup();
    const res = await route(post('/v1/entitlement/status', { token: 'garbage' }), deps);
    expect(res.status).toBe(403); // reached the handler, not the size gate
  });

  it('sets HSTS on every response, including the empty-bodied one', async () => {
    // The custom domain answers plain HTTP too, and these responses carry
    // entitlement tokens.
    const { deps } = await setup();
    const json = await route(post('/v1/entitlement/status', { token: 'x' }), deps);
    expect(json.headers.get('strict-transport-security'))
      .toBe('max-age=63072000; includeSubDomains');

    const empty = await route(
      new Request(
        'https://w.example/v1/admob/ssv?ad_network=1&transaction_id=t1&user_id=dev-A&signature=s&key_id=1',
      ) as unknown as Request,
      deps,
    );
    expect(await empty.text()).toBe('');
    expect(empty.headers.get('strict-transport-security')).toBeTruthy();
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

describe('GET /v1/version', () => {
  it('answers with a per-channel version table and edge caching', async () => {
    const { deps } = await setup();
    const res = await route(
      new Request('https://w.example/v1/version') as unknown as Request,
      deps,
    );
    expect(res.status).toBe(200);
    expect(res.headers.get('cache-control')).toBe('public, max-age=3600');
    const body = (await res.json()) as { channels: Record<string, { version: string }> };
    // Every key a client can ask about. macos-dmg joined with the first
    // published DMG (v1.2, 2026-08-15) — the rule stands that a key exists
    // only for artifacts that are actually downloadable.
    for (const k of ['android-play', 'android-cn', 'windows-portable', 'windows-setup', 'linux-appimage', 'macos-dmg']) {
      expect(body.channels[k].version).toMatch(/^\d+\.\d+\.\d+$/);
    }
  });
});
