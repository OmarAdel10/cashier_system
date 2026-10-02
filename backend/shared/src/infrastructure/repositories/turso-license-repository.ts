import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { LicenseRepository } from '../../domain/repositories/license-repository';
import { License } from '../../domain/entities/license';
import { LicenseRecord } from '../../types';

@injectable()
export class TursoLicenseRepository implements LicenseRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  async upsert(license: License): Promise<void> {
    await this.db.upsertLicense({
      tenant_id: license.tenantId,
      device_hwid: license.deviceHwid,
      license_key: license.licenseKey,
      subscription_end: license.subscriptionEnd,
      billing_cycle: license.billingCycle,
      grace_end: license.graceEnd,
      status: license.status,
      created_at: license.createdAt
    });
  }

  async findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<License | null> {
    const license = await this.db.getLicense(tenantId, deviceHwid);
    if (!license) return null;

    return {
      tenantId: license.tenant_id,
      deviceHwid: license.device_hwid,
      licenseKey: license.license_key,
      subscriptionEnd: license.subscription_end,
      billingCycle: license.billing_cycle,
      graceEnd: license.grace_end,
      status: license.status,
      createdAt: license.created_at
    };
  }

  async findLatestByTenant(tenantId: string): Promise<License | null> {
    const license = await this.db.getLatestLicense(tenantId);
    if (!license) return null;

    return {
      tenantId: license.tenant_id,
      deviceHwid: license.device_hwid,
      licenseKey: license.license_key,
      subscriptionEnd: license.subscription_end,
      billingCycle: license.billing_cycle,
      graceEnd: license.grace_end,
      status: license.status,
      createdAt: license.created_at
    };
  }

  async sweepExpired(now: number): Promise<void> {
    await this.db.sweepExpiredLicenses(now);
  }

  // Additional method for license service
  isExpired(graceEnd: number, now: number): boolean {
    // Lifetime licenses have graceEnd = 0 and never expire
    if (graceEnd === 0) return false;
    return now > graceEnd;
  }

  getDeviceLimit(tier: string): number {
    // Default limits - can be configured based on tier
    switch (tier) {
      case 'starter': return 1;
      case 'pro': return 3;
      case 'business': return 10;
      default: return 1;
    }
  }
}