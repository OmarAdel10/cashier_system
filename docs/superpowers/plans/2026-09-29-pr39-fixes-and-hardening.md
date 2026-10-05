# PR #39 Fixes + Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make PR #39 (`feature/admin-dashboard-phase1`) correct, secure, and mergeable: fix the Google sign-in outage, redesign owner re-auth so it never interrupts a live admin session, close every security/CI/compat finding from the PR #39 review, and clear the 16 admin-dashboard Plane items (excluding business-tier Phase 2).

**Architecture:** Six independent workstreams on one branch — (A) client auth-flow correctness, (B) session/owner-re-auth redesign, (C) backend security hardening, (D) data/perf/correctness, (E) CI/CD, (F) remaining Plane work items. The load-bearing change is B: session identity becomes a *server-side live row* (not just a signed JWT), which simultaneously fixes reload resume, the self-conflict dialog, revocation, and the "re-auth must not interrupt an active session" requirement.

**Tech Stack:** Flutter 3.47.1 (`--wasm`, web admin flavor) · firebase_auth · flutter_bloc · Cloudflare Workers (Hono) · TypeScript (strict) · libSQL/Turso · Vitest · GitHub Actions · Wrangler.

**Spec:** `docs/superpowers/specs/2026-09-29-pr39-fixes-design.md` (created by T1; it carries the full PR #39 review findings, the confirmed root cause for the Google sign-in bug, and the decisions this plan encodes). Companion sources: `specs/ARCHITECTURE.md`, `specs/USER_FLOW.md`, `specs/PRD.md`, `docs/followups.md`.

---

## Confirmed root cause — Google sign-in failure (new Plane item)

`backend/admin_host/src/index.ts:62` serves `Cross-Origin-Opener-Policy: same-origin`. That header severs the `window.opener` link between the dashboard page and Firebase's auth popup, so `signInWithPopup` cannot receive the credential back while Google/Firebase has *already* created the account — producing exactly the observed symptom (account visible in the Firebase console, dashboard shows "فشل تسجيل الدخول. حاول مجددًا.").

Evidence:
- `backend/admin_host/src/index.ts:61-62` sets COOP `same-origin` + COEP `require-corp`; asserted by `backend/admin_host/test/index.test.ts:66-67`.
- Flutter's own generated `backend/admin_host/public/flutter_bootstrap.js` says isolation is **optional performance**: *"Skwasm will run in single-threaded mode"* without it.
- `landing_page/web/_headers` is also a Flutter WASM app and ships **no** COOP/COEP — it works.
- The client collapses the failure into one opaque message: `admin_auth_bloc.dart:224-231` (`FIREBASE_FAILED`) discards the `FirebaseAuthException`; `admin_auth_service.dart:113-121` discards the server's `error` code; `api_client.dart:42-67` ignores HTTP status.

**Fix:** COOP → `same-origin-allow-popups` (keeps opener for popups; Skwasm drops to single-threaded, matching the landing page) **plus** end-to-end error propagation so this class of failure is never undiagnosable again (T4–T5).

## Plane scope (explicit IDs)

| Plan items | Plane IDs |
|---|---|
| Included (16) | `DAFTARI-85, 86, 89, 90, 91, 92, 93, 95, 96, 97, 98, 99, 100, 101, 102, 103` |
| Excluded | `DAFTARI-109` (business-tier Phase 2), `DAFTARI-94` (already Done) |
| New (created in T2) | Google popup sign-in failure (COOP) |
| New (created in T2) | Add `/health` dependency + schema diagnostics |
| New (created in T2) | Bound continuous web-session lifetime (residual risk from B2) |

`DAFTARI-95` is included but has an explicit decision branch (T11). `DAFTARI-99` is not in the PR body's deferred list but is the 16th admin-dashboard item in Plane and is unimplemented (followups #45); it is included to complete the set — drop it if a different 16 was intended.

---

## Global Constraints

- Flutter: `dart format --set-exit-if-changed lib test` and `flutter analyze` must exit 0. Dart SDK + Flutter `3.47.1` per `pubspec.yaml` / `ci.yml`.
- Backend: `npm test` (Vitest) and `npm run typecheck` must pass in `backend/api`, `backend/shared`, `backend/realtime`, `backend/admin_host`. TypeScript `strict`.
- **Never commit generated files**: `windows/**`, `android/**`, `ios/**`, `build/**`, `*.g.dart`, `*.freezed.dart` (only `specs/**` in a specs-sync commit).
- Branch: `task/admin-dashboard-phase1-*` off `feature/admin-dashboard-phase1`; PRs target `development`; never push to `development`/`staging`/`master`.
- Commits: emoji + Conventional Commits (`🩹 fix(auth): …`, `✨ feat(admin): …`, `🔒️ security(api): …`, `📝 docs(specs): …`, `🔧 ci: …`).
- Auth invariants that must not change: session JWT TTL 12 h; heartbeat freshness 5 min; owner re-auth window 90 days; bearer-only (no cookies, so no CSRF token needed); bearer token is never logged.
- `ADMIN_JWT_SECRET` must be identical in `api` and `realtime` per environment; never committed.
- All SQL parameterized; every tenant-scoped query filtered by `tenant_id`.

## Review Focus

1. **Google sign-in on a strict-COOP origin** — a user completes the popup but the credential never returns; the UI must show the *actual* failure (Firebase error code + server error code), never a generic "try again".
2. **F5 mid-session** — an admin reloads the dashboard; they must resume their live session (no credentials re-entry, no "logged in elsewhere" dialog, no owner re-auth).
3. **90-day window lapsing during an active session** — must never interrupt; the gate fires only when establishing a session with no live session present.
4. **Non-owner / revoked / deactivated principal hitting `/admin/*`** — must 403 immediately, including over an already-open WebSocket and with an unexpired JWT.
5. **Mis-provisioned environment** (missing `ADMIN_JWT_SECRET`, unapplied migration 002, unreachable Turso) — must be visible from `GET /health` and from the client error code, not indistinguishable from bad credentials.

---

## Phase A — Unblock authentication

### Task 1: Persist the findings spec

**Files:** Create `docs/superpowers/specs/2026-09-29-pr39-fixes-design.md`

**Interfaces:** Produces the in-repo context every later task cites (`§Finding N`).

- [ ] **Step 1:** Write the spec containing: the PR #39 review findings grouped as in this plan (severity, `path:line`, evidence, fix), the confirmed COOP root cause with the four evidence items above, the Plane ID table, and the **decisions register** (allowlist value, re-auth semantics, session lifetime, COOP value, `/admin/activity` shape).
- [ ] **Step 2:** Commit: `git add docs/superpowers/specs/2026-09-29-pr39-fixes-design.md && git commit -m "📝 docs(specs): PR #39 review findings + fix decisions"`

### Task 2: Create the three new Plane work items

**Files:** none (Plane only).

**Interfaces:** Produces identifiers `FIX-GOOGLE-POPUP`, `FIX-HEALTH-DIAG`, `FIX-SESSION-BOUND` referenced by T4/T8/T9.

- [ ] **Step 1:** Export `XDG_CACHE_HOME=/dev/shm/planecli-cache` (the CLI's disk cache cannot initialize on a read-only filesystem; `/tmp` is also read-only).

- [ ] **Step 2:** Create the Google popup item:

```bash
export XDG_CACHE_HOME=/dev/shm/planecli-cache
~/.local/bin/planecli wi create "Google popup sign-in fails on the admin dashboard (COOP same-origin)" \
  -p DAFTARI --state Todo --priority urgent --assignee 'me' --labels 'auth,flutter web,backend' \
  -d 'backend/admin_host/src/index.ts:62 serves Cross-Origin-Opener-Policy: same-origin, which severs window.opener between the dashboard and the Firebase auth popup. signInWithPopup cannot receive the credential back, but Google/Firebase has already created the account — so the account appears in the Firebase console while the dashboard shows a generic failure.

Evidence: admin_host sets COOP same-origin + COEP require-corp (asserted by admin_host/test/index.test.ts:66-67); Flutter-generated public/flutter_bootstrap.js states isolation is optional ("Skwasm will run in single-threaded mode"); landing_page/web/_headers serves no COOP/COEP and works; the client discards the real error (admin_auth_bloc.dart:224-231, admin_auth_service.dart:113-121, api_client.dart:42-67).

Fix: COOP -> same-origin-allow-popups; propagate Firebase + server error codes end-to-end. Plan tasks T4, T5, T7.'
```

- [ ] **Step 3:** Create the `/health` diagnostics item (`--priority high`, title `Add dependency + schema diagnostics to GET /health`) and the session-bound item (`--priority medium`, title `Bound continuous web-session lifetime (residual risk)`), each with the description from the decision register in T1.

- [ ] **Step 4:** Record the three returned identifiers in `docs/superpowers/specs/2026-09-29-pr39-fixes-design.md` and commit with the T1 commit or a follow-up `📝 docs(specs): add Plane IDs`.

### Task 3: Fix the COOP header (root cause) — *Plane: new FIX-GOOGLE-POPUP*

**Files:**
- Modify: `backend/admin_host/src/index.ts:62`
- Modify: `backend/admin_host/test/index.test.ts:66-67`

**Interfaces:** Produces `Cross-Origin-Opener-Policy: same-origin-allow-popups` on every admin_host response.

- [ ] **Step 1: Update the failing test first.** In `backend/admin_host/test/index.test.ts`, change the assertion at line 66 to `expect(res.headers.get('Cross-Origin-Opener-Policy')).toBe('same-origin-allow-popups')`. Keep the COEP assertion as `require-corp`.

- [ ] **Step 2: Run it to verify it fails.**

Run: `cd backend/admin_host && npm test`
Expected: FAIL — received `same-origin`.

- [ ] **Step 3:** In `backend/admin_host/src/index.ts`, set `headers.set('Cross-Origin-Opener-Policy', 'same-origin-allow-popups')` and replace the comment above lines 61-62 with:

```
// COOP must allow popups: Firebase signInWithPopup returns its credential via
// window.opener, which 'same-origin' severs. 'same-origin-allow-popups' keeps
// cross-origin opener protection while permitting the auth popup. Consequence:
// window.crossOriginIsolated is false, so Skwasm runs single-threaded — the
// same mode the landing page already runs in.
```

- [ ] **Step 4: Verify.**

Run: `cd backend/admin_host && npm test && npm run typecheck`
Expected: PASS, exit 0.

- [ ] **Step 5: Live confirmation (manual, required).** Build and serve the admin flavor, then sign in with Google on a fresh incognito profile:

```bash
flutter build web --wasm -t lib/main_admin.dart --dart-define=FLAVOR=admin --dart-define=ENV=development
```
Serve `build/web` with the COOP header applied, open it, click "Sign in with Google", and confirm the dashboard reaches Stage 2 (or the empty-accounts bootstrap). Record the result in the spec's decisions register.

- [ ] **Step 6:** Commit: `git add backend/admin_host/src/index.ts backend/admin_host/test/index.test.ts && git commit -m "🩹 fix(admin_host): allow popups so Firebase Google sign-in completes"`

### Task 4: Propagate real error codes through the API client — *Plane: new FIX-GOOGLE-POPUP*

**Files:**
- Modify: `lib/core/backend/workers/api_client.dart:28-102`
- Modify: `lib/core/error/failure.dart` (add `HttpFailure`)
- Test: `test/core/backend/api_client_test.dart`

**Interfaces:** Produces `class HttpFailure extends Failure { final int statusCode; final String path; }` and the invariant: **every non-2xx response whose body is a JSON object is returned as `Right(body)`** (so callers can read `body['error']`); a non-2xx with a non-JSON body returns `Left(HttpFailure(status, path))`.

- [ ] **Step 1: Write the failing tests** in `test/core/backend/api_client_test.dart` (MockClient):
  - `post returns the parsed ok:false body on a 401 JSON response` → assert `result.isRight` and `body['error'] == 'PROVIDER_NOT_ALLOWED'`.
  - `post returns HttpFailure when a 500 body is not JSON` → assert `result.isLeft` and `failure.statusCode == 500`.
  - `get returns the parsed body on a 500 JSON response`.

- [ ] **Step 2: Run to verify failure.** Run: `flutter test test/core/backend/api_client_test.dart` → FAIL.

- [ ] **Step 3:** Refactor all four methods onto one private helper:

```dart
Future<Either<Failure, Map<String, dynamic>>> _send(
  String method, String path, {required String idToken, Map<String, dynamic>? body, Map<String, String>? query})
```
It must: build the request; on success decode with a `try/catch` that checks `decoded is Map<String, dynamic>`; on non-2xx attempt the same JSON decode and return `Right` when it yields a map, else `Left(HttpFailure(res.statusCode, path))`. Replace `on Exception` with a bare `catch (e)` so `TypeError` cannot escape. Do not change the public signatures of `post/get/patch/delete`.

- [ ] **Step 4: Verify.** Run: `flutter test test/core/backend/api_client_test.dart test/core/backend/workers/realtime_client_test.dart` → PASS.

- [ ] **Step 5:** Commit: `git commit -am "🩹 fix(api-client): surface status codes and real error bodies"`

### Task 5: Surface the real failure in the login UI — *Plane: new FIX-GOOGLE-POPUP*

**Files:**
- Modify: `lib/core/backend/auth/firebase_auth_service.dart:47-56`
- Modify: `lib/features/admin_dashboard/login/admin_auth_service.dart:60-121`
- Modify: `lib/features/admin_dashboard/login/admin_auth_bloc.dart:211-281`
- Test: `test/features/admin_dashboard/admin_auth_bloc_test.dart`, `test/features/admin_dashboard/admin_auth_service_test.dart`

**Interfaces:** Produces `AuthError.code` carrying the **server** code (`PROVIDER_NOT_ALLOWED`, `EMAIL_NOT_VERIFIED`, `Invalid token`, `OWNER_ONLY`, `ACCOUNTS_CHECK_FAILED:<detail>`) or the **Firebase** code (`auth/popup-closed-by-user`, …), and `AdminAuthFailure.detail` (new `final String? detail`).

- [ ] **Step 1: Write the failing tests.**
  - `FIREBASE_FAILED keeps the FirebaseAuthException code` — stub `signInWithGooglePopup` to return `Left(DatabaseFailure(..., cause: FirebaseAuthException(code: 'auth/popup-closed-by-user')))`; assert `emit` is `AuthError(code: 'auth/popup-closed-by-user')`.
  - `ACCOUNTS_CHECK_FAILED carries the server error code` — stub `tenantAccounts` → `Left(AdminAuthFailure('EMAIL_NOT_VERIFIED'))`; assert `AuthError.code == 'EMAIL_NOT_VERIFIED'`.

- [ ] **Step 2: Run to verify failure.** Run: `flutter test test/features/admin_dashboard/admin_auth_bloc_test.dart` → FAIL.

- [ ] **Step 3:** Add `detail` to `AdminAuthFailure` (`lib/core/error/failure.dart`). In `firebase_auth_service.dart`, include the `FirebaseAuthException.code` in the returned failure message. In `admin_auth_service.dart:113-121`, keep the server code (already read at line 115) — ensure it is not replaced by `'UNKNOWN'`. In `admin_auth_bloc.dart`, replace the two hard-coded `FIREBASE_FAILED` emits (lines 224-231 and 234-242) with the code extracted from the failure, and replace the `ACCOUNTS_CHECK_FAILED` emit (258-266) with `AuthError(code: <server code or 'ACCOUNTS_CHECK_FAILED'>, …)`. Add an `_arabicFor` default that appends the raw code in parentheses so it is visible in the UI. Also `debugPrint` the failure cause when `EnvConfig.enableLogging`.

- [ ] **Step 4: Verify.** Run: `flutter test test/features/admin_dashboard/` and `flutter analyze` → PASS, exit 0.

- [ ] **Step 5:** Commit: `git commit -am "🩹 fix(admin-auth): show the real Firebase/server error instead of a generic message"`

### Task 6: Fix the WebSocket auth contract — *Finding B1 (Critical)*

**Files:**
- Modify: `backend/realtime/src/index.ts:81-88`
- Test: `backend/realtime/test/realtime.test.ts`
- Modify: `specs/ARCHITECTURE.md` (B9), `specs/PRD.md` (Y8) — header-vs-query auth

**Interfaces:** Produces `readWsToken(c: Context): string` that prefers `Authorization: Bearer` and falls back to `?token=`; `/ws` rejects with 401 when neither is present.

- [ ] **Step 1: Write the failing test** in `backend/realtime/test/realtime.test.ts`: `accepts a session JWT from the ?token= query parameter` — build the request as `new Request('https://x/ws?token=' + jwt, {headers: {Upgrade: 'websocket'}})` with no `Authorization` header; assert 101/upgrade (or the DO stub's success), not 401. Also add `rejects when neither header nor query token is present` → 401.

- [ ] **Step 2: Run to verify failure.** Run: `cd backend/realtime && npm test` → FAIL (401).

- [ ] **Step 3:** In `backend/realtime/src/index.ts`, replace lines 81-83 with the fallback helper and use it. Add the comment: `// Browsers cannot set headers on a WebSocket, so the dashboard sends ?token=.` Keep the HS256/RS256 branching unchanged.

- [ ] **Step 4: Verify.** Run: `cd backend/realtime && npm test && npm run typecheck` → PASS.

- [ ] **Step 5:** Update `specs/ARCHITECTURE.md` §B9 and `specs/PRD.md` §Y8 to document query-token support, and fix the false claim in `docs/followups.md:48` ("verified on the upgrade") to state the actual contract. (Docs edits land in the T36 specs commit; keep them staged.)

### Task 7: Gate every `/admin/*` route on role, using the session's own role — *Finding B3 (High)*

**Files:**
- Modify: `backend/api/src/middleware/auth.ts:144-160`
- Modify: `backend/api/src/routes/admin.ts:15-17`
- Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces `requireAdmin` that resolves the caller's role as: session path → `c.get('authRole')` (and asserts the `auth_users` row exists and `is_active = 1`); Firebase path → `users.role`.

- [ ] **Step 1: Write the failing tests.**
  - `GET /admin/users rejects a cashier-role session token with 403` — mint an HS256 session JWT with `role: 'cashier'` via `mintSessionJwt`, insert a matching `auth_users` row with `role='cashier'`; assert 403 and `error: 'Admin access only'`.
  - `GET /admin/users allows an admin-role session token` → 200.
  - `POST /admin/users rejects a cashier-role session token` → 403.

- [ ] **Step 2: Run to verify failure.** Run: `cd backend/api && npm test` → FAIL (200 returned).

- [ ] **Step 3:** Rewrite `requireAdmin` to branch on `c.get('authIsOwner')`: if `true`, keep the existing `users` lookup; if `false`, require `c.get('authRole') === 'admin'` **and** an `auth_users` row for `(authUid, authUsername)` with `is_active === 1`. In `admin.ts`, change line 15-16 to register `app.use('/admin/*', requireAuth(...))` followed immediately by `app.use('/admin/*', requireAdmin({ db: deps.getDb }))`, and delete the now-redundant per-route `requireAdmin` arguments at `admin.ts:18,38,61`. Update the `users.ts:1-11` header comment.

- [ ] **Step 4: Verify.** Run: `cd backend/api && npm test && npm run typecheck` → PASS.

- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): enforce admin role on every /admin/* route"`

### Task 8: Diagnosable `/health` + `ADMIN_JWT_SECRET` startup guard — *Plane: new FIX-HEALTH-DIAG*

**Files:**
- Modify: `backend/api/src/index.ts:33`
- Modify: `backend/api/src/env.ts`
- Modify: `backend/api/wrangler.toml` (comment only), create `backend/realtime/.dev.vars.example`, update `backend/api/.dev.vars.example`
- Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces `GET /health` → `{ ok, env, db: 'ok'|'unreachable', schema: { auth_users: boolean, sessions_source: boolean, users_last_owner_login_at: boolean }, secrets: { admin_jwt_secret: boolean } }`, with `ok: false` and HTTP 503 when any dependency is broken.

- [ ] **Step 1: Write the failing tests.** `GET /health reports schema readiness` — stub the DB with an `exec` that answers the three `PRAGMA table_info`/`SELECT 1` probes; assert the three schema booleans. `GET /health returns 503 when the db probe throws`. `GET /health reports admin_jwt_secret: false when unset`.

- [ ] **Step 2: Run to verify failure.** Run: `cd backend/api && npm test` → FAIL.

- [ ] **Step 3:** Add `checkSchema(): Promise<{auth_users: boolean; sessions_source: boolean; users_last_owner_login_at: boolean}>` to `TursoDb` in `backend/shared/src/turso.ts` using `SELECT name FROM sqlite_master WHERE type='table' AND name='auth_users'` and `PRAGMA table_info(<table>)`. Implement the `/health` handler with `Promise.all` and a `try/catch` mapping failures to `db: 'unreachable'` + 503. Add `ADMIN_JWT_SECRET` to `backend/api/.dev.vars.example`; create `backend/realtime/.dev.vars.example` with `ADMIN_JWT_SECRET=`.

- [ ] **Step 4: Verify.** Run: `cd backend/api && npm test && npm run typecheck && cd ../shared && npm test && npm run typecheck` → PASS.

- [ ] **Step 5:** Commit: `git commit -am "✨ feat(api): /health reports db, schema and secret readiness"`

---

## Phase B — Session identity and owner re-auth redesign

**Decision (from the user requirement):** the 90-day owner gate is evaluated **only when establishing a session with no live session present**. A live session (unended `sessions` row, `source='web'`, heartbeat within 5 min) is never interrupted by the gate, and a page reload resumes it. No absolute session cap is imposed in this phase; the residual risk (a continuously heartbeated session can outlive 90 days) is tracked by the `FIX-SESSION-BOUND` Plane item.

### Task 9: Make the session JWT carry an identity that the server can check

**Files:**
- Modify: `backend/shared/src/session_jwt.ts:28-86`
- Test: `backend/shared/src/session_jwt.test.ts`

**Interfaces:** Produces `SessionClaims { tid: string; usr: string; role: string; jti: string; iat: number; exp: number }`; `mintSessionJwt` emits `iss: 'daftari-api'`, `aud: 'daftari-admin'`, `jti = sessionId`; `verifySessionJwt` rejects wrong `iss`/`aud` and returns `jti`.

- [ ] **Step 1: Write the failing tests** — `mintSessionJwt mints jti/iss/aud`; `verifySessionJwt rejects a wrong audience`; `verifySessionJwt returns the jti`.

- [ ] **Step 2: Run to verify failure.** Run: `cd backend/shared && npm test` → FAIL.

- [ ] **Step 3:** Extend the claims type and both functions. Pass `jti: sessionId` from `backend/api/src/routes/auth.ts:104-113`.

- [ ] **Step 4: Verify.** Run: `cd backend/shared && npm test && npm run typecheck` → PASS.

### Task 10: Session liveness + revocation enforcement + logout

**Files:**
- Modify: `backend/shared/src/turso.ts` (add `getSessionById`, `endSessionForTenant`)
- Modify: `backend/api/src/middleware/auth.ts:92-101`
- Modify: `backend/api/src/routes/auth.ts` (add `POST /auth/logout`)
- Modify: `lib/features/admin_dashboard/login/admin_auth_bloc.dart:367-374`
- Test: `backend/api/test/api.test.ts`, `test/features/admin_dashboard/admin_auth_bloc_test.dart`

**Interfaces:** Produces `getSessionById(id: string): Promise<SessionRecord | null>`; the HS256 branch of `requireAuth` now requires that the row exists, `ended_at IS NULL`, and (for non-`/auth/*` routes) `heartbeat_at > now - HEARTBEAT_FRESH_MS`. Produces `POST /auth/logout` → ends the caller's own session row and returns `{ok:true}`.

- [ ] **Step 1: Write the failing tests.**
  - `a revoked session token is rejected with 401` — mint a token, insert the row, call `POST /sessions/revoke`-equivalent `endSession`, then `GET /auth/me` → 401.
  - `a deactivated admin's session token is rejected` — set `is_active = 0` → 401.
  - `POST /auth/logout ends the session row and the token stops working`.

- [ ] **Step 2: Run to verify failure.** Run: `cd backend/api && npm test` → FAIL.

- [ ] **Step 3:** Implement `getSessionById` (tenant-agnostic lookup by primary key) . In `requireAuth`'s HS256 branch after `verifySessionJwt` succeeds, load the row by `claims.jti`; reject 401 `SESSION_REVOKED` if missing/ended, and 401 `SESSION_STALE` if `heartbeat_at` is older than `HEARTBEAT_FRESH_MS` **except** for `/auth/session/resume` and `/auth/logout`. Add `POST /auth/logout` that calls `endSessionForTenant(claims.jti, claims.tid, Date.now())`. In Dart, `_onLogout` must call the new endpoint via a new `AdminAuthService.logout({required String idToken})` **before** `clearSession()`.

- [ ] **Step 4: Verify.** Run: `cd backend/api && npm test && npm run typecheck`; `flutter test test/features/admin_dashboard/admin_auth_bloc_test.dart` → PASS.

- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): enforce session liveness and add logout"`

### Task 11: Owner re-auth only when no live session — *Plane: DAFTARI-95; user requirement*

**Files:**
- Modify: `backend/shared/src/turso.ts` (add `getLiveWebSession`)
- Modify: `backend/api/src/routes/auth.ts:38-115` (login), add `POST /auth/session/resume`
- Modify: `backend/api/src/middleware/auth.ts:32` (allowlist)
- Modify: `lib/features/admin_dashboard/login/admin_auth_bloc.dart:138-164,283-328`
- Modify: `lib/features/admin_dashboard/login/login_screen.dart:39-42`
- Test: `backend/api/test/api.test.ts`, `test/features/admin_dashboard/admin_auth_bloc_test.dart`, `test/features/admin_dashboard/login_screen_test.dart`

**Interfaces:** Produces `getLiveWebSession(tenantId: string, username: string, since: number): Promise<SessionRecord | null>` (SQL: `WHERE tenant_id=? AND username=? AND source='web' AND ended_at IS NULL AND heartbeat_at > ? ORDER BY started_at DESC LIMIT 1`); `POST /auth/session/resume` (body `{}`, session JWT bearer) → `{ok:true, data:{token, session_id, profile}}` with a fresh token, enforcing the owner gate **only if no live session exists**; and `ALLOWED_SIGNIN_PROVIDERS = ['google.com', 'password']`.

- [ ] **Step 1: Write the failing tests.**
  - `login does not return OWNER_REAUTH_REQUIRED while a live web session exists` — insert a fresh `source='web'` row, set `last_owner_login_at` to 100 days ago, `POST /auth/login` → 200 (not 401).
  - `login returns OWNER_REAUTH_REQUIRED when no live session exists and the window lapsed` — same setup with no live row → 401 `OWNER_REAUTH_REQUIRED`.
  - `POST /auth/session/resume refreshes a live session` → 200 with a new token.
  - `POST /auth/session/resume returns OWNER_REAUTH_REQUIRED for a lapsed window with a stale session` → 401.
  - Dart: `_onCheckSession resumes a stored unexpired JWT without emitting CredentialsStage`; `OWNER_REAUTH_REQUIRED routes to the Firebase stage`.

- [ ] **Step 2: Run to verify failure.** Run: `cd backend/api && npm test` → FAIL; `flutter test test/features/admin_dashboard/` → FAIL.

- [ ] **Step 3:** In `auth.ts`, move the owner-freshness check (lines 65-72) so it runs **only** when `(await db.getLiveWebSession(tenantId, username, Date.now() - HEARTBEAT_FRESH_MS)) == null`, and place it after the password check but before the conflict check. Change the conflict branch (lines 76-86) to return the *existing* session via resume semantics when the live session's username matches and the caller has no other identity; keep `SESSION_CONFLICT` for a different device/username. Add the `POST /auth/session/resume` route immediately after `/auth/login` (before the `/auth/*` middleware) but implement it with an explicit inline `requireAuth`-style verification so it can bypass the staleness rule from T10.

- [ ] **Step 4: DAFTARI-95 decision branch — required.** Capture a live magic-link ID token in the dev dashboard, decode it, and read `firebase.sign_in_provider`.
  - If it is `password` (expected): the allowlist becomes `['google.com', 'password']`, and the console **Email/Password provider must stay disabled** so a `password` token can only originate from an email link. Record this in the spec decisions register and in the `middleware/auth.ts` comment (replace the GATE-1 warning block at lines 19-31).
  - If it is `emailLink`: keep `['google.com', 'emailLink']`.
  - If it is `google.com` only and magic link is impossible: allowlist `['google.com']` and file a follow-up for magic-link.
  Either way the spec's allowlist text (`ARCHITECTURE.md:1873,1879`, `USER_FLOW.md:2525`) must be rewritten to the verified value.

- [ ] **Step 5:** In Dart, add `SessionClaims? decodeSession(String jwt)` to `admin_auth_service.dart` (base64url-decode the payload, read `exp`/`tid`/`usr`/`role`/`jti`; return `null` on any malformed input). Change `_onCheckSession` to: if a stored JWT decodes with `exp * 1000 > now + 60s`, call the new `resumeSession` service method and emit `AuthAuthenticated` on success; on `OWNER_REAUTH_REQUIRED` emit `AuthError(code:'OWNER_REAUTH_REQUIRED')`; only when there is no/expired JWT fall through to the current behaviour. Add `'OWNER_REAUTH_REQUIRED'`, `'SESSION_STALE'`, `'SESSION_REVOKED'` to `_isFirebaseStageError` in `login_screen.dart:39-42`.

- [ ] **Step 6: Verify.** Run: `cd backend/api && npm test && npm run typecheck`; `flutter test test/features/admin_dashboard/ test/features/admin_dashboard/login_screen_test.dart`; `flutter analyze` → PASS.

- [ ] **Step 7:** Commit: `git commit -am "✨ feat(auth): resume live sessions; owner re-auth only when no session is active"`

### Task 12: Make single-session admission atomic — *CodeRabbit #14*

**Files:** Modify: `backend/shared/src/turso.ts` (`insertSession`), `backend/api/src/routes/auth.ts:88-103`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces `sessions` unique index `idx_sessions_live_web` on `(tenant_id, username)` where `source='web' AND ended_at IS NULL`; `insertSession` returns `boolean` (false on conflict).

- [ ] **Step 1:** Failing tests: `two concurrent logins yield exactly one web session` (insert two rows directly, assert the second returns false and `/auth/login` maps it to `SESSION_CONFLICT`).
- [ ] **Step 2:** Run `cd backend/api && npm test` → FAIL.
- [ ] **Step 3:** Add the partial unique index to migration `002_auth_users.sql` (append; do not reorder existing statements) and to a new `003_session_invariants.sql` for already-migrated environments. Make `insertSession` use `INSERT … ON CONFLICT DO NOTHING` and report whether a row was written; map `false` to `SESSION_CONFLICT` in `/auth/login`.
- [ ] **Step 4:** Verify `cd backend/api && npm test && npm run typecheck` and `cd ../shared && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): make single-session admission atomic"`

### Task 13: Scope session mutation to the tenant (IDOR) — *Plane: DAFTARI-98*

**Files:** Modify: `backend/shared/src/turso.ts:197-203`, `backend/api/src/routes/sessions.ts:68-86`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces `heartbeatSession(sessionId: string, tenantId: string, at: number): Promise<boolean>` and `endSession(sessionId: string, tenantId: string, at: number): Promise<boolean>` (SQL gains `AND tenant_id = ?`; return `rowsAffected > 0`).

- [ ] **Step 1:** Failing tests: `heartbeatSession does not touch another tenant's session`; `endSession does not touch another tenant's session`; `a foreign session id returns 404`.
- [ ] **Step 2:** Run `cd backend/api && npm test` → FAIL.
- [ ] **Step 3:** Add the `tenant_id` predicate, thread `c.get('authUid')` from `sessions.ts`, and return 404 `SESSION_NOT_FOUND` when the update affects no row. Update the two existing call sites in `sessions.ts:115-125` for the new signature.
- [ ] **Step 4:** Verify `cd backend/api && npm test && npm run typecheck` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): tenant-scope session heartbeat and end (DAFTARI-98)"`

### Task 14: Restrict `/sessions/revoke` to self-or-owner

**Files:** Modify: `backend/api/src/routes/sessions.ts:98-121`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces: a session-token caller may revoke only `c.get('authUsername')`; a Firebase-owner caller may revoke any username in the tenant; otherwise 403 `FORBIDDEN`.

- [ ] **Step 1:** Failing tests: `a session admin cannot revoke another admin's sessions` → 403; `an owner can revoke any username` → 200; `a session admin can revoke their own` → 200.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Add the self-or-owner guard before the `getActiveSessionsForUsername` call.
- [ ] **Step 4:** Verify `cd backend/api && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): restrict session revocation to self or owner"`

---

## Phase C — Remaining backend security

### Task 15: Authenticate the realtime notify path — *Finding B5 (High)*

**Files:** Modify: `backend/realtime/src/index.ts:68-78`, `backend/realtime/src/env.ts`, `backend/realtime/wrangler.toml`, `backend/api/src/routes/sales.ts:43-52`, `backend/api/src/routes/sessions.ts:114-125`, `backend/api/wrangler.toml:16-19`, Test: `backend/realtime/test/realtime.test.ts`, `backend/api/test/api.test.ts`

**Interfaces:** Produces `POST /internal/notify` requiring header `X-Internal-Secret: ${env.INTERNAL_NOTIFY_SECRET}` (401 otherwise); the api worker calls it with `env.REALTIME.fetch('https://realtime/internal/notify', {method:'POST', headers:{...}, body})`; the `[[services]]` binding is uncommented for all three environments with `service = "realtime"`.

- [ ] **Step 1:** Failing tests: `internal/notify rejects a request without the shared secret` → 401; `internal/notify accepts the shared secret` → 200; api test `a sale posts to the realtime binding` asserts `.fetch` with the secret header.
- [ ] **Step 2:** Run `cd backend/realtime && npm test` → FAIL.
- [ ] **Step 3:** Add `INTERNAL_NOTIFY_SECRET` to the realtime `Env`, guard the route, add the two secrets to both `.dev.vars.example` files and a `wrangler.toml` comment, replace the `.notify(...)` RPC calls with `.fetch(...)`, and uncomment the `[[services]]` blocks (dev + staging + production).
- [ ] **Step 4:** Verify `cd backend/realtime && npm test && npm run typecheck`; `cd backend/api && npm test && npm run typecheck` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(realtime): authenticate internal notify and wire the service binding"`

### Task 16: Equalize login timing — *Plane: DAFTARI-96*

**Files:** Modify: `backend/api/src/routes/auth.ts:25-59`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces `DUMMY_HASH` (a valid `pbkdf2-sha512$10000$…` constant) and an unconditional `await verifyTagged(user?.password_hash ?? DUMMY_HASH, password)`.

- [ ] **Step 1:** Failing test: `an unknown username still performs a password derivation` — inject a spy `verifyTagged` via a new `verify` dependency and assert it was called for a nonexistent user.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Restructure so the KDF always runs, then compute `passwordOk = user != null && user.is_active === 1 && derived`. Compute the lock deadline in one SQL statement (`recordAuthFailure` takes the computed lock as now) and reset `failed_attempts` when the lock expires.
- [ ] **Step 4:** Verify `cd backend/api && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): constant-work login for unknown users (DAFTARI-96)"`

### Task 17: Rate limiting + lockout reset — *Plane: DAFTARI-97*

**Files:** Create: `backend/shared/src/rate_limit.ts`; Modify: `backend/api/src/routes/auth.ts:38-59`, `backend/shared/src/turso.ts` (new `auth_attempts` table), create `backend/shared/migrations/004_login_throttle.sql`, Test: `backend/shared/src/rate_limit.test.ts`, `backend/api/test/api.test.ts`

**Interfaces:** Produces `checkLoginRateLimit(db, ip, tenantId, username, now): Promise<{allowed: boolean; retryAfterMs: number}>` implementing a 10-attempts/15-min sliding window per IP and per `(tenant, username)`; `/auth/login` returns 429 `RATE_LIMITED` with `retry_after_ms`.

- [ ] **Step 1:** Failing tests: `11th attempt from one IP in 15 minutes is rejected`; `attempts from a different IP are unaffected`; `the window slides`; API test asserts 429.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement the module + migration + route guard (guard runs before the KDF). Leave a `TODO(DAFTARI-97)` only for Turnstile, which is not part of this task.
- [ ] **Step 4:** Verify `cd backend/shared && npm test && npm run typecheck`; `cd backend/api && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): per-IP and per-account login throttling (DAFTARI-97)"`

### Task 18: KDF defaults, password policy, `hashTagged` validation, Dart parity — *Plane: DAFTARI-92*

**Files:** Modify: `backend/shared/src/password_kdf.ts:40-52`, `backend/api/src/routes/users.ts:20-21`, `lib/core/crypto/password_hasher.dart:68-75`, Test: `backend/shared/src/password_kdf.test.ts`, `test/core/crypto/password_hasher_test.dart`

**Interfaces:** Produces TS `DEFAULT_ITERATIONS = 210_000` and Dart `hashTagged(..., iterations = 210_000)` (identical for new hashes; verification still accepts 10 000 for existing rows); `MIN_PASSWORD = 12`, `MAX_PASSWORD = 256`; `hashTagged` throws `ArgumentError` when `iterations < 1 || iterations > 1_000_000` or `password.isEmpty || password.length > 256`.

- [ ] **Step 1:** Failing tests: `hashTagged rejects zero iterations`; `hashTagged rejects a 257-char password`; `verifyTagged still accepts a 10000-iteration hash`; `Dart default iterations equals the TS default` (assert the constant via a KDF fixture cross-check).
- [ ] **Step 2:** Run `cd backend/shared && npm test`; `flutter test test/core/crypto/password_hasher_test.dart` → FAIL.
- [ ] **Step 3:** Implement, and regenerate `backend/shared/fixtures/kdf_vectors.json` with `tool/gen_kdf_fixtures.dart` for the new default. Enforce max length in `/auth/login` and `POST /admin/users` (return 400 `INVALID_FIELDS`).
- [ ] **Step 4:** Verify both suites + `./tool/gen_kdf_fixtures.dart` produces no diff → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(auth): raise KDF cost, cap password length, validate hashTagged (DAFTARI-92)"`

### Task 19: Explicit CORS allowlist

**Files:** Modify: `backend/api/src/index.ts:31`, `backend/api/src/env.ts`, `backend/api/wrangler.toml`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces `cors({ origin: [adminOriginFor(env)], allowHeaders: ['Authorization','Content-Type'] })` where `adminOriginFor` maps dev/staging/production to `admin-dev|admin-staging|admin.daftariapp.workers.dev`; `localhost` origins allowed only when `ENVIRONMENT === 'development'`.

- [ ] **Step 1:** Failing tests: `a foreign origin is not echoed in Access-Control-Allow-Origin`; `the admin origin is echoed`; `localhost is allowed in development only`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement the origin resolver and wire it.
- [ ] **Step 4:** Verify `cd backend/api && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🔒️ security(api): restrict CORS to the admin origins"`

### Task 20: Fix `requireAdmin`-adjacent latent issues — *code-hygiene bundle*

**Files:** Modify: `backend/api/src/routes/users.ts:82-93,121-125`, `backend/api/src/routes/sales.ts:63-65`, `backend/api/src/index.ts` (`onError`), Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces: duplicate-username create → 409 `USERNAME_TAKEN` (catch the PK violation); `PATCH` can clear `display_name` (send `null`); `/sales?since=` must be a finite non-negative integer or 400 `INVALID_FIELDS`; a global `app.onError` mapping `SyntaxError` → 400 `INVALID_JSON` and everything else → 500 `INTERNAL` with no stack in the body.

- [ ] **Step 1:** Failing tests for each of the four behaviours, including `a malformed JSON body returns 400 not 500`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement all four.
- [ ] **Step 4:** Verify `cd backend/api && npm test && npm run typecheck` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🩹 fix(api): 409 on duplicate username, clearable display_name, validated since, JSON error handler"`

---

## Phase D — Data integrity, performance, client correctness

### Task 21: Bound `/admin/activity` — *Finding (High)*

**Files:** Modify: `backend/shared/src/turso.ts` (add `getRecentSales`), `backend/api/src/routes/admin.ts:58-70`, Test: `backend/shared/src/turso.test.ts`, `backend/api/test/api.test.ts`

**Interfaces:** Produces `getRecentSales(tenantId: string, limit: number): Promise<Array<Pick<SaleRecord,'id'|'total_piastres'|'created_at'>>>` with `SELECT id, total_piastres, created_at FROM sales WHERE tenant_id = ? ORDER BY created_at DESC LIMIT ?`.

- [ ] **Step 1:** Failing test: `getRecentSales selects only id/total/created_at and honours the limit` (assert the SQL text and row count).
- [ ] **Step 2:** Run `cd backend/shared && npm test` → FAIL.
- [ ] **Step 3:** Implement and call it with `limit: 5`, reversing to ascending for the feed.
- [ ] **Step 4:** Verify `cd backend/shared && npm test`; `cd backend/api && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "⚡ perf(api): bound the activity feed query and drop receipt blobs"`

### Task 22: POS reconnect must not leak device slots — *Finding (High)*

**Files:** Modify: `backend/api/src/routes/sessions.ts:37-63`, `backend/shared/src/turso.ts:248-254`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces: on `reconnect`, `endSession` the existing row for `(tenantId, device_hwid)` before inserting; `getActivePosSessions` gains `AND heartbeat_at > ?` (stale rows freed).

- [ ] **Step 1:** Failing tests: `a reconnecting device does not consume a second slot`; `a stale POS session does not count toward the limit`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement both changes; pass `now - HEARTBEAT_FRESH_MS` to `getActivePosSessions`.
- [ ] **Step 4:** Verify `cd backend/api && npm test && npm run typecheck` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🩹 fix(sessions): end the prior row on reconnect and ignore stale POS rows"`

### Task 23: Slim the realtime broadcast payload

**Files:** Modify: `backend/api/src/routes/sales.ts:45-52`, Test: `backend/api/test/api.test.ts`

**Interfaces:** Produces the broadcast body `{ type: 'sale', count: number }` only (no `sales` array).

- [ ] **Step 1:** Failing test: `the sale broadcast never contains receipt_json`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Drop `sales` from the payload.
- [ ] **Step 4:** Verify `cd backend/api && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "⚡ perf(api): broadcast a sale count, not full receipts"`

### Task 24: Add the missing indexes

**Files:** Create: `backend/shared/migrations/005_query_indexes.sql`, Test: `backend/shared/src/turso.test.ts` (schema smoke)

**Interfaces:** Produces `idx_sessions_tenant_started ON sessions(tenant_id, started_at)` and `idx_devices_tenant_last_seen ON devices(tenant_id, last_seen_at)`.

- [ ] **Step 1:** Failing test: `the migration set creates the sessions and devices indexes` (parse the migration files for the two `CREATE INDEX` statements).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Write the migration. Note in the header that it is additive and re-runnable (`IF NOT EXISTS`).
- [ ] **Step 4:** Verify `cd backend/shared && npm test` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "⚡ perf(shared): index sessions by started_at and devices by last_seen_at"`

### Task 25: Client — check `ok` and stop conflating errors with empty data — *Plane: DAFTARI-101*

**Files:** Modify: `lib/features/admin_dashboard/dashboard/dashboard_bloc.dart:100-149`, `lib/features/admin_dashboard/subscription/subscription_view.dart:31-66`, `lib/features/admin_dashboard/sales/sales_chart_view.dart:62-84`, `lib/features/admin_dashboard/users/users_bloc.dart:96-165`, `lib/features/admin_dashboard/users/users_view.dart:31-32`, Test: the four matching test files

**Interfaces:** Produces: each loader validates `body['ok'] == true` and emits an `error` state carrying the server code; views render an error + retry instead of zeros/defaults; `UsersBloc` separates `UsersLoadError` from a one-shot `UsersMutationFailed` (SnackBar) so a failed mutation never replaces the list; all handlers use bare `catch` (so `TypeError` cannot escape); `subscription_view.dart` moves `await widget.tokenProvider()` **inside** the `try`.

- [ ] **Step 1:** Failing widget/bloc tests: `a 403 overview response shows an error and a retry button, not zeros`; `a failed create keeps the user list and shows a snackbar`; `a throwing tokenProvider leaves the subscription view with an error state, not a spinner`; `a malformed device payload yields DashboardError, not a permanent loading state`.
- [ ] **Step 2:** Run `flutter test test/features/admin_dashboard/` → FAIL.
- [ ] **Step 3:** Implement across the listed files.
- [ ] **Step 4:** Verify `flutter test test/features/admin_dashboard/` and `flutter analyze` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🩹 fix(admin): surface API errors and keep the user list on mutation failure (DAFTARI-101)"`

### Task 26: Dashboard refresh concurrency + realtime client hardening — *Plane: DAFTARI-103*

**Files:** Modify: `lib/features/admin_dashboard/dashboard/dashboard_bloc.dart:72,152-161`, `lib/core/backend/workers/realtime_client.dart:52-79`, Test: `test/features/admin_dashboard/dashboard/dashboard_bloc_test.dart`, `test/core/backend/workers/realtime_client_test.dart`

**Interfaces:** Produces `on<OverviewRequested>(_onOverview, transformer: restartable())`; `RealtimeClient` resets `_attempts` on socket open (not only on a message) and exposes `Stream<bool> get connected`; `DashboardBloc` surfaces a `realtimeConnected` flag.

- [ ] **Step 1:** Failing tests: `a burst of realtime events results in one in-flight overview load`; `the backoff ladder resets after a successful open`; `connected emits false after the 5th failure`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement (`bloc_concurrency` is already available via `flutter_bloc`).
- [ ] **Step 4:** Verify `flutter test test/features/admin_dashboard/dashboard/ test/core/backend/workers/realtime_client_test.dart` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "⚡ perf(admin): serialize overview refreshes; signal realtime connectivity (DAFTARI-103)"`

### Task 27: Flutter polish bundle — *findings (Low/Medium)*

**Files:** Modify: `lib/app_admin.dart:34` (locale fallback), `lib/features/admin_dashboard/overview/overview_view.dart:159` (`BorderDirectional(start:)`), `lib/features/admin_dashboard/sales/sales_chart_view.dart:51-61` (`>=` boundary), `lib/features/admin_dashboard/admin_shell.dart:41-72` (scope the `BlocBuilder`), `lib/features/admin_dashboard/sales/sales_chart_view.dart:111-117` (memoize `_chartData`), `lib/app_admin.dart:47-86` (live token provider), `lib/features/admin_dashboard/login/admin_auth_bloc.dart:96-105` (stop holding the plaintext password in state), Test: matching files

**Interfaces:** Produces `tokenProvider: () => _admin.validToken()` for the session path and `() => _firebase.currentIdToken()` for the owner path (never a captured string); `AdminAuthService.validToken(): Future<String?>` returns the stored JWT only if unexpired; an explicit `localeResolutionCallback` falling back to `en`.

- [ ] **Step 1:** Failing tests: `an unsupported locale resolves to English, not Arabic`; `the token provider returns a refreshed Firebase ID token after expiry` (stub `currentIdToken` to change value); `SessionConflict does not expose the password` (assert the state has no `password` field).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement all listed changes; replace the `SessionConflict.password` field with a `VoidCallback retry` supplied by the widget.
- [ ] **Step 4:** Verify `flutter test` and `flutter analyze` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "🩹 fix(admin): live token provider, locale fallback, RTL border, chart boundary, narrower rebuilds"`

### Task 28: Map server auth failures to a session-expired UX

**Files:** Modify: `lib/features/admin_dashboard/dashboard/dashboard_bloc.dart`, `lib/features/admin_dashboard/admin_shell.dart`, `lib/features/admin_dashboard/login/admin_auth_bloc.dart`, Test: matching files

**Interfaces:** Produces a single `SessionExpired` handling path: any `401`/`SESSION_REVOKED`/`SESSION_STALE` from a dashboard request dispatches `AdminAuthEvent.sessionExpired`, which emits `AuthError(code:'SESSION_EXPIRED')` → `_isFirebaseStageError` → the Firebase card.

- [ ] **Step 1:** Failing test: `a 401 from /admin/overview routes the user to the Firebase stage`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement the signal path (do not add a global interceptor; dispatch from the bloc whose request failed).
- [ ] **Step 4:** Verify `flutter test test/features/admin_dashboard/` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "✨ feat(admin): route expired sessions back to re-authentication"`

---

## Phase E — CI/CD and environment

### Task 29: Build the admin entry point in CI — *Finding (High)*

**Files:** Modify: `.github/workflows/ci.yml:160-190`, Test: workflow lint by inspection + a branch push

**Interfaces:** Produces: for `matrix.flavor == 'admin'`, the build step runs `flutter build web --wasm -t lib/main_admin.dart --dart-define=FLAVOR=admin --dart-define=ENV=${{ matrix.env }}`; other flavors keep the current command.

- [ ] **Step 1:** Add an explicit `if`/`else` branch to the build step (a `case` on `matrix.flavor` is acceptable) rather than duplicating the whole job.
- [ ] **Step 2:** Push the branch and confirm the `Flutter admin/*/web` jobs still pass and that a deliberate `lib/main_admin.dart` syntax error fails the job. Revert the deliberate error.
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: compile the admin entry point with --wasm in the matrix"`

### Task 30: `CI Summary (Required)` must fail on skipped and cancelled — *Finding (High)*

**Files:** Modify: `.github/workflows/ci.yml:332-341`

**Interfaces:** Produces a summary step that fails when any needed job's result is not `success` (i.e. `failure`, `cancelled` or `skipped`).

- [ ] **Step 1:** Replace the `contains(needs.*.result,'failure')` expression with one that compares each needed job's result to `success` (a `join(needs.*.result, ',')` check for anything other than `success`, allowing an explicit allowlist of job names permitted to skip).
- [ ] **Step 2:** Verify on a scratch PR targeting a non-main base: the summary must report failure while heavy jobs skip.
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: fail the required summary when the build matrix is skipped"`

### Task 31: Packaging must not be masked by test failures — *Finding (Medium)*

**Files:** Modify: `.github/workflows/ci.yml:260-310`

**Interfaces:** Produces: `Build AppImage` and `Build RPM` run with `if: always()`; `Upload Linux Artifacts` uses `if-no-files-found: error`; the AppImage smoke test drops `|| true` and asserts a zero exit code.

- [ ] **Step 1:** Apply the three changes.
- [ ] **Step 2:** Verify by re-running the Packaging Verify (Linux) job and confirming artifacts are uploaded even when the .NET step fails, and that the job still goes red.
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: always build packaging artifacts and stop masking smoke failures"`

### Task 32: `deploy-cloud.yml` error swallowing + Node 22

**Files:** Modify: `.github/workflows/deploy-cloud.yml:98`, `.github/workflows/ci.yml:66`, `backend/*/package.json`

**Interfaces:** Produces: the pages-project step greps for the "already exists" text and re-raises any other failure; every backend job uses `node-version: 22`; each `backend/*/package.json` gains `"engines": {"node": ">=22"}`.

- [ ] **Step 1:** Implement the three changes.
- [ ] **Step 2:** Verify `cd backend/api && npm ci && npm run typecheck` on Node 22 and that CI passes.
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: surface real deploy errors and align Node on 22"`

### Task 33: `sync_specs` permissions — *followups #39*

**Files:** Modify: `.github/workflows/opencode.yml` (the two `anomalyco/opencode/github@latest` steps)

**Interfaces:** Produces `with: use_github_token: true` on both steps.

- [ ] **Step 1:** Add the input; leave the declared `permissions:` blocks intact.
- [ ] **Step 2:** Verify on a scratch PR that `sync_specs` reaches the analysis step instead of failing at `permission: none`.
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: let sync_specs use GITHUB_TOKEN for write access"`

### Task 34: Codacy calibration — *Finding*

**Files:** Create `.codacy.yml` (or `.codacy.yaml`)

**Interfaces:** Produces: `test/**` and `**/*_test.dart`/`*.test.ts` excluded from analysis; the Dart analyzer disabled (CI already runs `flutter analyze`); the gate threshold relaxed from 0.

- [ ] **Step 1:** Add the config. Record in the file why the Dart analyzer is off: all 25 failure-level annotations were resolution false positives (`Undefined class 'Widget'`, `The method 'Left' isn't defined`) on code that `flutter analyze` passes.
- [ ] **Step 2:** Verify by re-running the Codacy check on the PR; the check must no longer report 1000+ "new issues" from generated/test code.
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: calibrate Codacy to exclude tests and false-positive Dart analysis"`

### Task 35: Stop committing generated Windows registrants

**Files:** Modify: `.github/workflows/deploy-cloud.yml` (or `ci.yml`) to run `flutter pub get` before the Windows build; `.gitignore`

**Interfaces:** Produces a CI step that regenerates `windows/flutter/generated_*` and fails if they differ from the committed copies, so the last specs commit cannot smuggle generated files in.

- [ ] **Step 1:** Add the regenerate-and-diff step to the Windows build job.
- [ ] **Step 2:** Verify the step passes on the current tree (the committed files match the current `pubspec.yaml`).
- [ ] **Step 3:** Commit: `git commit -am "🔧 ci: verify generated Windows registrants instead of committing them"`

---

## Phase F — Remaining Plane work items

### Task 36: Spec regeneration — *findings A–J*

**Files:** Modify: `specs/ARCHITECTURE.md`, `specs/PRD.md`, `specs/USER_FLOW.md`, `specs/DESIGN.md`, `specs/DEVELOPMENT_ENVIRONMENT.md`, `docs/followups.md`

**Interfaces:** Produces specs whose every claim matches the merged code, verified by a checklist in the commit message.

- [ ] **Step 1:** Rewrite each mismatch from the review: provider allowlist (A), lockout formula (B), Dart KDF algorithm/iterations (C), `PATCH /admin/users` (D), DELETE self-delete (E), POST access (F), the non-existent `POST /sessions` (G), the 90-day gate location (H), the KDF fixtures claim (I), the `lib/core/config/` paths (J).
- [ ] **Step 2:** Fix `docs/followups.md:48`'s false "verified on the upgrade" claim; mark #39, #43, #44, #45, #46, #47, #48, #49 as resolved with the commit that resolved them.
- [ ] **Step 3:** Verify: `grep -n` each corrected claim against the code and confirm the text matches.
- [ ] **Step 4:** Commit **only** `specs/**` and `docs/**`: `git commit -m "📝 docs(specs): sync specs with the implemented auth and session behaviour"`

### Task 37: Offline banner — *Plane: DAFTARI-99*

**Files:** Modify: `pubspec.yaml` (add `connectivity_plus`), `lib/features/admin_dashboard/login/login_screen.dart`, `lib/features/admin_dashboard/admin_shell.dart`, Test: `test/features/admin_dashboard/login_screen_test.dart`

**Interfaces:** Produces `AdminLoginBloc` states `Offline`/`Online` driven by `Connectivity().onConnectivityChanged`, rendering the spec's `WEB_DASHBOARD_OFFLINE` banner with a disabled sign-in action.

- [ ] **Step 1:** Failing widget test: `the offline banner appears when connectivity is none and the sign-in button is disabled`.
- [ ] **Step 2:** Run `flutter test test/features/admin_dashboard/login_screen_test.dart` → FAIL.
- [ ] **Step 3:** Add the dependency, wire the stream, render the banner (Arabic copy from spec §6.4).
- [ ] **Step 4:** Verify `flutter test && flutter analyze` → PASS; confirm `connectivity_plus` supports web/WASM.
- [ ] **Step 5:** Commit: `git commit -am "✨ feat(admin): offline banner for the login screen (DAFTARI-99)"`

### Task 38: Tier gating per the feature matrix — *Plane: DAFTARI-100*

**Files:** Modify: `backend/api/src/routes/users.ts` (add a tier check), `backend/shared/src/turso.ts` (`getUser` already returns `tier`), `lib/features/admin_dashboard/admin_shell.dart:135`, Test: `backend/api/test/api.test.ts`, `test/features/admin_dashboard/admin_shell_test.dart`

**Interfaces:** Produces: `GET/POST /admin/users` return 403 `TIER_REQUIRED` when `users.tier === 'starter'`; `AdminShell` hides the Users and Subscription destinations for `starter`.

- [ ] **Step 1:** Failing tests: `a starter tenant gets 403 TIER_REQUIRED on /admin/users`; `an admin workspace hides the Users destination for starter`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement both sides using the spec §2.5.1 matrix (`Professional+`).
- [ ] **Step 4:** Verify `cd backend/api && npm test`; `flutter test test/features/admin_dashboard/admin_shell_test.dart` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "✨ feat(admin): enforce the tier matrix server-side and in the shell (DAFTARI-100)"`

### Task 39: Session-conflict choreography + magic-link completion — *Plane: DAFTARI-85*

**Files:** Modify: `lib/features/admin_dashboard/login/login_screen.dart`, `lib/features/admin_dashboard/login/admin_auth_bloc.dart:147-155,199-205`, Test: `test/features/admin_dashboard/admin_auth_bloc_test.dart`

**Interfaces:** Produces: when `isSignInWithEmailLink(url)` is true but `pendingMagicEmail()` is null, the Firebase card prompts for the email and dispatches `MagicLinkCompleted(email, url)`; the conflict dialog distinguishes "your own other browser" from "another device" and offers Revoke + Retry.

- [ ] **Step 1:** Failing tests: `a magic link opened in a different browser prompts for the email`; `the conflict dialog offers retry after revoke`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement the prompt + the dialog states.
- [ ] **Step 4:** Verify `flutter test test/features/admin_dashboard/` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "✨ feat(admin): cross-browser magic link and session-conflict UX (DAFTARI-85)"`

### Task 40: Device-linking wizard — *Plane: DAFTARI-86*

**Files:** Create: `lib/features/admin_dashboard/devices/device_linking_view.dart`, `lib/features/admin_dashboard/devices/device_linking_bloc.dart`; Modify: `lib/features/admin_dashboard/admin_shell.dart`, Test: `test/features/admin_dashboard/devices/device_linking_bloc_test.dart`

**Interfaces:** Produces `DeviceLinkingBloc` with events `OwnerSignInRequested`/`DeviceNamed(String)`/`LinkSubmitted`, consuming `POST /admin/devices/link` (new route: body `{device_hwid, name}`, owner-only, returns `{ok, data:{device}}`).

- [ ] **Step 1:** Failing tests: `linking requires an owner token` (API) and `the wizard advances from owner sign-in to device naming`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement the route (owner-only, tenant-scoped, `upsertDevice`) and the two-file client feature; add the destination to the shell.
- [ ] **Step 4:** Verify `cd backend/api && npm test`; `flutter test test/features/admin_dashboard/devices/`; `flutter analyze` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "✨ feat(admin): device-linking wizard (DAFTARI-86)"`

### Task 41: Rename stale docs/tests and remove stray files — *Plane: DAFTARI-89, 91, 93*

**Files:** Modify: `backend/README.md`, `test/core/crypto/password_hasher_test.dart:6`, `test/core/backend/api_client_test.dart:17`, `.gitignore`; Delete: `auth`, `auth-wal` (repo root, untracked 0-byte)

**Interfaces:** none (housekeeping).

- [ ] **Step 1:** Re-run the test suite to confirm the current pass state before touching test names.
- [ ] **Step 2:** Fix the `backend/README.md` directory table; rename `should return base64url string of length 24` to `…length 44`; rename `sham URL` to describe the canonical URL assertion.
- [ ] **Step 3:** Add `auth` and `auth-wal` to `.gitignore` and remove the stray files (confirm they are untracked and 0 bytes first).
- [ ] **Step 4:** Verify `flutter test test/core/crypto/password_hasher_test.dart test/core/backend/api_client_test.dart` → PASS.
- [ ] **Step 5:** Commit: `git commit -am "📝 docs: fix stale README/test names; ignore local libsql artifacts (DAFTARI-89, 91, 93)"`

### Task 42: Firebase email templates — *Plane: DAFTARI-90 (manual, console)*

**Files:** Modify: `docs/DEVELOPMENT_ENVIRONMENT.md` (document the console steps); no code.

**Interfaces:** none.

- [ ] **Step 1:** In the Firebase console for `daftari-pos`, customize the email-link template: sender name `Daftari`, subject and body in Arabic + English, action link label matching the dashboard.
- [ ] **Step 2:** Add `admin-dev.daftariapp.workers.dev`, `admin-staging…`, `admin…` to Authentication → Settings → Authorized domains (verify; re-auth must not depend on this).
- [ ] **Step 3:** Document both in `docs/DEVELOPMENT_ENVIRONMENT.md` §5i and check off DAFTARI-90 in Plane.
- [ ] **Step 4:** Commit: `git commit -am "📝 docs: document the Firebase email-template and authorized-domain setup (DAFTARI-90)"`

### Task 43: Plane close-out

**Files:** none.

- [ ] **Step 1:** For each of `DAFTARI-85, 86, 89, 90, 91, 92, 93, 95, 96, 97, 98, 99, 100, 101, 102, 103` and the three new items, comment the resolving commit SHA and move the item to `Done`:

```bash
export XDG_CACHE_HOME=/dev/shm/planecli-cache
~/.local/bin/planecli wi update DAFTARI-98 --state Done
```
- [ ] **Step 2:** Move the residual-risk item (`FIX-SESSION-BOUND`) to `Todo` with a description pointing at the decision register.

---

## Verification gates (run before opening the PR)

- [ ] `dart format --set-exit-if-changed lib test && flutter analyze && flutter test` → exit 0, all tests pass.
- [ ] `cd backend/api && npm test && npm run typecheck`
- [ ] `cd backend/shared && npm test && npm run typecheck`
- [ ] `cd backend/realtime && npm test && npm run typecheck`
- [ ] `cd backend/admin_host && npm test && npm run typecheck`
- [ ] `flutter build web --wasm -t lib/main_admin.dart --dart-define=FLAVOR=admin --dart-define=ENV=development` succeeds.
- [ ] Manual end-to-end on dev: Google sign-in completes → empty-accounts bootstrap → create the first admin → credential login → dashboard loads → realtime connects (no 401 in the network tab) → F5 resumes without a conflict dialog → logout invalidates the token.
- [ ] Migration 002 + 003 + 004 + 005 applied to `daftari-dev`; `ADMIN_JWT_SECRET` and `INTERNAL_NOTIFY_SECRET` set on `api-dev` and `realtime-dev`.
- [ ] Re-run the PR #39 check suite; `Codacy` and `CI Summary (Required)` behave as designed, and the CodeRabbit items that this plan addresses are marked resolved.

## Explicitly out of scope

`DAFTARI-109` (Business-tier Phase 2: permissions matrix, advanced analytics, exports). Turnstile (the rate limiter in T17 covers DAFTARI-97's stated need; Turnstile remains a follow-up). An absolute cap on continuous web-session lifetime (tracked as the new residual-risk item; the user requirement forbids interrupting an active session).

## Assumptions

1. The 16 Plane items are `DAFTARI-{85,86,89,90,91,92,93,95,96,97,98,99,100,101,102,103}`; `DAFTARI-109` is the only business-tier exclusion and `DAFTARI-94` is already Done. Adjust the ID list in T43 if a different 16 was intended.
2. The COOP fix (T3) is confirmed by live reproduction in Step 5; if the popup still fails, fall back to `signInWithRedirect` + `getRedirectResult()` in `main_admin.dart` while keeping the header change (the header change is correct regardless, since isolation is optional).
3. Magic-link `sign_in_provider` resolves to `password` (T11 Step 4); the plan's branch handles the other outcomes.
4. `bloc_concurrency` transformers are available through the already-pinned `flutter_bloc`.
5. This plan is saved at `docs/superpowers/plans/2026-09-29-pr39-fixes-and-hardening.md` (committed in T1 alongside the spec) and a working copy is on the Desktop at `~/Desktop/2026-09-29-pr39-fixes-and-hardening.md`.
6. Work lands on `feature/admin-dashboard-phase1` at the PR #39 head (`8107baf`); commits are NOT merged into `development` and not pushed to shared branches — PR #39 picks them up automatically.
