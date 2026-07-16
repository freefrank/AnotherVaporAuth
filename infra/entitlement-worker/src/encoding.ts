// Base64 / base64url / JSON segment helpers shared by jwt, google, admob.

export function utf8(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

export function bytesToB64(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

/** Standard-alphabet base64 → bytes; tolerant of whitespace and padding. */
export function b64ToBytes(s: string): Uint8Array | null {
  try {
    const bin = atob(s.replace(/\s+/g, ''));
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  } catch {
    return null;
  }
}

/** base64url without padding (JWT segment encoding). */
export function bytesToB64url(bytes: Uint8Array): string {
  return bytesToB64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** base64url → bytes; accepts missing or present padding. */
export function b64urlToBytes(s: string): Uint8Array | null {
  const std = s.replace(/-/g, '+').replace(/_/g, '/');
  const pad = std.length % 4 === 0 ? '' : '='.repeat(4 - (std.length % 4));
  return b64ToBytes(std + pad);
}

export function jsonToB64url(v: unknown): string {
  return bytesToB64url(utf8(JSON.stringify(v)));
}

/** Decodes a base64url JSON segment to an object; null on any failure. */
export function b64urlToJsonObject(s: string): Record<string, unknown> | null {
  const bytes = b64urlToBytes(s);
  if (!bytes) return null;
  try {
    const v: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return typeof v === 'object' && v !== null && !Array.isArray(v)
      ? (v as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}
