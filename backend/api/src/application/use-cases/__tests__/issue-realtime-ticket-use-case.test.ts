/**
 * IssueRealtimeTicketUseCase Tests
 *
 * Covers POST /auth/ticket parity: an existing user gets a UUID ticket with a
 * 60s TTL, a missing user is USER_NOT_FOUND (no insert), and a refused insert
 * is TICKET_CREATION_FAILED.
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { IssueRealtimeTicketUseCase } from '../issue-realtime-ticket-use-case';

const FIXED_NOW = 1_700_000_000_000;
const UUID_V4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

const makeUser = () => ({
  tenantId: 'tenant-1',
  email: 'owner@test.com',
  role: 'admin',
  createdAt: FIXED_NOW - 86_400_000,
});

const makeUserRepo = (user: ReturnType<typeof makeUser> | null = makeUser()) => ({
  findByTenantId: vi.fn().mockResolvedValue(user),
});

const makeTicketRepo = (inserted = true) => ({
  insert: vi.fn().mockResolvedValue(inserted),
});

describe('IssueRealtimeTicketUseCase', () => {
  let userRepo: ReturnType<typeof makeUserRepo>;
  let ticketRepo: ReturnType<typeof makeTicketRepo>;
  let useCase: IssueRealtimeTicketUseCase;

  beforeEach(() => {
    userRepo = makeUserRepo();
    ticketRepo = makeTicketRepo();
    useCase = new IssueRealtimeTicketUseCase(userRepo as any, ticketRepo as any);
    vi.useFakeTimers();
    vi.setSystemTime(new Date(FIXED_NOW));
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('issues a UUID ticket with a 60s TTL and returns it', async () => {
    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(userRepo.findByTenantId).toHaveBeenCalledWith('tenant-1');
    expect(ticketRepo.insert).toHaveBeenCalledTimes(1);
    expect(ticketRepo.insert).toHaveBeenCalledWith({
      ticket: expect.stringMatching(UUID_V4_RE),
      tenantId: 'tenant-1',
      expiresAt: FIXED_NOW + 60_000,
      createdAt: FIXED_NOW,
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.data.ticket).toMatch(UUID_V4_RE);
      expect(result.data.expiresAt).toBe(FIXED_NOW + 60_000);
      const payload = ticketRepo.insert.mock.calls[0]?.[0] as { ticket: string };
      expect(payload.ticket).toBe(result.data.ticket);
      expect(Object.keys(payload).sort()).toEqual([
        'createdAt',
        'expiresAt',
        'tenantId',
        'ticket',
      ]);
    }
  });

  it('issues a distinct ticket per call', async () => {
    const first = await useCase.execute({ tenantId: 'tenant-1' });
    const second = await useCase.execute({ tenantId: 'tenant-1' });

    expect(first.ok).toBe(true);
    expect(second.ok).toBe(true);
    if (first.ok && second.ok) {
      expect(first.data.ticket).toMatch(UUID_V4_RE);
      expect(second.data.ticket).toMatch(UUID_V4_RE);
      expect(first.data.ticket).not.toBe(second.data.ticket);
    }
    expect(ticketRepo.insert).toHaveBeenCalledTimes(2);
  });

  it('returns USER_NOT_FOUND without inserting when the user is missing', async () => {
    userRepo = makeUserRepo(null);
    useCase = new IssueRealtimeTicketUseCase(userRepo as any, ticketRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({ ok: false, error: 'USER_NOT_FOUND' });
    expect(ticketRepo.insert).not.toHaveBeenCalled();
  });

  it('returns TICKET_CREATION_FAILED when the insert is refused', async () => {
    ticketRepo = makeTicketRepo(false);
    useCase = new IssueRealtimeTicketUseCase(userRepo as any, ticketRepo as any);

    const result = await useCase.execute({ tenantId: 'tenant-1' });

    expect(result).toEqual({ ok: false, error: 'TICKET_CREATION_FAILED' });
  });

  it('propagates dependency rejections instead of resolving an error arm', async () => {
    userRepo.findByTenantId.mockRejectedValueOnce(new Error('db down'));

    await expect(useCase.execute({ tenantId: 'tenant-1' })).rejects.toThrow('db down');
  });
});
