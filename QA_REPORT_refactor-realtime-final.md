# QA Post-Implementation Report

**Feature:** Daftari realtime (Durable Object WebSocket hub + service-binding notify)
**Branch:** refactor/realtime ← development
**Date:** 2026-10-23
**Status:** ❌ BLOCKED (review phase — awaiting approval; no fixes applied)
**Risk Level:** Critical
**Phase:** Review (awaiting approval)
**Scope invoked:** full (verification + code-reviewer + security-appsec-engineer)

---

## 0. Project Context
- **Project root:** /mnt/ALL/Daftari
- **Repo:** https://github.com/OmarAdel10/daftari.git
- **Branch:** refactor/realtime ← development (origin/development exists; feature is 22 commits ahead, 0 behind)
- **Stack:** TypeScript / Hono / Cloudflare Workers + Durable Objects / libSQL / tsyringe DI / vitest (under backend/realtime/)
- **Monorepo:** yes (Flutter root + backend/ workspace); affected workspace: backend/realtime
- **Intent docs found:** specs/PRD.md, specs/ARCHITECTURE.md, specs/DESIGN.md, specs/USER_FLOW.md, specs/DEVELOPMENT_ENVIRONMENT.md (repo root specs/); backend/realtime/README.md (feature docs)
- **CI:** GitHub Actions (.github/workflows/ci.yml, cd-*.yml present); status not queried (no token)
- **Change set:** M=2 A=34 R=0 D=0 ??=3 untracked artifacts (36 total committed files), all under backend/realtime/
- **Sensitive surface area:** auth (HS256 JWT + ticket), tenantId IDOR guard (cross-tenant DO routing), rate limiting (pre-auth IP + post-auth tenant + global notify), secrets (ADMIN_JWT_SECRET, INTERNAL_NOTIFY_SECRET), broadcast data (fan-out to WS sessions)
- **Security role selected:** security-appsec-engineer (Web/API)

---

## 1. Executive Summary
The realtime feature is complete and well-layered (clean architecture, no business logic in routes, secrets out of source, 112/112 tests pass, tsc clean). However the Gate 1 quality gate FAILS: a **confirmed Critical** finding makes `/ws` Bearer-JWT auth reject every API-minted session JWT (iss/aud/claim-name mismatch with backend/shared/src/session_jwt.ts), so primary WebSocket authentication is non-functional in production. Score is far below 90. **BLOCKED until the Critical is fixed.**

---

## 2. Verification
- **Acceptance criteria:** Partial (all 6 phases implemented; primary /ws Bearer auth broken → core criterion not met)
- **End-to-end behavior:** tsc typecheck + full vitest suite pass; routes delegate correctly; DO fan-out tested with mocked WebSocket
- **Tests:** 112 passed / 0 failed / 0 skipped across 9 files:
  - src/application/__tests__/websocket-connect-use-case-fuzz (3), notify-use-case-fuzz (3)
  - src/application/__tests__/notify-use-case (12), websocket-connect-use-case (10)
  - src/__tests__/tenant-notifier (8)
  - src/domain/__tests__/domain-services (18), domain-services-fuzz (6)
  - src/runtime.test.ts (9); test/realtime.test.ts (43)
- **Evidence:** `./node_modules/.bin/tsc --noEmit` → exit 0; `./node_modules/.bin/vitest run` → 9 passed, 112 passed, exit 0
- **Open issues:** Critical auth mismatch (#1); coverage not re-measured with `--coverage` flag (all changed units have corresponding tests; rate-limiter exercised via route integration tests only)

---

## 3. Code Quality (Code Reviewer: engineering-code-reviewer)
| Severity | File:Line | Finding | Suggested Fix |
|----------|-----------|---------|---------------|
| Critical | backend/realtime/src/index.ts:140,142 | `verifyHs256Jwt` requires aud='realtime', iss='daftari-realtime', reads claim `tenantId`; but session_jwt.ts mints iss='daftari-api', aud='daftari-admin', claim `tid` → every API-minted JWT rejected on /ws Bearer path; primary WS auth non-functional | Align iss/aud with session_jwt.ts ('daftari-api'/'daftari-admin') and read `tid`, or mint separate realtime JWTs. OWASP A07 / CWE-287 |
| Medium | backend/realtime/src/tenant_notifier.ts:35 | `notify(_tenantId, event)` trusts caller-supplied _tenantId; no in-DO tenant-identity validation (DO-level re-auth missing) | Validate _tenantId matches DO's tenant identity inside notify(). OWASP A01 / CWE-284 |
| Medium | backend/realtime/src/index.ts:264 | GET /ws requires CF-Connecting-IP; returns 400 when absent → unreachable outside Cloudflare edge (workers.dev/preview) | Fall back to connection-based key or skip pre-auth IP limit when header absent |
| Medium | backend/realtime/src/index.ts:88-90 | tenantId validation constants (TENANT_ID_RE, MAX_TENANT_ID_LENGTH) duplicated in NotifyUseCase (notify-use-case.ts:56-59) — divergence risk | Extract shared tenantId validation into a domain value object used by both layers |
| Low | backend/realtime/src/index.ts:179 | Inline magic number `256 * 1024` body limit | Named constant MAX_BODY_BYTES |
| Low | backend/realtime/src/index.ts:166; runtime.ts:53 | Inline magic numbers `100, 60_000` RateLimiter(maxHits, windowMs) | Named constants |
| Low | backend/realtime/src/index.ts:247 | Redundant cast `payload as unknown as Record<string, unknown>` | Remove cast |
| Low | backend/realtime/src/index.ts:206 | Redundant `const tenantId = rawTenantId;` | Use rawTenantId directly |
| Low | backend/realtime/src/domain/services/broadcast-service.impl.ts:17-18 | Unnecessary `?? ''` on non-optional string params | Remove `?? ''` |
| Low | backend/realtime/src/application/use-cases/websocket-connect-use-case.ts:38-43 | TICKET_RE charset/length duplicates TicketValidationServiceImpl.validateFormat | Keep format validation in one authoritative location |
| Low | backend/realtime/src/infrastructure/services/rate-limiter.ts:20 | sweep() iterates all buckets on every check() → O(n) per request | Lazy/periodic sweep instead of per-check |
| Info | backend/realtime/qa/coverage-report-phase-4.md:29 | Stale reference to index.ts:309 `export default createRealtimeApp()` (no such export; runtime.ts exports default) | Correct or remove stale doc reference |
| Info | specs/PRD.md / README | Spec describes Firebase RS256 + `?token=` fallback on /ws; code uses HS256 + `?ticket=` | Document deferral or align naming with spec |

**Code Reviewer totals: 1 Critical, 0 High, 4 Medium, 6 Low, 2 Info.**

---

## 4. Security (security-appsec-engineer)
- **Threat model scope:** in-scope — authN/authZ, IDOR, rate limiting, data exposure, secrets, DoS
- **Attack surface touched:** POST /internal/notify (X-Internal-Secret), GET /ws (Bearer JWT / ?ticket), Durable Object broadcast fan-out, env secrets (ADMIN_JWT_SECRET, INTERNAL_NOTIFY_SECRET)
- **Findings:**
| Severity | File:Line | Finding | Suggested Fix / Repro |
|----------|-----------|---------|----------------------|
| Critical | backend/realtime/src/tenant_notifier.ts:26 | TenantNotifier.fetch() has no DO-level re-authorization; route-level JWT/ticket is sole auth gate before proxying WS upgrade to DO. Direct/future DO.fetch() call or exposed NOTIFIER binding → cross-tenant WS access | Add tenant identity binding in TenantNotifier.fetch(); validate caller authorization for this DO's tenant. CWE-639, OWASP A01 |
| Medium | backend/realtime/src/index.ts:305 | Short-lived ticket (?ticket=) in URL query → leakage via Referer, browser history, access logs; capture = DoS or access | Prefer Bearer JWT; if ticket retained, deliver via same-site HttpOnly cookie or Authorization header. CWE-352/CWE-200 |
| Medium | backend/realtime/src/index.ts:115-158 | JWT verified (sig/exp/nbf/aud/iss) but no revocation — stolen ADMIN JWT valid until exp | Add JTI claim + short-lived blocklist (KV/Redis); enforce max lifetime at issuance. CWE-287, OWASP A07 |
| Medium | backend/realtime/src/infrastructure/services/rate-limiter.ts:9 | In-memory, per-Worker-instance limiter → limits multiplied across instances; distributable bypass | Distributed limiter (KV/Redis) in Phase 5/6; add per-tenant + per-IP buckets for /internal/notify. CWE-770, OWASP A04 |
| Medium | backend/realtime/src/tenant_notifier.ts:35-43 | notify() broadcasts raw JSON.stringify(event) to all tenant WS sessions, no PII filtering/classification | Data-sensitivity filter in NotifyUseCase before broadcast; mask sensitive fields. CWE-200, OWASP A01 |
| Low | backend/realtime/src/index.ts:66-73 | constantTimeEqual() runtime depends on input length (not truly constant-time) | Fixed-length digest comparison (SHA-256 both sides) or Web Crypto primitive. CWE-208 |
| Low | backend/realtime/wrangler.toml:7 | FIREBASE_PROJECT_ID ("daftari-pos") committed via [vars] — env config drift / project-ID leak risk | Move to env-specific wrangler configs or inject at deploy |
| Low | backend/realtime/src/index.ts:263-266 | /ws fail-closed on missing CF-Connecting-IP → availability impact outside Cloudflare | Fall back to trusted proxy chain (X-Forwarded-For first hop). CWE-400 |
| Info | backend/realtime/src/infrastructure/services/rate-limiter.ts:36-41 | sweep() O(n) CPU scan per check — potential CPU DoS under high cardinality | Lazy timestamp expiration / time-wheel buckets. CWE-400 |
| Info | backend/realtime/src/domain/services/broadcast-service.impl.ts:24-30 | shouldBroadcast() no data-sensitivity classification, size check, or per-event-type routing policy | Add sensitivity classification + per-event-type broadcast policy. CWE-200 |
| Info | backend/realtime/test/realtime.test.ts:22-23 | Hardcoded test secrets ('test-internal-secret', 'test-rt-secret') — test-only, but pattern could be copied to prod | Segregate test secrets; never in wrangler.toml/production env |

**Security totals: 1 Critical (tenant_notifier.ts:26), 0 High, 5 Medium, 3 Low, 3 Info.**
- Positive: no hardcoded production secrets (CWE-798 clean); tenantId IDOR guard validated at route + use-case layers; JWT alg/exp/nbf/aud/iss/signature verified with crypto.subtle; pre-auth per-IP + post-auth per-tenant rate limiting; body (256KB) and data (64KB) caps; prototype-pollution sanitization.

---

## 5. Branch Status
- **Commits ahead of base:** 22 (origin/development → refactor/realtime)
- **Commits behind base:** 0 (feature not behind development; up to date)
- **CI status:** config present (ci.yml); status not queried
- **Merge conflicts:** none expected (feature branched from development, 0 behind)
- **Uncommitted changes:** none for feature; 3 untracked out-of-scope artifacts (QA_REPORT_refactor-api-session-routes.md at root; backend/api/.vitest/; backend/realtime/qa/) — not part of the feature diff
- **Cleanup needed:** none for feature; untracked QA artifacts are session residue, not to be committed here

---

## 6. Handoff Summary
- **User-facing change:** Admin dashboard gains realtime WebSocket feed (per-tenant Durable Object hub with connection hibernation) plus a service-binding `POST /internal/notify` endpoint for the API worker to fan out sale/session/sync events.
- **How to use:** Client connects `GET /ws` with `Authorization: Bearer <HS256 JWT>` or `?ticket=<short-lived ticket>`; API posts `POST /internal/notify` with `X-Internal-Secret` + `{tenantId, event, data}`.
- **Rollback plan:** Revert `refactor/realtime` to development (branch retained per policy — never delete); remove NOTIFIER DO binding and wrangler entries if rolling back fully.
- **Follow-ups:** fix iss/aud/tenantId claim mismatch (#1); DO-level re-authorization (#2); ticket transport (#5); JWT revocation (#6); distributed rate limiter (#7).

---

## 7. Proposed Fix Plan + Decision Matrix
Score formula: `100 − 25×C − 10×H − 5×M − 1×L`. Reconciled counts: C=1, H=0, M=7, L=8 → score ≈ 32 (strictly ≤ 90). Gate requires 0 C / 0 H / 0 M and score > 90. **FAILS.**

| # | Severity | Fix target (file:line) | Diff sketch | Risk-of-fix | Needs test | Recommended action | Owner |
|---|----------|------------------------|-------------|-------------|------------|--------------------|-------|
| 1 | Critical | backend/realtime/src/index.ts:140,142 (+ session_jwt.ts:26-27 contract) | Change aud/iss to 'daftari-api'/'daftari-admin' and read `tid` (or mint realtime JWTs); update verify to return tenant id from `tid` | Medium (cross-service contract — must match api worker's mint exactly) | Y | **apply** (unblocks merge) | ? |
| 2 | Critical | backend/realtime/src/tenant_notifier.ts:26 | Add tenant-identity binding; validate caller in fetch() before acceptWebSocket | Low | Y | apply/defer (mitigated by DO-name=tenant-uid routing) | ? |
| 3 | Medium | backend/realtime/src/index.ts:305 | Move ticket out of query string to cookie/Auth header | Low | Y | apply | ? |
| 4 | Medium | backend/realtime/src/index.ts:115-158 | Add JTI + blocklist check; max lifetime | Medium | Y | apply/defer | ? |
| 5 | Medium | backend/realtime/src/tenant_notifier.ts:35-43 | PII field filter/classification in NotifyUseCase before broadcast | Low | Y | apply | ? |
| 6 | Medium | backend/realtime/src/index.ts:264 | Fallback when CF-Connecting-IP absent | Low | N | apply | ? |
| 7 | Medium | backend/realtime/src/index.ts:88-90 / notify-use-case.ts:56-59 | Extract shared tenantId validation value object | Low | N | apply | ? |
| 8 | Medium | backend/realtime/src/infrastructure/services/rate-limiter.ts:9 | Note: distributed limiter deferred to Phase 5/6 (documented) | Low | Y | defer (Phase 5/6) | ? |
| 9 | Low | backend/realtime/src/index.ts:179 | Named constant MAX_BODY_BYTES | Low | N | apply | ? |
| 10 | Low | backend/realtime/src/index.ts:166; runtime.ts:53 | Named rate-limiter constants | Low | N | apply | ? |
| 11 | Low | backend/realtime/src/index.ts:247 | Remove redundant cast | Low | N | apply | ? |
| 12 | Low | backend/realtime/src/index.ts:206 | Remove redundant const | Low | N | apply | ? |
| 13 | Low | backend/realtime/src/domain/services/broadcast-service.impl.ts:17-18 | Remove `?? ''` | Low | N | apply | ? |
| 14 | Low | backend/realtime/src/application/use-cases/websocket-connect-use-case.ts:38-43 | Dedup ticket format validation | Low | N | apply | ? |
| 15 | Low | backend/realtime/src/infrastructure/services/rate-limiter.ts:20 | Lazy/periodic sweep | Low | Y | apply | ? |
| 16 | Low | backend/realtime/src/index.ts:66-73 | Fixed-length digest comparison | Low | N | apply | ? |
| 17 | Low | backend/realtime/wrangler.toml:7 | Remove/commit FIREBASE_PROJECT_ID | Low | N | apply | ? |
| 18 | Info | backend/realtime/src/domain/services/broadcast-service.impl.ts:24-30 | Sensitivity classification policy | Low | Y | discuss | ? |
| 19 | Info | backend/realtime/test/realtime.test.ts:22-23 | Segregate test secrets | Low | N | apply | ? |
| 20 | Info | specs/PRD.md / backend/realtime/README | Align auth naming (HS256/?ticket= vs RS256/?token=) | Low | N | discuss | ? |

**AWAITING APPROVAL.** Reply with one of:
- `apply all` — execute every `apply` row
- `apply #1, #3, #5` — execute specific rows (e.g. just the Critical + key Mediums)
- `defer #2` — leave specific rows for later
- `reject #18` — drop specific rows
- `proceed as-is` — merge without fixes (logged as explicit risk acceptance; NOT recommended given Critical)

---

## 8. Prioritized Action Items
1. **[Critical]** Fix /ws Bearer auth iss/aud/claim contract vs backend/shared/src/session_jwt.ts — blocks merge. Owner? 
2. **[Critical]** Add DO-level re-authorization in TenantNotifier.fetch() — defense in depth. Owner?
3. **[Medium]** Move ?ticket= out of URL query string (Referer/log leakage). Owner?
4. **[Medium]** Add JWT revocation (JTI blocklist) — stolen token valid until exp. Owner?
5. **[Medium]** PII filtering on broadcast data. Owner?
6. **[Medium]** CF-Connecting-IP fallback / duplicated tenantId constants. Owner?
7. **[Low]** Magic numbers, redundant cast/const, `?? ''`, sweep O(n), constantTimeEqual, wrangler vars. Owner?
8. **[Info]** Spec/doc alignment, test-secret segregation. Owner?

---

## 9. Appendix
**Tools / agents / skills / CLIs / MCP endpoints invoked (all read-only, review phase):**
- `git` (status, diff, branch, log, worktree list) — read-only — change-set & branch discovery
- `read` (index.ts, runtime.ts, tenant_notifier.ts, package.json, vitest.config.ts, wrangler.toml, notify-use-case.ts, websocket-connect-use-case.ts, broadcast-service.impl.ts, rate-limiter.ts, session_jwt.ts) — read-only — source corroboration
- `glob` (specs, shared/src) — read-only — intent-doc & shared-module discovery
- `./node_modules/.bin/tsc --noEmit` — read-only verification — exit 0
- `./node_modules/.bin/vitest run` — read-only verification — 112/112 pass
- `subagent engineering-code-reviewer` — read-only — code review findings (Critical/4M/6L/2I)
- `subagent security-appsec-engineer` — read-only — security findings (1C/5M/3L/3I)
- `skill`: none invoked via `skill` tool during review phase; verification-before-completion discipline performed directly via tsc/vitest
- No mutating tools/CLIs/skills/MCP endpoints used. No file writes, no commits, no pushes.

**Commands run (full text):**
- `git rev-parse --show-toplevel` / `--abbrev-ref HEAD`; `git config --get remote.origin.url`; `git symbolic-ref refs/remotes/origin/HEAD`
- `git status --porcelain`; `git diff --name-status origin/development...HEAD -- backend/realtime/`
- `git branch -a`; `git log --oneline HEAD..origin/development` / `origin/development..HEAD`; `git worktree list`
- `./node_modules/.bin/tsc --noEmit` (exit 0); `./node_modules/.bin/vitest run` (112 passed, exit 0)

**Sub-agents dispatched:** engineering-code-reviewer (code quality), security-appsec-engineer (Web/AppSec). Both returned; findings integrated above. No optional sub-agents (spec-compliance, test-coverage) dispatched — full scope was requested.

**Skills loaded:** none via `skill` tool.

**Raw findings JSON:** summarized in sections 3–4 tables (full sub-agent output retained in session context).

**User's approval / override:** (pending — awaiting reply; none logged yet)

---
**END OF REPORT — awaiting your approval decision before any fixes are applied.**