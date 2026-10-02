import { Device } from '../entities/device';

export interface DeviceRepository {
  upsert(device: Device): Promise<void>;
  findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<Device | null>;
  listByTenant(tenantId: string): Promise<Device[]>;
}