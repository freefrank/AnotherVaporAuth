import { describe, expect, it } from 'vitest';
import { b64urlToJsonObject, bytesToB64, bytesToB64url, utf8 } from '../src/encoding';
import {
  createTokenService,
  importSigningKeys,
  signToken,
  verifyToken,
  type TokenClaims,
} from '../src/jwt';
import { NOW } from './helpers';

const CLAIMS: TokenClaims = {
  sub: 'subject-1',
  chan: 'play',
  tier: 'pro',
  dev: 'device-1',
  cls: 'android',
  iat: NOW,
  exp: NOW + 86400,
  pro: NOW + 30 * 86400,
};

async function makeKeys() {
  const kp = (await crypto.subtle.generateKey({ name: 'Ed25519' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const pkcs8 = new Uint8Array(
    (await crypto.subtle.exportKey('pkcs8', kp.privateKey)) as ArrayBuffer,
  );
  return { kp, pkcs8Base64: bytesToB64(pkcs8) };
}

describe('Ed25519 JWT', () => {
  it('round-trips claims through the pkcs8 secret import path', async () => {
    const { pkcs8Base64 } = await makeKeys();
    const keys = await importSigningKeys(pkcs8Base64);
    const token = await signToken(CLAIMS, keys.privateKey);
    expect(await verifyToken(token, keys.publicKey)).toEqual(CLAIMS);
  });

  it('verifies with the original keypair public key (derived x is correct)', async () => {
    const { kp, pkcs8Base64 } = await makeKeys();
    const keys = await importSigningKeys(pkcs8Base64);
    const token = await signToken(CLAIMS, keys.privateKey);
    const [h, p, s] = token.split('.');
    const sig = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/') + '=='), (c) =>
      c.charCodeAt(0),
    );
    expect(
      await crypto.subtle.verify({ name: 'Ed25519' }, kp.publicKey, sig, utf8(`${h}.${p}`)),
    ).toBe(true);
  });

  it('emits header {alg:EdDSA, typ:JWT} and padding-free base64url', async () => {
    const keys = await importSigningKeys((await makeKeys()).pkcs8Base64);
    const token = await signToken(CLAIMS, keys.privateKey);
    expect(token).not.toContain('=');
    expect(token.split('.')).toHaveLength(3);
    expect(b64urlToJsonObject(token.split('.')[0])).toEqual({ alg: 'EdDSA', typ: 'JWT' });
    // signature is exactly 64 bytes, as the Dart client requires
    expect(token.split('.')[2]).toHaveLength(86);
  });

  it('rejects a tampered payload and a tampered signature', async () => {
    const keys = await importSigningKeys((await makeKeys()).pkcs8Base64);
    const token = await signToken(CLAIMS, keys.privateKey);
    const [h, p, s] = token.split('.');
    const forgedPayload = bytesToB64url(utf8(JSON.stringify({ ...CLAIMS, tier: 'vip' })));
    expect(await verifyToken(`${h}.${forgedPayload}.${s}`, keys.publicKey)).toBeNull();
    // Flip the FIRST char: the last one holds base64 padding bits, so a flip
    // there can decode to the very same 64 bytes and (flakily) still verify.
    const flipped = (s.startsWith('A') ? 'B' : 'A') + s.slice(1);
    expect(await verifyToken(`${h}.${p}.${flipped}`, keys.publicKey)).toBeNull();
  });

  it('rejects algorithm confusion (alg none / HS256)', async () => {
    const keys = await importSigningKeys((await makeKeys()).pkcs8Base64);
    const token = await signToken(CLAIMS, keys.privateKey);
    const [, p, s] = token.split('.');
    for (const alg of ['none', 'HS256']) {
      const h = bytesToB64url(utf8(JSON.stringify({ alg, typ: 'JWT' })));
      expect(await verifyToken(`${h}.${p}.${s}`, keys.publicKey)).toBeNull();
    }
  });

  it('rejects tokens signed by a different key', async () => {
    const a = await importSigningKeys((await makeKeys()).pkcs8Base64);
    const b = await importSigningKeys((await makeKeys()).pkcs8Base64);
    const token = await signToken(CLAIMS, a.privateKey);
    expect(await verifyToken(token, b.publicKey)).toBeNull();
  });

  it('rejects structural garbage and bad claim types', async () => {
    const keys = await importSigningKeys((await makeKeys()).pkcs8Base64);
    expect(await verifyToken('not-a-jwt', keys.publicKey)).toBeNull();
    expect(await verifyToken('a.b', keys.publicKey)).toBeNull();
    const svc = createTokenService(keys);
    const bad = await svc.sign({ ...CLAIMS, pro: -5 });
    expect(await svc.verify(bad)).toBeNull();
  });

  it('accepts expired tokens (refresh needs structure+signature only)', async () => {
    const keys = await importSigningKeys((await makeKeys()).pkcs8Base64);
    const svc = createTokenService(keys);
    const expired = await svc.sign({ ...CLAIMS, iat: NOW - 90 * 86400, exp: NOW - 89 * 86400 });
    expect(await svc.verify(expired)).not.toBeNull();
  });
});
