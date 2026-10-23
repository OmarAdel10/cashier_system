/**
 * Unit tests for ProcessWebhookUseCase.
 *
 * Tests the webhook processing flow: HMAC validation, idempotency check,
 * license payload computation, and issue decision. All dependencies are
 * mocked so only the use case logic is under test.
 */
import { describe, expect, it, vi } from 'vitest';
import { ProcessWebhookUseCase } from '../use-cases/process-webhook-use-case';
import type { HmacValidationService } from '../../domain/services/hmac-validation-service';
import type { WebhookEventRepository } from '../../domain/repositories/webhook-event-repository';
import type { LicenseSigningService } from '../../domain/services/license-signing-service';
import type { ProcessWebhookDto } from '../dtos/process-webhook-dto';
import type { WebhookEvent } from '../../domain/entities/webhook-event';

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

function makeDto(overrides: Partial<ProcessWebhookDto> = {}): ProcessWebhookDto {
  return {
    event: makeEvent(),
    concatenated: 'concat-string-123',
    signatureHex: 'abc123def456',
    hmacSecret: 'secret-123',
    ...overrides,
  };
}

function makeServices(overrides: {
  hmacValidationService?: Partial<HmacValidationService>;
  webhookEventRepo?: Partial<WebhookEventRepository>;
  licenseSigningService?: Partial<LicenseSigningService>;
} = {}) {
  const hmacValidationService = {
    isValid: vi.fn().mockResolvedValue(true),
    ...overrides.hmacValidationService,
  };
  const webhookEventRepo = {
    insert: vi.fn().mockResolvedValue(true),
    ...overrides.webhookEventRepo,
  };
  const licenseSigningService = {
    computePayload: vi.fn().mockReturnValue({
      tenantId: 'tenant-1',
      deviceHwid: 'device-abc',
      subscriptionEnd: NOW + 30 * 24 * 60 * 60 * 1000,
      billingCycle: 'monthly' as const,
      graceEnd: NOW + 37 * 24 * 60 * 60 * 1000,
      createdAt: NOW,
    }),
    shouldIssue: vi.fn().mockReturnValue({ issue: true }),
    ...overrides.licenseSigningService,
  };
  return {
    hmacValidationService: hmacValidationService as HmacValidationService,
    webhookEventRepo: webhookEventRepo as WebhookEventRepository,
    licenseSigningService: licenseSigningService as LicenseSigningService,
  };
}

describe('ProcessWebhookUseCase', () => {
  describe('HMAC validation', () => {
    it('returns INVALID_HMAC when HMAC validation fails', async () => {
      const { hmacValidationService, webhookEventRepo } = makeServices({
        hmacValidationService: { isValid: vi.fn().mockResolvedValue(false) },
      });
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        makeServices().licenseSigningService,
      );
      const result = await useCase.execute(makeDto());
      expect(result).toEqual({ ok: false, error: 'INVALID_HMAC' });
      expect(webhookEventRepo.insert).not.toHaveBeenCalled();
      expect(hmacValidationService.isValid).toHaveBeenCalledWith(
        'concat-string-123',
        'abc123def456',
        'secret-123',
      );
    });

    it('proceeds when HMAC is valid', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(makeDto());
      expect(result.ok).toBe(true);
      expect(webhookEventRepo.insert).toHaveBeenCalled();
    });
  });

  describe('Idempotency', () => {
    it('returns DUPLICATE_EVENT when insert returns false', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices({
          webhookEventRepo: { insert: vi.fn().mockResolvedValue(false) },
        });
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(makeDto());
      expect(result).toEqual({ ok: false, error: 'DUPLICATE_EVENT' });
      expect(licenseSigningService.computePayload).not.toHaveBeenCalled();
    });

    it('proceeds when insert returns true', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(makeDto());
      expect(result.ok).toBe(true);
      expect(licenseSigningService.computePayload).toHaveBeenCalled();
    });
  });

  describe('License computation', () => {
    it('computes payload and decision for successful event', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ billingCycle: 'monthly' }) }),
      );
      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.data.payload.tenantId).toBe('tenant-1');
        expect(result.data.payload.deviceHwid).toBe('device-abc');
        expect(result.data.payload.billingCycle).toBe('monthly');
        expect(result.data.decision).toEqual({ issue: true });
      }
    });

    it('calls insert with event fields', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const event = makeEvent({ tenantId: 'tenant-42', deviceHwid: 'device-42' });
      await useCase.execute(makeDto({ event }));
      expect(webhookEventRepo.insert).toHaveBeenCalledWith({
        transactionId: event.transactionId,
        success: event.success,
        isRefunded: event.isRefunded,
        isVoided: event.isVoided,
        tenantId: event.tenantId,
        deviceHwid: event.deviceHwid,
        billingCycle: event.billingCycle,
        receivedAt: event.receivedAt,
      });
    });
  });

  describe('Entitlement gate', () => {
    it('rejects unsuccessful payment → INVALID_EVENT', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ success: false }) }),
      );
      expect(result).toEqual({ ok: false, error: 'INVALID_EVENT' });
      expect(licenseSigningService.computePayload).not.toHaveBeenCalled();
    });

    it('rejects refunded payment → INVALID_EVENT', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ isRefunded: true }) }),
      );
      expect(result).toEqual({ ok: false, error: 'INVALID_EVENT' });
      expect(licenseSigningService.computePayload).not.toHaveBeenCalled();
    });

    it('rejects voided payment → INVALID_EVENT', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ isVoided: true }) }),
      );
      expect(result).toEqual({ ok: false, error: 'INVALID_EVENT' });
      expect(licenseSigningService.computePayload).not.toHaveBeenCalled();
    });
  });

  describe('Input validation', () => {
    it('rejects empty transactionId → INVALID_EVENT', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ transactionId: '' }) }),
      );
      expect(result).toEqual({ ok: false, error: 'INVALID_EVENT' });
      expect(hmacValidationService.isValid).not.toHaveBeenCalled();
    });

    it('rejects empty tenantId → INVALID_EVENT', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ tenantId: '' }) }),
      );
      expect(result).toEqual({ ok: false, error: 'INVALID_EVENT' });
      expect(hmacValidationService.isValid).not.toHaveBeenCalled();
    });

    it('rejects empty deviceHwid → INVALID_EVENT', async () => {
      const { hmacValidationService, webhookEventRepo, licenseSigningService } =
        makeServices();
      const useCase = new ProcessWebhookUseCase(
        hmacValidationService,
        webhookEventRepo,
        licenseSigningService,
      );
      const result = await useCase.execute(
        makeDto({ event: makeEvent({ deviceHwid: '' }) }),
      );
      expect(result).toEqual({ ok: false, error: 'INVALID_EVENT' });
      expect(hmacValidationService.isValid).not.toHaveBeenCalled();
    });
  });
});
