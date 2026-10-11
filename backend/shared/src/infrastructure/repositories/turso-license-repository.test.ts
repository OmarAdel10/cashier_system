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
});
