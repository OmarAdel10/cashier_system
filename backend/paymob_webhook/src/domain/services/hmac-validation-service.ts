/**
 * Domain service for HMAC validation business rules.
 *
 * Encapsulates pure policy for verifying a Paymob webhook's HMAC-SHA512
 * signature over the 20 documented transaction fields. Cryptographic
 * computation is delegated to the shared `verifyPaymobHmac` at the
 * application layer; this service owns the decision of what to validate
 * and how to interpret the result.
 */
export interface HmacValidationService {
  /**
   * Decides whether an event's HMAC signature is valid.
   *
   * @param concatenated - Concatenated HMAC string over the 20 fields
   * @param signatureHex - Hex HMAC signature from the `hmac` query param
   * @param secret - Shared HMAC secret
   * @returns true if the signature is valid, false otherwise
   */
  isValid(
    concatenated: string,
    signatureHex: string,
    secret: string,
  ): Promise<boolean>;
}
