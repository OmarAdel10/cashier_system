/**
 * Use case for processing a Paymob webhook callback.
 *
 * Validates the HMAC signature, checks idempotency against previously
 * processed events, computes the license payload, and decides whether a
 * license should be issued. Persists the webhook event for audit and
 * replay protection. All side effects (repository writes) are confined
 * to this use case; the actual license key signing is delegated to
 * IssueLicenseUseCase.
 */
import type { HmacValidationService } from '../../domain/services/hmac-validation-service';
import type { WebhookEventRepository } from '../../domain/repositories/webhook-event-repository';
import type { LicenseSigningService } from '../../domain/services/license-signing-service';
import type { ProcessWebhookDto, ProcessWebhookResponse } from '../dtos/process-webhook-dto';

export class ProcessWebhookUseCase {
  constructor(
    private readonly hmacValidationService: HmacValidationService,
    private readonly webhookEventRepo: WebhookEventRepository,
    private readonly licenseSigningService: LicenseSigningService,
  ) {}

  async execute(dto: ProcessWebhookDto): Promise<ProcessWebhookResponse> {
    // Validate HMAC signature before processing.
    const isValid = await this.hmacValidationService.isValid(
      dto.event.transactionId,
      dto.signatureHex,
      dto.hmacSecret,
    );
    if (!isValid) {
      return { ok: false, error: 'INVALID_HMAC' };
    }

    // Idempotency: reject duplicate events.
    const inserted = await this.webhookEventRepo.insert({
      transactionId: dto.event.transactionId,
      success: dto.event.success,
      isRefunded: dto.event.isRefunded,
      isVoided: dto.event.isVoided,
      tenantId: dto.event.tenantId,
      deviceHwid: dto.event.deviceHwid,
      billingCycle: dto.event.billingCycle,
      receivedAt: dto.event.receivedAt,
    });
    if (!inserted) {
      return { ok: false, error: 'DUPLICATE_EVENT' };
    }

    // Compute license payload and issue decision.
    const payload = this.licenseSigningService.computePayload(
      dto.event,
      dto.event.receivedAt,
    );
    const decision = this.licenseSigningService.shouldIssue(dto.event);

    return { ok: true, data: { payload, decision } };
  }
}
