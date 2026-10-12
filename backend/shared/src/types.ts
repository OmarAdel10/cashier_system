/** Shared types for Daftari backend workers. */

/** Injectable fetch for tests. */
export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

/** A tenant owner / user row in Turso. */
export interface UserProfile {
  tenantId: string;
  email: string;
  /** 'admin' for tenant owners; 'cashier' if POS users are ever synced. */
  role: string;
  /** Pricing tier: 'starter' | 'pro' | 'business' (device limits). */
  tier?: string;
  displayName?: string;
  createdAt: number;
  lastLoginAt?: number;
  /** When the owner last completed a Firebase (Stage-1) login. */
  lastOwnerLoginAt?: number;
}

/** Signed license payload (inside the license key). */
export interface LicensePayload {
  tenantId: string;
  deviceHwid: string;
  subscriptionEnd: number;
  billingCycle: 'monthly' | 'yearly' | 'lifetime';
  graceEnd: number;
  createdAt: number;
}

/** A license row in Turso. */
export interface LicenseRecord extends LicensePayload {
  licenseKey: string;
  status: 'active' | 'expired';
}

/** A device row in Turso (device tracking per tenant). */
export interface DeviceRecord {
  tenantId: string;
  deviceHwid: string;
  deviceName?: string;
  platform?: string;
  firstSeenAt: number;
  lastSeenAt: number;
}

/** A POS user session (for device-limit conflict resolution). */
export interface SessionRecord {
  id: string;
  tenantId: string;
  deviceHwid: string;
  username: string;
  startedAt: number;
  heartbeatAt: number;
  endedAt?: number;
  /** Where the session started: 'pos' (device) or 'web' (dashboard login). */
  source?: string;
}

/** An admin/cashier account row in the cloud auth_users table
 *  (the extension of the device-side Hive auth system). */
export interface AuthUserRecord {
  tenantId: string;
  username: string;
  /** Scheme-tagged: pbkdf2-sha512$<iters>$<salt_b64url>$<hash_b64>. */
  passwordHash: string;
  /** 'admin' | 'cashier'. */
  role: string;
  displayName?: string;
  mustChangePassword: number;
  isActive: number;
  failedAttempts: number;
  lockedUntil?: number;
  createdAt: number;
  updatedAt: number;
}

/** Fields required to create an auth_users row (timestamps are stamped
 *  by the db helper). */
export interface NewAuthUser {
  tenantId: string;
  username: string;
  passwordHash: string;
  role: 'admin' | 'cashier';
  displayName?: string;
  mustChangePassword?: number;
}

/** A synced sale row in Turso. */
export interface SaleRecord {
  id: string;
  tenantId: string;
  receiptJson: string;
  totalPiastres: number;
  createdAt: number;
}

/** Standard API response envelope. */
export interface ApiResponse<T> {
  ok: boolean;
  data?: T;
  error?: string;
}

/** Device limits per pricing tier (Starter=1, Pro=2, Business=4). */
export const TIER_DEVICE_LIMITS: Record<string, number> = {
  starter: 1,
  pro: 2,
  business: 4,
};
