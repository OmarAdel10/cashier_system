export interface License {
  readonly tenantId: string;
  readonly deviceHwid: string;
  readonly licenseKey: string;
  readonly subscriptionEnd: number;
  readonly billingCycle: 'monthly' | 'yearly' | 'lifetime';
  readonly graceEnd: number;
  readonly status: 'active' | 'expired';
  readonly createdAt: number;
}