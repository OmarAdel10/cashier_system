import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { License } from '../../domain/entities/license';
import { LicenseRecord, TIER_DEVICE_LIMITS } from '../../types';

@injectable()
export class TursoLicenseRepository implements LicenseRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  private toLicense(record: LicenseRecord): License {
    return {
      tenantId: record.tenantId,
      deviceHwid: record.deviceHwid,
      licenseKey: record.licenseKey,
      subscriptionEnd: record.subscriptionEnd,
      billingCycle: record.billingCycle,
      graceEnd: record.graceEnd,
      status: record.status,
      createdAt: record.createdAt,
    };
  }

  async upsert(license: License): Promise<void> {
    await this.db.upsertLicense(license);
  }

  async findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<License | null> {
    const license = await this.db.getLicense(tenantId, deviceHwid);
    if (!license) return null;
    return this.toLicense(license);
  }

  async findLatestByTenant(tenantId: string): Promise<License | null> {
    const license = await this.db.getLatestLicense(tenantId);
    if (!license) return null;
    return this.toLicense(license);
  }

  async sweepExpired(now: number): Promise<void> {
    await this.db.sweepExpiredLicenses(now);
  }

  // Additional method for license service
  async isExpired(graceEnd: number, now: number): Promise<boolean> {
    // Lifetime licenses have graceEnd = 0 and never expire
    if (graceEnd === 0) return false;
    return now > graceEnd;
  }

  getDeviceLimit(tier: string): number {
    // Keep repository behavior aligned with the canonical tier limits.
    return Object.prototype.hasOwnProperty.call(TIER_DEVICE_LIMITS, tier) ? TIER_DEVICE_LIMITS[tier] : 1;
  }
}
