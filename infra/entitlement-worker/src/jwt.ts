// EdDSA (Ed25519) JWT issue/verify — the token contract mirrored by the app's
// app/lib/src/core/entitlement.dart. Keep the claim set in sync.

import { b64ToBytes, b64urlToBytes, b64urlToJsonObject, bytesToB64url, jsonToB64url, utf8 } from './encoding';

export interface TokenClaims {
  /** Subject: Google sub / Afdian user_id / beta code / device_id (vip). */
  sub: string;
  /** Channel: 'play' | 'afdian' | 'beta'. */
  chan: string;
  /** 'pro' | 'vip' (vip = rewarded-ad temporary unlock). */
  tier: string;
  /** Bound device id. */
  dev: string;
  /** Device class: 'android' | 'windows' | 'linux' | 'macos'. */
  cls: string;
  /** Issued-at, epoch seconds. */
  iat: number;
  /** Refresh deadline (iat + 24h), epoch seconds. */
  exp: number;
  /** Entitlement end, epoch seconds; 0 = lifetime. */
  pro: number;
}

const ED25519: { name: 'Ed25519' } = { name: 'Ed25519' };
const HEADER = jsonToB64url({ alg: 'EdDSA', typ: 'JWT' });

export interface SigningKeys {
  privateKey: CryptoKey;
  publicKey: CryptoKey;
}

/**
 * Imports the worker's signing secret: a standard-base64 PKCS#8 Ed25519
 * private key (`openssl pkey -outform DER | base64 -w0`). The verify half is
 * derived by exporting the private key as JWK — both Node and workerd fill in
 * the public `x` coordinate.
 */
export async function importSigningKeys(pkcs8Base64: string): Promise<SigningKeys> {
  const der = b64ToBytes(pkcs8Base64);
  if (!der) throw new Error('ENTITLEMENT_SIGNING_KEY is not valid base64');
  const privateKey = await crypto.subtle.importKey('pkcs8', der, ED25519, true, ['sign']);
  const jwk = (await crypto.subtle.exportKey('jwk', privateKey)) as JsonWebKey;
  if (!jwk.x) throw new Error('could not derive Ed25519 public key from private key');
  const publicKey = await crypto.subtle.importKey(
    'jwk',
    { kty: 'OKP', crv: 'Ed25519', x: jwk.x },
    ED25519,
    true,
    ['verify'],
  );
  return { privateKey, publicKey };
}

export async function signToken(claims: TokenClaims, privateKey: CryptoKey): Promise<string> {
  const payload = jsonToB64url(claims);
  const msg = utf8(`${HEADER}.${payload}`);
  const sig = new Uint8Array(await crypto.subtle.sign(ED25519, privateKey, msg));
  return `${HEADER}.${payload}.${bytesToB64url(sig)}`;
}

/**
 * Structural + signature verification only — `exp` is deliberately NOT
 * checked: /v1/token/refresh accepts expired-but-authentic tokens.
 * Returns null on any structural, type, or signature problem.
 */
export async function verifyToken(raw: string, publicKey: CryptoKey): Promise<TokenClaims | null> {
  const parts = raw.split('.');
  if (parts.length !== 3) return null;

  const header = b64urlToJsonObject(parts[0]);
  // Exact-match the algorithm: anything else (none, HS256, …) is an
  // algorithm-confusion attempt or garbage.
  if (!header || header['alg'] !== 'EdDSA') return null;

  const claims = b64urlToJsonObject(parts[1]);
  if (!claims) return null;

  const sig = b64urlToBytes(parts[2]);
  if (!sig || sig.length !== 64) return null;

  const msg = utf8(`${parts[0]}.${parts[1]}`);
  let ok = false;
  try {
    ok = await crypto.subtle.verify(ED25519, publicKey, sig, msg);
  } catch {
    return null;
  }
  if (!ok) return null;

  const { sub, chan, tier, dev, cls, iat, exp, pro } = claims as Record<string, unknown>;
  if (typeof sub !== 'string' || typeof chan !== 'string' || typeof tier !== 'string') return null;
  if (typeof dev !== 'string' || typeof cls !== 'string') return null;
  if (typeof iat !== 'number' || typeof exp !== 'number' || typeof pro !== 'number') return null;
  if (!Number.isInteger(iat) || !Number.isInteger(exp) || !Number.isInteger(pro) || pro < 0) return null;

  return { sub, chan, tier, dev, cls, iat, exp, pro };
}

export interface TokenService {
  sign(claims: TokenClaims): Promise<string>;
  verify(raw: string): Promise<TokenClaims | null>;
}

export function createTokenService(keys: SigningKeys): TokenService {
  return {
    sign: (claims) => signToken(claims, keys.privateKey),
    verify: (raw) => verifyToken(raw, keys.publicKey),
  };
}
