import { describe, expect, it } from 'vitest';
import { TicketValidationServiceImpl } from '../services/ticket-validation-service.impl';
import { BroadcastServiceImpl } from '../services/broadcast-service.impl';

describe('TicketValidationService — structural ticket validation', () => {
  const svc = new TicketValidationServiceImpl();

  it('accepts a well-formed ticket', () => {
    const result = svc.validateFormat('abc123');
    expect(result).toEqual({ ok: true, value: 'abc123' });
  });

  it('trims surrounding whitespace', () => {
    const result = svc.validateFormat('  abc123  ');
    expect(result).toEqual({ ok: true, value: 'abc123' });
  });

  it.each(['', '   ', '\t', '\n'])('rejects empty/whitespace ticket %j', (ticket) => {
    const result = svc.validateFormat(ticket);
    expect(result).toEqual({ ok: false, error: 'MISSING_TICKET' });
  });

  it.each(['a b', 'a\tb', 'a\nb', 'a\u0000b', 'a\u007fb'])(
    'rejects ticket with control/whitespace char %j',
    (ticket) => {
      const result = svc.validateFormat(ticket);
      expect(result).toEqual({ ok: false, error: 'INVALID_TICKET' });
    },
  );
});

describe('BroadcastService — payload building and fanout policy', () => {
  const svc = new BroadcastServiceImpl();
  const now = 1_769_000_000_000;

  it('builds a canonical payload', () => {
    const payload = svc.buildPayload('sale', 'tenant-1', { count: 3 }, now);
    expect(payload).toEqual({
      type: 'sale',
      tenantId: 'tenant-1',
      data: { count: 3 },
      createdAt: now,
    });
  });

  it('trims type and tenantId', () => {
    const payload = svc.buildPayload('  sale  ', '  tenant-1  ', {}, now);
    expect(payload.type).toBe('sale');
    expect(payload.tenantId).toBe('tenant-1');
  });

  it('defaults data to empty object', () => {
    const payload = svc.buildPayload('sale', 'tenant-1', undefined as unknown as Record<string, unknown>, now);
    expect(payload.data).toEqual({});
  });

  it.each([
    { type: '', tenantId: 'tenant-1' },
    { type: 'sale', tenantId: '' },
    { type: '', tenantId: '' },
  ])('shouldBroadcast returns false for %j', (payload) => {
    expect(svc.shouldBroadcast(payload as never)).toBe(false);
  });

  it('shouldBroadcast returns true for a valid payload', () => {
    expect(svc.shouldBroadcast({ type: 'sale', tenantId: 'tenant-1', data: {}, createdAt: now })).toBe(true);
  });
});
