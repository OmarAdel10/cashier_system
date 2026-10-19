/**
 * AuthClient Tests
 *
 * Covers verify delegating to verifyFirebaseToken with the projectId and
 * returning the result, plus error propagation.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AuthClient } from '../auth-client';
import { verifyFirebaseToken } from 'daftari-backend-shared/jwt';
import type { FirebaseTokenResult } from 'daftari-backend-shared/jwt';

vi.mock('daftari-backend-shared/jwt', () => ({
  verifyFirebaseToken: vi.fn(),
}));

describe('AuthClient', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('delegates to verifyFirebaseToken with the projectId and returns the result', async () => {
    const result: FirebaseTokenResult = {
      valid: true,
      uid: 'uid-1',
      email: 'owner@example.com',
    };
    (verifyFirebaseToken as ReturnType<typeof vi.fn>).mockResolvedValue(
      result,
    );

    const client = new AuthClient('test-project');
    const output = await client.verify('id-token-1');

    expect(verifyFirebaseToken).toHaveBeenCalledWith(
      'id-token-1',
      'test-project',
    );
    expect(output).toEqual(result);
  });

  it('propagates verifyFirebaseToken rejection', async () => {
    (verifyFirebaseToken as ReturnType<typeof vi.fn>).mockRejectedValue(
      new Error('jwks fetch failed'),
    );

    const client = new AuthClient('test-project');
    await expect(client.verify('id-token-1')).rejects.toThrow(
      'jwks fetch failed',
    );
  });
});
