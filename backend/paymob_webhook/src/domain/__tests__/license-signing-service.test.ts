/**
 * Unit tests for LicenseSigningServiceImpl.
 *
 * Pure policy: compute license payload from webhook event, decide whether
 * to issue a license. No external dependencies.
 */
import { describe, expect, it } from 'vitest';
import { LicenseSigningServiceImpl } from '../services/license-signing-service.impl';
import type { WebhookEvent } from '../entities/webhook-event';

const NOW = 1_769_000_000_000;

function makeEvent(overrides: Partial<WebhookEvent> = {}): WebhookEvent {
  return {
    transactionId: 'txn_123',
    success: true,
    isRefunded: false,
    isVoided: false,
    tenantId: 'tenant-1',
    deviceHwid: 'device-abc',
    billingCycle: 'monthly',
    receivedAt: NOW,
    ...overrides,
  };
}

describe('LicenseSigningServiceImpl', () => {
  const svc = new LicenseSigningServiceImpl();

  describe('computePayload', () => {
    it('computes monthly subscription end (30 days)', () => {
      const payload = svc.computePayload(makeEvent({ billingCycle: 'monthly' }), NOW);
      expect(payload.subscriptionEnd).toBe(NOW + 30 * 24 * 60 * 60 * 1000);
      expect(payload.graceEnd).toBe(payload.subscriptionEnd + 7 * 24 * 60 * 60 * 1000);
      expect(payload.createdAt).toBe(NOW);
    });

    it('computes yearly subscription end (365 days)', () => {
      const payload = svc.computePayload(makeEvent({ billingCycle: 'yearly' }), NOW);
      expect(payload.subscriptionEnd).toBe(NOW + 365 * 24 * 60 * 60 * 1000);
      expect(payload.graceEnd).toBe(payload.subscriptionEnd + 7 * 24 * 60 * 60 * 1000);
    });

    it('computes lifetime: subscriptionEnd = 0, graceEnd = 0', () => {
      const payload = svc.computePayload(makeEvent({ billingCycle: 'lifetime' }), NOW);
      expect(payload.subscriptionEnd).toBe(0);
      expect(payload.graceEnd).toBe(0);
      expect(payload.createdAt).toBe(NOW);
    });

    it('copies tenantId, deviceHwid, billingCycle from event', () => {
      const payload = svc.computePayload(makeEvent({ tenantId: 'tenant-42', deviceHwid: 'device-42', billingCycle: 'yearly' }), NOW);
      expect(payload.tenantId).toBe('tenant-42');
      expect(payload.deviceHwid).toBe('device-42');
      expect(payload.billingCycle).toBe('yearly');
    });
  });

  describe('shouldIssue', () => {
    it('issues for successful, non-refunded, non-voided event', () => {
      expect(svc.shouldIssue(makeEvent({ success: true, isRefunded: false, isVoided: false }))).toEqual({ issue: true });
    });

    it('rejects unsuccessful payment', () => {
      expect(svc.shouldIssue(makeEvent({ success: false }))).toEqual({ issue: false, reason: 'NOT_SUCCESSFUL' });
    });

    it('rejects refunded payment', () => {
      expect(svc.shouldIssue(makeEvent({ success: true, isRefunded: true }))).toEqual({ issue: false, reason: 'REFUNDED' });
    });

    it('rejects voided payment', () => {
      expect(svc.shouldIssue(makeEvent({ success: true, isVoided: true }))).toEqual({ issue: false, reason: 'VOIDED' });
    });

    it('checks success before refund before void', () => {
      // A refunded-but-not-successful payment should report NOT_SUCCESSFUL
      expect(svc.shouldIssue(makeEvent({ success: false, isRefunded: true }))).toEqual({ issue: false, reason: 'NOT_SUCCESSFUL' });
    });
  });
});
