export interface User {
  readonly tenantId: string;
  readonly email: string;
  readonly role: string;
  readonly tier?: string;
  readonly displayName?: string;
  readonly createdAt: number;
  readonly lastLoginAt?: number;
  readonly lastOwnerLoginAt?: number;
}