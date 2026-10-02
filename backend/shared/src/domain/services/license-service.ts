export interface LicenseService {
  isExpired(graceEnd: number, now: number): boolean;
  getDeviceLimit(tier: string): number;
}