import { readFileSync, readdirSync } from 'node:fs';
import { beforeEach, describe, expect, it, vi } from 'vitest';

// Mock @libsql/client before importing the module under test.
const executeMock = vi.fn();
const batchMock = vi.fn();
vi.mock('@libsql/client', () => ({
  createClient: vi.fn(() => ({ execute: executeMock, batch: batchMock })),
}));

import { createTurso, TursoDb } from './turso';

const db = createTurso('https://db.turso.io', 'token-123');

beforeEach(() => {
  executeMock.mockReset();
  executeMock.mockResolvedValue({ rows: [], columns: [], rowsAffected: 0 });
  batchMock.mockReset();
  batchMock.mockResolvedValue([{ rows: [], columns: [], rowsAffected: 0 }]);
});

describe('createTurso', () => {
  it('creates client with url + authToken', () => {
    expect(db).toBeDefined();
  });

  it('upsertUser inserts with ON CONFLICT DO UPDATE', async () => {
    await db.upsertUser({
      tenantId: 'uid-1',
      email: 'a@b.co',
      role: 'admin',
      createdAt: 123,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO users');
    expect(arg0.sql).toContain('ON CONFLICT');
    expect(arg0.args[0]).toBe('uid-1');
    expect(arg0.args[1]).toBe('a@b.co');
    expect(arg0.args[2]).toBe('admin');
    expect(arg0.args[3]).toBeNull();
    expect(arg0.args[4]).toBe(123);
    expect(arg0.args[5]).toBeNull(); // last_login_at omitted on profile upsert
  });

  it('updates an existing email when the supplied email is non-empty', async () => {
    const { createClient } = await vi.importActual<typeof import('@libsql/client')>(
      '@libsql/client',
    );
    const client = createClient({ url: ':memory:' });
    await client.execute(
      `CREATE TABLE users (
         tenant_id TEXT PRIMARY KEY,
         email TEXT NOT NULL,
         role TEXT NOT NULL DEFAULT 'admin',
         tier TEXT NOT NULL DEFAULT 'starter',
         display_name TEXT,
         created_at INTEGER NOT NULL,
         last_login_at INTEGER,
         last_owner_login_at INTEGER
       )`,
    );
    const persistentDb = new TursoDb(client);

    await persistentDb.upsertUser({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      createdAt: 100,
    });
    await persistentDb.upsertUser({
      tenantId: 'tenant-1',
      email: 'updated@example.test',
      role: 'admin',
      createdAt: 200,
      lastLoginAt: 300,
      lastOwnerLoginAt: 400,
    });

    await db.upsertUser({
      tenantId: 'tenant-1',
      email: 'updated@example.test',
      role: 'admin',
      createdAt: 200,
    });
    const [mockStatement] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(mockStatement.sql).toContain('email = COALESCE(NULLIF(excluded.email, \'\'), users.email)');

    const profile = await persistentDb.getUser('tenant-1');
    expect(profile?.email).toBe('updated@example.test');
    expect(profile?.lastLoginAt).toBe(300);
    expect(profile?.lastOwnerLoginAt).toBe(400);

    await client.close();
  });

  it('preserves the existing email on conflict and still inserts a new row with an empty email', async () => {
    const { createClient } = await vi.importActual<typeof import('@libsql/client')>(
      '@libsql/client',
    );
    const client = createClient({ url: ':memory:' });
    await client.execute(
      `CREATE TABLE users (
         tenant_id TEXT PRIMARY KEY,
         email TEXT NOT NULL,
         role TEXT NOT NULL DEFAULT 'admin',
         tier TEXT NOT NULL DEFAULT 'starter',
         display_name TEXT,
         created_at INTEGER NOT NULL,
         last_login_at INTEGER,
         last_owner_login_at INTEGER
       )`,
    );
    const persistentDb = new TursoDb(client);

    await persistentDb.upsertUser({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      createdAt: 100,
    });
    await persistentDb.upsertUser({
      tenantId: 'tenant-1',
      email: '',
      role: 'admin',
      createdAt: 200,
      lastLoginAt: 300,
    });

    await db.upsertUser({
      tenantId: 'tenant-1',
      email: '',
      role: 'admin',
      createdAt: 200,
    });
    const [mockStatement] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(mockStatement.sql).toContain('email = COALESCE(NULLIF(excluded.email, \'\'), users.email)');
    const persisted = await persistentDb.getUser('tenant-1');
    expect(persisted?.email).toBe('owner@example.test');
    expect(persisted?.lastLoginAt).toBe(300);

    await persistentDb.upsertUser({
      tenantId: 'tenant-new',
      email: '',
      role: 'admin',
      createdAt: 400,
    });
    const inserted = await persistentDb.getUser('tenant-new');
    expect(inserted?.email).toBe('');

    await client.close();
  });

  it('does not overwrite optional login timestamps when they are absent', async () => {
    const { createClient } = await vi.importActual<typeof import('@libsql/client')>(
      '@libsql/client',
    );
    const client = createClient({ url: ':memory:' });
    await client.execute(
      `CREATE TABLE users (
         tenant_id TEXT PRIMARY KEY,
         email TEXT NOT NULL,
         role TEXT NOT NULL DEFAULT 'admin',
         tier TEXT NOT NULL DEFAULT 'starter',
         display_name TEXT,
         created_at INTEGER NOT NULL,
         last_login_at INTEGER,
         last_owner_login_at INTEGER
       )`,
    );
    const persistentDb = new TursoDb(client);

    await persistentDb.upsertUser({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      createdAt: 100,
      lastLoginAt: 200,
      lastOwnerLoginAt: 300,
    });
    await persistentDb.upsertUser({
      tenantId: 'tenant-1',
      email: 'owner@example.test',
      role: 'admin',
      createdAt: 400,
    });

    const profile = await persistentDb.getUser('tenant-1');
    expect(profile?.lastLoginAt).toBe(200);
    expect(profile?.lastOwnerLoginAt).toBe(300);

    await client.close();
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
    expect(user?.lastOwnerLoginAt).toBeUndefined(); // absent -> undefined
  });

  it('getUser returns null when no row', async () => {
    const user = await db.getUser('missing');
    expect(user).toBeNull();
  });

  it('upsertLicense writes license row', async () => {
    await db.upsertLicense({
      tenantId: 't1',
      deviceHwid: 'hw1',
      licenseKey: 'key',
      subscriptionEnd: 1,
      billingCycle: 'monthly',
      graceEnd: 2,
      createdAt: 3,
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
    expect(license?.tenantId).toBe('t1');
  });

  it('getLatestLicense returns null when no license', async () => {
    const license = await db.getLatestLicense('t-none');
    expect(license).toBeNull();
  });

  it('insertSale writes sale row', async () => {
    await db.insertSale({
      id: 'sale-1',
      tenantId: 't1',
      receiptJson: '{}',
      totalPiastres: 5000,
      createdAt: 999,
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
      tenantId: 't1',
      deviceHwid: 'hw1',
      deviceName: 'Shop PC',
      platform: 'windows',
      firstSeenAt: 1,
      lastSeenAt: 2,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO devices');
    expect(arg0.sql).toContain('ON CONFLICT');
  });

  it('listDevices selects by tenant, orders by last_seen_at, maps rows', async () => {
    executeMock.mockResolvedValue({
      rows: [
        { tenant_id: 't1', device_hwid: 'hw1', device_name: 'Shop PC', platform: 'windows', first_seen_at: 1, last_seen_at: 9 },
        { tenant_id: 't1', device_hwid: 'hw2', device_name: null, platform: null, first_seen_at: 2, last_seen_at: 8 },
      ],
      columns: [],
      rowsAffected: 0,
    });
    const devices = await db.listDevices('t1');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('FROM devices');
    expect(arg0.sql).toContain('ORDER BY last_seen_at DESC');
    expect(arg0.args).toEqual(['t1']);
    expect(devices).toHaveLength(2);
    expect(devices[0]?.deviceHwid).toBe('hw1');
    expect(devices[0]?.deviceName).toBe('Shop PC');
    expect(devices[1]?.deviceName).toBeUndefined(); // SQL NULL -> undefined
    expect(devices[1]?.platform).toBeUndefined();
  });

  it('insertSession + endSession manage session lifecycle', async () => {
    executeMock.mockResolvedValueOnce({ rows: [], columns: [], rowsAffected: 1 });
    const inserted = await db.insertSession({
      id: 'sess-1',
      tenantId: 't1',
      deviceHwid: 'hw1',
      username: 'admin',
      startedAt: 1,
      heartbeatAt: 1,
    });
    expect(inserted).toBe(true);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('INSERT INTO sessions');
    expect(arg0.sql).toContain('ON CONFLICT DO NOTHING');

    executeMock.mockResolvedValueOnce({ rows: [], columns: [], rowsAffected: 1 });
    const ended = await db.endSession('sess-1', 't1', 200);
    expect(ended).toBe(true);
    const [arg1] = executeMock.mock.calls[1] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg1.sql).toContain('UPDATE sessions');
    expect(arg1.sql).toContain('ended_at = ?');
    expect(arg1.sql).toContain('tenant_id = ?');
    expect(arg1.args).toEqual([200, 'sess-1', 't1']);
  });

  it('insertSession reports false when the live-web unique index rejects the row (T12)', async () => {
    executeMock.mockResolvedValueOnce({ rows: [], columns: [], rowsAffected: 0 });
    const inserted = await db.insertSession({
      id: 'sess-race',
      tenantId: 't1',
      deviceHwid: 'web',
      username: 'admin',
      startedAt: 1,
      heartbeatAt: 1,
      source: 'web',
    });
    expect(inserted).toBe(false);
  });

  it('heartbeatSession scopes the UPDATE by id + tenant and returns rowsAffected > 0 (T13)', async () => {
    executeMock.mockResolvedValueOnce({ rows: [], columns: [], rowsAffected: 1 });
    const ok = await db.heartbeatSession('sess-1', 't1', 555);
    expect(ok).toBe(true);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('UPDATE sessions SET heartbeat_at = ?');
    expect(arg0.sql).toContain('id = ?');
    expect(arg0.sql).toContain('tenant_id = ?');
    expect(arg0.args).toEqual([555, 'sess-1', 't1']);

    executeMock.mockResolvedValueOnce({ rows: [], columns: [], rowsAffected: 0 });
    await expect(db.heartbeatSession('foreign', 't1', 556)).resolves.toBe(false);
  });

  it('admitPosSession serializes the slot check and INSERT in a write transaction (T12)', async () => {
    batchMock.mockResolvedValueOnce([{ rows: [], columns: [], rowsAffected: 1 }]);
    const admitted = await db.admitPosSession(
      {
        id: 'sess-p',
        tenantId: 't1',
        deviceHwid: 'hw2',
        username: 'admin',
        startedAt: 1,
        heartbeatAt: 1,
        source: 'pos',
      },
      2,
    );
    expect(admitted).toBe(true);
    expect(executeMock).not.toHaveBeenCalled();
    const [arg0, mode] = batchMock.mock.calls[0] as unknown as [
      Array<{ sql: string; args: unknown[] }>,
      string,
    ];
    // The write-mode batch is the cross-device serialization boundary; the
    // count/EXISTS predicate remains inside the INSERT itself.
    expect(mode).toBe('write');
    expect(arg0).toHaveLength(1);
    const statement = arg0[0];
    if (!statement) throw new Error('expected an admission statement');
    expect(statement.sql).toContain('INSERT INTO sessions');
    expect(statement.sql).toContain('ON CONFLICT DO NOTHING');
    expect(statement.sql).toContain('WHERE EXISTS');
    expect(statement.sql).toContain('SELECT COUNT(*) FROM sessions');
    expect(statement.args).toEqual([
      'sess-p', 't1', 'hw2', 'admin', 1, 1, 't1', 'hw2', 't1', 2,
    ]);
  });

  it('admitPosSession reports a rejected batch result without inserting (T12)', async () => {
    batchMock.mockResolvedValueOnce([{ rows: [], columns: [], rowsAffected: 0 }]);
    const admitted = await db.admitPosSession(
      {
        id: 'sess-p',
        tenantId: 't1',
        deviceHwid: 'hw2',
        username: 'admin',
        startedAt: 1,
        heartbeatAt: 1,
        source: 'pos',
      },
      2,
    );
    expect(admitted).toBe(false);
    expect(executeMock).not.toHaveBeenCalled();
    expect(batchMock).toHaveBeenCalledWith(
      expect.arrayContaining([
        expect.objectContaining({
          sql: expect.stringContaining('INSERT INTO sessions'),
          args: expect.any(Array),
        }),
      ]),
      'write',
    );
  });

  it('admitPosSession returns false if the batch omits a result', async () => {
    batchMock.mockResolvedValueOnce([]);
    const admitted = await db.admitPosSession(
      {
        id: 'sess-p',
        tenantId: 't1',
        deviceHwid: 'hw2',
        username: 'admin',
        startedAt: 1,
        heartbeatAt: 1,
        source: 'pos',
      },
      2,
    );
    expect(admitted).toBe(false);
    expect(executeMock).not.toHaveBeenCalled();
  });

  it('admitPosSession propagates a rejected batch promise', async () => {
    const failure = new Error('batch rejected');
    batchMock.mockRejectedValueOnce(failure);

    await expect(
      db.admitPosSession(
        {
          id: 'sess-p',
          tenantId: 't1',
          deviceHwid: 'hw2',
          username: 'admin',
          startedAt: 1,
          heartbeatAt: 1,
          source: 'pos',
        },
        2,
      ),
    ).rejects.toBe(failure);
    expect(executeMock).not.toHaveBeenCalled();
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
    await expect(db.upsertUser({ tenantId: 'x', email: 'e', role: 'admin', createdAt: 1 })).rejects.toThrow('turso down');
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
    expect(user?.passwordHash).toBe('pbkdf2-sha512$1000$s$h');
    expect(user?.failedAttempts).toBe(2);
    expect(user?.lockedUntil).toBe(12345);
    expect(user?.isActive).toBe(1);
    expect(user?.displayName).toBe('Owner');
    expect(user?.role).toBe('admin');
    expect(user?.mustChangePassword).toBe(0);
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
    expect(user?.displayName).toBeUndefined();
    expect(user?.lockedUntil).toBeUndefined();
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
    await db.insertAuthUser({ tenantId: 't1', username: 'cash', passwordHash: 'h', role: 'cashier' });
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
      tenantId: 't1',
      username: 'admin',
      passwordHash: 'h',
      role: 'admin',
      displayName: 'Owner',
      mustChangePassword: 1,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.args[4]).toBe('Owner'); // display_name
    expect(arg0.args[5]).toBe(1); // must_change_password
  });

  it('updateAuthUser patches only provided fields and stamps updated_at', async () => {
    await db.updateAuthUser('t1', 'admin', { passwordHash: 'new-h' });
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
      passwordHash: 'h2',
      displayName: 'Owner',
      isActive: 0,
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
    await db.recordAuthFailure('t1', 'admin');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('failed_attempts = failed_attempts + 1');
    expect(arg0.sql).toContain('locked_until = CASE');
    expect(arg0.sql).toContain('MIN(2 ** (failed_attempts + 1) * 15000, 900000)');
    expect(arg0.args[0]).toBeTypeOf('number'); // updated_at
    expect(arg0.args[1]).toBe('t1');
    expect(arg0.args[2]).toBe('admin');
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
    expect(user?.lastOwnerLoginAt).toBe(777);
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
      tenantId: 't1',
      deviceHwid: 'hw1',
      username: 'admin',
      startedAt: 1,
      heartbeatAt: 1,
    });
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('source');
    expect(arg0.args[6]).toBe('pos');

    await db.insertSession({
      id: 'sess-2',
      tenantId: 't1',
      deviceHwid: 'web',
      username: 'admin',
      startedAt: 2,
      heartbeatAt: 2,
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
    expect(arg0.sql).toContain('heartbeat_at > ?');
    expect(arg0.args).toEqual(['t1', expect.any(Number)]);
    expect(sessions).toHaveLength(1);
  });

  it('getRecentSessions orders by started_at desc with a limit', async () => {
    executeMock.mockResolvedValue({
      rows: [{ id: 'sess-1', tenant_id: 't1', device_hwid: 'hw1', username: 'admin', started_at: 5, heartbeat_at: 6, source: 'pos' }],
      columns: [],
      rowsAffected: 0,
    });
    const sessions = await db.getRecentSessions('t1', 5);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('FROM sessions');
    expect(arg0.sql).toContain('ORDER BY started_at DESC');
    expect(arg0.sql).toContain('LIMIT ?');
    expect(arg0.sql).not.toContain('ended_at'); // any ended-state (doc comment)
    expect(arg0.args).toEqual(['t1', 5]);
    expect(sessions).toHaveLength(1);
    expect(sessions[0]?.startedAt).toBe(5);
  });
});

// ---- live-session lookup + tenant-scoped revocation (admin-dashboard T10) ----
//
// The auth gate calls getLiveWebSession on every HS256 request: the row must
// belong to the token's tenant and be unended. Web sessions do NOT heartbeat,
// so heartbeat freshness must play no part here — the JWT `exp` bounds the
// lifetime and revocation is expressed by ended_at (the sessions table has no
// separate revoked flag).

describe('session liveness (auth gate, T10)', () => {
  it('getLiveWebSession returns an unended web row with a 6-hour-old heartbeat', async () => {
    executeMock.mockResolvedValue({
      rows: [
        {
          id: 'sess-live',
          tenant_id: 't1',
          device_hwid: 'web',
          username: 'admin',
          started_at: 5,
          heartbeat_at: Date.now() - 6 * 60 * 60 * 1000,
          source: 'web',
        },
      ],
      columns: [],
      rowsAffected: 0,
    });
    const session = await db.getLiveWebSession('t1', 'sess-live');
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('FROM sessions');
    expect(arg0.sql).toContain('id = ?');
    expect(arg0.sql).toContain('tenant_id = ?');
    expect(arg0.sql).toContain('ended_at IS NULL');
    expect(arg0.sql).not.toContain('heartbeat_at');
    expect(arg0.args).toEqual(['sess-live', 't1']);
    expect(session?.id).toBe('sess-live');
    expect(session?.source).toBe('web');
  });

  it('getLiveWebSession returns null when no live row matches', async () => {
    const session = await db.getLiveWebSession('t1', 'missing');
    expect(session).toBeNull();
  });

  it('endSessionForTenant scopes the UPDATE by id + tenant and only unended rows', async () => {
    await db.endSessionForTenant('sess-1', 't1', 777);
    const [arg0] = executeMock.mock.calls[0] as unknown as [{ sql: string; args: unknown[] }];
    expect(arg0.sql).toContain('UPDATE sessions SET ended_at = ?');
    expect(arg0.sql).toContain('id = ?');
    expect(arg0.sql).toContain('tenant_id = ?');
    expect(arg0.sql).toContain('ended_at IS NULL');
    expect(arg0.args).toEqual([777, 'sess-1', 't1']);
  });
});

// ---- query indexes (Task 24) ----
//
// Migrations are applied by operators, not by the test harness (the libSQL
// client is mocked above), so the only executable guarantee we can give is
// that the shipped migration set carries the index DDL for the hot
// per-tenant ordered reads. Parse the SQL files and assert the statements.

const migrationSql = readdirSync(new URL('../migrations/', import.meta.url))
  .filter((name) => name.endsWith('.sql'))
  .map((name) => readFileSync(new URL(`../migrations/${name}`, import.meta.url), 'utf8'))
  .join('\n')
  // Collapse whitespace so the assertions do not depend on line breaks.
  .replace(/\s+/g, ' ');

describe('migration set — query indexes', () => {
  it('creates the sessions index on (tenant_id, started_at)', () => {
    expect(migrationSql).toContain(
      'CREATE INDEX IF NOT EXISTS idx_sessions_tenant_started ON sessions (tenant_id, started_at)',
    );
  });

  it('creates the devices index on (tenant_id, last_seen_at)', () => {
    expect(migrationSql).toContain(
      'CREATE INDEX IF NOT EXISTS idx_devices_tenant_last_seen ON devices (tenant_id, last_seen_at)',
    );
  });

  it('creates the partial unique live-web index (T12 atomic admission)', () => {
    expect(migrationSql).toContain(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_live_web ON sessions (tenant_id, username)',
    );
    expect(migrationSql).toContain("WHERE source = 'web' AND ended_at IS NULL");
  });

  it('creates the partial unique live-POS-per-device index (Task 3)', () => {
    expect(migrationSql).toContain(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_live_pos_device ON sessions (tenant_id, device_hwid)',
    );
    expect(migrationSql).toContain("WHERE source = 'pos' AND ended_at IS NULL");
  });
});
