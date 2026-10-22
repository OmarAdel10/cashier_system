import { describe, expect, it, vi } from 'vitest';
import { NotifyUseCase } from '../use-cases/notify-use-case';
import type { BroadcastService } from '../../domain/services/broadcast-service';
import type { BroadcastRepository } from '../../domain/repositories/broadcast-repository';
import type { WebSocketSessionRepository } from '../../domain/repositories/websocket-session-repository';
import type { NotifyUseCaseDto } from '../dtos/notify-use-case-dto';

const now = 1_769_000_000_000;

function makeDto(overrides: Partial<NotifyUseCaseDto> = {}): NotifyUseCaseDto {
  return {
    tenantId: 'tenant-1',
    event: 'sale',
    data: { count: 1 },
    ...overrides,
  };
}

function makeUseCase(overrides: {
  broadcastService?: Partial<BroadcastService>;
  broadcastRepo?: Partial<BroadcastRepository>;
  sessionRepo?: Partial<WebSocketSessionRepository>;
} = {}) {
  const broadcastService = {
    buildPayload: vi.fn(
      (_type: string, _tenantId: string, _data: Record<string, unknown>, createdAt: number) => ({
        type: 'sale',
        tenantId: 'tenant-1',
        data: { count: 1 },
        createdAt,
      }),
    ),
    shouldBroadcast: vi.fn().mockReturnValue(true),
    ...overrides.broadcastService,
  };
  const broadcastRepo = {
    insert: vi.fn().mockResolvedValue(true),
    ...overrides.broadcastRepo,
  };
  const sessionRepo = {
    insert: vi.fn(),
    close: vi.fn(),
    heartbeat: vi.fn(),
    getOpenForTenant: vi.fn(),
    sweepStale: vi.fn(),
    ...overrides.sessionRepo,
  };
  return { useCase: new NotifyUseCase(
    broadcastService as unknown as BroadcastService,
    broadcastRepo as unknown as BroadcastRepository,
    sessionRepo as unknown as WebSocketSessionRepository,
  ), broadcastService, broadcastRepo, sessionRepo };
}

describe('NotifyUseCase — business rules for notify events', () => {
  it('valid notify returns ok with broadcastId', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: true });
    if (result.ok) {
      expect(result.data.broadcastId).toBeDefined();
      expect(typeof result.data.broadcastId).toBe('string');
    }
    expect(broadcastRepo.insert).toHaveBeenCalledTimes(1);
  });

  it('missing tenantId → MISSING_TENANT, no repo work', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto({ tenantId: '' }));
    expect(result).toMatchObject({ ok: false, error: 'MISSING_TENANT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('missing event → INVALID_EVENT, no repo work', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto({ event: '' }));
    expect(result).toMatchObject({ ok: false, error: 'INVALID_EVENT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('shouldBroadcast false → INVALID_EVENT, no repo work', async () => {
    const { useCase, broadcastRepo, broadcastService } = makeUseCase({
      broadcastService: { shouldBroadcast: vi.fn().mockReturnValue(false) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'INVALID_EVENT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
    expect(broadcastService.buildPayload).toHaveBeenCalled();
  });

  it('broadcastRepo insert fails → BROADCAST_FAILED', async () => {
    const { useCase, broadcastRepo } = makeUseCase({
      broadcastRepo: { insert: vi.fn().mockResolvedValue(false) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'BROADCAST_FAILED' });
  });

  it('buildPayload receives event, tenantId, data, and now', async () => {
    const { useCase, broadcastService } = makeUseCase();
    vi.spyOn(Date, 'now').mockReturnValue(now);
    await useCase.execute(makeDto({ event: 'session', data: { n: 5 } }));
    expect(broadcastService.buildPayload).toHaveBeenCalledWith(
      'session',
      'tenant-1',
      { n: 5 },
      now,
    );
    vi.restoreAllMocks();
  });
});
