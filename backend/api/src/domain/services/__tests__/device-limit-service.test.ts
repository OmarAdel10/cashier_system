/**
 * DeviceLimitService Tests with Fuzz Testing
 */
import { describe, it, expect } from 'vitest';
import { getDeviceLimit, wouldExceedLimit, getTierForLimit } from '../device-limit-service';
import { TIER_DEVICE_LIMITS } from '../../../../../shared/src/types';

describe('DeviceLimitService', () => {
  describe('getDeviceLimit', () => {
    it('should return correct limit for known tiers', () => {
      expect(getDeviceLimit('starter')).toBe(1);
      expect(getDeviceLimit('pro')).toBe(2);
      expect(getDeviceLimit('business')).toBe(4);
    });

    it('should default to starter for unknown tier', () => {
      expect(getDeviceLimit('unknown')).toBe(1);
      expect(getDeviceLimit('')).toBe(1);
    });

    it('should default to starter for undefined', () => {
      expect(getDeviceLimit(undefined)).toBe(1);
    });

    it('should handle null input', () => {
      expect(getDeviceLimit(null as any)).toBe(1);
    });

    // Fuzz testing for edge cases
    it('should handle various invalid inputs gracefully', () => {
      const invalidInputs = [
        0,
        1,
        -1,
        NaN,
        Infinity,
        -Infinity,
        {},
        [],
        true,
        false,
        Symbol('tier'),
      ];

      for (const input of invalidInputs) {
        const result = getDeviceLimit(input as any);
        // Should always return a valid number (defaulting to 1)
        expect(typeof result).toBe('number');
        expect(result).toBeGreaterThanOrEqual(1);
      }
    });
  });

  describe('wouldExceedLimit', () => {
    it('should return false when active count is below limit', () => {
      expect(wouldExceedLimit(0, 1)).toBe(false);
      expect(wouldExceedLimit(1, 2)).toBe(false);
      expect(wouldExceedLimit(3, 4)).toBe(false);
    });

    it('should return true when active count equals limit', () => {
      expect(wouldExceedLimit(1, 1)).toBe(true);
      expect(wouldExceedLimit(2, 2)).toBe(true);
      expect(wouldExceedLimit(4, 4)).toBe(true);
    });

    it('should return true when active count exceeds limit', () => {
      expect(wouldExceedLimit(2, 1)).toBe(true);
      expect(wouldExceedLimit(3, 2)).toBe(true);
      expect(wouldExceedLimit(5, 4)).toBe(true);
    });

    // Fuzz testing
    it('should handle edge cases gracefully', () => {
      const edgeCases = [
        { active: -1, limit: 1 },   // negative active
        { active: 0, limit: 0 },    // zero limit
        { active: -1, limit: -1 },  // negative limit
        { active: NaN, limit: 1 },  // NaN active
        { active: 1, limit: NaN },  // NaN limit
        { active: Infinity, limit: 1 }, // Infinity active
        { active: 1, limit: Infinity }, // Infinity limit
      ];

      for (const { active, limit } of edgeCases) {
        const result = wouldExceedLimit(active, limit);
        expect(typeof result).toBe('boolean');
      }
    });
  });

  describe('getTierForLimit', () => {
    it('should return correct tier for known limits', () => {
      expect(getTierForLimit(1)).toBe('starter');
      expect(getTierForLimit(2)).toBe('pro');
      expect(getTierForLimit(4)).toBe('business');
    });

    it('should default to starter for unknown limit', () => {
      expect(getTierForLimit(0)).toBe('starter');
      expect(getTierForLimit(3)).toBe('starter');
      expect(getTierForLimit(5)).toBe('starter');
      expect(getTierForLimit(-1)).toBe('starter');
    });

    // Fuzz testing
    it('should handle various invalid inputs', () => {
      const invalidInputs = [NaN, Infinity, -Infinity, '1', null, undefined, {}, []];

      for (const input of invalidInputs) {
        const result = getTierForLimit(input as any);
        expect(typeof result).toBe('string');
        expect(result.length).toBeGreaterThan(0);
      }
    });
  });

  describe('TIER_DEVICE_LIMITS constant', () => {
    it('should have expected tiers and limits', () => {
      expect(TIER_DEVICE_LIMITS.starter).toBe(1);
      expect(TIER_DEVICE_LIMITS.pro).toBe(2);
      expect(TIER_DEVICE_LIMITS.business).toBe(4);
    });

    it('should only have expected keys', () => {
      const keys = Object.keys(TIER_DEVICE_LIMITS);
      expect(keys).toEqual(['starter', 'pro', 'business']);
    });
  });
});
