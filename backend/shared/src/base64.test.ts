import { describe, expect, it } from 'vitest';
import { b64ToBytes, b64urlToJson, bytesToB64url } from './base64';

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
});
