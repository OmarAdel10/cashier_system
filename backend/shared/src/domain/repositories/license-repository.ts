import { License } from '../entities/license';

export interface LicenseRepository {
  upsert(license: License): Promise<void>;
  findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<License | null>;
  findLatestByTenant(tenantId: string): Promise<License | null>;
  sweepExpired(now: number): Promise<void>;
}