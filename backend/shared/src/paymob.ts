/**
 * Paymob HMAC verification (per Paymob docs, June 2026).
 *
 * Algorithm: HMAC-SHA512 over the 20 documented transaction fields,
 * concatenated in lexicographic order, compared with the `hmac` value
 * Paymob appends to the callback URL query parameters.
 */

/** The 20 HMAC fields in the documented lexicographic order. */
const HMAC_FIELDS = [
  'amount_cents',
  'created_at',
  'currency',
  'error_occured',
  'has_parent_transaction',
  'id', // obj.id for Processed (POST) callbacks
  'integration_id',
  'is_3d_secure',
  'is_auth',
  'is_capture',
  'is_refunded',
  'is_standalone_payment',
  'is_voided',
  'order.id',
  'owner',
  'pending',
  'source_data.pan',
  'source_data.sub_type',
  'source_data.type',
  'success',
] as const;

/** Renders a field value the way Paymob concatenates it: booleans as
 *  true/false, numbers as plain digits, null/undefined/objects as ''. */
function renderValue(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string') return value;
  return '';
}

/** Reads a dotted path (e.g. 'order.id', 'source_data.pan') from obj. */
function readPath(obj: Record<string, unknown>, path: string): unknown {
  let cursor: unknown = obj;
  for (const part of path.split('.')) {
    if (cursor === null || cursor === undefined) return undefined;
    cursor = (cursor as Record<string, unknown>)[part];
  }
  return cursor;
}

/** Builds the concatenated HMAC string from a transaction `obj`. */
export function buildPaymobHmacString(obj: Record<string, unknown>): string {
  let out = '';
  for (const field of HMAC_FIELDS) {
    out += renderValue(readPath(obj, field));
  }
  return out;
}

/** Constant-time-ish comparison of two equal-length hex strings. */
function secureHexEqual(a: string, b: string): boolean {
  const aLower = a.toLowerCase();
  const bLower = b.toLowerCase();
  if (aLower.length !== bLower.length) return false;
  let diff = 0;
  for (let i = 0; i < aLower.length; i++) {
    diff |= aLower.charCodeAt(i) ^ bLower.charCodeAt(i);
  }
  return diff === 0;
}

/** Verifies the concatenated string against the hex HMAC using HMAC-SHA512. */
export async function verifyPaymobHmac(
  concatenated: string,
  signatureHex: string,
  secret: string,
): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-512' },
      false,
      ['sign'],
    );
    const sigBuf = await crypto.subtle.sign(
      'HMAC',
      key,
      new TextEncoder().encode(concatenated),
    );
    const actual = Array.from(new Uint8Array(sigBuf))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
    return secureHexEqual(actual, signatureHex);
  } catch {
    return false;
  }
}
