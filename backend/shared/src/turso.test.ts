import { beforeEach, describe, expect, it, vi } from 'vitest';

// Mock @libsql/client before importing the module under test.
const executeMock = vi.fn();
vi.mock('@libsql/client', () => ({
  createClient: vi.fn(() => ({ execute: executeMock })),
}));

import { createTurso } from './turso';

const db = createTurso('https://db.turso.io', 'token-123');

beforeEach(() => {
  executeMock.mockReset();
  executeMock.mockResolvedValue({ rows: [], columns: [], rowsAffected: 0 });
});

describe('createTurso', () => {
  it('creates client with url + authToken', () => {
    expect(db).toBeDefined();
  });

  it('upsertUser inserts with ON CONFLICT DO UPDATE', async () => {
    await db.upsertUser({
      tenant_id: 'uid-1',
      email: 'a@b.co',
      role: 'admin',
      created_at: 123,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO users');
    expect(arg0.sql).toContain('ON CONFLICT');
    expect(arg0.args[0]).toBe('uid-1');
    expect(arg0.args[1]).toBe('a@b.co');
    expect(arg0.args[2]).toBe('admin');
    expect(arg0.args[3]).toBeNull();
    expect(arg0.args[4]).toBe(123);
    expect(typeof arg0.args[5]).toBe('number'); // last_login_at
  });

  it('getUser selects by tenant_id and maps the row', async () => {
    executeMock.mockResolvedValue({
      rows: [{ tenant_id: 'uid-1', email: 'a@b.co', role: 'admin', display_name: 'O', created_at: 123, last_login_at: 456 }],
      columns: [],
      rowsAffected: 0,
    });
    const user = await db.getUser('uid-1');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('SELECT');
    expect(arg0.sql).toContain('FROM users');
    expect(arg0.args).toEqual(['uid-1']);
    expect(user?.email).toBe('a@b.co');
    expect(user?.role).toBe('admin');
  });

  it('getUser returns null when no row', async () => {
    const user = await db.getUser('missing');
    expect(user).toBeNull();
  });

  it('upsertLicense writes license row', async () => {
    await db.upsertLicense({
      tenant_id: 't1',
      device_hwid: 'hw1',
      license_key: 'key',
      subscription_end: 1,
      billing_cycle: 'monthly',
      grace_end: 2,
      created_at: 3,
      status: 'active',
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO licenses');
    expect(arg0.sql).toContain('ON CONFLICT');
    expect(arg0.args).toEqual(['t1', 'hw1', 'key', 1, 'monthly', 2, 'active', 3]);
  });

  it('getLatestLicense orders by created_at desc, limit 1', async () => {
    executeMock.mockResolvedValue({
      rows: [{ tenant_id: 't1', device_hwid: 'hw1', license_key: 'k', subscription_end: 9, billing_cycle: 'monthly', grace_end: 9, status: 'active', created_at: 1 }],
      columns: [],
      rowsAffected: 0,
    });
    const license = await db.getLatestLicense('t1');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('FROM licenses');
    expect(arg0.sql).toContain('ORDER BY created_at DESC');
    expect(arg0.args).toEqual(['t1']);
    expect(license?.tenant_id).toBe('t1');
  });

  it('getLatestLicense returns null when no license', async () => {
    const license = await db.getLatestLicense('t-none');
    expect(license).toBeNull();
  });

  it('insertSale writes sale row', async () => {
    await db.insertSale({
      id: 'sale-1',
      tenant_id: 't1',
      receipt_json: '{}',
      total_piastres: 5000,
      created_at: 999,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT OR REPLACE INTO sales');
    expect(arg0.args).toEqual(['sale-1', 't1', '{}', 5000, 999]);
  });

  it('listSales selects by tenant with since filter', async () => {
    executeMock.mockResolvedValue({
      rows: [{ id: 's1', tenant_id: 't1', receipt_json: '{}', total_piastres: 1, created_at: 5 }],
      columns: [],
      rowsAffected: 0,
    });
    const sales = await db.listSales('t1', 100);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('created_at > ?');
    expect(arg0.args).toEqual(['t1', 100]);
    expect(sales).toHaveLength(1);
  });

  it('upsertDevice tracks device presence', async () => {
    await db.upsertDevice({
      tenant_id: 't1',
      device_hwid: 'hw1',
      device_name: 'Shop PC',
      platform: 'windows',
      first_seen_at: 1,
      last_seen_at: 2,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO devices');
    expect(arg0.sql).toContain('ON CONFLICT');
  });

  it('insertSession + endSession manage session lifecycle', async () => {
    await db.insertSession({
      id: 'sess-1',
      tenant_id: 't1',
      device_hwid: 'hw1',
      username: 'admin',
      started_at: 1,
      heartbeat_at: 1,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO sessions');

    await db.endSession('sess-1', 200);
    const [arg1] = executeMock.mock.calls[1] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg1.sql).toContain('UPDATE sessions');
    expect(arg1.sql).toContain('ended_at = ?');
    expect(arg1.args).toEqual([200, 'sess-1']);
  });

  it('getActiveSessions returns only open sessions', async () => {
    executeMock.mockResolvedValue({
      rows: [{ id: 'sess-1', tenant_id: 't1', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 2 }],
      columns: [],
      rowsAffected: 0,
    });
    const sessions = await db.getActiveSessions('t1');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('ended_at IS NULL');
    expect(arg0.args).toEqual(['t1']);
    expect(sessions).toHaveLength(1);
  });

  it('marks expired licenses in sweepExpiredLicenses', async () => {
    await db.sweepExpiredLicenses(1000);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain("status = 'expired'");
    // grace_end = 0 is lifetime — must NOT expire (review finding 1)
    expect(arg0.sql).toContain('grace_end > 0');
    expect(arg0.sql).toContain('grace_end < ?');
    expect(arg0.args).toEqual([1000]);
  });

  it('propagates execute errors', async () => {
    executeMock.mockRejectedValue(new Error('turso down'));
    await expect(db.upsertUser({ tenant_id: 'x', email: 'e', role: 'admin', created_at: 1 })).rejects.toThrow('turso down');
  });
});
