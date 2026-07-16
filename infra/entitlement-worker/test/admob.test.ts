// Exercises the real ECDSA verification path with a locally generated P-256
// key: sign the query string exactly the way Google does (DER signature,
// websafe base64) and check acceptance/rejection.

import { describe, expect, it } from 'vitest';
import { createAdmob, derToP1363 } from '../src/admob';
import { bytesToB64, bytesToB64url, utf8 } from '../src/encoding';

const KEY_ID = 3335741209;

function derInt(v: Uint8Array): number[] {
  let i = 0;
  while (i < v.length - 1 && v[i] === 0) i++;
  let body = Array.from(v.slice(i));
  if (body[0] & 0x80) body = [0, ...body];
  return [0x02, body.length, ...body];
}

/** raw r||s → DER ECDSA-Sig-Value (what Google actually sends). */
function p1363ToDer(raw: Uint8Array): Uint8Array {
  const r = derInt(raw.slice(0, 32));
  const s = derInt(raw.slice(32));
  return new Uint8Array([0x30, r.length + s.length, ...r, ...s]);
}

async function makeVerifier() {
  const kp = (await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const spki = new Uint8Array(
    (await crypto.subtle.exportKey('spki', kp.publicKey)) as ArrayBuffer,
  );
  let fetches = 0;
  const fetcher = (async () => {
    fetches++;
    return new Response(JSON.stringify({ keys: [{ keyId: KEY_ID, base64: bytesToB64(spki) }] }));
  }) as unknown as typeof fetch;
  const admob = createAdmob({ fetcher, now: () => 1_800_000_000 });
  return { kp, admob, fetchCount: () => fetches };
}

async function signedUrl(kp: CryptoKeyPair, qs: string, keyId = KEY_ID): Promise<URL> {
  const raw = new Uint8Array(
    await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, kp.privateKey, utf8(qs)),
  );
  const sig = bytesToB64url(p1363ToDer(raw));
  return new URL(`https://w.example/v1/admob/ssv?${qs}&signature=${sig}&key_id=${keyId}`);
}

const QS =
  'ad_network=5450213213286189855&ad_unit=1234567890&reward_amount=1&reward_item=vip' +
  '&timestamp=150777823&transaction_id=abc123&user_id=dev-1';

describe('admob ssv verification', () => {
  it('accepts a genuine signature', async () => {
    const { kp, admob } = await makeVerifier();
    expect(await admob.verify(await signedUrl(kp, QS))).toBe(true);
  });

  it('rejects a tampered message (user_id swapped after signing)', async () => {
    const { kp, admob } = await makeVerifier();
    const url = await signedUrl(kp, QS);
    const tampered = new URL(url.toString().replace('user_id=dev-1', 'user_id=dev-2'));
    expect(await admob.verify(tampered)).toBe(false);
  });

  it('rejects an unknown key_id and a missing signature', async () => {
    const { kp, admob } = await makeVerifier();
    expect(await admob.verify(await signedUrl(kp, QS, 999))).toBe(false);
    expect(await admob.verify(new URL(`https://w.example/v1/admob/ssv?${QS}`))).toBe(false);
  });

  it('caches the verifier keys across calls', async () => {
    const { kp, admob, fetchCount } = await makeVerifier();
    await admob.verify(await signedUrl(kp, QS));
    await admob.verify(await signedUrl(kp, QS));
    expect(fetchCount()).toBe(1);
  });
});

describe('derToP1363', () => {
  it('round-trips through the test DER encoder, including leading-zero cases', async () => {
    for (let i = 0; i < 8; i++) {
      const raw = new Uint8Array(64);
      crypto.getRandomValues(raw);
      raw[0] = i % 2 === 0 ? 0 : raw[0]; // exercise short-integer encoding
      expect(derToP1363(p1363ToDer(raw))).toEqual(raw);
    }
  });

  it('rejects malformed DER', () => {
    expect(derToP1363(new Uint8Array([0x31, 0x02, 0x02, 0x01]))).toBeNull();
    expect(derToP1363(new Uint8Array(0))).toBeNull();
  });
});
