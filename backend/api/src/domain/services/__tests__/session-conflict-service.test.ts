/**
 * SessionConflictService Tests with Fuzz Testing
 */
import { describe, it, expect } from 'vitest';
import {
  checkWebSessionConflict,
  checkPosSessionConflict,
  canAdmitSession,
  SessionConflictResult,
} from '../session-conflict-service';
import { SessionRecord } from '../../../../../shared/src/types';

const createSession = (overrides: Partial<SessionRecord> = {}): SessionRecord => ({
  id: 'sess-1',
  tenantId: 'tenant-1',
  deviceHwid: 'device-1',
  username: 'user1',
  startedAt: Date.now() - 1000,
  heartbeatAt: Date.now(),
  endedAt: undefined,
  source: 'pos',
  ...overrides,
});

describe('SessionConflictService', () => {
  describe('checkWebSessionConflict', () => {
    it('should return no conflict for empty sessions array', () => {
      const result = checkWebSessionConflict([]);
      expect(result).toEqual({ hasConflict: false, conflictType: 'none' });
    });

    it('should return no conflict when no web sessions exist', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'pos' }),
        createSession({ id: 'sess-2', source: 'pos' }),
      ];
      const result = checkWebSessionConflict(sessions);
      expect(result).toEqual({ hasConflict: false, conflictType: 'none' });
    });

    it('should return no conflict when web session is ended', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'web', endedAt: Date.now() }),
      ];
      const result = checkWebSessionConflict(sessions);
      expect(result).toEqual({ hasConflict: false, conflictType: 'none' });
    });

    it('should detect conflict when live web session exists', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'web' }),
        createSession({ id: 'sess-2', source: 'pos' }),
      ];
      const result = checkWebSessionConflict(sessions);
      expect(result.hasConflict).toBe(true);
      expect(result.conflictType).toBe('web');
      expect(result.conflictSessionId).toBe('sess-1');
    });

    it('should detect conflict with multiple live web sessions (first one)', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'web' }),
        createSession({ id: 'sess-2', source: 'web' }),
      ];
      const result = checkWebSessionConflict(sessions);
      expect(result.hasConflict).toBe(true);
      expect(result.conflictType).toBe('web');
      expect(result.conflictSessionId).toBe('sess-1');
    });

    // Fuzz testing
    it('should handle malformed session objects gracefully', () => {
      const malformedSessions = [
        {}, // empty object
        { id: 'test' }, // missing required fields
        { source: 'web' }, // missing endedAt
        { source: 'web', endedAt: null }, // null endedAt
        { source: 'web', endedAt: 'invalid' }, // invalid endedAt
        { source: 'unknown' }, // unknown source
        { source: 123 }, // invalid source type
        { endedAt: undefined }, // missing source
        null as any, // null session
        undefined as any, // undefined session
      ];

      for (const session of malformedSessions) {
        const result = checkWebSessionConflict([session as any]);
        expect(result).toHaveProperty('hasConflict');
        expect(result).toHaveProperty('conflictType');
        expect(typeof result.hasConflict).toBe('boolean');
      }
    });

    it('should handle non-array input gracefully', () => {
      const invalidInputs = [null, undefined, 'string', 123, {}, true];

      for (const input of invalidInputs) {
        const result = checkWebSessionConflict(input as any);
        expect(result).toHaveProperty('hasConflict');
        expect(typeof result.hasConflict).toBe('boolean');
      }
    });
  });

  describe('checkPosSessionConflict', () => {
    it('should return no conflict for empty sessions', () => {
      const result = checkPosSessionConflict([], 1);
      expect(result).toEqual({ hasConflict: false, conflictType: 'none' });
    });

    it('should return no conflict when active POS sessions below limit', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'pos' }),
      ];
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(false);
    });

    it('should return conflict when active POS sessions equal limit', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'pos' }),
        createSession({ id: 'sess-2', source: 'pos' }),
      ];
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(true);
      expect(result.conflictType).toBe('pos');
      expect(result.conflictSessionId).toBe('sess-1');
    });

    it('should return conflict when active POS sessions exceed limit', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'pos' }),
        createSession({ id: 'sess-2', source: 'pos' }),
        createSession({ id: 'sess-3', source: 'pos' }),
      ];
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(true);
      expect(result.conflictType).toBe('pos');
    });

    it('should ignore ended POS sessions', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'pos', endedAt: Date.now() }), // ended
        createSession({ id: 'sess-2', source: 'pos' }), // active
      ];
      // With limit=2, we have 1 active session, so no conflict
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(false);
    });

    it('should detect conflict when active POS sessions reach limit (including ended)', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'pos', endedAt: Date.now() }), // ended
        createSession({ id: 'sess-2', source: 'pos' }), // active
        createSession({ id: 'sess-3', source: 'pos' }), // active
      ];
      // With limit=2, we have 2 active sessions, so conflict
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(true);
    });

    it('should ignore web sessions when counting POS', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'web' }),
        createSession({ id: 'sess-2', source: 'web' }),
        createSession({ id: 'sess-3', source: 'pos' }), // only 1 POS
      ];
      // With limit=2, we have 1 active POS session, so no conflict
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(false);
    });

    it('should detect conflict when POS sessions reach limit (ignoring web)', () => {
      const sessions = [
        createSession({ id: 'sess-1', source: 'web' }),
        createSession({ id: 'sess-2', source: 'pos' }), // active POS 1
        createSession({ id: 'sess-3', source: 'pos' }), // active POS 2
      ];
      // With limit=2, we have 2 active POS sessions, so conflict
      const result = checkPosSessionConflict(sessions, 2);
      expect(result.hasConflict).toBe(true);
    });

    // Fuzz testing
    it('should handle edge case limits', () => {
      const sessions = [createSession({ source: 'pos' })];

      // Invalid limits should mean no limit (no conflict)
      expect(checkPosSessionConflict(sessions, 0).hasConflict).toBe(false);
      expect(checkPosSessionConflict(sessions, -1).hasConflict).toBe(false);
      expect(checkPosSessionConflict(sessions, NaN).hasConflict).toBe(false);
      expect(checkPosSessionConflict(sessions, Infinity).hasConflict).toBe(false);
    });

    it('should handle malformed sessions gracefully', () => {
      const malformedSessions = [
        {},
        { source: 'pos' },
        { source: 'pos', endedAt: null },
        { source: 123 },
        null as any,
        undefined as any,
      ];

      for (const session of malformedSessions) {
        const result = checkPosSessionConflict([session as any], 1);
        expect(result).toHaveProperty('hasConflict');
        expect(typeof result.hasConflict).toBe('boolean');
      }
    });
  });

  describe('canAdmitSession', () => {
    it('should check web conflict for web session', () => {
      const newSession = createSession({ id: 'new', source: 'web' });
      const active = [createSession({ id: 'existing', source: 'web' })];

      const result = canAdmitSession(newSession, active, 10);
      expect(result.hasConflict).toBe(true);
      expect(result.conflictType).toBe('web');
    });

    it('should check pos conflict for pos session', () => {
      const newSession = createSession({ id: 'new', source: 'pos' });
      const active = [
        createSession({ id: 'existing1', source: 'pos' }),
        createSession({ id: 'existing2', source: 'pos' }),
      ];

      const result = canAdmitSession(newSession, active, 2);
      expect(result.hasConflict).toBe(true);
      expect(result.conflictType).toBe('pos');
    });

    it('should allow admission when no conflict', () => {
      const newSession = createSession({ id: 'new', source: 'pos' });
      const active = [createSession({ id: 'existing', source: 'pos' })];

      const result = canAdmitSession(newSession, active, 2);
      expect(result.hasConflict).toBe(false);
      expect(result.conflictType).toBe('none');
    });

    it('should handle unknown source', () => {
      const newSession = createSession({ id: 'new', source: 'unknown' as any });
      const active: SessionRecord[] = [];

      const result = canAdmitSession(newSession, active, 1);
      // Unknown source treated as POS
      expect(result).toHaveProperty('hasConflict');
    });

    // Fuzz testing
    it('should handle malformed input gracefully', () => {
      const malformedSessions = [{}, { source: 'web' }, null as any, undefined as any];
      const newSession = createSession();

      for (const session of malformedSessions) {
        const result = canAdmitSession(newSession, [session as any], 1);
        expect(result).toHaveProperty('hasConflict');
        expect(typeof result.hasConflict).toBe('boolean');
      }
    });

    it('should handle invalid device limits', () => {
      const newSession = createSession({ source: 'pos' });
      const active = [createSession({ source: 'pos' })];

      // Invalid limits mean no limit (no conflict)
      expect(canAdmitSession(newSession, active, -1).hasConflict).toBe(false);
      expect(canAdmitSession(newSession, active, 0).hasConflict).toBe(false);
      expect(canAdmitSession(newSession, active, NaN).hasConflict).toBe(false);
      expect(canAdmitSession(newSession, active, Infinity).hasConflict).toBe(false);
    });

    it('should reject invalid session object', () => {
      const invalidSessions = [{}, { source: 'pos' }, null as any, undefined as any];
      const active: SessionRecord[] = [];

      for (const session of invalidSessions) {
        const result = canAdmitSession(session, active, 1);
        expect(result.hasConflict).toBe(true);
        expect(result.conflictType).toBe('pos');
      }
    });
  });

  describe('SessionConflictResult type', () => {
    it('should have correct structure', () => {
      const result: SessionConflictResult = {
        hasConflict: false,
        conflictType: 'none',
      };
      expect(result.hasConflict).toBe(false);
      expect(result.conflictType).toBe('none');
      expect(result.conflictSessionId).toBeUndefined();
    });

    it('should allow conflictSessionId when hasConflict is true', () => {
      const result: SessionConflictResult = {
        hasConflict: true,
        conflictSessionId: 'sess-123',
        conflictType: 'web',
      };
      expect(result.hasConflict).toBe(true);
      expect(result.conflictSessionId).toBe('sess-123');
    });
  });
});
