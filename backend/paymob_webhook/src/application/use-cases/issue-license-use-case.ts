/**
 * Use case for issuing a license key.
 *
 * Signs a license payload using the Ed25519 private key and returns the
 * opaque license key (base64url(signature || JSON(payload))). The actual
 * persistence of the license record is delegated to the caller (route
 * layer or infrastructure adapter).
 */
import type { LicensePayload } from '../../domain/value-objects/license-payload';
import type { IssueLicenseDto, IssueLicenseResponse } from '../dtos/issue-license-dto';

export class IssueLicenseUseCase {
  constructor(
    private readonly signLicenseKey: (
      payload: LicensePayload,
      privateKeyB64: string,
    ) => Promise<string>,
  ) {}

  async execute(dto: IssueLicenseDto): Promise<IssueLicenseResponse> {
    try {
      const licenseKey = await this.signLicenseKey(
        dto.payload,
        dto.privateKeyB64,
      );
      return { ok: true, data: { licenseKey } };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      if (
        message.includes('invalid') ||
        message.includes('key') ||
        message.includes('32-byte')
      ) {
        return { ok: false, error: 'KEY_INVALID' };
      }
      // Transient or unexpected signing failure
      return { ok: false, error: 'SIGNING_TRANSIENT' };
    }
  }
}
