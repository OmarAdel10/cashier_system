/**
 * Unit tests for IssueLicenseUseCase.
 *
 * Tests the license key signing flow: signing succeeds or fails.
 * The signLicenseKey function is mocked so only the use case logic is under test.
 */
import { describe, expect, it, vi } from 'vitest';
import { IssueLicenseUseCase } from '../use-cases/issue-license-use-case';
import type { LicensePayload } from '../../domain/value-objects/license-payload';
import type { IssueLicenseDto } from '../dtos/issue-license-dto';

const NOW = 1_769_000_000_000;

function makePayload(overrides: Partial<LicensePayload> = {}): LicensePayload {
  return {
    tenantId: 'tenant-1',
    deviceHwid: 'device-abc',
    subscriptionEnd: NOW + 30 * 24 * 60 * 60 * 1000,
    billingCycle: 'monthly',
    graceEnd: NOW + 37 * 24 * 60 * 60 * 1000,
    createdAt: NOW,
    ...overrides,
  };
}

function makeDto(overrides: Partial<IssueLicenseDto> = {}): IssueLicenseDto {
  return {
    payload: makePayload(),
    privateKeyB64: 'private-key-base64',
    ...overrides,
  };
}

describe('IssueLicenseUseCase', () => {
  describe('Signing success', () => {
    it('returns license key when signing succeeds', async () => {
      const signLicenseKey = vi.fn().mockResolvedValue('signed-license-key');
      const useCase = new IssueLicenseUseCase(signLicenseKey);
      const result = await useCase.execute(makeDto());
      expect(result).toEqual({ ok: true, data: { licenseKey: 'signed-license-key' } });
      expect(signLicenseKey).toHaveBeenCalledWith(makePayload().tenantId ? makePayload() : makePayload(), 'private-key-base64');
    });
  });

  describe('Signing failure', () => {
    it('returns SIGNING_FAILED when signing throws', async () => {
      const signLicenseKey = vi.fn().mockRejectedValue(new Error('signing failed'));
      const useCase = new IssueLicenseUseCase(signLicenseKey);
      const result = await useCase.execute(makeDto());
      expect(result).toEqual({ ok: false, error: 'SIGNING_FAILED' });
    });

    it('returns SIGNING_FAILED when signing rejects', async () => {
      const signLicenseKey = vi.fn().mockRejectedValue(null);
      const useCase = new IssueLicenseUseCase(signLicenseKey);
      const result = await useCase.execute(makeDto());
      expect(result).toEqual({ ok: false, error: 'SIGNING_FAILED' });
    });
  });
});
