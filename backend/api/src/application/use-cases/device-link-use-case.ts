/**
 * Device Link Use Case
 *
 * Links a device (device_hwid + name) to the tenant. Owner-only.
 * Upserts the device row and returns the persisted device record.
 *
 * Error arms: MISSING_FIELDS.
 *
 * Wiring precondition (doc): identity fields (tenantId) must be sourced ONLY
 * from verified middleware context at the wiring phase - never from request
 * body/query/header. Application layer trusts DTO input by design; authz is a
 * Phases 7-12 concern.
 */
import type { DeviceRepository } from 'daftari-backend-shared/domain/repositories/device-repository';
import type { Device } from 'daftari-backend-shared/domain/entities/device';
import type { DeviceLinkDto, DeviceLinkResponse } from '../dtos/device-link.dto';
import { validateTenantId, validateDeviceHwid } from '../validation';

export class DeviceLinkUseCase {
  constructor(private readonly deviceRepo: DeviceRepository) {}

  async execute(dto: DeviceLinkDto): Promise<DeviceLinkResponse> {
    const { tenantId, deviceHwid, deviceName, platform } = dto;
    if (!validateTenantId(tenantId)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }
    if (!validateDeviceHwid(deviceHwid)) {
      return { ok: false, error: 'MISSING_FIELDS' };
    }

    const now = Date.now();
    const device: Device = {
      tenantId,
      deviceHwid,
      deviceName,
      platform,
      firstSeenAt: now,
      lastSeenAt: now,
    };
    await this.deviceRepo.upsert(device);

    return {
      ok: true,
      data: {
        deviceHwid,
        device_name: deviceName ?? null,
        platform: platform ?? null,
        first_seen_at: now,
        last_seen_at: now,
      },
    };
  }
}
