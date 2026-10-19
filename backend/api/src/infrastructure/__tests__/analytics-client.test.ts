/**
 * AnalyticsClient Tests
 *
 * Covers success (returns ok batch result), non-ok batch (propagates retryable),
 * empty event batch, multiple events, and fetchFn injection with exact payload
 * assertion.
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

  it('returns ok batch result when postHogBatch succeeds', async () => {
    const client = new AnalyticsClient('api-key-1');
    await expect(client.batch(events)).resolves.toEqual({
      ok: true,
      retryable: false,
    });

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

  it('returns non-ok batch result with retryable flag', async () => {
    fetchMock.mockResolvedValueOnce({ ok: false, status: 503 } as Response);
    const client = new AnalyticsClient('api-key-1');
    await expect(client.batch(events)).resolves.toEqual({
      ok: false,
      retryable: true,
    });
  });

  it('resolves empty batch without error', async () => {
    const client = new AnalyticsClient('api-key-1');
    await expect(client.batch([])).resolves.toEqual({
      ok: true,
      retryable: false,
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock).toHaveBeenCalledWith(
      'https://us.i.posthog.com/batch/',
      expect.objectContaining({
        body: JSON.stringify({ api_key: 'api-key-1', batch: [] }),
      }),
    );
  });

  it('maps multiple events into the batch array', async () => {
    const multiEvents: PostHogEvent[] = [
      { event: 'page_view', properties: { tenant_id: 'tenant-1' } },
      { event: 'click', properties: { tenant_id: 'tenant-2' } },
    ];
    const client = new AnalyticsClient('api-key-1');
    await expect(client.batch(multiEvents)).resolves.toEqual({
      ok: true,
      retryable: false,
    });

    const body = JSON.parse(
      (fetchMock.mock.calls[0]?.[1] as { body: string }).body,
    );
    expect(body.batch).toHaveLength(2);
    expect(body.batch[0].event).toBe('page_view');
    expect(body.batch[1].event).toBe('click');
  });
});
