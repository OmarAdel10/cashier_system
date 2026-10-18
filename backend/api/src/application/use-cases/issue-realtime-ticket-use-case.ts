/**
 * Issue Realtime Ticket Use Case
 *
 * Issues a 60-second single-use ticket for WebSocket auth (POST /auth/ticket).
 * Requires an existing tenant profile — a missing user is USER_NOT_FOUND
 * (legacy 401 'User not found') for the route to map in a later phase.
 *
 * Wiring pin: identity fields (tenantId/sessionId/username/role) must be
 * sourced ONLY from verified middleware context at the wiring phase - never
 * from request body/query/header values (base precedent: cross-tenant tests,
 * backend/api/test/api.test.ts:1115-1134).
 */
import type { UserRepository } from 'daftari-backend-shared/domain/repositories/user-repository';
import type { RealtimeTicketRepository } from '../../domain/repositories/realtime-ticket-repository';
import type { TicketIssueDto, TicketIssueResponse } from '../dtos/ticket-issue.dto';

export class IssueRealtimeTicketUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly ticketRepo: RealtimeTicketRepository,
  ) {}

  async execute(dto: TicketIssueDto): Promise<TicketIssueResponse> {
    const user = await this.userRepo.findByTenantId(dto.tenantId);
    if (!user) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }
    // Read post-lookup, matching legacy ordering.
    const now = Date.now();
    const ticket = crypto.randomUUID();
    const expiresAt = now + 60_000; // 60-second TTL (preserved policy)
    const inserted = await this.ticketRepo.insert({
      ticket,
      tenantId: dto.tenantId,
      expiresAt,
      createdAt: now,
    });
    if (!inserted) {
      return { ok: false, error: 'TICKET_CREATION_FAILED' };
    }
    return { ok: true, data: { ticket, expiresAt } };
  }
}
