export interface Session {
  readonly id: string;
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly username: string;
  readonly startedAt: number;
  readonly heartbeatAt: number;
  readonly endedAt?: number;
  readonly source?: 'pos' | 'web';
}