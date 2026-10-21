import { describe, expect, it } from 'vitest';

const pickChar = (s: string, rng: () => number): string =>
  s[Math.floor(rng() * s.length)]!;
const pickItem = <T>(arr: readonly T[], rng: () => number): T =>
  arr[Math.floor(rng() * arr.length)]!;
import { TicketValidationServiceImpl } from '../services/ticket-validation-service.impl';
import { BroadcastServiceImpl } from '../services/broadcast-service.impl';

/** Simple deterministic xorshift32 PRNG. */
function makeRng(seed: number) {
  let state = seed >>> 0;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0xffffffff;
  };
}

const seeds = [2101, 2202, 2303];
const operations = 200;

describe('TicketValidationService — deterministic fuzz', () => {
  const svc = new TicketValidationServiceImpl();

  it.each(seeds)('seed %i classifies %i tickets without crashing', (seed) => {
    const rng = makeRng(seed);
    const blanks = ['', ' ', '\t', '\n', '\r'];
    const alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    for (let operation = 0; operation < operations; operation += 1) {
      const choice = Math.floor(rng() * 5);
      let ticket: string;

      if (choice === 0) {
        const len = 1 + Math.floor(rng() * 40);
        ticket = Array.from({ length: len }, () => pickChar(alpha, rng)).join('');
      } else if (choice === 1) {
        ticket = pickItem(blanks, rng);
      } else if (choice === 2) {
        const a = Array.from({ length: 20 }, () => pickChar(alpha, rng)).join('');
        const b = Array.from({ length: 5 }, () => pickChar(alpha, rng)).join('');
        ticket = a + ' ' + b;
      } else if (choice === 3) {
        const a = Array.from({ length: 10 }, () => pickChar(alpha, rng)).join('');
        ticket = a + '\u0000';
      } else {
        ticket = Array.from({ length: 5 }, () => pickChar(alpha, rng)).join('');
      }

      const result = svc.validateFormat(ticket);
      expect(typeof result.ok).toBe('boolean');
      if (result.ok) {
        expect(typeof result.value).toBe('string');
        expect(result.value.length).toBeGreaterThan(0);
      } else {
        expect(typeof result.error).toBe('string');
        expect(result.error.length).toBeGreaterThan(0);
      }
    }
  });
});

describe('BroadcastService — deterministic fuzz', () => {
  const svc = new BroadcastServiceImpl();
  const now = 1_769_000_000_000;
  const alpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const randWord = (rng: () => number, len: number) =>
    Array.from({ length: len }, () => pickChar(alpha, rng)).join('');

  it.each(seeds)('seed %i builds and classifies %i payloads without crashing', (seed) => {
    const rng = makeRng(seed);
    const types = ['sale', 'session', 'sync'];

    for (let operation = 0; operation < operations; operation += 1) {
      const choice = Math.floor(rng() * 5);
      let type: string;
      let tenantId: string;

      if (choice === 0) {
        type = pickItem(types, rng);
        tenantId = randWord(rng, 1 + Math.floor(rng() * 20));
      } else if (choice === 1) {
        type = '';
        tenantId = randWord(rng, 10);
      } else if (choice === 2) {
        type = randWord(rng, 6);
        tenantId = '';
      } else if (choice === 3) {
        type = '';
        tenantId = '';
      } else {
        type = randWord(rng, 1 + Math.floor(rng() * 30)) + ' ';
        tenantId = ' ' + randWord(rng, 8) + ' ';
      }

      const payload = svc.buildPayload(type, tenantId, {}, now);
      expect(payload.createdAt).toBe(now);
      expect(typeof payload.data).toBe('object');

      const should = svc.shouldBroadcast(payload);
      expect(typeof should).toBe('boolean');

      if (type.trim().length > 0 && tenantId.trim().length > 0) {
        expect(should).toBe(true);
      } else {
        expect(should).toBe(false);
      }
    }
  });
});
