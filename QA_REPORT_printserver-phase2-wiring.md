# QA Post-Implementation Report

**Feature:** PrintServer.Linux stale-instance cleanup fix (`ps -o comm=` → `ps -o args=`) + tests for `--parent-pid` spawn and `exeCandidatesLinux()`
**Branch:** feat/printserver-phase2-wiring ← origin/development
**Date:** 2026-10-30
**Status:** ❌ BLOCKED
**Risk Level:** Medium
**Phase:** Review (awaiting approval) — HALT, no fixes applied
**Scope invoked:** full (Code Reviewer + Security sub-agents required; NOT dispatched — see Appendix)

---

## 0. Project Context

- **Project root:** /mnt/ALL/Daftari (master base checkout; `.git` is a directory)
- **Repo:** https://github.com/OmarAdel10/daftari.git
- **Branch:** feat/printserver-phase2-wiring ← origin/development
- **Stack:** Flutter/Dart (SDK ^3.13.0); test runner `flutter_test`/`flutter test`; linter `flutter analyze` (analysis_options.yaml, extends flutter_lints/flutter.yaml); formatter `dart format`
- **Monorepo:** no (single pubspec.yaml; `backend/` is a sibling Node folder, not a workspace)
- **Intent docs found:** specs/PRD.md, specs/ARCHITECTURE.md, specs/DESIGN.md, specs/USER_FLOW.md, specs/DEVELOPMENT_ENVIRONMENT.md, specs/PERFORMANCE_GUIDELINES.md
- **CI:** GitHub Actions (`.github/workflows/ci.yml`, `printserver-ci.yml`, `cd-development.yml`, `cd-staging.yml`, `cd-production.yml`, `deploy-cloud.yml`); live status not checked (no PR URL; `gh pr checks` not run — read-only GET would be allowed but no PR exists yet)
- **Change set:** M=2 A=0 R=0 D=0 ??=6 (total 8 entries). Feature files = the 2 modified below. Untracked entries are pre-existing QA_REPORT artifacts + backend dirs, NOT part of this feature.
  - M lib/core/printing/print_server_manager_linux.dart
  - M test/linux/print_server_manager_linux_test.dart
- **Sensitive surface area:** local process execution (`Process.run` with `ps`/`ss`/`kill`), loopback network port 5150 (`127.0.0.1:5150`), filesystem (candidate exe paths, `Directory.systemTemp` in tests), PID-based process identification/kill
- **Security role selected:** security-architect (system design / threat model) — NOT dispatched (see §3/§4)

---

## 1. Executive Summary

One commit (`5a50253 🐛 fix(printserver): fix stale-instance ps comm bug`) on `feat/printserver-phase2-wiring`, 1 commit ahead of `origin/development`. The fix changes `_isPrintServerProcess` to read `ps -o args=` (full command line) instead of `ps -o comm=` so `PrintServer.Linux` (17 chars) is no longer truncated to `PrintServer.Li` (15-char Linux `comm` limit), allowing stale port-5150 instances to be identified and killed. Two tests were added (`--parent-pid` spawn, `exeCandidatesLinux()` AppImage/RPM paths). The change is small and matches the spec (PRD.md §J3, specs/DEVELOPMENT_ENVIRONMENT.md §5f). **However, the required independent Code Reviewer and Security sub-agents could not be dispatched (subagent depth limit = 1; I am already a nested subagent), so no independent severity findings exist.** Per contract, status is BLOCKED pending independent review; no code has been modified or executed by this QA run.

---

## 2. Verification

- **Acceptance criteria:** Partial — the code change and tests match the described fix and spec intent, but dynamic behavior has not been observed (review-gate blocks test execution until approval).
- **End-to-end behavior:** Not dynamically verified. Static read-only inspection of the diff, full source file, full test file, and specs only. No `flutter test` / `flutter analyze` / `dart format` executed (mutating/execution blocked pre-approval).
- **Tests:** 0 run / 0 failed / 0 skipped. Two new tests added in the diff; existing suite not executed.
- **Evidence:** `git diff origin/development...HEAD` (full diff quoted in §7 sketches); full file reads of `lib/core/printing/print_server_manager_linux.dart` (379 lines) and `test/linux/print_server_manager_linux_test.dart` (200 lines); spec greps for PrintServer (PRD, ARCHITECTURE, DESIGN, DEVELOPMENT_ENVIRONMENT).
- **Open issues:**
  1. Independent Code Reviewer + Security sub-agents not dispatched (depth limit).
  2. `flutter analyze` / `dart format --set-exit-if-changed` / `flutter test` not executed (gated).
  3. `test/` is excluded from `flutter analyze` per analysis_options.yaml line 45 (`- test/**`); the new test file is covered by `flutter test` only.

---

## 3. Code Quality (Code Reviewer) — NOT RUN

**Sub-agent:** `engineering-code-reviewer` — could not be dispatched (subagent depth limit reached: host returned `Subagent depth limit reached (1)`; nested subagents disabled at depth 1). Section marked not run per contract. No independent Code Reviewer findings exist.

**Corroborating read-only observations (QA agent, not a substitute for review):**
- `_isPrintServerProcess` at lib/core/printing/print_server_manager_linux.dart:351-355 now uses `ps -p $processPid -o args=` and `args.contains('PrintServer.Linux')`. This correctly avoids the 15-char `comm` truncation described in the added doc comment (lines 348-350).
- `_killStaleInstance` (lines 302-345) calls `_isPrintServerProcess` per port-5150 PID and kills with `kill -TERM` then `kill -KILL`; the fix makes the identification step actually match.
- `_spawn` (lines 203-259) passes `--parent-pid $pid` (line 214) and uses `runInShell: false` (line 222/228) — no shell-injection vector from user input; `$pid` is Dart's own PID.
- `exeCandidatesLinux()` (lines 144-199) resolves side-by-side, `/opt/...`, AppImage, and build-bundle candidates — matches spec §5f / DESIGN.md line 424.
- `analysis_options.yaml` excludes `test/**`, `build/**`, `linux/**`, `windows/**` from analyzer; `test/` is lint-free by config but still run by `flutter_test`.
- No `print(`/`debugPrint(` outside tests in the staged diff (source uses `log(` from dart:developer). No secrets/keys in the diff.

*(These are factual observations, not severity-tagged review findings. Independent Code Reviewer must produce the real table.)*

---

## 4. Security (security-architect) — NOT RUN

**Sub-agent:** `security-architect` — could not be dispatched (subagent depth limit reached). Section marked not run per contract. No independent security findings exist.

**Corroborating read-only observations (QA agent, not a substitute for review):**
- **Threat-model scope:** In-scope: local process identification/kill, loopback port 5150, candidate exe resolution, test temp dir. Out-of-scope: remote auth, crypto, payments, PII (this is an experimental/development-only Linux sidecar per specs).
- **Attack surface touched:** `Process.run('ps', ...)` / `Process.run('ss', ...)` / `Process.run('kill', ...)`; `Process.start(absoluteExePath, args)` with `runInShell: false`; `File(candidate).existsSync()` over `exeCandidatesLinux()`; `Directory.systemTemp.createTempSync` in tests.
- **Notable:** `ps -o args=` exposes full command lines of other processes — standard on Linux, no new secret leakage introduced by this change (it only *reads* and matches a known binary name). `chmod +x` on the candidate exe (line 211) requires the binary to be present/writable; no path-injection from user-controlled input in the spawn path.
- **Compliance:** Linux PrintServer is explicitly "Experimental / Development Only" (specs/ARCHITECTURE.md line 1059, DEVELOPMENT_ENVIRONMENT.md line 214); no production compliance (SOC2/HIPAA/PII) claim applies.

*(Independent Security sub-agent must produce the real STRIDE table.)*

---

## 5. Branch Status

- **Commits ahead of base:** 1 (`5a50253`, message: "🐛 fix(printserver): fix stale-instance ps comm bug")
- **CI status:** not checked (no PR opened; workflows present)
- **Merge conflicts:** none (single commit cleanly ahead of origin/development; merge-base 091635d)
- **Uncommitted changes:** none in tracked files. 6 untracked entries on disk (4 QA_REPORT_*.md artifacts + `backend/api/.vitest/` + `backend/realtime/qa/`) — pre-existing, not part of the feature diff, not staged.
- **Cleanup needed:** none for the feature branch. Untracked QA_REPORT files are leftover artifacts from prior QA runs; not this feature's responsibility.

---

## 6. Handoff Summary

- **User-facing change:** On Linux, stale PrintServer.Linux instances holding port 5150 are now correctly detected and killed at startup (was broken because `ps -o comm=` truncated `PrintServer.Linux` → `PrintServer.Li`), so the sidecar starts reliably instead of failing/leaving zombies.
- **How to use:** `PrintServerManagerLinux.start()` is invoked by `PrintServerFactory` on Linux (specs/ARCHITECTURE.md §print-server). It probes `exeCandidatesLinux()`, spawns with `--parent-pid`, adopts healthy existing instances, validates API version ≥ 4, then cleans stale port-5150 processes.
- **Rollback plan:** Revert commit `5a50253` (restores `ps -o comm=`); stale instances would again go undetected — only roll back if the `args=` regression appears on a specific kernel/ps variant.
- **Follow-ups:** dispatch independent Code Reviewer + Security sub-agents; execute `flutter analyze` + `dart format` + `flutter test` post-approval; confirm `test/` exclusion from analyzer is intentional.

---

## 7. Proposed Fix Plan + Decision Matrix

No independent Code Reviewer / Security findings exist (sub-agents not dispatched). The rows below are the QA agent's **observational plan items** (factual, not severity-tagged findings), each requiring user approval before any execution. The actual code fix is already committed; nothing is pending to *apply* in the code itself.

| # | Severity | Fix target (file:line) | Diff sketch | Risk-of-fix | Needs test | Recommended action | Owner |
|---|----------|------------------------|-------------|-------------|------------|--------------------|-------|
| 1 | Medium | lib/core/printing/print_server_manager_linux.dart:351-355 | Already applied: `comm=` → `args=`; `comm` var → `args`; `comm.contains(...)` → `args.contains('PrintServer.Linux')` | Low | Y (new test) | **discuss** (already merged into branch; confirm via flutter test) | QA/dev |
| 2 | Medium | test/linux/print_server_manager_linux_test.dart:92-148 | Already applied: added `_spawn passes --parent-pid...` test + `exeCandidatesLinux includes AppImage and RPM paths` test + `FakeProcess`/`_FakeIOSink` | Low | N (it is the test) | **discuss** (confirm passes via flutter test) | QA/dev |
| 3 | Critical | (none — process gap) | Dispatch independent Code Reviewer (`engineering-code-reviewer`) and Security (`security-architect`) sub-agents on this diff; depth limit must be raised or dispatch at depth 0 | Low | N | **discuss** (required before merge sign-off; status BLOCKED until done) | orchestrator |

**Awaiting approval.** No code mutation will occur until you reply. Reply with one of:
- `apply all` — execute every `apply` row (none currently `apply`; all are `discuss`)
- `apply #N` — execute specific rows
- `defer #N` — leave specific rows
- `reject #N` — drop specific rows
- `proceed as-is` — merge without fixes (logged as explicit risk acceptance; note sub-agents still not run)

---

## 8. Prioritized Action Items

1. **[High]** Dispatch independent Code Reviewer + Security sub-agents for `git diff origin/development...HEAD` (required; currently blocked by subagent depth limit) — blocks merge sign-off.
2. **[Medium]** Post-approval: run `dart format --set-exit-if-changed lib test`, `flutter analyze` (note `test/` excluded by analysis_options.yaml), and `flutter test test/linux/print_server_manager_linux_test.dart`; confirm 0 failures, 0 undocumented skips.
3. **[Medium]** Confirm independent reviewers produce severity-tagged file:line findings; fold into this report and re-evaluate Status.
4. **[Info]** Untracked QA_REPORT_*.md artifacts + backend dirs present on disk — not part of feature; no action required.

---

## 9. Appendix

**Tools / agents / skills / CLIs / MCP endpoints invoked (classification | phase | reason):**

| Capability | Class | Phase | Reason |
|------------|-------|-------|--------|
| `pwd`, `git rev-parse --show-toplevel/--abbrev-ref HEAD`, `git config --get remote.origin.url` | read-only | review (P0) | project root, branch, remote |
| `git status --porcelain`, `git worktree list` | read-only | review (P0) | change set, checkout type |
| `git diff --name-status/--stat origin/development...HEAD` | read-only | review (P0) | feature change set (M=2) |
| `git branch -a / -r`, `git symbolic-ref refs/remotes/origin/HEAD` | read-only | review (P0) | base branch = origin/development |
| `git rev-list --count origin/development..HEAD`, `git log --oneline origin/development..HEAD`, `git merge-base origin/development HEAD` | read-only | review (P5) | commits ahead of base (1) |
| `read pubspec.yaml`, `analysis_options.yaml` | read-only | review (P0/P1) | stack, lint/test tooling |
| `read lib/core/printing/print_server_manager_linux.dart`, `test/linux/print_server_manager_linux_test.dart` | read-only | review (P2/P4) | corroborating reads of full source + test |
| `ls .github/`, `.github/workflows/` | read-only | review (P0) | CI config inventory |
| `grep specs/` for PrintServer | read-only | review (P1/P4) | spec compliance context |
| `skill qa-post-implementation` | read-only (observational) | review (P2) | loaded skill contract/instructions only |
| `subagent engineering-code-reviewer` | mutating-capable (dispatched read-only prompt) | review (P3) | **FAILED** — subagent depth limit reached (1); not run |
| `subagent security-architect` | mutating-capable (dispatched read-only prompt) | review (P3) | **FAILED** — subagent depth limit reached (1); not run |

**Commands run (full text):**
- `pwd && git rev-parse --show-toplevel && git rev-parse --abbrev-ref HEAD && git config --get remote.origin.url && git symbolic-ref refs/remotes/origin/HEAD`
- `git status --porcelain && git worktree list`
- `git diff --name-status origin/development...HEAD` and `git diff --stat origin/development...HEAD`
- `git diff origin/development...HEAD` (full diff — quoted in §7)
- `git branch -a; git branch -r`
- `git rev-list --count origin/development..HEAD; git log --oneline origin/development..HEAD; git merge-base origin/development HEAD`
- `ls -la .github/; ls -la .github/workflows/`
- `grep -R PrintServer specs/`

**Sub-agents dispatched:** `engineering-code-reviewer` and `security-architect` — both FAILED to dispatch (subagent depth limit reached = 1). Marked "not run" in §3 and §4. Per contract this downgrades overall Status to ❌ BLOCKED (required agents missing).

**Skills loaded:** `qa-post-implementation` (observational only; no action-taking flags used).

**Raw findings JSON:** none — no sub-agent findings were produced (dispatch failed).

**User's approval / override:** Pending. Awaiting explicit reply (`apply all` / `apply #N` / `defer #N` / `reject #N` / `proceed as-is`). No approval has been given; no code has been mutated by this QA run.
