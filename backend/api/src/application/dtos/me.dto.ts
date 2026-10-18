/**
 * Me DTOs
 *
 * Data Transfer Objects for the "get my profile" use case.
 */

/**
 * Input data for getting current user profile.
 */
export interface MeDto {
  readonly tenantId: string;
}

/**
 * Output data for getting current user profile.
 */
export type MeResponse =
  | {
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
        } | null;
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
    }
  | {
      readonly ok: false;
      readonly error: 'USER_NOT_FOUND';
    };
