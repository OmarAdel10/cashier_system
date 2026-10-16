/**
 * Sync User DTOs
 *
 * Data Transfer Objects for the user sync use case.
 */

/**
 * Input data for user sync.
 */
export interface SyncUserDto {
  readonly tenantId: string;
  readonly email?: string;
}

/**
 * Output data for user sync.
 */
export interface SyncUserResponse {
  readonly ok: true;
  readonly data: {
    readonly profile: {
      readonly tenantId: string;
      readonly email: string;
      readonly role: string;
      readonly tier?: string;
      readonly displayName?: string;
      readonly createdAt: number;
      readonly lastLoginAt?: number;
      readonly lastOwnerLoginAt?: number;
    };
    readonly license: {
      readonly tenantId: string;
      readonly deviceHwid: string;
      readonly licenseKey: string;
      readonly subscriptionEnd: number;
      readonly billingCycle: 'monthly' | 'yearly' | 'lifetime';
      readonly graceEnd: number;
      readonly status: 'active' | 'expired';
      readonly createdAt: number;
    } | null;
  };
} | {
  readonly ok: false;
  readonly error: 'USER_NOT_FOUND';
};
