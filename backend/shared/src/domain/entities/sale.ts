export interface Sale {
  readonly id: string;
  readonly tenantId: string;
  readonly receiptJson: string;
  readonly totalPiastres: number;
  readonly createdAt: number;
}