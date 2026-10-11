import 'reflect-metadata';
import { describe, expect, it, vi } from 'vitest';
import { TursoSessionRepository } from './turso-session-repository';
import { TursoDb } from '../../turso';
import type { SessionRecord } from '../../types';

function makeRecord(source: 'pos' | 'web'): SessionRecord {
  return {
    id: 'session-1',
    tenantId: 'tenant-1',
    deviceHwid: 'device-1',
    username: 'owner',
    startedAt: 1000,
    heartbeatAt: 2000,
    endedAt: undefined,
    source,
  };
}

describe('TursoSessionRepository', () => {
  it('delegates source-neutral getLive to the existing live-session query', async () => {
    const record = makeRecord('pos');
    const db = { getLiveWebSession: vi.fn().mockResolvedValue(record) };
    const repository = new TursoSessionRepository(db as unknown as TursoDb);

    const session = await repository.getLive('tenant-1', 'session-1');

    expect(db.getLiveWebSession).toHaveBeenCalledWith('tenant-1', 'session-1');
    expect(session).toEqual({
      id: 'session-1',
      tenantId: 'tenant-1',
      deviceHwid: 'device-1',
      username: 'owner',
      startedAt: 1000,
      heartbeatAt: 2000,
      endedAt: undefined,
      source: 'pos',
    });
  });

  it('returns null when the delegated live-session query has no row', async () => {
    const db = { getLiveWebSession: vi.fn().mockResolvedValue(null) };
    const repository = new TursoSessionRepository(db as unknown as TursoDb);

    const session = await repository.getLive('tenant-1', 'missing-session');

    expect(session).toBeNull();
    expect(db.getLiveWebSession).toHaveBeenCalledWith(
      'tenant-1',
      'missing-session',
    );
  });
});
