import 'reflect-metadata';
import { describe, expect, it } from 'vitest';
import { TursoLicenseRepository } from './turso-license-repository';
import type { TursoDb } from '../../turso';

describe('TursoLicenseRepository.getDeviceLimit', () => {
  it('uses the canonical tier limits', () => {
    const repository = new TursoLicenseRepository({} as TursoDb);

    expect(repository.getDeviceLimit('starter')).toBe(1);
    expect(repository.getDeviceLimit('pro')).toBe(2);
    expect(repository.getDeviceLimit('business')).toBe(4);
  });

  it('falls back to one device for an unknown tier', () => {
    const repository = new TursoLicenseRepository({} as TursoDb);

    expect(repository.getDeviceLimit('unknown')).toBe(1);
  });

  it('treats lifetime and exact grace-end boundaries as active', async () => {
    const repository = new TursoLicenseRepository({} as TursoDb);

    await expect(repository.isExpired(0, 9_999_999_999)).resolves.toBe(false);
    await expect(repository.isExpired(1_000, 1_000)).resolves.toBe(false);
    await expect(repository.isExpired(1_000, 1_001)).resolves.toBe(true);
  });
});
