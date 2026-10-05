import { inject, injectable } from 'tsyringe';
import { TursoDb } from '../../turso';
import { DeviceRepository } from '../../domain/repositories/device-repository';
import { Device } from '../../domain/entities/device';
import { DeviceRecord } from '../../types';

@injectable()
export class TursoDeviceRepository implements DeviceRepository {
  constructor(
    @inject('TursoDb') private readonly db: TursoDb
  ) {}

  async upsert(device: Device): Promise<void> {
    await this.db.upsertDevice({
      tenant_id: device.tenantId,
      device_hwid: device.deviceHwid,
      device_name: device.deviceName,
      platform: device.platform,
      first_seen_at: device.firstSeenAt,
      last_seen_at: device.lastSeenAt
    });
  }

  async findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<Device | null> {
    const device = await this.db.getDevice(tenantId, deviceHwid);
    if (!device) return null;

    return {
      tenantId: device.tenantId,
      deviceHwid: device.deviceHwid,
      deviceName: device.deviceName,
      platform: device.platform,
      firstSeenAt: device.firstSeenAt,
      lastSeenAt: device.lastSeenAt
    };
  }

  async listByTenant(tenantId: string): Promise<Device[]> {
    const devices = await this.db.listDevices(tenantId);
    return devices.map(device => ({
      tenantId: device.tenantId,
      deviceHwid: device.deviceHwid,
      deviceName: device.deviceName,
      platform: device.platform,
      firstSeenAt: device.firstSeenAt,
      lastSeenAt: device.lastSeenAt
    }));
  }
}