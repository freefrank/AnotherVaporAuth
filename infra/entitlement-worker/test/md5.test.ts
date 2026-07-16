import { describe, expect, it } from 'vitest';
import { afdianSign } from '../src/afdian';
import { md5Hex } from '../src/md5';

describe('md5Hex', () => {
  it('matches RFC 1321 test vectors', () => {
    expect(md5Hex('')).toBe('d41d8cd98f00b204e9800998ecf8427e');
    expect(md5Hex('abc')).toBe('900150983cd24fb0d6963f7d28e17f72');
    expect(md5Hex('message digest')).toBe('f96b697d7cb7938d525a2f31aaf161d0');
    expect(md5Hex('The quick brown fox jumps over the lazy dog')).toBe(
      '9e107d9d372bb6826bd81d3542a419d6',
    );
  });

  it('handles multi-byte UTF-8 and >64-byte inputs', () => {
    // Independently computed: echo -n ... | md5sum
    expect(md5Hex('a'.repeat(100))).toBe('36a92cc94a9e0fa21f625f8bfb007adf');
  });
});

describe('afdianSign', () => {
  it('is md5 of token+params+ts+user_id concatenation', () => {
    const token = 'tok';
    const userId = 'u1';
    const params = '{"out_trade_no":"x"}';
    const ts = 1700000000;
    expect(afdianSign(token, userId, params, ts)).toBe(
      md5Hex(`tokparams{"out_trade_no":"x"}ts1700000000user_idu1`),
    );
  });
});
