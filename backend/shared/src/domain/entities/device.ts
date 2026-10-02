export interface Device {
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly deviceName?: string;
  readonly platform?: string;
  readonly firstSeenAt: number;
  readonly lastSeenAt: number;
}