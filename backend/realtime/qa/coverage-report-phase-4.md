# Coverage Report — Daftari Backend Realtime Worker Refactor, Phase 4

**Branch:** `refactor/realtime-infrastructure` @ `1d9ec9f`
**Scope:** changed/new testable units (read-only analysis — no code modified)
**Gate:** Gate 1 — "coverage zero gaps in changed units"

---

## Coverage map — Phase 4 changed/new units

| File | Function / Method | Status | Exercised by |
|------|-------------------|--------|--------------|
| `backend/realtime/src/runtime.ts` | `createRealtimeAppFromEnv(env)` | COVERED | `runtime.test.ts` × 4 — every DI wiring integration test calls it (tests: POST /internal/notify 200, GET /ws valid ticket, POST missing secret 401, GET /ws missing ticket 401) |
| `backend/realtime/src/infrastructure/services/rate-limiter.ts` | `RateLimiter` constructor `(maxHits, windowMs)` | COVERED | instantiated at `runtime.ts:42` (`new RateLimiter(100, 60_000)`) and `index.ts:160` default fallback; exercised through Phase 4 integration routes and Phase 3 test `test/realtime.test.ts:56` (`new RateLimiter(1, 60_000)`) |
| `backend/realtime/src/infrastructure/services/rate-limiter.ts` | `RateLimiter.check(key)` | COVERED | POST `/internal/notify` (key `'realtime-notify'`) + GET `/ws` (keys `ws-preauth:<ip>`, `ws-authed:<tenantId>`) in Phase 4 integration tests; `allowed:false` + `retryAfterMs` branch + global-quota branch covered by Phase 3 rate-limit tests (`test/realtime.test.ts:204-238`, `:279-296`) |
| `backend/realtime/src/index.ts` | `createRealtimeApp(deps)` | COVERED | Phase 3 tests (`test/realtime.test.ts:43`, `:51`); Phase 4 via `createRealtimeAppFromEnv`. Inline `RateLimiter` removed and DI'd with `deps.rateLimiter ?? new RateLimiter(...)` default — removal verified not broken |

---

## Pre-existing `index.ts` helpers (not Phase 4 changed units — verified for completeness)

| File | Function / Method | Status | Exercised by |
|------|-------------------|--------|--------------|
| `backend/realtime/src/index.ts` | `constantTimeEqual(a, b)` | COVERED | Phase 3 valid-secret and wrong-secret POST tests; Phase 4 test 1 (valid secret) |
| `backend/realtime/src/index.ts` | `b64urlDecode(part)` | COVERED | Phase 3 JWT tests (via `verifyHs256Jwt`) |
| `backend/realtime/src/index.ts` | `validateTenantId(tenantId)` | COVERED | Phase 3 JWT "tenantId invalid format → 401" test |
| `backend/realtime/src/index.ts` | `verifyHs256Jwt(token, secret)` | COVERED | Phase 3 JWT tests (valid/invalid/wrong-secret/exp/nbf/aud/iss/malformed) |

**Note:** `index.ts:309` `export default createRealtimeApp()` is a module-load side effect executed on import in every test suite that imports `./index`; it adds no separately testable unit surface.

---

## Gaps

**None.** Every testable function/method in the changed units is exercised by tests.

| File:function | Coverage |
|---------------|----------|
| — | (no gaps) |

---

## Verdict

**PASS** — coverage zero gaps in changed units: **0 gaps**.

- `createRealtimeAppFromEnv` (new, `runtime.ts`): COVERED
- `RateLimiter` constructor (new, `rate-limiter.ts`): COVERED
- `RateLimiter.check` (new, `rate-limiter.ts`): COVERED
- `createRealtimeApp` (modified, `index.ts` — inline `RateLimiter` removed → DI'd): COVERED, not broken

All four changed units are covered → Gate 1 coverage criterion satisfied.
