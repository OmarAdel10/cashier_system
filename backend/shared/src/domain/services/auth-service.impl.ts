import { verifyTagged as verify } from '../../password_kdf';
import { verifySessionJwt } from '../../session_jwt';
import { User } from '../entities/user';

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
   * Determine if the owner should be required to re-authenticate based on their last login time.
   * @param lastOwnerLoginAt - The timestamp of the owner's last login (optional)
   * @returns True if re-authentication is required, false otherwise
   */
  shouldRequireOwnerReauth(lastOwnerLoginAt: number | undefined): boolean {
    // Require re-authentication if the owner hasn't logged in in the last 24 hours
    const TWENTY_FOUR_HOURS_IN_MS = 24 * 60 * 60 * 1000;
    if (lastOwnerLoginAt === undefined) {
      return true; // Never logged in before, require auth
    }
    const now = Date.now();
    return (now - lastOwnerLoginAt) > TWENTY_FOUR_HOURS_IN_MS;
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
   * Implements exponential backoff with a maximum lockout time.
   * @param failedAttempts - The number of consecutive failed attempts
   * @returns Lockout duration in milliseconds, or null if no lockout should be applied
   */
  calculateLockout(failedAttempts: number): number | null {
    if (failedAttempts < 1) {
      return null;
    }
    // Exponential backoff: 1s, 2s, 4s, 8s, ... up to a maximum of 5 minutes
    const baseDelayMs = 1000; // 1 second
    const maxDelayMs = 5 * 60 * 1000; // 5 minutes
    const delayMs = Math.min(baseDelayMs * Math.pow(2, failedAttempts - 1), maxDelayMs);
    return delayMs;
  }
}