// AdMob rewarded-ad server-side verification (SSV), per
// https://developers.google.com/admob/android/ssv :
//   - the message is the raw query string up to (excluding) `&signature=`
//   - `signature` is websafe-base64 DER-encoded ECDSA-SHA256
//   - public keys rotate at https://www.gstatic.com/admob/reward/verifier-keys.json
//     (cache them; match on key_id)

import { b64ToBytes, b64urlToBytes, utf8 } from './encoding';

const VERIFIER_KEYS_URL = 'https://www.gstatic.com/admob/reward/verifier-keys.json';
const KV_KEY = 'admob_verifier_keys';
const KEYS_TTL_SECONDS = 86400;

interface VerifierKey {
  keyId: number | string;
  pem?: string;
  base64?: string; // DER SPKI
}

export interface AdmobConfig {
  /** KV namespace used to cache the verifier keys across isolates (optional). */
  kv?: KVNamespace;
  fetcher?: typeof fetch;
  now?: () => number;
}

/** DER ECDSA-Sig-Value → raw 64-byte r||s (IEEE P1363) that WebCrypto expects. */
export function derToP1363(der: Uint8Array): Uint8Array | null {
  if (der.length < 8 || der[0] !== 0x30) return null;
  let o = 2;
  if (der[1] & 0x80) o = 2 + (der[1] & 0x7f);
  const readInt = (): Uint8Array | null => {
    if (o + 2 > der.length || der[o] !== 0x02) return null;
    const len = der[o + 1];
    o += 2;
    if (o + len > der.length) return null;
    let v = der.slice(o, o + len);
    o += len;
    while (v.length > 32 && v[0] === 0) v = v.slice(1);
    if (v.length > 32) return null;
    const out = new Uint8Array(32);
    out.set(v, 32 - v.length);
    return out;
  };
  const r = readInt();
  const s = readInt();
  if (!r || !s) return null;
  const raw = new Uint8Array(64);
  raw.set(r, 0);
  raw.set(s, 32);
  return raw;
}

export function createAdmob(cfg: AdmobConfig = {}): { verify(url: URL): Promise<boolean> } {
  const fetcher = cfg.fetcher ?? ((...args: Parameters<typeof fetch>) => fetch(...args));
  const now = cfg.now ?? (() => Math.floor(Date.now() / 1000));

  let memCache: { keys: VerifierKey[]; fetchedAt: number } | null = null;

  async function verifierKeys(): Promise<VerifierKey[]> {
    const t = now();
    if (memCache && t - memCache.fetchedAt < KEYS_TTL_SECONDS) return memCache.keys;
    if (cfg.kv) {
      const cached = await cfg.kv.get<{ keys: VerifierKey[] }>(KV_KEY, 'json');
      if (cached?.keys) {
        memCache = { keys: cached.keys, fetchedAt: t };
        return cached.keys;
      }
    }
    const res = await fetcher(VERIFIER_KEYS_URL);
    if (!res.ok) throw new Error(`verifier-keys fetch failed: ${res.status}`);
    const j = (await res.json()) as { keys?: VerifierKey[] };
    const keys = j.keys ?? [];
    memCache = { keys, fetchedAt: t };
    if (cfg.kv) {
      await cfg.kv.put(KV_KEY, JSON.stringify({ keys }), { expirationTtl: KEYS_TTL_SECONDS });
    }
    return keys;
  }

  async function verify(url: URL): Promise<boolean> {
    try {
      const qs = url.search.startsWith('?') ? url.search.slice(1) : url.search;
      // Google appends &signature=...&key_id=... last; the signed message is
      // the verbatim query string before &signature= (no re-encoding).
      const cut = qs.indexOf('&signature=');
      if (cut <= 0) return false;
      const message = utf8(qs.slice(0, cut));

      const sigParam = url.searchParams.get('signature');
      const keyId = url.searchParams.get('key_id');
      if (!sigParam || !keyId) return false;
      const der = b64urlToBytes(sigParam);
      if (!der) return false;
      const raw = derToP1363(der);
      if (!raw) return false;

      const key = (await verifierKeys()).find((k) => String(k.keyId) === keyId);
      if (!key?.base64) return false;
      const spki = b64ToBytes(key.base64);
      if (!spki) return false;
      const publicKey = await crypto.subtle.importKey(
        'spki',
        spki,
        { name: 'ECDSA', namedCurve: 'P-256' },
        false,
        ['verify'],
      );
      return await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, raw, message);
    } catch {
      return false;
    }
  }

  return { verify };
}
