/**
 * Base64 / base64url helpers — pure Web APIs (btoa/atob), available in both
 * Cloudflare Workers and Node 16+. No Buffer dependency (Workers-pure).
 */

/** Encodes bytes to base64url (RFC 4648 §5: - and _ instead of + and /). */
export function bytesToB64url(bytes: Uint8Array): string {
  if (bytes.length === 0) return '';
  let binary = '';
  const chunkSize = 0x8000; // avoid call-stack limits on large arrays
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Decodes base64url (or standard base64) to bytes. */
export function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  if (b64.length === 0) return new Uint8Array(0);
  const normalized = b64.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

/** Decodes a base64url string into a parsed JSON object. */
export function b64urlToJson(b64: string): Record<string, unknown> {
  return JSON.parse(new TextDecoder().decode(b64ToBytes(b64))) as Record<string, unknown>;
}
