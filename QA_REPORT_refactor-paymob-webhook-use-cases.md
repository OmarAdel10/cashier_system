# QA Post-Implementation Review Report

**Feature:** paymob_webhook Phase 2 — application layer (use cases + DTOs)
**Branch:** `refactor/paymob-webhook-use-cases` ← `development`
**Commit:** `8b5d1b3` ✅ feat(paymob_webhook): add application use cases
**Date:** 2026-10-23
**Status:** ❌ **BLOCKED**
**Risk Level:** Critical
**Phase:** Review (awaiting approval)
**Scope invoked:** full (verification + code-reviewer + security-appsec + skills)

---

## 0. Project Context

- **Project root:** /mnt/ALL/Daftari
- **Repo:** https://github.com/OmarAdel10/daftari.git
- **Branch:** refactor/paymob-webhook-use-cases ← development (canonical integration branch per AGENTS.md §2; origin/HEAD=master but development is the merge target; Phase 1 domain merged to development via PR #67)
- **Stack:** Node/TypeScript (vitest, tsc, hono, Cloudflare Worker)
- **Monorepo:** no (polyrepo backend under `backend/`; paymob_webhook is one worker)
- **Intent docs found:** specs/PRD.md, specs/ARCHITECTURE.md, specs/DESIGN.md, specs/USER_FLOW.md, specs/DEVELOPMENT_ENVIRONMENT.md
- **CI:** GitHub Actions (`.github/workflows/ci.yml`, `cd-*`, `opencode.yml`, etc.) present; no PR opened yet → no CI status
- **Change set:** M=0 A=8 R=0 D=0 ??=0 (total 8 files, all new additions in commit 8b5d1b3; 590 insertions)
- **Sensitive surface area:** webhook HMAC authn gate, Ed25519 license signing/issuance (entitlement), idempotency/replay protection, secret handling (hmacSecret, privateKeyB64 via DTOs), PII (tenantId, deviceHwid)
- **Security role selected:** security-appsec-engineer (web/API feature type)

---

## 1. Executive Summary

Phase 2 delivers 8 new application-layer files (2 use cases, 2 DTOs, 2 unit tests, 2 fuzz tests) on top of the merged Phase 1 domain layer. `tsc --noEmit` exits 0 and `vitest` passes 34/34 across 8 files. However, the Code Reviewer and security-appsec sub-agents both identified a **Critical** defect: `ProcessWebhookUseCase` invokes `hmacValidationService.isValid(dto.event.transactionId, …)` passing the transaction ID where the contract requires the 20-field HMAC concatenated string (as `src/index.ts:84` does correctly), rendering the webhook authenticity gate non-functional/bypassable. Two High findings (no entitlement gate on success/refund/void; bare `catch` swallowing signing errors) and two Medium findings (idempotency TOCTOU, unvalidated PII) follow. Per the gate (Zero Critical/High/Medium; score strictly > 90) the branch is **BLOCKED**. Score = 100 − 25×1 − 10×2 − 5×2 − 1×6 = **39**.

---

## 2. Verification

- **Acceptance criteria:** Partial — use cases implemented and unit/fuzz tested, but the HMAC authn input is wrong (Critical) and entitlement is not gated (High).
- **End-to-end behavior:** Not yet wired — `src/index.ts` (route layer) still does inline HMAC + signing + Turso upsert and does not call these use cases (Phase 3 wiring pending). Use cases are correct in isolation except for the HMAC argument and missing success-gate.
- **Tests:** vitest 8 files / 34 tests passed, exit 0. Both new use cases have unit + deterministic fuzz tests (3 seeds × 200 ops). DTOs are pure type definitions, type-checked by tsc. Coverage: zero gaps in changed units (each runtime unit exercised; DTOs have no runtime statements).
- **Typecheck:** `tsc --noEmit` exit 0.
- **Evidence:**
  - `./node_modules/.bin/tsc --noEmit` → `TSC_EXIT=0`
  - `./node_modules/.bin/vitest run` → `Test Files 8 passed (8), Tests 34 passed (34), VITEST_EXIT=0`
- **Open issues:** Critical F1, High F2/F3, Medium F4/F5 (see §7).

---

## 3. Code Quality — Code Reviewer (`engineering-code-reviewer`)

| Severity | File:Line | Finding | Suggested Fix |
|----------|-----------|---------|---------------|
| Critical | process-webhook-use-case.ts:26 | `isValid(dto.event.transactionId, …)` passes transactionId as the `concatenated` param; contract needs the 20-field HMAC string → every valid signature rejected, authenticity check meaningless (CWE-345, OWASP A02) | Pass the route-built concatenated string (add `concatenated` to DTO; route builds via `buildPaymobHmacString(obj)` as index.ts:84) |
| Medium | process-webhook-use-case.test.ts:47 | `isValid` mock always true, no argument assertions → the Critical F1 bug is not caught by tests | Assert `isValid` called with expected concatenated string as first arg |
| Low | issue-license-use-case.ts:27 | bare `catch {}` swallows signing error, no logging (CWE-221) | Log error before returning `SIGNING_FAILED` |
| Low | issue-license-dto.ts:12 | `privateKeyB64` documented base64url but never validated; malformed key fails only at signing time | Validate base64url format + 32-byte length at DTO/use-case entry |
| Low | process-webhook-use-case.ts:35-44 | `webhookEventRepo.insert` called without validating required fields (transactionId, tenantId, …) non-empty | Add guard clauses rejecting empty `transactionId`/`tenantId` before insert |
| Info | process-webhook-dto.ts:6-15 | DTO doc says route verifies HMAC before constructing DTO, but use case re-verifies; `signatureHex`/`hmacSecret` carried redundantly → contradictory security-boundary ownership | Clarify ownership: verify HMAC at exactly one layer; drop redundant field(s) |
| Low | issue-license-use-case.test.ts:41 | `makePayload().tenantId ? makePayload() : makePayload()` tautology; never verifies actual payload/key args passed to `signLicenseKey` | Assert against the actual payload captured from `makeDto()` |

Sub-agent summary: [Critical] 1, [High] 0, [Medium] 1, [Low] 4, [Info] 1

---

## 4. Security Audit — AppSec (`security-appsec-engineer`)

**Threat model scope (in scope):** webhook HMAC authn gate, Ed25519 license signing/issuance (entitlement), idempotency/replay, secret handling (hmacSecret, privateKeyB64 via DTOs), PII (tenantId, deviceHwid), error handling (bare catch). Out of scope: unchanged route layer `index.ts` and shared crypto libs.

| Severity | File:Line | Finding | Suggested Fix |
|----------|-----------|---------|---------------|
| Critical | process-webhook-use-case.ts:26 | HMAC-SHA512 computed over `transactionId` instead of the 20-field concatenated string → attacker can forge `signatureHex = HMAC-SHA512(secret, transactionId)` and the gate passes though Paymob signed the full string = complete authentication bypass (CWE-345, OWASP A01). Repro: POST webhook with `signatureHex` = HMAC(secret, `txn_123`); `isValid` returns true. | Do not recompute HMAC input in the use case; pass route-layer-built concatenated string into DTO/use case (add `concatenated` field, validate non-empty) |
| High | issue-license-use-case.ts:27 | bare `catch` swallows every signing failure (invalid key material, algorithm errors, revocation, transient crypto errors) with no logging/metric/differentiation → masks signing-oracle probing and key-compromise indicators; caller cannot distinguish permanent vs transient (CWE-754, OWASP A09). Repro: malformed `privateKeyB64` → silently `SIGNING_FAILED`. | Catch specific error types only; log error class server-side; return distinct codes (`KEY_INVALID` vs `SIGNING_TRANSIENT`) |
| High | process-webhook-dto.ts:15, issue-license-dto.ts:12 | `hmacSecret` and `privateKeyB64` are plaintext fields in application-layer DTOs crossing trust boundaries → leak if DTOs serialized into logs/error responses/debug endpoints (CWE-312, OWASP A07) | Secrets must not be DTO fields; resolve HMAC secret + Ed25519 private key from Env/secrets manager at infrastructure/route layer (as index.ts:62-69 does) and inject service instances, not raw keys |
| High | process-webhook-use-case.ts:50-54 | Use case returns `ok:true` with payload/decision for all events incl. `success===false`, `isRefunded===true`, `isVoided===true` → no entitlement gate, licenses issuable for failed/refunded/voided payments (index.ts gates at :94 but that's not defense-in-depth) (CWE-287, OWASP A01). Repro: `execute` with `event.success=false` → `ok:true` + payload that downstream can sign into a license. | Return `{ok:false, error:'INVALID_EVENT'}` before payload computation when `!success || isRefunded || isVoided`; gate issuance on `decision.issue` |
| Medium | process-webhook-use-case.ts:26 | `transactionId` and PII (`tenantId`, `deviceHwid`) accepted unvalidated: no length/format check; empty/oversized values flow into repository and PostHog analytics (CWE-20, OWASP A04). Repro: `transactionId=''` or 10 KB `tenantId`; accepted, inserted, logged. | Validate field formats/lengths at DTO construction (Zod schema); reject empty `transactionId`, bound `tenantId`/`deviceHwid` |
| Medium | process-webhook-use-case.ts:35-47 | Idempotency `insert` not atomic with payload computation/issuance; TOCTOU replay window; no visible unique constraint/transaction (CWE-367, OWASP A04). Repro: two simultaneous valid-HMAC callbacks same `transactionId`; both may insert before uniqueness enforces. | Enforce unique constraint on `transactionId`; wrap HMAC-check + insert + issuance atomically; return `DUPLICATE_EVENT` on constraint violation |
| Low | process-webhook-use-case.ts | No rate limiting/throttling per tenant or transaction → valid-HMAC callback flood causes DoS via repo writes, license computation, PostHog calls (CWE-770, OWASP A04) | Add per-tenant/per-transaction rate limiting before processing (edge/route concern) |
| Info | issue-license-use-case.test.ts:41 | Test assertion tautology; never verifies actual payload/key args passed to `signLicenseKey` — weak regression coverage for signing-input integrity | Assert `signLicenseKey` called with exact `makePayload()` and `'private-key-base64'` |
| Info | process-webhook-use-case.ts | `ProcessWebhookResponse` error union lacks generic/`UNKNOWN` error; unexpected failures (repo throw, `computePayload` throw) propagate as unhandled exceptions → 500s / stack-trace exposure (CWE-755, OWASP A09). Repro: `webhookEventRepo.insert` throws → unhandled 500. | Wrap body in try/catch mapping unexpected errors to `PROCESSING_FAILED` with server-side logging |

Sub-agent summary: Critical=1, High=3, Medium=3, Low=1, Info=2

---

## 5. Branch Status

- **Commits ahead of base (development):** 1 (`8b5d1b3`)
- **Working tree:** clean for this branch (8 files committed in `8b5d1b3`); unrelated untracked files pre-exist from prior sessions (`QA_REPORT_*.md`, `backend/api/.vitest/`, `backend/realtime/qa/`) — not part of this branch, not touched
- **CI:** workflows present (`ci.yml` runs format/lint/analyze/test on all branches + PRs per AGENTS §9); no PR opened yet → no CI status; CI must run on push/PR before merge
- **Merge conflicts:** none (single clean commit atop development)
- **Uncommitted changes:** none belonging to this branch
- **Cleanup needed:** none for this branch (never delete branch per AGENTS §3)

---

## 6. Handoff Summary

- **User-facing change:** Phase 2 adds the application-layer use cases `ProcessWebhookUseCase` and `IssueLicenseUseCase` plus their DTOs for the Paymob webhook → Ed25519 license-issuance flow (Phase 1 domain layer already merged). Route-layer wiring (`index.ts`) is Phase 3, pending.
- **How to use:** Route extracts Paymob callback (query `hmac`, body `obj`), builds `concatenated = buildPaymobHmacString(obj)`, verifies HMAC, constructs DTOs, calls `ProcessWebhookUseCase.execute` (returns `payload` + `decision`), then `IssueLicenseUseCase.execute` to sign when `decision.issue`.
- **Rollback plan:** Branch not merged → do not merge / revert commit `8b5d1b3`. Branch retained intact (never deleted, per AGENTS §3).
- **Follow-ups:** Fix F1–F5 (§7), wire route to use cases, open PR into `development`, run CI, sync specs via `filling-gaps`, Plane work item → Done.

---

---

## 7. Proposed Fix Plan + Decision Matrix

| # | Severity | Fix target (file:line) | Diff sketch | Risk-of-fix | Needs test | Recommended action | Owner |
|---|----------|------------------------|-------------|-------------|------------|--------------------|-------|
| 1 | Critical | process-webhook-use-case.ts:25-29 | Replace `dto.event.transactionId` first arg with a `concatenated` HMAC string carried in the DTO (built by route via `buildPaymobHmacString(obj)` as index.ts:84), or remove HMAC re-verification from the use case | Low | Y | **apply** | feature author |
| 2 | High | process-webhook-use-case.ts:50-54 | Add `if (!dto.event.success || dto.event.isRefunded || dto.event.isVoided) return {ok:false, error:'INVALID_EVENT'}` before payload computation; gate issuance on `decision.issue` | Low | Y | **apply** | feature author |
| 3 | High | issue-license-use-case.ts:27 | Replace bare `catch` with typed catch; log server-side; return distinct codes (`KEY_INVALID` vs `SIGNING_TRANSIENT`) | Low | Y | **apply** | feature author |
| 4 | Medium | process-webhook-use-case.ts:35-47 | Enforce unique constraint on `transactionId`; wrap HMAC+insert+issuance atomically; `DUPLICATE_EVENT` on violation | Med | Y | **apply** | feature author + backend |
| 5 | Medium | process-webhook-use-case.ts:26 + DTO | Validate field formats/lengths at DTO construction; reject empty `transactionId`/`tenantId` | Low | Y | **apply** | feature author |
| 6 | Low | issue-license-dto.ts:12; process-webhook-dto.ts:15 | Remove `hmacSecret`/`privateKeyB64` from DTOs; resolve secrets at infrastructure/route layer; inject services not raw keys | Med | N | **defer** (discuss) | feature author |
| 7 | Low | issue-license-use-case.test.ts:41 | Assert `signLicenseKey` called with exact payload + `'private-key-base64'` | Low | Y | **apply** | feature author |
| 8 | Low | process-webhook-use-case.test.ts:47 | Assert `isValid` called with expected concatenated string as first arg | Low | Y | **apply** | feature author |
| 9 | Info | process-webhook-use-case.ts | Wrap body in try/catch mapping unexpected errors to `PROCESSING_FAILED` with server-side logging | Low | Y | **apply** | feature author |
| 10 | Info | process-webhook-dto.ts:6-15 | Clarify HMAC ownership; drop redundant `signatureHex`/`hmacSecret` fields | Low | N | **discuss** | feature author |

Score = 100 − 25×C − 10×H − 5×M − 1×L = 100 − 25(1) − 10(2) − 5(2) − 1×6 = **39** (must be strictly > 90). Zero Critical/High/Medium required for merge; currently C=1 H=2 M=2 → BLOCKED.

**Awaiting approval.** Reply with one of:
- `apply all` — execute every `apply` row
- `apply #1, #2, #3` — execute specific rows
- `defer #6` — leave specific rows
- `reject #10` — drop specific rows
- `proceed as-is` — merge without fixes (logged as explicit risk acceptance)

---

## 8. Prioritized Action Items

1. **[Critical]** Fix HMAC input mismatch in process-webhook-use-case.ts:26 — pass route-built concatenated string, not transactionId — blocks merge
2. **[High]** Add entitlement gate (reject success=false/refunded/voided) in process-webhook-use-case.ts:50-54 — blocks merge
3. **[High]** Replace bare `catch` in issue-license-use-case.ts:27 with typed error handling + logging — blocks merge
4. **[Medium]** Atomic idempotency with unique constraint on transactionId — should fix before merge
5. **[Medium]** Validate required PII fields non-empty before repo insert — should fix before merge
6. **[Low]** Validate privateKeyB64 base64url format + length at DTO entry — nice to have
7. **[Low]** Fix test tautologies (issue-license-use-case.test.ts:41; process-webhook-use-case.test.ts:47) — nice to have
8. **[Info]** wrap unexpected errors in PROCESSING_FAILED — nice to have
9. **[Info]** clarify HMAC ownership / drop redundant DTO fields — FYI, discuss

---

## 9. Appendix

**Tools / agents / skills / CLIs / MCP endpoints invoked (review phase, all read-only unless noted):**
- `git` (status, log, diff, rev-list, rev-parse, branch, worktree list) — read-only — change set + branch discovery
- `read` / `glob` / `grep` — read-only — inspect changed files + shared domain contracts + specs + CI configs
- `./node_modules/.bin/tsc --noEmit` — read-only (typecheck, no emit) — TSC_EXIT=0
- `./node_modules/.bin/vitest run` — read-only (test run, no state mutation) — 8 files / 34 tests pass
- `subagent: engineering-code-reviewer` — read-only — primary code-review findings (§3)
- `subagent: security-appsec-engineer` — read-only — primary security findings (§4)
- `skill: verification-before-completion` — observational — evidence-before-claims discipline
- `skill: finishing-a-development-branch` — observational — branch/merge readiness framing
- `skill: feature-summary` — observational — handoff summary framing
- `write` — mutating — created QA_REPORT_refactor-paymob-webhook-use-cases.md (this report artifact; NOT source code)

**Commands run:**
- `git rev-parse --show-toplevel`, `--abbrev-ref HEAD`; `git status --porcelain`; `git worktree list`; `git symbolic-ref refs/remotes/origin/HEAD`; `git config --get remote.origin.url`
- `git diff --name-status development...HEAD`; `git diff --stat development...HEAD`
- `git rev-list --count development..HEAD`
- `ls .github/workflows/`
- `./node_modules/.bin/tsc --noEmit` (TSC_EXIT=0)
- `./node_modules/.bin/vitest run` (VITEST_EXIT=0; Test Files 8 passed, Tests 34 passed)

**Sub-agents dispatched:** engineering-code-reviewer (findings §3), security-appsec-engineer (findings §4). Both read-only, return-findings-only. No Spec Compliance or Test Coverage sub-agents dispatched (not requested via scope flag; coverage assessed directly from test files: zero gaps in changed units).

**Skills loaded:** verification-before-completion, finishing-a-development-branch, feature-summary (all observational, read-only).

**Raw findings JSON:** (summarized in §3/§4 tables; full sub-agent output retained in subagent sessions ses_e99a90dbcffeuYlq3iEskXPBsv and ses_e99a90dbaffeHkgQ5eUmx0Y4tR)

**User's approval / override:** (pending — awaiting reply)

---

**HALT.** This is the Review Report (Phase 5). No code has been modified. Awaiting your explicit per-row decision before any fixes are applied.
