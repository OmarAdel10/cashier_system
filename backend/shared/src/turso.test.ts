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
    expect(user?.last_owner_login_at).toBeUndefined(); // absent -> undefined
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

  // ---- auth_users (admin-dashboard T04) ----

  it('getAuthUser selects by tenant + username and maps the row', async () => {
    executeMock.mockResolvedValue({
      rows: [
        {
          tenant_id: 't1',
          username: 'admin',
          password_hash: 'pbkdf2-sha512$1000$s$h',
          role: 'admin',
          display_name: 'Owner',
          must_change_password: 0,
          is_active: 1,
          failed_attempts: 2,
          locked_until: 12345,
          created_at: 10,
          updated_at: 20,
        },
      ],
      columns: [],
      rowsAffected: 0,
    });
    const user = await db.getAuthUser('t1', 'admin');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('FROM auth_users');
    expect(arg0.args).toEqual(['t1', 'admin']);
    expect(user?.password_hash).toBe('pbkdf2-sha512$1000$s$h');
    expect(user?.failed_attempts).toBe(2);
    expect(user?.locked_until).toBe(12345);
    expect(user?.is_active).toBe(1);
    expect(user?.display_name).toBe('Owner');
    expect(user?.role).toBe('admin');
    expect(user?.must_change_password).toBe(0);
  });

  it('getAuthUser maps SQL NULLs to undefined for display_name/locked_until', async () => {
    executeMock.mockResolvedValue({
      rows: [
        {
          tenant_id: 't1',
          username: 'admin',
          password_hash: 'h',
          role: 'admin',
          display_name: null,
          must_change_password: 0,
          is_active: 1,
          failed_attempts: 0,
          locked_until: null,
          created_at: 1,
          updated_at: 2,
        },
      ],
      columns: [],
      rowsAffected: 0,
    });
    const user = await db.getAuthUser('t1', 'admin');
    expect(user?.display_name).toBeUndefined();
    expect(user?.locked_until).toBeUndefined();
  });

  it('getAuthUser returns null when no row', async () => {
    expect(await db.getAuthUser('t1', 'ghost')).toBeNull();
  });

  it('listAuthUsers orders by username', async () => {
    executeMock.mockResolvedValue({
      rows: [{ username: 'a' }, { username: 'b' }],
      columns: [],
      rowsAffected: 0,
    });
    const users = await db.listAuthUsers('t1');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('ORDER BY username');
    expect(arg0.args).toEqual(['t1']);
    expect(users).toHaveLength(2);
    expect(users.map((u) => u.username)).toEqual(['a', 'b']);
  });

  it('insertAuthUser inserts all fields and stamps timestamps', async () => {
    await db.insertAuthUser({ tenant_id: 't1', username: 'cash', password_hash: 'h', role: 'cashier' });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO auth_users');
    expect(arg0.args[0]).toBe('t1');
    expect(arg0.args[1]).toBe('cash');
    expect(arg0.args[2]).toBe('h');
    expect(arg0.args[3]).toBe('cashier');
    expect(arg0.args[4]).toBeNull(); // display_name
    expect(arg0.args[5]).toBe(0); // must_change_password
    expect(arg0.args[6]).toBe(1); // is_active
    expect(arg0.args[7]).toBe(0); // failed_attempts
    expect(arg0.args[8]).toBeNull(); // locked_until
    expect(typeof arg0.args[9]).toBe('number'); // created_at
    expect(typeof arg0.args[10]).toBe('number'); // updated_at
  });

  it('insertAuthUser passes through display_name and must_change_password=1', async () => {
    await db.insertAuthUser({
      tenant_id: 't1',
      username: 'admin',
      password_hash: 'h',
      role: 'admin',
      display_name: 'Owner',
      must_change_password: 1,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.args[4]).toBe('Owner'); // display_name
    expect(arg0.args[5]).toBe(1); // must_change_password
  });

  it('updateAuthUser patches only provided fields and stamps updated_at', async () => {
    await db.updateAuthUser('t1', 'admin', { password_hash: 'new-h' });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('UPDATE auth_users');
    expect(arg0.sql).toContain('password_hash = ?');
    expect(arg0.sql).toContain('updated_at = ?');
    expect(arg0.sql).not.toContain('display_name');
    expect(arg0.args[0]).toBe('new-h');
    expect(typeof arg0.args[1]).toBe('number'); // updated_at
    expect(arg0.args[2]).toBe('t1');
    expect(arg0.args[3]).toBe('admin');
  });

  it('updateAuthUser builds aligned SETs for a multi-field patch (incl. is_active: 0)', async () => {
    await db.updateAuthUser('t1', 'admin', {
      password_hash: 'h2',
      display_name: 'Owner',
      is_active: 0,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('password_hash = ?, display_name = ?, is_active = ?, updated_at = ?');
    expect(arg0.args[0]).toBe('h2');
    expect(arg0.args[1]).toBe('Owner');
    expect(arg0.args[2]).toBe(0); // falsy must NOT be dropped
    expect(typeof arg0.args[3]).toBe('number'); // updated_at
    expect(arg0.args[4]).toBe('t1');
    expect(arg0.args[5]).toBe('admin');
  });

  it('updateAuthUser with an empty patch still stamps updated_at', async () => {
    await db.updateAuthUser('t1', 'admin', {});
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('SET updated_at = ?');
    expect(arg0.sql).not.toContain('password_hash');
    expect(arg0.args).toHaveLength(3); // updated_at, tenant, username
  });

  it('recordAuthFailure increments attempts and sets or clears the lock', async () => {
    await db.recordAuthFailure('t1', 'admin', 999);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('failed_attempts = failed_attempts + 1');
    expect(arg0.sql).toContain('locked_until = ?');
    expect(arg0.args[0]).toBe(999);
    expect(typeof arg0.args[1]).toBe('number'); // updated_at
    expect(arg0.args[2]).toBe('t1');
    expect(arg0.args[3]).toBe('admin');

    await db.recordAuthFailure('t1', 'admin', null);
    const [arg1] = executeMock.mock.calls[1] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg1.args[0]).toBeNull();
  });

  it('resetAuthFailures zeroes attempts and clears the lock', async () => {
    await db.resetAuthFailures('t1', 'admin');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('failed_attempts = 0');
    expect(arg0.sql).toContain('locked_until = NULL');
    expect(arg0.args[1]).toBe('t1');
    expect(arg0.args[2]).toBe('admin');
  });

  it('touchOwnerLogin stamps last_owner_login_at on the tenant row', async () => {
    await db.touchOwnerLogin('t1', 555);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('last_owner_login_at = ?');
    expect(arg0.sql).toContain('UPDATE users');
    expect(arg0.args).toEqual([555, 't1']);
  });

  it('getUser maps last_owner_login_at when present', async () => {
    executeMock.mockResolvedValue({
      rows: [{ tenant_id: 't1', email: 'a@b.co', role: 'admin', created_at: 1, last_owner_login_at: 777 }],
      columns: [],
      rowsAffected: 0,
    });
    const user = await db.getUser('t1');
    expect(user?.last_owner_login_at).toBe(777);
  });

  it('getActiveSessionsForUsername filters open sessions with fresh heartbeats', async () => {
    executeMock.mockResolvedValue({
      rows: [
        {
          id: 'sess-9',
          tenant_id: 't1',
          device_hwid: 'web',
          username: 'admin',
          started_at: 5,
          heartbeat_at: 6,
          source: 'web',
        },
      ],
      columns: [],
      rowsAffected: 0,
    });
    const sessions = await db.getActiveSessionsForUsername('t1', 'admin', 100);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('ended_at IS NULL');
    expect(arg0.sql).toContain('heartbeat_at > ?');
    expect(arg0.sql).toContain('username = ?');
    expect(arg0.args).toEqual(['t1', 'admin', 100]);
    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.username).toBe('admin');
    expect(sessions[0]?.source).toBe('web');
  });

  it('insertSession writes the source column (default pos, explicit web)', async () => {    await db.insertSession({
      id: 'sess-1',
      tenant_id: 't1',
      device_hwid: 'hw1',
      username: 'admin',
      started_at: 1,
      heartbeat_at: 1,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('source');
    expect(arg0.args[6]).toBe('pos');

    await db.insertSession({
      id: 'sess-2',
      tenant_id: 't1',
      device_hwid: 'web',
      username: 'admin',
      started_at: 2,
      heartbeat_at: 2,
      source: 'web',
    });
    const [arg1] = executeMock.mock.calls[1] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg1.args[6]).toBe('web');
  });

  it('endWebSessions ends only unended web rows for the username', async () => {
    await db.endWebSessions('t1', 'admin', 555);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain("source = 'web'");
    expect(arg0.sql).toContain('ended_at IS NULL');
    expect(arg0.sql).toContain('username = ?');
    expect(arg0.args).toEqual([555, 't1', 'admin']);
  });

  it('getActivePosSessions excludes web sessions from the device count', async () => {
    executeMock.mockResolvedValue({
      rows: [{ id: 's-pos', tenant_id: 't1', device_hwid: 'hw1', username: 'admin', started_at: 1, heartbeat_at: 2, source: 'pos' }],
      columns: [],
      rowsAffected: 0,
    });
    const sessions = await db.getActivePosSessions('t1');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain("source != 'web'");
    expect(arg0.sql).toContain('ended_at IS NULL');
    expect(arg0.args).toEqual(['t1']);
    expect(sessions).toHaveLength(1);
  });
});
