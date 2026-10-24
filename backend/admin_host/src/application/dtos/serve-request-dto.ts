/**
 * Command DTO for `ServeRequestUseCase`.
 *
 * `method` is the HTTP method, matched case-sensitively against
 * `'GET'` (preserved legacy behavior). `pathname` is a URL pathname
 * only — no query string (the SPA fallback strips it; the asset
 * branch forwards it — a presentation-layer concern).
 */
export interface ServeRequestDto {
  /** HTTP method of the incoming request (e.g. `'GET'`). */
  method: string;
  /** URL pathname of the incoming request (e.g. `'/settings'`). */
  pathname: string;
}
