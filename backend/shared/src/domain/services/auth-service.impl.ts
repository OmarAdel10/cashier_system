import { verifyTagged as verify } from '../../password_kdf';

export class AuthServiceImpl {
  /**
   * Validate credentials by comparing the provided password with the stored hash.
   * @param password - The plain text password to validate
   * @param passwordHash - The stored hash to compare against
   * @returns True if the password matches the hash, false otherwise
   */
  async validateCredentials(password: string, passwordHash: string): Promise<boolean> {
    return verify(passwordHash, password);
  }

  /**
   * Determine if the owner should be required to re-authenticate based on
   * their last Firebase Stage-1 login. The policy matches the dashboard:
   * forced re-auth after 90 days, or when no owner login is recorded.
   * @param lastOwnerLoginAt - The timestamp of the owner's last login (optional)
   * @returns True if re-authentication is required, false otherwise
   */
  shouldRequireOwnerReauth(lastOwnerLoginAt: number | undefined): boolean {
    const OWNER_REAUTH_MS = 90 * 24 * 3600 * 1000;
    if (lastOwnerLoginAt === undefined) {
      return true; // Never logged in before, require auth
    }
    const now = Date.now();
    return (now - lastOwnerLoginAt) > OWNER_REAUTH_MS;
  }

  /**
   * Check if there is a session conflict based on the current sessions.
   * @param currentSessions - Array of current session objects (each with an id)
   * @returns True if there is a conflict, false otherwise
   */
  isSessionConflict(currentSessions: Array<{ id: string }>): boolean {
    // For now, we allow multiple sessions (no conflict)
    // In the future, we might want to limit concurrent sessions per user
    return currentSessions.length > 0; // Example: conflict if any session exists
  }

  /**
   * Calculate the lockout duration in milliseconds based on the number of failed attempts.
   * Starts on the 3rd consecutive failure, doubles per failure, and caps at
   * 15 minutes. This is the single TypeScript implementation of the policy.
   * @param failedAttempts - The number of consecutive failed attempts
   * @returns Lockout duration in milliseconds, or null if no lockout should be applied
   */
  calculateLockout(failedAttempts: number): number | null {
    if (failedAttempts < 3) {
      return null;
    }
    const maxDelayMs = 15 * 60 * 1000;
    const delayMs = Math.min(2 ** failedAttempts * 15_000, maxDelayMs);
    return delayMs;
  }
}
