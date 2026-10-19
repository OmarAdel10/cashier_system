/**
 * AuthClient Tests
 *
 * Covers verify delegating to verifyFirebaseToken with the projectId and
 * returning the result.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AuthClient } from '../auth-client';
import { verifyFirebaseToken } from 'daftari-backend-shared/jwt';
import type { FirebaseTokenResult } from 'daftari-backend-shared/jwt';

const FIXED_NOW = 1_700_000_000_000;

vi.mock('daftari-backend-shared/jwt', () => ({
  verifyFirebaseToken: vi.fn(),
}));

describe('AuthClient', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
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
});
