import { describe, expect, it } from 'vitest';
import { b64ToBytes, b64urlToJson, bytesToB64, bytesToB64url } from './base64';

describe('base64 helpers (Workers-pure: no Buffer)', () => {
  it('roundtrips arbitrary bytes through base64url', () => {
    const bytes = new Uint8Array([0, 1, 2, 250, 251, 255, 77]);
    const encoded = bytesToB64url(bytes);
    expect(encoded).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(b64ToBytes(encoded)).toEqual(bytes);
  });

  it('roundtrips a utf8 JSON string via b64urlToJson', () => {
    const obj = { tenant_id: 't1', amount: 5000, arabic: 'مرحبا' };
    const encoded = bytesToB64url(new TextEncoder().encode(JSON.stringify(obj)));
    expect(b64urlToJson(encoded)).toEqual(obj);
  });

  it('handles empty input', () => {
    expect(bytesToB64url(new Uint8Array(0))).toBe('');
    expect(b64ToBytes('')).toEqual(new Uint8Array(0));
  });

  it('encodes standard padded base64 (dkLen-32 hashes are 44 chars)', () => {
    const bytes = new Uint8Array(32).fill(0xab);
    const encoded = bytesToB64(bytes);
    expect(encoded).toHaveLength(44);
    expect(encoded).toMatch(/^[A-Za-z0-9+/]+={0,2}$/);
    expect(b64ToBytes(encoded)).toEqual(bytes);
  });

  it('handles empty and multi-chunk input in standard base64', () => {
    expect(bytesToB64(new Uint8Array(0))).toBe('');
    const big = new Uint8Array(0x8001);
    for (let i = 0; i < big.length; i++) big[i] = i & 0xff;
    expect(b64ToBytes(bytesToB64(big))).toEqual(big);
  });
});
