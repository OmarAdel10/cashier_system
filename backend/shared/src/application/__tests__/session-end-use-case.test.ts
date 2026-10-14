import 'reflect-metadata';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SessionEndUseCase } from '../use-cases/session-end-use-case';
import type { SessionRepository } from '../../domain/repositories/session-repository';

const NOW = 1_769_000_000_000;

describe('SessionEndUseCase', () => {
  let sessionRepo: { end: ReturnType<typeof vi.fn> };
  let useCase: SessionEndUseCase;

  beforeEach(() => {
    vi.spyOn(Date, 'now').mockReturnValue(NOW);
    sessionRepo = { end: vi.fn().mockResolvedValue(true) };
    useCase = new SessionEndUseCase(
      sessionRepo as unknown as SessionRepository,
    );
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('rejects missing or blank principal, tenant, and session fields', async () => {
    const valid = {
      principal: { tenantId: 'tenant-1', sessionId: 'session-1' },
      sessionId: 'session-1',
    };
    const invalidRequests = [
      { ...valid, principal: undefined },
      { ...valid, principal: { tenantId: '' } },
      { ...valid, principal: { tenantId: ' ' } },
      { ...valid, principal: { tenantId: 'tenant-1', sessionId: ' ' } },
      { ...valid, sessionId: '' },
      { ...valid, sessionId: ' ' },
    ];

    for (const request of invalidRequests) {
      const result = await useCase.execute(request as never);
      expect(result).toMatchObject({ ok: false, error: 'MISSING_FIELDS' });
    }
    expect(sessionRepo.end).not.toHaveBeenCalled();
  });

  it('rejects a request session that is not the principal session', async () => {
    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1', sessionId: 'session-1' },
      sessionId: 'session-2',
    });

    expect(result).toMatchObject({ ok: false, error: 'SESSION_NOT_FOUND' });
    expect(sessionRepo.end).not.toHaveBeenCalled();
  });

  it('ends the session through the principal tenant', async () => {
    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1', sessionId: 'session-1' },
      sessionId: 'session-1',
    });

    expect(result).toEqual({
      ok: true,
      data: { message: 'Session ended successfully' },
    });
    expect(sessionRepo.end).toHaveBeenCalledWith(
      'session-1',
      'tenant-1',
      NOW,
    );
  });

  it('reports a missing session when the tenant-owned update affects no row', async () => {
    sessionRepo.end.mockResolvedValue(false);

    const result = await useCase.execute({
      principal: { tenantId: 'tenant-1' },
      sessionId: 'session-1',
    });

    expect(result).toMatchObject({ ok: false, error: 'SESSION_NOT_FOUND' });
    expect(sessionRepo.end).toHaveBeenCalledWith(
      'session-1',
      'tenant-1',
      NOW,
    );
  });
});
