import { describe, it, expect, vi } from 'vitest';

const executeMock = vi.fn().mockResolvedValue({ rows: [], columns: [], rowsAffected: 0 });
vi.mock('@libsql/client', () => ({
  createClient: vi.fn(() => ({ execute: executeMock })),
}));

import { createApp } from '../src/index';

describe('debug temp', () => {
  it('sync-user', async () => {
    const verifyTokenStub = async (t: string) => t === 't1' ? { valid: true, uid: 'u1' } : { valid: false };
    const env = {
      PAYMOB_HMAC_SECRET: 'x', ED25519_PRIVATE_KEY: 'x', ED25519_PUBLIC_KEY: 'x',
      FIREBASE_PROJECT_ID: 'p', TURSO_DATABASE_URL: 'https://x.turso.io', TURSO_AUTH_TOKEN: 'x',
      POSTHOG_API_KEY: 'x', REALTIME: { notify: async () => {} }, LOGOS: { put: async () => {}, },
    };
    const app = createApp({ verifyToken: verifyTokenStub as any });
    const res = await app.request('/auth/sync-user', { method: 'POST', headers: { Authorization: 'Bearer t1' } }, env as any);
    console.log('STATUS:', res.status);
    expect(res.status).toBe(401);
  });
});
