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

  private toDevice(record: DeviceRecord): Device {
    return {
      tenantId: record.tenant_id,
      deviceHwid: record.device_hwid,
      deviceName: record.device_name,
      platform: record.platform,
      firstSeenAt: record.first_seen_at,
      lastSeenAt: record.last_seen_at,
    };
  }

  async upsert(device: Device): Promise<void> {
    await this.db.upsertDevice({
      tenant_id: device.tenantId,
      device_hwid: device.deviceHwid,
      device_name: device.deviceName,
      platform: device.platform,
      first_seen_at: device.firstSeenAt,
      last_seen_at: device.lastSeenAt,
    });
  }

  async findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<Device | null> {
    const device = await this.db.getDevice(tenantId, deviceHwid);
    if (!device) return null;
    return this.toDevice(device);
  }

  async listByTenant(tenantId: string): Promise<Device[]> {
    const devices = await this.db.listDevices(tenantId);
    return devices.map(device => this.toDevice(device));
  }
}
