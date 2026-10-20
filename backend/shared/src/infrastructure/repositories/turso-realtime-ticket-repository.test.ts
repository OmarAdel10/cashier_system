import 'reflect-metadata';
import { describe, expect, it, vi } from 'vitest';
import { TursoRealtimeTicketRepository } from './turso-realtime-ticket-repository';
import type { TursoDb } from '../../turso';

function makeExec(overrides: Partial<{ rowsAffected: number; rows: unknown[] }> = {}) {
  return vi.fn().mockResolvedValue({
    rowsAffected: 1,
    rows: [],
    ...overrides,
  });
}

describe('TursoRealtimeTicketRepository', () => {
  it('insert returns true when rowsAffected > 0', async () => {
    const exec = makeExec({ rowsAffected: 1 });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.insert({
      ticket: 'ticket-1',
      tenantId: 'tenant-1',
      expiresAt: 2000,
      createdAt: 1000,
    });

    expect(result).toBe(true);
    expect(exec).toHaveBeenCalledWith(
      `INSERT INTO realtime_tickets (ticket, tenant_id, expires_at, used_at) VALUES (?, ?, ?, NULL)`,
      ['ticket-1', 'tenant-1', 2000],
    );
  });

  it('insert returns false when rowsAffected is 0', async () => {
    const exec = makeExec({ rowsAffected: 0 });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.insert({
      ticket: 'ticket-1',
      tenantId: 'tenant-1',
      expiresAt: 2000,
      createdAt: 1000,
    });

    expect(result).toBe(false);
  });

  it('validateAndConsume returns valid for unused, unexpired ticket', async () => {
    const exec = vi.fn()
      .mockResolvedValueOnce({ rowsAffected: 1, rows: [{ ticket: 'ticket-1', tenant_id: 'tenant-1', expires_at: 9999999999, used_at: null }] })
      .mockResolvedValueOnce({ rowsAffected: 1, rows: [] });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.validateAndConsume('ticket-1', 1000);

    expect(result).toEqual({ valid: true, tenantId: 'tenant-1' });
    expect(exec).toHaveBeenNthCalledWith(1, `SELECT ticket, tenant_id, expires_at, used_at FROM realtime_tickets WHERE ticket = ?`, ['ticket-1']);
    expect(exec).toHaveBeenNthCalledWith(2, `UPDATE realtime_tickets SET used_at = ? WHERE ticket = ? AND used_at IS NULL`, [1000, 'ticket-1']);
  });

  it('validateAndConsume returns INVALID_TICKET when no row', async () => {
    const exec = vi.fn().mockResolvedValueOnce({ rowsAffected: 0, rows: [] });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.validateAndConsume('ticket-1', 1000);

    expect(result).toEqual({ valid: false, error: 'INVALID_TICKET' });
  });

  it('validateAndConsume returns EXPIRED_TICKET when expired', async () => {
    const exec = vi.fn().mockResolvedValueOnce({ rowsAffected: 1, rows: [{ ticket: 'ticket-1', tenant_id: 'tenant-1', expires_at: 500, used_at: null }] });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.validateAndConsume('ticket-1', 1000);

    expect(result).toEqual({ valid: false, error: 'EXPIRED_TICKET' });
  });

  it('validateAndConsume returns ALREADY_USED_TICKET when already used', async () => {
    const exec = vi.fn().mockResolvedValueOnce({ rowsAffected: 1, rows: [{ ticket: 'ticket-1', tenant_id: 'tenant-1', expires_at: 9999999999, used_at: 500 }] });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.validateAndConsume('ticket-1', 1000);

    expect(result).toEqual({ valid: false, error: 'ALREADY_USED_TICKET' });
  });

  it('validateAndConsume returns ALREADY_USED_TICKET when update affects 0 rows (race)', async () => {
    const exec = vi.fn()
      .mockResolvedValueOnce({ rowsAffected: 1, rows: [{ ticket: 'ticket-1', tenant_id: 'tenant-1', expires_at: 9999999999, used_at: null }] })
      .mockResolvedValueOnce({ rowsAffected: 0, rows: [] });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    const result = await repository.validateAndConsume('ticket-1', 1000);

    expect(result).toEqual({ valid: false, error: 'ALREADY_USED_TICKET' });
  });

  it('sweepExpired deletes expired tickets', async () => {
    const exec = vi.fn().mockResolvedValue({ rowsAffected: 1, rows: [] });
    const db = { exec } as unknown as TursoDb;
    const repository = new TursoRealtimeTicketRepository(db);

    await repository.sweepExpired(1000);

    expect(exec).toHaveBeenCalledWith(`DELETE FROM realtime_tickets WHERE expires_at <= ?`, [1000]);
  });
});
