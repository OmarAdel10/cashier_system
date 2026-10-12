import { beforeEach, describe, expect, it, vi } from 'vitest';

const executeMock = vi.fn();
vi.mock('@libsql/client', () => ({
  createClient: vi.fn(() => ({ execute: executeMock })),
}));

import { createTurso } from './turso';

const db = createTurso('https://db.turso.io', 'token-123');
const dbRow = {
  tenant_id: 'tenant-1',
  email: 'owner@example.test',
  role: 'admin',
  tier: 'pro',
  display_name: 'Owner',
  created_at: 10,
  last_login_at: 11,
  last_owner_login_at: 12,
  device_hwid: 'device-1',
  license_key: 'license-key',
  subscription_end: 20,
  billing_cycle: 'monthly',
  grace_end: 30,
  status: 'active',
  device_name: 'POS 1',
  platform: 'windows',
  first_seen_at: 40,
  last_seen_at: 50,
  password_hash: 'password-hash',
  must_change_password: 0,
  is_active: 1,
  failed_attempts: 2,
  locked_until: 60,
  updated_at: 70,
  receipt_json: '{"total":100}',
  total_piastres: 100,
};

function mockOneRow(overrides: Record<string, unknown> = {}) {
  executeMock.mockResolvedValueOnce({
    rows: [{ ...dbRow, ...overrides }],
    columns: [],
    rowsAffected: 1,
  });
}

beforeEach(() => {
  executeMock.mockReset();
});

describe('backend/shared public API contract', () => {
  it('maps UserProfile to camelCase only', async () => {
    mockOneRow();
    const profile = await db.getUser('tenant-1');

    expect(Object.keys(profile ?? {})).toEqual([
      'tenantId',
      'email',
      'role',
      'tier',
      'displayName',
      'createdAt',
      'lastLoginAt',
      'lastOwnerLoginAt',
    ]);
  });

  it('maps LicenseRecord to camelCase only', async () => {
    mockOneRow();
    const license = await db.getLicense('tenant-1', 'device-1');

    expect(Object.keys(license ?? {})).toEqual([
      'tenantId',
      'deviceHwid',
      'licenseKey',
      'subscriptionEnd',
      'billingCycle',
      'graceEnd',
      'status',
      'createdAt',
    ]);
  });

  it('maps DeviceRecord to camelCase only', async () => {
    mockOneRow();
    const device = await db.getDevice('tenant-1', 'device-1');

    expect(Object.keys(device ?? {})).toEqual([
      'tenantId',
      'deviceHwid',
      'deviceName',
      'platform',
      'firstSeenAt',
      'lastSeenAt',
    ]);
  });

  it('maps SessionRecord to camelCase only', async () => {
    mockOneRow({ id: 'session-1', username: 'admin', started_at: 80, heartbeat_at: 90 });
    const session = await db.getLiveWebSession('tenant-1', 'session-1');

    expect(Object.keys(session ?? {})).toEqual([
      'id',
      'tenantId',
      'deviceHwid',
      'username',
      'startedAt',
      'heartbeatAt',
      'endedAt',
      'source',
    ]);
  });

  it('maps AuthUserRecord to camelCase only', async () => {
    mockOneRow({ username: 'admin' });
    const user = await db.getAuthUser('tenant-1', 'admin');

    expect(Object.keys(user ?? {})).toEqual([
      'tenantId',
      'username',
      'passwordHash',
      'role',
      'displayName',
      'mustChangePassword',
      'isActive',
      'failedAttempts',
      'lockedUntil',
      'createdAt',
      'updatedAt',
    ]);
  });

  it('maps SaleRecord to camelCase only', async () => {
    mockOneRow({ id: 'sale-1', username: undefined });
    const sale = (await db.listSales('tenant-1', 0))[0];

    expect(Object.keys(sale ?? {})).toEqual([
      'id',
      'tenantId',
      'receiptJson',
      'totalPiastres',
      'createdAt',
    ]);
  });
});
