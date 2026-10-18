/**
 * Owner Refresh DTOs
 *
 * Data Transfer Objects for the owner refresh use case.
 */

/**
 * Input data for owner refresh.
 */
export interface OwnerRefreshDto {
  readonly tenantId: string;
}

/**
 * Output data for owner refresh.
 */
export type OwnerRefreshResponse = { readonly ok: true };
