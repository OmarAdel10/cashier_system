/** Shared types for Daftari backend workers. */

/** Injectable fetch for tests. */
export type FetchFn = (url: string, init?: RequestInit) => Promise<Response>;

/** A tenant owner / user row in Turso. */
export interface UserProfile {
  tenant_id: string;
  email: string;
  /** 'admin' for tenant owners; 'cashier' if POS users are ever synced. */
  role: string;
  /** Pricing tier: 'starter' | 'pro' | 'business' (device limits). */
  tier?: string;
  display_name?: string;
  created_at: number;
  last_login_at?: number;
  /** When the owner last completed a Firebase (Stage-1) login. */
  last_owner_login_at?: number;
}

/** Signed license payload (inside the license key). */
export interface LicensePayload {
  tenant_id: string;
  device_hwid: string;
  subscription_end: number;
  billing_cycle: 'monthly' | 'yearly' | 'lifetime';
  grace_end: number;
  created_at: number;
}

/** A license row in Turso. */
export interface LicenseRecord extends LicensePayload {
  license_key: string;
  status: 'active' | 'expired';
}

/** A device row in Turso (device tracking per tenant). */
export interface DeviceRecord {
  tenant_id: string;
  device_hwid: string;
  device_name?: string;
  platform?: string;
  first_seen_at: number;
  last_seen_at: number;
}

/** A POS user session (for device-limit conflict resolution). */
export interface SessionRecord {
  id: string;
  tenant_id: string;
  device_hwid: string;
  username: string;
  started_at: number;
  heartbeat_at: number;
  ended_at?: number;
  /** Where the session started: 'pos' (device) or 'web' (dashboard login). */
  source?: string;
}

/** An admin/cashier account row in the cloud auth_users table
 *  (the extension of the device-side Hive auth system). */
export interface AuthUserRecord {
  tenant_id: string;
  username: string;
  /** Scheme-tagged: pbkdf2-sha512$<iters>$<salt_b64url>$<hash_b64>. */
  password_hash: string;
  /** 'admin' | 'cashier'. */
  role: string;
  display_name?: string;
  must_change_password: number;
  is_active: number;
  failed_attempts: number;
  locked_until?: number;
  created_at: number;
  updated_at: number;
}

/** Fields required to create an auth_users row (timestamps are stamped
 *  by the db helper). */
export interface NewAuthUser {
  tenant_id: string;
  username: string;
  password_hash: string;
  role: string;
  display_name?: string;
  must_change_password?: number;
}

/** A synced sale row in Turso. */
export interface SaleRecord {
  id: string;
  tenant_id: string;
  receipt_json: string;
  total_piastres: number;
  created_at: number;
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
