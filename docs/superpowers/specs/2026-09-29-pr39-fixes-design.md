# PR #39 Review Findings and Fix Decisions (Design Spec)

**Date:** 2026-09-29
**Branch:** `feature/admin-dashboard-phase1` (PR #39, base `development`)
**Status:** Binding

## Authority

This document is the **binding authority** for every change made on the PR #39 fixes branch. Where this spec and any other document disagree, this spec wins. The implementation plan at `docs/superpowers/plans/2026-09-29-pr39-fixes-and-hardening.md` **argues from this spec**: its tasks exist to close the findings registered here, and every later implementer cites this file as `§Finding <ID>`. The plan is the *how*; this spec is the *what* and *why*.

Scope of this spec: the Google popup sign-in root cause (Part 1), the complete PR #39 review findings register (Part 2), the decisions this branch is committed to (Part 3), the Plane scope (Part 4), and the verification gates that must pass before merge (Part 5).

---

## 1. Confirmed root cause: Google popup sign-in failure

**Root cause:** `backend/admin_host/src/index.ts:62` serves `Cross-Origin-Opener-Policy: same-origin`. That header severs the `window.opener` link between the dashboard page and Firebase's auth popup. `signInWithPopup` therefore cannot receive the credential back — while Google/Firebase has *already* created the account. The observed symptom follows exactly: the account is visible in the Firebase console, but the dashboard shows the generic message "فشل تسجيل الدخول. حاول مجددًا." (`FIREBASE_FAILED`).

`same-origin` is the *only* header at fault. The accompanying `Cross-Origin-Embedder-Policy: require-corp` (`index.ts:61`) is not the popup blocker; it is what makes the page cross-origin isolated. Both headers are set unconditionally in `withHeaders()` and both are currently asserted as-is by tests.

### Evidence (all four items)

1. **The header and its test.** `backend/admin_host/src/index.ts:61-62` sets `Cross-Origin-Embedder-Policy: require-corp` and `Cross-Origin-Opener-Policy: same-origin`; `backend/admin_host/test/index.test.ts:66-67` asserts `Cross-Origin-Opener-Policy` is `same-origin` and `Cross-Origin-Embedder-Policy` is `require-corp`. The comment above them reads `// Cross-origin isolation — required for Flutter WASM (SharedArrayBuffer).`

2. **Flutter itself says isolation is optional.** The generated `backend/admin_host/public/flutter_bootstrap.js` (Skwasm loader, minified, line 6) states verbatim:

   > "Flutter Web: Skwasm uses multi-threading and web workers for better performance, but your page needs to be cross-origin isolated to support multi-threading. **Skwasm will run in single-threaded mode.**"

   It then computes `skwasmSingleThreaded: e.enableWimp||!s.crossOriginIsolated||...`, where `s.crossOriginIsolated` is `window.crossOriginIsolated`. So dropping isolation degrades performance only; it does not break the app. Flutter therefore does **not** require `COOP: same-origin`.

3. **The landing page is the working precedent.** `landing_page/web/_headers` is also a Flutter WASM app (same `wasm-unsafe-eval` CSP, same security-header set) and ships **no `Cross-Origin-Opener-Policy` and no `Cross-Origin-Embedder-Policy`**. It works. The admin host is stricter than the app it mirrors, for a benefit Flutter labels optional.

4. **The client destroys the diagnostic signal.** Three layers collapse the real failure into one opaque message: `lib/features/admin_dashboard/login/admin_auth_bloc.dart:224-231` emits a hard-coded `FIREBASE_FAILED` and discards the `FirebaseAuthException`; `lib/features/admin_dashboard/login/admin_auth_service.dart:113-121` reads the server `error` code but lets it be replaced by `'UNKNOWN'`; `lib/core/backend/workers/api_client.dart:42-67` ignores the HTTP status entirely and only surfaces `Exception` causes. Even after the header is fixed, this class of failure stays undiagnosable until these are corrected.

### Fix

1. `COOP: same-origin` → `Cross-Origin-Opener-Policy: same-origin-allow-popups` on every `admin_host` response (`index.ts:62`, test updated in lockstep at `test/index.test.ts:66`). `same-origin-allow-popups` preserves cross-origin opener protection for ordinary navigations while permitting a popup to retain `window.opener` — exactly the Firebase contract. `COEP: require-corp` is retained.
2. Propagate Firebase and server error codes end-to-end so this class of failure is never undiagnosable again (Findings F02/F03; plan tasks T4, T5, T7).
3. Live confirmation on a fresh incognito profile is **required** (plan T3 Step 5); the result is recorded in this register. If the popup still fails with the header corrected, the documented fallback is `signInWithRedirect` + `getRedirectResult()` in `main_admin.dart` while keeping the header change (the header change is correct regardless, since isolation is optional).

---

## 2. Findings register

ID, severity, `path:line`, one-line evidence, one-line fix, fixing plan task. Rows are derived from the plan's Phase A–F tasks plus the plan's Review Focus and the CI/CodeRabbit/Codacy verdicts. Findings with a dedicated Plane item name it; the rest are covered by the plan's commit sequence.

### 2.1 Auth / session

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F01 | Critical | `backend/admin_host/src/index.ts:62` | `COOP: same-origin` severs `window.opener`, so `signInWithPopup` never receives the credential even though the account is created. | Set COOP to `same-origin-allow-popups` (keep `COEP: require-corp`) and confirm live. | T3 (Plane DAFTARI-110) |
| F02 | High | `lib/core/backend/workers/api_client.dart:42-67` | All four methods ignore HTTP status and only catch `Exception`, so non-2xx JSON bodies (and `TypeError`) are lost. | One `_send` helper: return `Right(body)` for any non-2xx JSON object, else `Left(HttpFailure(status, path))`; bare `catch`. | T4 |
| F03 | High | `lib/features/admin_dashboard/login/admin_auth_bloc.dart:224-242`; `admin_auth_service.dart:113-121` | Two hard-coded `FIREBASE_FAILED` emits discard the `FirebaseAuthException`; the server code read at line 115 can become `'UNKNOWN'`. | Carry `AuthError.code` from Firebase/server; append raw code in the Arabic fallback; `debugPrint` cause when logging. | T5 |
| F04 | Critical | `backend/realtime/src/index.ts:81-83` | `/ws` reads only the `Authorization` header; browsers cannot set headers on a WebSocket, so the dashboard's `?token=` realtime auth gets 401. | `readWsToken` prefers `Authorization: Bearer`, falls back to `?token=`, 401 only when neither present. | T6 (Finding B1) |
| F05 | High | `backend/api/src/middleware/auth.ts:144-160`; `routes/admin.ts:15-17` | `requireAdmin` resolves role from `users.role` via `authUid`, so a cashier session token is not checked against its `auth_users` row and can pass. | Session path uses `authRole` + an active `auth_users` row; register the guard once on `/admin/*`. | T7 (Finding B3) |
| F06 | High | `backend/api/src/middleware/auth.ts:92-101` | The HS256 branch trusts the signed JWT alone: a revoked/ended session row stays valid until `exp`. | Verify `jti` against the live `sessions` row (`ended_at IS NULL`); enforce heartbeat freshness outside `/auth/*`. | T9, T10 |
| F07 | High | `lib/features/admin_dashboard/login/admin_auth_bloc.dart:367-374` | Logout only clears the local session; the server row lives on and the token stays usable. | Add `POST /auth/logout` ending the caller's row; call it before `clearSession()`. | T10 |
| F08 | High | `backend/api/src/routes/auth.ts:65-72` | The 90-day owner gate runs unconditionally on login, so it interrupts an admin who has a live web session (F5 mid-session). | Evaluate the gate only when no live web session exists; resume the live session instead. | T11 (Plane DAFTARI-95) |
| F09 | Medium | `lib/features/admin_dashboard/login/admin_auth_bloc.dart:138-164,283-328` | `_onCheckSession` drops a stored, unexpired JWT and forces a fresh credential stage on reload. | Decode stored JWT; if unexpired call `POST /auth/session/resume` and emit `AuthAuthenticated`. | T11 |
| F10 | Medium | `backend/shared/src/turso.ts` (`insertSession`); `routes/auth.ts:88-103` | Two concurrent logins can both insert a live web row — admission is read-then-write, not atomic. | Partial unique index `idx_sessions_live_web` + `ON CONFLICT DO NOTHING`, mapping conflict to `SESSION_CONFLICT`. | T12 (CodeRabbit #14) |
| F11 | High | `backend/shared/src/turso.ts:197-203`; `routes/sessions.ts:68-86` | `heartbeatSession`/`endSession` update by session id with no `tenant_id` predicate — cross-tenant IDOR. | Add `AND tenant_id = ?`, thread `authUid`, return 404 `SESSION_NOT_FOUND` when no row changes. | T13 (Plane DAFTARI-98) |
| F12 | High | `backend/api/src/routes/sessions.ts:98-121` | `/sessions/revoke` lets any session admin revoke another admin's sessions in the tenant. | Allow only self for session callers; owners may revoke any username; else 403 `FORBIDDEN`. | T14 |

### 2.2 Security

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F13 | High | `backend/realtime/src/index.ts:68-78` | `POST /internal/notify` has no authentication; anyone who can reach the worker can inject broadcasts. | Require `X-Internal-Secret: ${INTERNAL_NOTIFY_SECRET}` (401 otherwise); wire the `[[services]]` binding and call via `REALTIME.fetch`. | T15 (Finding B5) |
| F14 | Medium | `backend/api/src/routes/auth.ts:25-59` | Unknown usernames skip the KDF, creating a timing oracle for account enumeration. | Always run `verifyTagged` against a `DUMMY_HASH`; compute `passwordOk` afterwards. | T16 (Plane DAFTARI-96) |
| F15 | Medium | `backend/api/src/routes/auth.ts:38-59` | No rate limit on `/auth/login`; the lockout deadline can leave `failed_attempts` un-reset. | 10-attempt/15-min sliding window per IP and per `(tenant, username)` → 429 `RATE_LIMITED` with `retry_after_ms`. | T17 (Plane DAFTARI-97) |
| F16 | Medium | `backend/shared/src/password_kdf.ts:40-52`; `routes/users.ts:20-21`; `lib/core/crypto/password_hasher.dart:68-75` | KDF default is 10 000 iterations, password length is uncapped, and `hashTagged` accepts invalid parameters. | Default 210 000 (TS + Dart), min 12 / max 256, `hashTagged` throws on invalid iterations/length; regenerate KDF fixtures. | T18 (Plane DAFTARI-92) |
| F17 | High | `backend/api/src/index.ts:31`; `backend/api/src/env.ts` | CORS is not restricted to an explicit allowlist; `localhost` origins are not environment-gated. | `cors({ origin: [adminOriginFor(env)], allowHeaders: [...] })`; localhost only when `ENVIRONMENT === 'development'`. | T19 |
| F18 | Medium | `backend/api/src/routes/users.ts:82-93,121-125`; `sales.ts:63-65`; `index.ts` (`onError`) | Duplicate username returns 500, `display_name` cannot be cleared, `/sales?since=` is unvalidated, malformed JSON returns 500. | 409 `USERNAME_TAKEN`; nullable `display_name`; validated `since`; global `onError` → 400 `INVALID_JSON` / 500 `INTERNAL`. | T20 |

### 2.3 Correctness

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F19 | High | `backend/api/src/routes/sessions.ts:37-63`; `backend/shared/src/turso.ts:248-254` | POS `reconnect` inserts a new row without ending the old one and `getActivePosSessions` counts stale rows, leaking device slots. | End the prior `(tenantId, device_hwid)` row before insert; add `heartbeat_at > now - HEARTBEAT_FRESH_MS`. | T22 |
| F20 | High | `lib/features/admin_dashboard/dashboard/dashboard_bloc.dart:100-149`; `subscription/subscription_view.dart:31-66`; `sales/sales_chart_view.dart:62-84`; `users/users_bloc.dart:96-165`; `users/users_view.dart:31-32` | Loaders ignore `body['ok']` and render zeros/defaults on 403/500; a failed mutation can replace the user list; a throwing token provider leaves a spinner. | Validate `ok == true`, emit an error state with the server code and a retry affordance, separate `UsersLoadError` from one-shot `UsersMutationFailed`, use bare `catch`. | T25 (Plane DAFTARI-101) |
| F21 | Medium | `lib/features/admin_dashboard/dashboard/dashboard_bloc.dart:72,152-161`; `lib/core/backend/workers/realtime_client.dart:52-79` | Realtime bursts start overlapping overview loads; the backoff ladder resets only on a message, not on socket open. | `restartable()` transformer on `OverviewRequested`; reset `_attempts` on open; expose `connected`. | T26 (Plane DAFTARI-103) |
| F22 | Low | `lib/app_admin.dart:34,47-86`; `overview/overview_view.dart:159`; `sales/sales_chart_view.dart:51-61,111-117`; `admin_shell.dart:41-72`; `login/admin_auth_bloc.dart:96-105` | Locale falls back to Arabic, RTL border uses the wrong edge, chart boundary is exclusive, the shell rebuilds too widely, `_chartData` is recomputed, the token is captured as a string, and `SessionConflict` holds the plaintext password. | Explicit `localeResolutionCallback` → `en`; `BorderDirectional(start:)`; `>=`; scope the `BlocBuilder`; memoize; live `tokenProvider` closure; replace `password` with `VoidCallback retry`. | T27 |
| F23 | Medium | `lib/features/admin_dashboard/*` + `admin_shell.dart`; `login/admin_auth_bloc.dart` | A 401 / `SESSION_REVOKED` / `SESSION_STALE` from a dashboard request does not route the user back to re-authentication. | Dispatch `AdminAuthEvent.sessionExpired` → `AuthError(code:'SESSION_EXPIRED')` → Firebase stage; no global interceptor. | T28 |

### 2.4 Performance

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F24 | High | `backend/api/src/routes/admin.ts:58-70` | `/admin/activity` calls `listSales(uid, 0)` (all sales, full receipt blobs) then `.slice(-5)` in memory. | `getRecentSales(tenantId, limit)` selecting only `id`/`total_piastres`/`created_at` with `LIMIT 5`, reversed to ascending. | T21 |
| F25 | Medium | `backend/api/src/routes/sales.ts:45-52` | The realtime sale broadcast carries the full `sales`/receipt payload. | Broadcast `{ type: 'sale', count }` only. | T23 |
| F26 | Medium | `backend/shared/migrations/` (absent) | No `sessions(tenant_id, started_at)` or `devices(tenant_id, last_seen_at)` indexes. | Additive `CREATE INDEX IF NOT EXISTS` migration `005_query_indexes.sql`. | T24 |

### 2.5 CI/CD

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F27 | High | `.github/workflows/ci.yml:160-190` | The matrix build never compiles `lib/main_admin.dart` (no `--wasm` admin flavor), so admin-only breakage reaches `development`. | Branch the build step on `matrix.flavor == 'admin'` with the explicit `flutter build web --wasm -t lib/main_admin.dart` command. | T29 |
| F28 | High | `.github/workflows/ci.yml:332-341` | `CI Summary (Required)` only tests `contains(needs.*.result,'failure')`, so skipped/cancelled required jobs pass. | Fail unless every needed job's result is `success` (explicit allowlist for legitimately-skipped jobs). | T30 |
| F29 | Medium | `.github/workflows/ci.yml:260-310` | `Build AppImage`/`Build RPM` are masked by upstream test failures, the smoke test swallows errors with `|| true`, and artifact upload tolerates missing files. | `if: always()` on both builds, `if-no-files-found: error`, smoke test asserts zero exit. | T31 |
| F30 | Medium | `.github/workflows/deploy-cloud.yml:98`; `ci.yml:66`; `backend/*/package.json` | The pages-project step swallows real errors; backend jobs drift on Node versions. | Re-raise non-"already exists" failures; pin `node-version: 22` and `engines.node >= 22`. | T32 |
| F31 | Low | `.github/workflows/opencode.yml` | The `sync_specs` opencode steps fail at `permission: none` (followups #39). | Add `with: use_github_token: true` to both steps. | T33 |
| F32 | Medium | repository-wide (Codacy) | Codacy reports 1000+ "new issues" from test/generated code and 25 failure-level Dart resolution false positives, with the gate at 0. | Add `.codacy.yml`: exclude tests, disable the Dart analyzer, relax the gate; document why. | T34 |
| F33 | Low | `.github/workflows/deploy-cloud.yml` (Windows job); `.gitignore` | Generated Windows registrants are committed and never regenerate-checked. | `flutter pub get` + regenerate-and-diff step that fails on drift. | T35 |

### 2.6 Compatibility / feature parity

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F34 | Medium | `pubspec.yaml`; `login/login_screen.dart`; `admin_shell.dart` | DAFTARI-99: no offline banner; the spec's `WEB_DASHBOARD_OFFLINE` state is unimplemented. | Add `connectivity_plus`; `Offline`/`Online` states; render the banner with a disabled sign-in action. | T37 (Plane DAFTARI-99) |
| F35 | Medium | `backend/api/src/routes/users.ts`; `admin_shell.dart:135` | DAFTARI-100: the tier matrix is not enforced — `starter` tenants reach Users/Subscription. | `403 TIER_REQUIRED` for `starter` on `/admin/users`; hide the destinations in the shell. | T38 (Plane DAFTARI-100) |
| F36 | Medium | `login/login_screen.dart`; `login/admin_auth_bloc.dart:147-155,199-205` | DAFTARI-85: a magic link opened in another browser cannot complete (no email prompt); the conflict dialog cannot revoke-and-retry. | Prompt for the email when `pendingMagicEmail()` is null; conflict dialog distinguishes same-user other browser from another device and offers Revoke + Retry. | T39 (Plane DAFTARI-85) |
| F37 | Medium | `lib/features/admin_dashboard/devices/` (absent); `admin_shell.dart` | DAFTARI-86: the device-linking wizard and its owner-only `POST /admin/devices/link` route do not exist. | Build the route + `DeviceLinkingBloc`/view and add the shell destination. | T40 (Plane DAFTARI-86) |
| F38 | Low | Firebase console; `docs/DEVELOPMENT_ENVIRONMENT.md` | DAFTARI-90: email-link templates and authorized domains are undocumented and unverified. | Customize the template (ar+en), add the admin origins, document in §5i. | T42 (Plane DAFTARI-90) |

### 2.7 Docs / spec drift

| ID | Severity | `path:line` | Evidence | Fix | Plan task |
|---|---|---|---|---|---|
| F39 | High | `specs/ARCHITECTURE.md`, `specs/PRD.md`, `specs/USER_FLOW.md`, `specs/DESIGN.md`, `specs/DEVELOPMENT_ENVIRONMENT.md` | Ten claims (A–J) do not match the merged code: provider allowlist; lockout formula; Dart KDF algorithm/iterations; `PATCH /admin/users`; DELETE self-delete; POST access; a non-existent `POST /sessions`; the 90-day gate location; the KDF-fixtures claim; `lib/core/config/` paths. | Rewrite each claim to match code; verify with `grep -n`; commit only `specs/**` + `docs/**`. | T36 (Plane F-A–J) |
| F40 | Low | `docs/followups.md:48` | The WS token is falsely described as "verified on the upgrade"; several followups are already resolved. | Correct the claim; mark #39, #43–#49 resolved with resolving commit SHAs. | T36 Step 2 |
| F41 | Low | `backend/README.md`; `test/core/crypto/password_hasher_test.dart:6`; `test/core/backend/api_client_test.dart:17` | Stale directory table and stale test names (`length 24`, `sham URL`). | Fix the README table and rename the tests. | T41 (Plane DAFTARI-89, 91, 93) |
| F42 | Low | repo root `auth`, `auth-wal` | Untracked 0-byte local libsql artifacts are not gitignored. | Confirm untracked/0-byte, delete, add to `.gitignore`. | T41 |

### 2.8 Non-task findings from Review Focus and the CI/CodeRabbit verdicts

These are the review concerns the plan addresses without a one-to-one Phase task heading, plus the external check verdicts.

| ID | Severity | Source | Finding | Resolution |
|---|---|---|---|---|
| F43 | High | Review Focus #1 | On a strict-COOP origin a user completes the popup but the credential never returns; the UI must show the *actual* Firebase + server error, never a generic "try again". | F01 + F02/F03 (T3–T5) |
| F44 | High | Review Focus #2 | F5 mid-session must resume the live session — no credentials re-entry, no "logged in elsewhere" dialog, no owner re-auth. | F09 (T11) |
| F45 | High | Review Focus #3 | A 90-day window lapsing during an active session must never interrupt; the gate fires only when establishing a session with no live session. | F08 (T11) |
| F46 | High | Review Focus #4 | A non-owner / revoked / deactivated principal hitting `/admin/*` must 403 immediately, including over an open WebSocket and with an unexpired JWT. | F05, F06, F12, F13 (T7, T10, T13, T14, T15) |
| F47 | High | Review Focus #5 | A mis-provisioned environment (missing `ADMIN_JWT_SECRET`, unapplied migration 002, unreachable Turso) must be visible from `GET /health` and the client error code — not indistinguishable from bad credentials. | T8, `/health` diagnostics (Plane DAFTARI-111); F02/F03 |
| F48 | Medium | CodeRabbit #14 | Single-session admission is not atomic under concurrent logins. | F10 (T12) |
| F49 | Medium | CI verdict | `CI Summary (Required)` does not fail on skipped/cancelled required jobs. | F28 (T30) |
| F50 | Medium | Codacy verdict | 1000+ new-issue noise from tests/generated code plus 25 Dart resolution false positives; gate at 0. | F32 (T34) |
| F51 | Low | CodeRabbit (carried) | Remaining CodeRabbit items that this plan addresses must be marked resolved on the PR before merge. | Verification gate (Part 5) |

---

## 3. Decisions register

Each decision records the choice, why, and what it costs if the choice is wrong.

### D1 — COOP value: `same-origin-allow-popups`

**Decision.** `backend/admin_host` serves `Cross-Origin-Opener-Policy: same-origin-allow-popups` on every response while keeping `Cross-Origin-Embedder-Policy: require-corp`.

**Rationale.** `same-origin` is the sole cause of the popup failure (Part 1). Flutter's generated bootstrap explicitly states cross-origin isolation is optional performance and that Skwasm "will run in single-threaded mode" without it; the landing page already runs exactly that way with no COOP/COEP and works. `same-origin-allow-popups` keeps cross-origin opener protection for normal navigations and only relaxes it for the auth popup, which is the required Firebase contract.

**Cost if wrong.** `window.crossOriginIsolated` becomes `false`, so Skwasm runs single-threaded — a render-performance regression identical to the landing page's current mode (accepted). If the popup still fails with the corrected header, the fallback is `signInWithRedirect` + `getRedirectResult()` in `main_admin.dart`; the header change remains correct regardless.

### D2 — Owner 90-day re-auth is evaluated only when no live web session exists

**Decision.** The 90-day owner re-auth gate runs **only when establishing a session with no live session present**. A live session — an unended `sessions` row with `source='web'` and a heartbeat within 5 minutes — is never interrupted by the gate. A page reload resumes the live session. **No absolute session cap is imposed in this phase.** The gate fires on `/auth/login` and on `POST /auth/session/resume` only when `getLiveWebSession(...) == null`.

**Rationale.** This mirrors the user requirement verbatim: an admin must never be kicked out of an active session. The gate exists to force periodic credential re-verification for *dormant* access, not to cap session duration. Making live-session presence the condition simultaneously fixes F5-resume (F09), the self-conflict dialog (F10/F08), and the "gate lapsed mid-session" hazard (F45).

**Cost if wrong.** If the intent was a hard 90-day cap, this decision under-delivers; the residual risk (a continuously heartbeated session can outlive 90 days) is tracked explicitly as Plane **DAFTARI-112** and must be revisited with a cap policy in a later phase. If the gate is too permissive, a stale-but-heartbeating client retains access until logout or heartbeat lapse.

### D3 — Provider allowlist value — **PENDING VERIFICATION**

**Decision.** The allowlist used by `backend/api/src/middleware/auth.ts` for Firebase-path sign-in is **pending verification** of `firebase.sign_in_provider` in a real magic-link ID token. The verification procedure is plan T11 Step 4 (capture a live magic-link ID token in the dev dashboard, decode it, read `firebase.sign_in_provider`). Three outcomes are pre-decided:

1. **`password` (expected):** allowlist becomes `['google.com', 'password']`, **and** the Firebase console Email/Password provider must stay disabled so a `password` token can only originate from an email link. Recorded in `middleware/auth.ts` (replacing the GATE-1 warning block at lines 19-31).
2. **`emailLink`:** allowlist stays `['google.com', 'emailLink']`.
3. **`google.com` only, magic link impossible:** allowlist becomes `['google.com']` and a follow-up is filed for magic-link support.

Whichever value is verified, the spec text that currently claims the allowlist (`specs/ARCHITECTURE.md:1873,1879`, `specs/USER_FLOW.md:2525`) must be rewritten to the verified value (F39).

**Rationale.** The code's real behavior depends on Firebase's token claim, which cannot be determined from source alone; guessing would either lock out magic-link users or admit the wrong provider.

**Cost if wrong.** An incorrect allowlist either rejects legitimate magic-link sign-ins (`PROVIDER_NOT_ALLOWED`) or admits a provider the security model did not intend. This is why the value is left explicitly unresolved rather than assumed.

### D4 — Session identity is a server-side live row (`jti` = session id), not just a signed JWT

**Decision.** The session JWT carries `jti = sessionId` (plus `iss: 'daftari-api'`, `aud: 'daftari-admin'`), and the HS256 branch of `requireAuth` loads the `sessions` row by `jti`, requiring it to exist, be unended, and (outside `/auth/*`) be heartbeat-fresh. `POST /auth/logout` ends the caller's own row. A reload resumes via `POST /auth/session/resume` with a fresh token.

**Rationale.** The signed-JWT-only model cannot express revocation, deactivation, or liveness; every one of F06, F07, F08, F09, F10, F46 follows from that gap. Making the row authoritative lets one mechanism fix reload resume, self-conflict handling, revocation, deactivation, and logout simultaneously. `iss`/`aud` binding prevents a token minted for another purpose from being accepted.

**Cost if wrong.** Every authenticated request gains one indexed DB lookup; if the `sessions` table is unavailable or its migration is unapplied, all session auth fails closed (401) — mitigated by the `/health` schema diagnostics (F47). A wrong `jti` threading would reject all valid sessions, so T9's tests (`jti`/`iss`/`aud`) gate it.

### D5 — `/admin/activity` response shape

**Decision.** `/admin/activity` returns sales events containing **only** `id`, `total_piastres`, and `created_at`, fetched with `LIMIT 5` in SQL (`getRecentSales(tenantId, limit)`), then reversed to ascending for the feed. No receipt blobs, no in-memory slicing of the full sales list.

**Rationale.** The old path (`admin.ts:58-70`) loaded every sale with full payloads and sliced client-side — unbounded work and a data-exposure surface for receipt contents. The dashboard feed needs only these three fields.

**Cost if wrong.** If a later feature needs another sale field in the feed, the query and interface must be extended deliberately (cheap, additive). Consumers that assumed the old shape must be updated in T21/T25 — F20 already requires the client to validate `ok` and handle errors rather than defaulting.

### D6 — Process constraints (binding on this branch)

**Decision.** Commits use **emoji + Conventional Commits** (`🩹 fix(...)`, `✨ feat(...)`, `🔒️ security(...)`, `⚡ perf(...)`, `🔧 ci(...)`, `📝 docs(...)`); commit bodies are `-` bulleted; subject under 50 characters, imperative, no trailing period; **no double-quote character in any commit payload**. This branch is **never merged into `development`** and **never pushed to shared branches** (`development`/`staging`/`master`); PR #39 picks the commits up from `feature/admin-dashboard-phase1`. Work branches off `feature/admin-dashboard-phase1` as `task/admin-dashboard-phase1-*`.

**Rationale.** PR #39 is the integration point; direct merges or shared-branch pushes would bypass review and the required-check gates. The commit format keeps history consistent with the repo and the emoji-commit tooling.

**Cost if wrong.** A shared-branch push or premature merge would land unreviewed security changes (F06–F19) into `development`. Recovering requires reverting shared history — high cost, which is exactly why the constraint is absolute.

---

## 4. Plane scope

Plane project identifier: **`DAFTARI`**. States in use: `Backlog`, `Todo`, `In Progress`, `Done`, `Cancelled`, `Review`, `Planing`. All work items below are assigned to `me`.

### 4.1 Included (16)

| Plane ID | Covered by |
|---|---|
| `DAFTARI-85` | T39 — session-conflict choreography + cross-browser magic link |
| `DAFTARI-86` | T40 — device-linking wizard |
| `DAFTARI-89` | T41 — stale docs/tests and stray files |
| `DAFTARI-90` | T42 — Firebase email templates + authorized domains |
| `DAFTARI-91` | T41 — stale test/README names |
| `DAFTARI-92` | T18 — KDF defaults, password policy, hashTagged validation, Dart parity |
| `DAFTARI-93` | T41 — stale README/test names |
| `DAFTARI-95` | T11 — owner re-auth only when no live session (decision branch D3) |
| `DAFTARI-96` | T16 — equalize login timing |
| `DAFTARI-97` | T17 — rate limiting + lockout reset |
| `DAFTARI-98` | T13 — tenant-scope session heartbeat/end (IDOR) |
| `DAFTARI-99` | T37 — offline banner |
| `DAFTARI-100` | T38 — tier gating per the feature matrix |
| `DAFTARI-101` | T25 — check `ok` and stop conflating errors with empty data |
| `DAFTARI-102` | **No dedicated task.** Included in the set of 16 but unmapped in the plan; scope it at T43 close-out and move to `Done` only when its requirement is verified or file a follow-up. |
| `DAFTARI-103` | T26 — dashboard refresh concurrency + realtime client hardening |

### 4.2 Excluded

| Plane ID | Reason |
|---|---|
| `DAFTARI-109` | Business-tier Phase 2 (permissions matrix, advanced analytics, exports) — out of scope. |
| `DAFTARI-94` | Already `Done`. |

### 4.3 New work items created by this bundle

| Local interface name | Plane ID | Title | State | Priority |
|---|---|---|---|---|
| `FIX-GOOGLE-POPUP` | **`DAFTARI-110`** | Google popup sign-in fails on the admin dashboard (COOP same-origin) | `Todo` | `urgent` |
| `FIX-HEALTH-DIAG` | **`DAFTARI-111`** | Add dependency and schema diagnostics to GET /health | `Todo` | `high` |
| `FIX-SESSION-BOUND` | **`DAFTARI-112`** | Bound continuous web-session lifetime (residual risk) | `Todo` | `medium` |

`DAFTARI-110` carries labels `auth`, `flutter web`, `backend`. `DAFTARI-111` and `DAFTARI-112` carry no labels. All three are assigned to `me`.

### 4.4 Close-out

T43 comments each included item with its resolving commit SHA and moves it to `Done`. `DAFTARI-112` stays in `Todo` (residual risk, decision pending) with a description pointing back at §3 D2.

---

## 5. Verification gates (before opening the PR)

- [ ] `dart format --set-exit-if-changed lib test && flutter analyze && flutter test` → exit 0, all tests pass.
- [ ] `cd backend/api && npm test && npm run typecheck`
- [ ] `cd backend/shared && npm test && npm run typecheck`
- [ ] `cd backend/realtime && npm test && npm run typecheck`
- [ ] `cd backend/admin_host && npm test && npm run typecheck`
- [ ] `flutter build web --wasm -t lib/main_admin.dart --dart-define=FLAVOR=admin --dart-define=ENV=development` succeeds.
- [ ] Manual end-to-end on dev: Google sign-in completes → empty-accounts bootstrap → create the first admin → credential login → dashboard loads → realtime connects (no 401 in the network tab) → F5 resumes without a conflict dialog → logout invalidates the token.
- [ ] Migration 002 + 003 + 004 + 005 applied to `daftari-dev`; `ADMIN_JWT_SECRET` and `INTERNAL_NOTIFY_SECRET` set on `api-dev` and `realtime-dev`.
- [ ] Re-run the PR #39 check suite; `Codacy` and `CI Summary (Required)` behave as designed, and the CodeRabbit items that this plan addresses are marked resolved.

## 6. Explicitly out of scope

`DAFTARI-109` (Business-tier Phase 2: permissions matrix, advanced analytics, exports). Turnstile (the rate limiter in T17 covers DAFTARI-97's stated need; Turnstile remains a follow-up). An absolute cap on continuous web-session lifetime (tracked as the new residual-risk item `DAFTARI-112`; the user requirement forbids interrupting an active session).

---

## 7. Assumptions

1. The 16 Plane items are `DAFTARI-{85,86,89,90,91,92,93,95,96,97,98,99,100,101,102,103}`; `DAFTARI-109` is the only business-tier exclusion and `DAFTARI-94` is already `Done`.
2. The COOP fix (T3) is confirmed by live reproduction; if the popup still fails, fall back to `signInWithRedirect` + `getRedirectResult()` while keeping the header change.
3. Magic-link `sign_in_provider` resolves to `password` (D3); the plan branches for the other outcomes.
4. `bloc_concurrency` transformers are available through the already-pinned `flutter_bloc`.
5. This spec and the plan at `docs/superpowers/plans/2026-09-29-pr39-fixes-and-hardening.md` are committed together on `feature/admin-dashboard-phase1`.
