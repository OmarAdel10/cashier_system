/**
 * AnalyticsClient Tests
 *
 * Covers success (no throw), non-ok batch (throws), and fetchFn injection
 * with exact payload assertion.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { AnalyticsClient } from '../analytics-client';
import type { PostHogEvent } from 'daftari-backend-shared/analytics';

const FIXED_NOW = 1_700_000_000_000;

const events: PostHogEvent[] = [
  { event: 'page_view', properties: { tenant_id: 'tenant-1' } },
];

describe('AnalyticsClient', () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn().mockResolvedValue({ ok: true } as Response);
    vi.stubGlobal('fetch', fetchMock);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it('does not throw when postHogBatch succeeds', async () => {
    const client = new AnalyticsClient('api-key-1');
    await expect(client.batch(events)).resolves.toBeUndefined();

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledWith(
      'https://us.i.posthog.com/batch/',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          api_key: 'api-key-1',
          batch: [
            {
              event: 'page_view',
              properties: { tenant_id: 'tenant-1' },
              distinct_id: 'tenant-1',
              timestamp: new Date(FIXED_NOW).toISOString(),
            },
          ],
        }),
      },
    );
  });

  it('throws when the batch is not ok', async () => {
    fetchMock.mockResolvedValueOnce({ ok: false, status: 503 } as Response);
    const client = new AnalyticsClient('api-key-1');
    await expect(client.batch(events)).rejects.toThrow(
      'analytics batch failed',
    );
  });
});
