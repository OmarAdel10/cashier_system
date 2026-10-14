import 'reflect-metadata';
import { describe, expect, it, vi } from 'vitest';
import { TursoDeviceRepository } from './turso-device-repository';
import type { TursoDb } from '../../turso';

const device = {
  tenantId: 'tenant-1',
  deviceHwid: 'device-1',
  deviceName: 'Front counter',
  platform: 'windows',
  firstSeenAt: 1000,
  lastSeenAt: 2000,
};

describe('TursoDeviceRepository', () => {
  it('maps present and absent optional device fields', async () => {
    const db = {
      getDevice: vi.fn()
        .mockResolvedValueOnce(device)
        .mockResolvedValueOnce({
          ...device,
          deviceName: undefined,
          platform: undefined,
        }),
      listDevices: vi.fn().mockResolvedValue([device]),
      upsertDevice: vi.fn(),
    } as unknown as TursoDb;
    const repository = new TursoDeviceRepository(db);

    await expect(repository.findByTenantAndDevice('tenant-1', 'device-1'))
      .resolves.toEqual(device);
    await expect(repository.findByTenantAndDevice('tenant-1', 'device-1'))
      .resolves.toEqual({ ...device, deviceName: undefined, platform: undefined });
    await expect(repository.listByTenant('tenant-1')).resolves.toEqual([device]);
  });

  it('delegates device upserts without dropping optional fields', async () => {
    const db = { upsertDevice: vi.fn() } as unknown as TursoDb;
    const repository = new TursoDeviceRepository(db);

    await repository.upsert(device);

    expect(db.upsertDevice).toHaveBeenCalledWith(device);
  });
});
