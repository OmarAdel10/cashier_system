import { inject, injectable } from 'tsyringe';
import { SessionRepository } from '../../domain/repositories/session-repository';
import { SaleRepository } from '../../domain/repositories/sale-repository';
import { DeviceRepository } from '../../domain/repositories/device-repository';
import { UserRepository } from '../../domain/repositories/user-repository';

/**
 * Data Transfer Object for sync data request.
 */
export interface SyncDataDto {
  /** Tenant identifier */
  tenantId: string;
  /** Session identifier */
  sessionId: string;
  /** Timestamp of last successful sync (milliseconds since epoch) */
  lastSyncTimestamp: number;
}

/**
 * Sale summary for sync response (simplified from full Sale entity).
 */
export interface SyncedSale {
  /** Sale identifier */
  id: string;
  /** Tenant identifier */
  tenantId: string;
  /** Sale amount in piastres */
  amount: number;
  /** Sale line items (not stored in Sale entity, empty for now) */
  items: Array<{
    productId: string;
    quantity: number;
    price: number;
    total: number;
  }>;
  /** Payment method */
  paymentMethod: 'cash' | 'card' | 'mobile';
  /** Sale status */
  status: 'pending' | 'completed' | 'voided';
  /** Creation timestamp */
  createdAt: number;
  /** Last update timestamp */
  updatedAt: number;
}

/**
 * Session info for sync response.
 */
export interface SyncedSession {
  id: string;
  tenantId: string;
  deviceHwid: string;
  username: string;
  startedAt: number;
  heartbeatAt: number;
  endedAt: number;
  source: 'pos' | 'web';
}

/**
 * Sync data response type discriminated union.
 */
export type SyncDataResponse =
  | {
      ok: true;
      data: {
        /** Current session info */
        session: SyncedSession;
        /** Sales created since lastSyncTimestamp */
        unsyncedSales: SyncedSale[];
        /** Server timestamp for client clock sync */
        serverTime: number;
      };
      error?: never;
    }
  | {
      ok: false;
      /** Error code: MISSING_FIELDS, SESSION_NOT_FOUND */
      error: string;
      /** Milliseconds until retry allowed */
      retryAfterMs?: number;
    };

/**
 * Use case for synchronizing POS data with server.
 *
 * Provides incremental sync for offline-first POS devices.
 * Returns current session state and any sales created since
 * the last successful sync timestamp.
 *
 * The POS device calls this periodically to:
 * 1. Verify session is still valid
 * 2. Download new sales from other devices
 * 3. Upload its own pending sales (via separate endpoint)
 * 4. Sync server time for clock drift correction
 *
 * @example
 * ```typescript
 * const syncUseCase: SyncDataUseCase = container.resolve('SyncDataUseCase');
 * const result = await syncUseCase.execute({
 *   tenantId: 'tenant-123',
 *   sessionId: 'sess_1234567890_abc123',
 *   lastSyncTimestamp: Date.now() - 300000 // 5 minutes ago
 * });
 *
 * if (result.ok) {
 *   console.log('Server time:', result.data.serverTime);
 *   console.log('New sales:', result.data.unsyncedSales.length);
 * }
 * ```
 */
@injectable()
export class SyncDataUseCase {
  /**
   * Creates a SyncDataUseCase with injected dependencies.
   *
   * @param sessionRepo - Repository for session validation
   * @param saleRepo - Repository for sale queries
   * @param deviceRepo - Repository for device info (future use)
   * @param userRepo - Repository for user info (future use)
   */
  constructor(
    @inject('SessionRepository') private readonly sessionRepo: SessionRepository,
    @inject('SaleRepository') private readonly saleRepo: SaleRepository,
    @inject('DeviceRepository') private readonly deviceRepo: DeviceRepository,
    @inject('UserRepository') private readonly userRepo: UserRepository
  ) {}

  /**
   * Executes the sync data use case.
   *
   * @param dto - Sync parameters including last sync timestamp
   * @returns SyncDataResponse with session info and unsynced sales
   */
  async execute(dto: SyncDataDto): Promise<SyncDataResponse> {
    // Input validation
    if (!dto.tenantId || !dto.sessionId || dto.lastSyncTimestamp === undefined) {
      return {
        ok: false,
        error: 'MISSING_FIELDS',
        retryAfterMs: 0
      };
    }

    // Validate session exists and is active
    const session = await this.sessionRepo.getLiveWeb(dto.tenantId, dto.sessionId);

    if (!session) {
      return {
        ok: false,
        error: 'SESSION_NOT_FOUND',
        retryAfterMs: 0
      };
    }

    // Get unsynced sales since last sync
    const unsyncedSales = await this.saleRepo.listByTenantSince(dto.tenantId, dto.lastSyncTimestamp);

    // Format sales for response
    const formattedSales: SyncedSale[] = unsyncedSales.map(sale => ({
      id: sale.id,
      tenantId: sale.tenantId,
      amount: sale.totalPiastres,
      items: [], // Sale entity doesn't contain item details, would need separate lookup
      paymentMethod: 'cash' as const, // Default, not stored in Sale entity
      status: 'completed' as const, // Default, not stored in Sale entity
      createdAt: sale.createdAt,
      updatedAt: sale.createdAt // Sale doesn't have updatedAt, use createdAt
    }));

    return {
      ok: true,
      data: {
        session: {
          id: session.id,
          tenantId: session.tenantId,
          deviceHwid: session.deviceHwid,
          username: session.username,
          startedAt: session.startedAt,
          heartbeatAt: session.heartbeatAt,
          endedAt: session.endedAt ?? 0,
          source: session.source ?? 'pos'
        },
        unsyncedSales: formattedSales,
        serverTime: Date.now()
      }
    };
  }
}