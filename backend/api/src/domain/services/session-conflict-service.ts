/**
 * Session Conflict Service
 *
 * Encapsulates business logic for detecting and resolving session conflicts.
 * This includes web session conflicts (single session per username) and
 * POS session conflicts (device limit enforcement).
 */
import { SessionRecord } from 'daftari-backend-shared/types';

/**
 * Result of a session conflict check.
 */
export interface SessionConflictResult {
  readonly hasConflict: boolean;
  readonly conflictSessionId?: string;
  readonly conflictType: 'web' | 'pos' | 'none';
}

/**
 * Type guard to check if a value is a valid SessionRecord.
 */
function isValidSession(session: unknown): session is SessionRecord {
  return (
    typeof session === 'object' &&
    session !== null &&
    typeof (session as Record<string, unknown>).source === 'string' &&
    ((session as Record<string, unknown>).endedAt === undefined ||
      typeof (session as Record<string, unknown>).endedAt === 'number' ||
      (session as Record<string, unknown>).endedAt === null) &&
    typeof (session as Record<string, unknown>).id === 'string'
  );
}

/**
 * Checks for web session conflict (single web session per username).
 * A web session conflict occurs when there's an active web session
 * (source === 'web', endedAt === undefined) for the same username.
 *
 * @param sessions - Array of active sessions for the username
 * @returns Conflict result with the conflicting session ID if found
 */
export function checkWebSessionConflict(
  sessions: unknown[],
): SessionConflictResult {
  // Handle non-array input
  if (!Array.isArray(sessions)) {
    return { hasConflict: false, conflictType: 'none' };
  }

  const webSession = sessions.find(
    (s): s is SessionRecord =>
      isValidSession(s) && s.source === 'web' && s.endedAt === undefined,
  );
  if (webSession) {
    return {
      hasConflict: true,
      conflictSessionId: webSession.id,
      conflictType: 'web',
    };
  }
  return { hasConflict: false, conflictType: 'none' };
}

/**
 * Checks for POS session conflict (device limit exceeded).
 * A POS conflict occurs when the number of active POS sessions
 * (source === 'pos', endedAt === undefined) reaches the device limit.
 *
 * @param sessions - Array of active POS sessions for the tenant
 * @param deviceLimit - Maximum allowed POS sessions for the tenant's tier
 * @returns Conflict result
 */
export function checkPosSessionConflict(
  sessions: unknown[],
  deviceLimit: number,
): SessionConflictResult {
  // Handle non-array input
  if (!Array.isArray(sessions)) {
    return { hasConflict: false, conflictType: 'none' };
  }

  // Handle invalid device limits: NaN, Infinity, <= 0 means no limit (no conflict)
  if (typeof deviceLimit !== 'number' || !isFinite(deviceLimit) || deviceLimit <= 0) {
    return { hasConflict: false, conflictType: 'none' };
  }

  const activePosSessions = sessions.filter(
    (s): s is SessionRecord =>
      isValidSession(s) && s.source === 'pos' && s.endedAt === undefined,
  );
  if (activePosSessions.length >= deviceLimit) {
    return {
      hasConflict: true,
      conflictSessionId: activePosSessions[0]?.id,
      conflictType: 'pos',
    };
  }
  return { hasConflict: false, conflictType: 'none' };
}

/**
 * Determines if a session can be admitted based on its type and current state.
 *
 * @param session - The session to admit
 * @param activeSessions - Currently active sessions for the tenant/username
 * @param deviceLimit - Device limit for POS sessions (ignored for web)
 * @returns Conflict result
 */
export function canAdmitSession(
  session: unknown,
  activeSessions: unknown[],
  deviceLimit: number,
): SessionConflictResult {
  // Handle invalid session
  if (!isValidSession(session)) {
    return { hasConflict: true, conflictType: 'pos' }; // Reject invalid session
  }

  if (session.source === 'web') {
    return checkWebSessionConflict(activeSessions);
  }
  return checkPosSessionConflict(activeSessions, deviceLimit);
}
