/**
 * Default implementation of HmacValidationService.
 *
 * Delegates cryptographic computation to the shared `verifyPaymobHmac`
 * from `backend/shared/src/paymob`. This service owns only the decision
 * of what to validate and how to interpret the result.
 */
import type { HmacValidationService } from './hmac-validation-service';

export class HmacValidationServiceImpl implements HmacValidationService {
  async isValid(
    concatenated: string,
    signatureHex: string,
    secret: string,
  ): Promise<boolean> {
    const { verifyPaymobHmac } = await import('../../../../shared/src/paymob');
    return verifyPaymobHmac(concatenated, signatureHex, secret);
  }
}
