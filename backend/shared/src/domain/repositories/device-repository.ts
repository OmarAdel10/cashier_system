import { Device } from '../entities/device';

/**
 * Repository interface for POS device registrations.
 *
 * Provides operations for device registration and listing per tenant.
 * Used for device limit enforcement and device management.
 *
 * @example
 * ```typescript
 * const deviceRepo: DeviceRepository = container.resolve('DeviceRepository');
 * await deviceRepo.upsert(device);
 * const devices = await deviceRepo.listByTenant('tenant-123');
 * ```
 */
export interface DeviceRepository {
  /**
   * Creates or updates a device registration.
   *
   * @param device - Device entity to persist
   * @returns Promise that resolves when operation completes
   */
  upsert(device: Device): Promise<void>;

  /**
   * Finds a device by tenant and hardware ID.
   *
   * @param tenantId - Tenant identifier
   * @param deviceHwid - Device hardware identifier
   * @returns Device entity or null if not found
   */
  findByTenantAndDevice(tenantId: string, deviceHwid: string): Promise<Device | null>;

  /**
   * Lists all devices registered to a tenant.
   *
   * @param tenantId - Tenant identifier
   * @returns Array of Device entities
   */
  listByTenant(tenantId: string): Promise<Device[]>;
}