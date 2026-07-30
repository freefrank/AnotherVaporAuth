// Google module against fully faked HTTP: a locally generated RSA key plays
// both the JWKS signing key (id_token path) and the service account key
// (Play subscription path).

import { describe, expect, it } from 'vitest';
import { bytesToB64, bytesToB64url, jsonToB64url, utf8 } from '../src/encoding';
import { createGoogle } from '../src/google';

const NOW = 1_800_000_000;
const RS256 = {
  name: 'RSASSA-PKCS1-v1_5',
  modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]),
  hash: 'SHA-256',
} as const;

async function makeRsa() {
  const kp = (await crypto.subtle.generateKey(RS256, true, ['sign', 'verify'])) as CryptoKeyPair;
  const jwk = (await crypto.subtle.exportKey('jwk', kp.publicKey)) as JsonWebKey & {
    kid?: string;
  };
  jwk.kid = 'kid-1';
  const pkcs8 = new Uint8Array(
    (await crypto.subtle.exportKey('pkcs8', kp.privateKey)) as ArrayBuffer,
  );
  return { kp, jwk, pkcs8Base64: bytesToB64(pkcs8) };
}

async function signJwt(kp: CryptoKeyPair, header: object, claims: object): Promise<string> {
  const h = jsonToB64url(header);
  const p = jsonToB64url(claims);
  const sig = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', kp.privateKey, utf8(`${h}.${p}`)),
  );
  return `${h}.${p}.${bytesToB64url(sig)}`;
}

const ID_CLAIMS = {
  iss: 'https://accounts.google.com',
  sub: 'g-sub-42',
  aud: 'client-1',
  exp: NOW + 3600,
};

interface FakeBackend {
  subscription?: object;
  subscriptionStatus?: number;
}

function makeFetcher(jwk: JsonWebKey, backend: FakeBackend) {
  const calls: string[] = [];
  const fetcher = (async (input: RequestInfo | URL) => {
    const url = String(input);
    calls.push(url);
    if (url.includes('/oauth2/v3/certs')) {
      return new Response(JSON.stringify({ keys: [jwk] }));
    }
    if (url.includes('oauth2.googleapis.com/token')) {
      return new Response(JSON.stringify({ access_token: 'at-1', expires_in: 3600 }));
    }
    if (url.includes('androidpublisher')) {
      return new Response(JSON.stringify(backend.subscription ?? {}), {
        status: backend.subscriptionStatus ?? 200,
      });
    }
    return new Response('not found', { status: 404 });
  }) as unknown as typeof fetch;
  return { fetcher, calls };
}

async function makeGoogle(backend: FakeBackend = {}, clientId = 'client-1') {
  const rsa = await makeRsa();
  const { fetcher, calls } = makeFetcher(rsa.jwk, backend);
  const google = createGoogle({
    saEmail: 'sa@example.iam.gserviceaccount.com',
    saKey: `-----BEGIN PRIVATE KEY-----\n${rsa.pkcs8Base64}\n-----END PRIVATE KEY-----\n`,
    packageName: 'pro.dotslash.ava',
    clientId,
    fetcher,
    now: () => NOW,
  });
  return { google, rsa, calls };
}

describe('verifyIdToken', () => {
  it('accepts a valid RS256 id_token and returns sub', async () => {
    const { google, rsa } = await makeGoogle();
    const token = await signJwt(rsa.kp, { alg: 'RS256', kid: 'kid-1' }, ID_CLAIMS);
    expect(await google.verifyIdToken(token)).toEqual({ sub: 'g-sub-42' });
  });

  it('rejects wrong issuer, expiry, unknown kid, tampering, and aud mismatch', async () => {
    const { google, rsa } = await makeGoogle({}, 'client-1');
    const bad = async (h: object, c: object) =>
      google.verifyIdToken(await signJwt(rsa.kp, h, c));
    const H = { alg: 'RS256', kid: 'kid-1' };
    expect(await bad(H, { ...ID_CLAIMS, iss: 'https://evil.example' })).toBeNull();
    expect(await bad(H, { ...ID_CLAIMS, exp: NOW - 1 })).toBeNull();
    expect(await bad({ alg: 'RS256', kid: 'other' }, ID_CLAIMS)).toBeNull();
    expect(await bad(H, { ...ID_CLAIMS, aud: 'someone-else' })).toBeNull();

    const good = await signJwt(rsa.kp, H, ID_CLAIMS);
    const [h, , s] = good.split('.');
    const forged = `${h}.${jsonToB64url({ ...ID_CLAIMS, sub: 'attacker' })}.${s}`;
    expect(await google.verifyIdToken(forged)).toBeNull();
  });

  it('fails closed when clientId is unset — never skips the aud check', async () => {
    // A dropped/renamed GOOGLE_CLIENT_ID must break loudly, not quietly turn
    // audience pinning off and accept any Google-issued id_token.
    const { google, rsa } = await makeGoogle({}, '');
    const token = await signJwt(rsa.kp, { alg: 'RS256', kid: 'kid-1' }, ID_CLAIMS);
    expect(await google.verifyIdToken(token)).toBeNull();
  });
});

describe('getSubscription', () => {
  it('maps an active subscriptionsv2 response to valid + expiry epoch', async () => {
    const { google, calls } = await makeGoogle({
      subscription: {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [{ expiryTime: '2027-01-01T00:00:00Z' }],
      },
    });
    expect(await google.getSubscription('ptok')).toEqual({
      valid: true,
      expiresAt: Math.floor(Date.parse('2027-01-01T00:00:00Z') / 1000),
    });
    // exercised the SA OAuth exchange first
    expect(calls.some((u) => u.includes('oauth2.googleapis.com/token'))).toBe(true);
    expect(calls.some((u) => u.includes('/purchases/subscriptionsv2/tokens/ptok'))).toBe(true);
  });

  it('treats expired/paused/missing subscriptions as invalid', async () => {
    const expired = await makeGoogle({ subscriptionStatus: 404 });
    expect(await expired.google.getSubscription('ptok')).toEqual({ valid: false, expiresAt: 0 });

    const paused = await makeGoogle({
      subscription: {
        subscriptionState: 'SUBSCRIPTION_STATE_PAUSED',
        lineItems: [{ expiryTime: '2027-01-01T00:00:00Z' }],
      },
    });
    expect((await paused.google.getSubscription('ptok')).valid).toBe(false);
  });

  it('caches the service-account access token', async () => {
    const { google, calls } = await makeGoogle({
      subscription: {
        subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
        lineItems: [{ expiryTime: '2027-01-01T00:00:00Z' }],
      },
    });
    await google.getSubscription('a');
    await google.getSubscription('b');
    expect(calls.filter((u) => u.includes('oauth2.googleapis.com/token'))).toHaveLength(1);
  });
});
