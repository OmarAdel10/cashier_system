/**
 * Sale Record Use Case
 *
 * Records a sale for a tenant, enforcing license validity and device limits.
 *
 * Error arms: MISSING_FIELDS, USER_NOT_FOUND, ACCOUNT_DISABLED, NO_LICENSE,
 * LICENSE_EXPIRED, DEVICE_LIMIT_EXCEEDED, SALE_RECORD_FAILED.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { SaleRepository } from 'daftari-backend-shared/domain/repositories/sale-repository';
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { LicenseRepository } from 'daftari-backend-shared/domain/repositories/license-repository';
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { SaleRecordDto, SaleRecordResponse } from '../dtos/sale-record.dto';

export class SaleRecordUseCase {
  constructor(
    private readonly saleRepo: SaleRepository,
    private readonly deviceRepo: DeviceRepository,
    private readonly licenseRepo: LicenseRepository,
    private readonly userRepo: UserRepository,
  ) {}

  async execute(dto: SaleRecordDto): Promise<SaleRecordResponse> {
    const { tenantId, deviceHwid, receiptJson, totalPiastres, createdAt } = dto;
    const isNonEmptyString = (v: unknown): v is string =>
      typeof v === 'string' && v.trim().length > 0;
    if (
      !isNonEmptyString(tenantId) ||
      !isNonEmptyString(deviceHwid) ||
      !isNonEmptyString(receiptJson) ||
      typeof totalPiastres !== 'number' ||
      !Number.isFinite(totalPiastres) ||
      totalPiastres < 0 ||
      typeof createdAt !== 'number' ||
      !Number.isFinite(createdAt)
    ) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const user = await this.userRepo.findByTenantId(tenantId);
    if (!user) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }
    if ((user as { isActive?: number }).isActive === 0) {
      return { ok: false, error: 'ACCOUNT_DISABLED' };
    }

    const latestLicense = await this.licenseRepo.findLatestByTenant(tenantId);
    if (!latestLicense) {
      return { ok: false, error: 'NO_LICENSE' };
    }
    if (await this.licenseRepo.isExpired(latestLicense.graceEnd, createdAt)) {
      return { ok: false, error: 'LICENSE_EXPIRED' };
    }

    const tier = user.tier ?? 'starter';
    const limit = this.licenseRepo.getDeviceLimit(tier);
    const devices = await this.deviceRepo.listByTenant(tenantId);
    if (devices.length >= limit) {
      return { ok: false, error: 'DEVICE_LIMIT_EXCEEDED' };
    }

    const saleId = `sale_${crypto.randomUUID()}`;
    try {
      await this.saleRepo.insert({
        id: saleId,
        tenantId,
        receiptJson,
        totalPiastres,
        createdAt,
      });
    } catch {
      return { ok: false, error: 'SALE_RECORD_FAILED' };
    }

    return { ok: true, data: { saleId } };
  }
}
