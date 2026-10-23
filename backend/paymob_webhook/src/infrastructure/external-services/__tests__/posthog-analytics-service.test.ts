/**
 * Unit tests for PostHogAnalyticsService.
 */
import { describe, expect, it, vi } from 'vitest';
import { PostHogAnalyticsService } from '../posthog-analytics-service';

describe('PostHogAnalyticsService', () => {
  it('capture sends event to PostHog', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response('ok'));
    const service = new PostHogAnalyticsService(fetchFn, 'test-api-key');

    await service.capture({
      event: 'payment_success',
      distinct_id: 'tenant-1',
      properties: { transaction_id: 'txn_1' },
    });

    expect(fetchFn).toHaveBeenCalledTimes(1);
    const [url, options] = fetchFn.mock.calls[0] ?? [];
    expect(url).toBe('https://us.i.posthog.com/capture/');
    expect(options.method).toBe('POST');
    const body = JSON.parse((options as { body: string }).body);
    expect(body.api_key).toBe('test-api-key');
    expect(body.event).toBe('payment_success');
    expect(body.distinct_id).toBe('tenant-1');
  });

  it('capture uses default timestamp when none provided', async () => {
    const fetchFn = vi.fn().mockResolvedValue(new Response('ok'));
    const service = new PostHogAnalyticsService(fetchFn, 'test-api-key');

    await service.capture({
      event: 'payment_success',
      distinct_id: 'tenant-1',
      properties: { transaction_id: 'txn_1' },
      // No timestamp provided — should use default
    } as any);

    expect(fetchFn).toHaveBeenCalledTimes(1);
    const [, options] = fetchFn.mock.calls[0] ?? [];
    const body = JSON.parse((options as { body: string }).body);
    expect(body.timestamp).toBeDefined();
  });

  it('capture swallows fetch errors', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new Error('network error'));
    const service = new PostHogAnalyticsService(fetchFn, 'test-api-key');

    // Should not throw
    await expect(
      service.capture({
        event: 'payment_success',
        distinct_id: 'tenant-1',
        properties: { transaction_id: 'txn_1' },
      }),
    ).resolves.toBeUndefined();
  });
});
