export interface AuthUser {
  readonly tenantId: string;
  readonly username: string;
  readonly passwordHash: string;
  readonly role: 'admin' | 'cashier';
  readonly displayName?: string;
  readonly mustChangePassword: number;
  readonly isActive: number;
  readonly failedAttempts: number;
  readonly lockedUntil?: number;
  readonly createdAt: number;
  readonly updatedAt: number;
}