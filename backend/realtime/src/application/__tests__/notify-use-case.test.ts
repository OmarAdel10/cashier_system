import { describe, expect, it, vi } from 'vitest';
import { NotifyUseCase } from '../use-cases/notify-use-case';
import type { BroadcastService } from '../../domain/services/broadcast-service';
import type { BroadcastRepository } from '../../domain/repositories/broadcast-repository';
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
  return { useCase: new NotifyUseCase(
    broadcastService as unknown as BroadcastService,
    broadcastRepo as unknown as BroadcastRepository,
  ), broadcastService, broadcastRepo };
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

  it('whitespace-only tenantId → MISSING_TENANT', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto({ tenantId: '   ' }));
    expect(result).toMatchObject({ ok: false, error: 'MISSING_TENANT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('tenantId too long → INVALID_TENANT', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const longId = 'a'.repeat(129);
    const result = await useCase.execute(makeDto({ tenantId: longId }));
    expect(result).toMatchObject({ ok: false, error: 'INVALID_TENANT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('tenantId with invalid chars → INVALID_TENANT', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto({ tenantId: 'Tenant Upper!' }));
    expect(result).toMatchObject({ ok: false, error: 'INVALID_TENANT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('missing event → INVALID_EVENT, no repo work', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto({ event: '' }));
    expect(result).toMatchObject({ ok: false, error: 'INVALID_EVENT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('disallowed event → INVALID_EVENT, no repo work', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const result = await useCase.execute(makeDto({ event: 'delete_everything' }));
    expect(result).toMatchObject({ ok: false, error: 'INVALID_EVENT' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
  });

  it('shouldBroadcast false → BROADCAST_DROPPED, no repo work', async () => {
    const { useCase, broadcastRepo, broadcastService } = makeUseCase({
      broadcastService: { shouldBroadcast: vi.fn().mockReturnValue(false) },
    });
    const result = await useCase.execute(makeDto());
    expect(result).toMatchObject({ ok: false, error: 'BROADCAST_DROPPED' });
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

  it('oversized data → BROADCAST_FAILED', async () => {
    const { useCase, broadcastRepo } = makeUseCase();
    const bigData = { payload: 'x'.repeat(70_000) };
    const result = await useCase.execute(makeDto({ data: bigData }));
    expect(result).toMatchObject({ ok: false, error: 'BROADCAST_FAILED' });
    expect(broadcastRepo.insert).not.toHaveBeenCalled();
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

  it('omits data defaults to empty object', async () => {
    const { useCase, broadcastService } = makeUseCase();
    await useCase.execute(makeDto({ data: undefined }));
    expect(broadcastService.buildPayload).toHaveBeenCalledWith(
      'sale',
      'tenant-1',
      {},
      expect.any(Number),
    );
  });
});
