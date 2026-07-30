// Google integrations: id_token verification (RS256 against Google's JWKS)
// and Play Developer API subscription lookup via a service-account OAuth
// token. All network I/O goes through an injectable fetcher.
//
// TODO(launch): verify against the official docs before go-live —
//   - subscriptionsv2 response shape (subscriptionState values, lineItems[].expiryTime)
//   - the acknowledgement requirement (purchases.subscriptions must be
//     acknowledged within 3 days or Play auto-refunds)

import { b64ToBytes, b64urlToBytes, b64urlToJsonObject, bytesToB64url, jsonToB64url, utf8 } from './encoding';
import type { GoogleSubscription } from './logic';

const JWKS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const ANDROID_PUBLISHER = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

const RS256 = { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' } as const;

export interface GoogleConfig {
  saEmail: string;
  /** Service-account private key: PEM ("-----BEGIN PRIVATE KEY-----") or bare base64 PKCS#8. */
  saKey: string;
  packageName: string;
  /** The app's Web OAuth client id. Required: id_token `aud` is pinned to it,
   * and an absent value fails verification rather than skipping the check. */
  clientId: string;
  fetcher?: typeof fetch;
  now?: () => number;
}

interface GoogleJwk extends JsonWebKey {
  kid?: string;
}

export function createGoogle(cfg: GoogleConfig): {
  verifyIdToken(idToken: string): Promise<{ sub: string } | null>;
  getSubscription(purchaseToken: string): Promise<GoogleSubscription>;
} {
  const fetcher = cfg.fetcher ?? ((...args: Parameters<typeof fetch>) => fetch(...args));
  const now = cfg.now ?? (() => Math.floor(Date.now() / 1000));

  let jwksCache: { keys: GoogleJwk[]; fetchedAt: number } | null = null;
  let accessTokenCache: { token: string; expiresAt: number } | null = null;
  let saKeyPromise: Promise<CryptoKey> | null = null;

  async function jwks(): Promise<GoogleJwk[]> {
    if (jwksCache && now() - jwksCache.fetchedAt < 3600) return jwksCache.keys;
    const res = await fetcher(JWKS_URL);
    if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`);
    const j = (await res.json()) as { keys?: GoogleJwk[] };
    jwksCache = { keys: j.keys ?? [], fetchedAt: now() };
    return jwksCache.keys;
  }

  async function verifyIdToken(idToken: string): Promise<{ sub: string } | null> {
    try {
      const parts = idToken.split('.');
      if (parts.length !== 3) return null;
      const header = b64urlToJsonObject(parts[0]);
      if (!header || header['alg'] !== 'RS256') return null;

      const jwk = (await jwks()).find((k) => k.kid === header['kid']);
      if (!jwk) return null;
      const key = await crypto.subtle.importKey(
        'jwk',
        { kty: jwk.kty, n: jwk.n, e: jwk.e },
        RS256,
        false,
        ['verify'],
      );
      const sig = b64urlToBytes(parts[2]);
      if (!sig) return null;
      const okSig = await crypto.subtle.verify(
        RS256.name,
        key,
        sig,
        utf8(`${parts[0]}.${parts[1]}`),
      );
      if (!okSig) return null;

      const claims = b64urlToJsonObject(parts[1]);
      if (!claims) return null;
      const iss = claims['iss'];
      if (iss !== 'https://accounts.google.com' && iss !== 'accounts.google.com') return null;
      const exp = claims['exp'];
      if (typeof exp !== 'number' || exp <= now()) return null;
      // Audience pinning is unconditional. Guarding this on `cfg.clientId`
      // being set would mean a deleted/renamed GOOGLE_CLIENT_ID silently
      // removes an authentication check instead of breaking loudly — the
      // token would then only have to be *some* Google id_token, not one
      // issued to this app (OIDC token substitution).
      if (!cfg.clientId || claims['aud'] !== cfg.clientId) return null;
      const sub = claims['sub'];
      if (typeof sub !== 'string' || sub.length === 0) return null;
      return { sub };
    } catch {
      return null;
    }
  }

  function importSaKey(): Promise<CryptoKey> {
    saKeyPromise ??= (async () => {
      const stripped = cfg.saKey
        .replace(/-----(?:BEGIN|END) PRIVATE KEY-----/g, '')
        .replace(/\\n/g, '')
        .replace(/\s+/g, '');
      const der = b64ToBytes(stripped);
      if (!der) throw new Error('GOOGLE_SA_KEY is not a valid PEM/base64 PKCS#8 key');
      return crypto.subtle.importKey('pkcs8', der, RS256, false, ['sign']);
    })();
    return saKeyPromise;
  }

  /** OAuth 2.0 JWT-bearer flow for the service account. */
  async function accessToken(): Promise<string> {
    const t = now();
    if (accessTokenCache && accessTokenCache.expiresAt - 60 > t) return accessTokenCache.token;
    const key = await importSaKey();
    const header = jsonToB64url({ alg: 'RS256', typ: 'JWT' });
    const payload = jsonToB64url({
      iss: cfg.saEmail,
      scope: SCOPE,
      aud: TOKEN_URL,
      iat: t,
      exp: t + 3600,
    });
    const sig = new Uint8Array(
      await crypto.subtle.sign(RS256.name, key, utf8(`${header}.${payload}`)),
    );
    const assertion = `${header}.${payload}.${bytesToB64url(sig)}`;
    const res = await fetcher(TOKEN_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body:
        'grant_type=' +
        encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer') +
        '&assertion=' +
        encodeURIComponent(assertion),
    });
    if (!res.ok) throw new Error(`SA token exchange failed: ${res.status}`);
    const j = (await res.json()) as { access_token?: string; expires_in?: number };
    if (!j.access_token) throw new Error('SA token exchange returned no access_token');
    accessTokenCache = { token: j.access_token, expiresAt: t + (j.expires_in ?? 3600) };
    return j.access_token;
  }

  async function getSubscription(purchaseToken: string): Promise<GoogleSubscription> {
    try {
      const token = await accessToken();
      const url =
        `${ANDROID_PUBLISHER}/applications/${encodeURIComponent(cfg.packageName)}` +
        `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
      const res = await fetcher(url, { headers: { authorization: `Bearer ${token}` } });
      if (!res.ok) return { valid: false, expiresAt: 0 };
      const j = (await res.json()) as {
        subscriptionState?: string;
        lineItems?: { expiryTime?: string }[];
      };
      // Canceled-but-not-expired users keep access until expiryTime; the
      // caller additionally compares expiresAt against `now`.
      const okStates = [
        'SUBSCRIPTION_STATE_ACTIVE',
        'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        'SUBSCRIPTION_STATE_CANCELED',
      ];
      let expiresAt = 0;
      for (const li of j.lineItems ?? []) {
        const t = Date.parse(li.expiryTime ?? '');
        if (!Number.isNaN(t)) expiresAt = Math.max(expiresAt, Math.floor(t / 1000));
      }
      const valid = okStates.includes(j.subscriptionState ?? '') && expiresAt > 0;
      return { valid, expiresAt };
    } catch {
      return { valid: false, expiresAt: 0 };
    }
  }

  return { verifyIdToken, getSubscription };
}
