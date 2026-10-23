/**
 * Unit tests for InMemoryWebhookEventRepository.
 *
 * Tests insert, findByTransactionId, idempotency, size-limit eviction,
 * and TTL sweep.
 */
import { describe, expect, it, vi } from 'vitest';
import { InMemoryWebhookEventRepository } from '../in-memory-webhook-event-repository';
import type { NewWebhookEvent } from '../../../domain/entities/webhook-event';

const baseEvent: NewWebhookEvent = {
  transactionId: 'txn_1',
  success: true,
  isRefunded: false,
  isVoided: false,
  tenantId: 'tenant-1',
  deviceHwid: 'device-abc',
  billingCycle: 'monthly',
  receivedAt: Date.now(),
};

describe('InMemoryWebhookEventRepository', () => {
  it('insert stores and findByTransactionId retrieves', async () => {
    const repo = new InMemoryWebhookEventRepository();
    const inserted = await repo.insert(baseEvent);
    expect(inserted).toBe(true);

    const found = await repo.findByTransactionId('txn_1');
    expect(found).toEqual(baseEvent);
  });

  it('insert returns false for duplicate transactionId', async () => {
    const repo = new InMemoryWebhookEventRepository();
    await repo.insert(baseEvent);
    const inserted = await repo.insert(baseEvent);
    expect(inserted).toBe(false);
  });

  it('findByTransactionId returns null for missing transaction', async () => {
    const repo = new InMemoryWebhookEventRepository();
    const found = await repo.findByTransactionId('nonexistent');
    expect(found).toBeNull();
  });

  it('evicts oldest entry when maxSize reached', async () => {
    const repo = new InMemoryWebhookEventRepository();
    // maxSize is 10_000, so insert 10001 events to trigger eviction
    for (let i = 0; i < 10001; i++) {
      await repo.insert({ ...baseEvent, transactionId: `txn_${i}` });
    }
    // First transaction should have been evicted
    const found = await repo.findByTransactionId('txn_0');
    expect(found).toBeNull();
    // Last transaction should still be there
    const foundLast = await repo.findByTransactionId('txn_10000');
    expect(foundLast).not.toBeNull();
  });

  it('sweep removes expired events', async () => {
    const repo = new InMemoryWebhookEventRepository();
    const oldEvent = { ...baseEvent, transactionId: 'txn_old', receivedAt: Date.now() - 100_000 };
    const newEvent = { ...baseEvent, transactionId: 'txn_new', receivedAt: Date.now() };
    await repo.insert(oldEvent);
    await repo.insert(newEvent);

    const removed = repo.sweep(50_000);
    expect(removed).toBe(1);

    const oldFound = await repo.findByTransactionId('txn_old');
    expect(oldFound).toBeNull();
    const newFound = await repo.findByTransactionId('txn_new');
    expect(newFound).not.toBeNull();
  });

  it('sweep returns 0 when no events are expired', async () => {
    const repo = new InMemoryWebhookEventRepository();
    await repo.insert(baseEvent);

    const removed = repo.sweep(100_000_000);
    expect(removed).toBe(0);

    const found = await repo.findByTransactionId('txn_1');
    expect(found).not.toBeNull();
  });
});
