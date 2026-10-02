export interface AuthService {
  validateCredentials(password: string, passwordHash: string): Promise<boolean>;
  shouldRequireOwnerReauth(lastOwnerLoginAt: number | undefined): boolean;
  isSessionConflict(currentSessions: Array<{ id: string }>): boolean;
  calculateLockout(failedAttempts: number): number | null;
}