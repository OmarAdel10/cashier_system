/**
 * Issue Realtime Ticket Use Case
 *
 * Issues a 60-second single-use ticket for WebSocket auth (POST /auth/ticket).
 * Requires an existing tenant profile — a missing user is USER_NOT_FOUND
 * (legacy 401 'User not found') for the route to map in a later phase.
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
    const now = Date.now();
    const user = await this.userRepo.findByTenantId(dto.tenantId);
    if (!user) {
      return { ok: false, error: 'USER_NOT_FOUND' };
    }
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
