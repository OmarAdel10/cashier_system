import { describe, expect, it, vi } from 'vitest';
import { postHogBatch } from './analytics';

describe('postHogBatch', () => {
  it('sends one POST to the PostHog batch endpoint with api_key + events', async () => {
    const fetchFn = vi.fn(() =>
      Promise.resolve(new Response('{"status": "Ok"}', { status: 200 })),
    );
    const events = [{ event: 'payment_success', properties: { tenant_id: 't1' } }];

    const result = await postHogBatch('phc_test_key', events, fetchFn);

    expect(result.ok).toBe(true);
    expect(fetchFn).toHaveBeenCalledTimes(1);
    const [url, init] = fetchFn.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toContain('/batch/');
    expect(init.method).toBe('POST');
    const body = JSON.parse(init.body as string) as { api_key: string; batch: unknown[] };
    expect(body.api_key).toBe('phc_test_key');
    expect(body.batch).toHaveLength(1);
  });

  it('reports retryable on 5xx', async () => {
    const fetchFn = vi.fn(() => Promise.resolve(new Response('boom', { status: 500 })));
    const result = await postHogBatch('phc_key', [{ event: 'e', properties: {} }], fetchFn);
    expect(result.ok).toBe(false);
    expect(result.retryable).toBe(true);
  });

  it('reports non-retryable on 4xx', async () => {
    const fetchFn = vi.fn(() => Promise.resolve(new Response('bad', { status: 400 })));
    const result = await postHogBatch('phc_key', [{ event: 'e', properties: {} }], fetchFn);
    expect(result.ok).toBe(false);
    expect(result.retryable).toBe(false);
  });

  it('reports retryable on network error', async () => {
    const fetchFn = vi.fn(() => Promise.reject(new Error('offline')));
    const result = await postHogBatch('phc_key', [{ event: 'e', properties: {} }], fetchFn);
    expect(result.ok).toBe(false);
    expect(result.retryable).toBe(true);
  });

  it('sends distinct_id and timestamp with each event', async () => {
    const fetchFn = vi.fn(() =>
      Promise.resolve(new Response('{"status": "Ok"}', { status: 200 })),
    );
    await postHogBatch(
      'phc_key',
      [{ event: 'sale_synced', properties: { tenant_id: 't1', total: 5000 } }],
      fetchFn,
    );
    const [, init] = fetchFn.mock.calls[0] as unknown as [string, RequestInit];
    const body = JSON.parse(init.body as string) as {
      batch: Array<{ event: string; distinct_id: string; timestamp: string }>;
    };
    expect(body.batch[0]!.event).toBe('sale_synced');
    expect(body.batch[0]!.distinct_id).toBe('t1');
    expect(typeof body.batch[0]!.timestamp).toBe('string');
  });
});
