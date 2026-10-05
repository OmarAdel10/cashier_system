/**
 * Synced sale record entity.
 *
 * Represents a sale transaction synced from a POS device to the cloud.
 * The receipt is stored as JSON for flexibility in receipt format.
 * Total is stored in piastres (1/100 of currency unit) for integer precision.
 *
 * @example
 * ```typescript
 * const sale: Sale = {
 *   id: 'sale_1234567890_abc123',
 *   tenantId: 'tenant-123',
 *   receiptJson: '{"items":[{"name":"Coffee","qty":2,"price":5000}],"total":10000,"payment":"cash"}',
 *   totalPiastres: 10000,
 *   createdAt: Date.now()
 * };
 * ```
 */
export interface Sale {
  /** Unique sale identifier: 'sale_{timestamp}_{random}' */
  readonly id: string;
  /** Tenant this sale belongs to */
  readonly tenantId: string;
  /** Full receipt data as JSON string */
  readonly receiptJson: string;
  /** Total amount in piastres (1/100 of base currency unit) */
  readonly totalPiastres: number;
  /** Unix timestamp (ms) when sale was created/synced */
  readonly createdAt: number;
}