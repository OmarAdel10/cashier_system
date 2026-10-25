/**
 * Command DTO for `ServeRequestUseCase`.
 *
 * `method` is the HTTP method, matched case-sensitively against
 * `'GET'` (preserved legacy behavior). `pathname` is a URL pathname
 * only — the value of `new URL(request.url).pathname`: always starts
 * with `/` and MAY begin with `//` (treat as opaque path data, never
 * as URL authority — see the port's adapter obligations); no query
 * string (the SPA fallback strips it; the asset branch forwards it —
 * a presentation-layer concern), no fragment.
 */
export interface ServeRequestDto {
  /** HTTP method of the incoming request (e.g. `'GET'`). */
  method: string;
  /** URL pathname of the incoming request (e.g. `'/settings'`). */
  pathname: string;
}
