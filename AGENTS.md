# Daftari — Agent Operating Contract

This file is the per-project `AGENTS.md`. It **tightens** the global
`~/.config/opencode/AGENTS.md` — it never loosens it. Where this file and the
global contract disagree, the stricter rule applies.

---

## 1. Project Identity

- **Name:** Daftari (formerly "Cashier System") — official product name.
- **Root:** `/mnt/ALL/Daftari` (master base checkout)
- **Worktree pool:** `/mnt/ALL/Flutter Projects/Worktrees/daftari_worktrees/`
- **Integration branch:** `development` · **Release branch:** `master`
- **Plane project:** `DAFTARI`

---

## 2. Stack (Locked)

| Layer | Tech | Location |
|-------|------|----------|
| Flutter Desktop/Mobile | Dart / Flutter stable | `apps/daftari/` |
| Flutter Web (app + admin) | Dart / Flutter stable | `apps/daftari/web/` |
| Landing page (Jaspr) | Dart | `landing_page/` |
| Backend API | TypeScript (Hono, Cloudflare Workers) | `backend/api/` |
| Admin host | TypeScript | `backend/admin_host/` |
| PayMob webhook | TypeScript | `backend/paymob_webhook/` |
| Realtime | TypeScript | `backend/realtime/` |
| Shared backend | TypeScript (Turso/libSQL, cache, repos) | `backend/shared/` |
| Print server | C# .NET 8 | `PrintServer/`, `PrintServer.Linux/`, `PrintServer.Linux.Tests/`, `PrintServer.Tests/` |

**No other languages/runtimes.** Do not introduce Go, Rust, Python, etc.

---

## 3. Monorepo: Melos (Enforced)

- Config: `melos.yaml` at repo root. Root `pubspec.yaml` carries the `melos`
  dev dependency only — it is **not** a Dart pub workspace.
- **Melos manages Dart/Flutter packages only**: `apps/daftari`, `landing_page`.
  TypeScript and C# are orchestrated by CI and the commands below; Melos has no
  concept of non-Dart packages.
- **Package mode is deliberate.** A Dart pub workspace is impossible while
  `hive_generator ^2.0.1` (needs `source_gen ^1.0.0`) and `jaspr_builder`
  (needs `source_gen ^4.0.0`) coexist. Do not add `workspace:`/`resolution:
  workspace` keys.

```bash
melos bootstrap     # flutter pub get for every Dart package
melos run analyze   # format check + analyze (flutter analyze / dart analyze)
melos run test      # flutter test / dart test
melos run format    # dart format
melos run build     # flutter build apk --debug (Flutter packages)
```

Non-Dart gates (run from repo root):

```bash
for d in shared api realtime admin_host paymob_webhook; do
  ( cd "backend/$d" && npm ci --include=dev && npm test && npm run typecheck )
done
dotnet build PrintServer.Linux/PrintServer.Linux.csproj -c Release
dotnet test PrintServer.Tests/PrintServer.Tests.csproj -c Release
```

---

## 4. Verification Gates (Non-Negotiable)

### FAST gate — before EVERY commit

1. `dart format --set-exit-if-changed lib test` (per Dart package)
2. `flutter analyze` / `dart analyze` — exit 0 (infos are failures for the app)
3. `npm test` + `npm run typecheck` for every touched TS package
4. `dotnet build --no-restore` for every touched C# project
5. No `print` / `debugPrint` outside tests in the staged diff
6. No secrets, keys, or tokens in the staged diff

### FULL gate — before EVERY PR handoff

1. Branch synced from `origin/development` (merge, not rebase)
2. FAST gate green
3. `melos run test` — all pass, zero undocumented skips
4. Backend `npm test` + `npm run typecheck` — all pass
5. `dotnet test` — all pass
6. `flutter build apk --debug` (or web/linux per change) — compile proof
7. Scope audit: `git diff origin/development...HEAD --stat` touches only the
   branch's declared domains

---

## 5. Specs Compliance

`specs/` (`PRD.md`, `ARCHITECTURE.md`, `DESIGN.md`, `USER_FLOW.md`,
`DEVELOPMENT_ENVIRONMENT.md`) is the source of truth. No out-of-spec features.
Ambiguity → ask the user, never guess.

---

## 6. Review & Quality Gates

**Gate 0 (per commit):** FAST gate + targeted tests of touched units.
Evidence before claims (`verification-before-completion`).

**Gate 1 (pre-merge):** `feature-summary` + `qa-post-implementation` +
`test-coverage-analysis` on the current HEAD. Zero Critical/High/Medium,
score **strictly > 90**, zero coverage gaps. PR body updated with final scores
and deferred Low/Info notes. **HALT** for user approval.

**Gate 2 (post-merge):** re-verify merged `development`, sync specs, keep the
branch intact, clean the worktree, move the Plane item to Done.

### Definition of Done (per phase/feature)

- [ ] Working tree clean; branch pushed; up to date with `origin/development`
- [ ] FULL gate green
- [ ] CI checks green on the PR
- [ ] Scope audit clean
- [ ] `implement-review-ship` loop complete (zero C/H/M, score > 90, zero gaps)
- [ ] Specs synced (`filling-gaps`)
- [ ] No secrets, debug prints, or new TODO/FIXME in the diff
- [ ] PR open into `development` with a complete body
- [ ] Gate 1 approved by the user
- [ ] **User merged manually** (the agent never merges)
- [ ] Gate 2 complete; Plane work item → Done

---

## 7. CI/CD

- `.github/workflows/ci.yml` runs on **all branches and PRs**: format, analyze,
  tests, builds, backend matrix, PrintServer, packaging, security scan.
- CD pipelines (`cd-development.yml`, `cd-staging.yml`, `cd-production.yml`,
  `release.yml`, `deploy-cloud.yml`) — **only `master` deploys to production**.
- Every Flutter step declares `working-directory: apps/daftari`; the landing
  page step uses `working-directory: landing_page`.
- PR checks must be green before Gate 1 handoff.

---

## 8. Commit Protocol

- **Every** commit goes through the `emoji-commit` skill — no manual commits.
- Stage by explicit path only. `git add -A` and `git add .` are **forbidden**.
- Review `git diff --staged` for secrets, debug prints, and scope leakage.
- A commit is a coherent unit that passes the FAST gate.
- Never commit `build/`, `.dart_tool/`, `node_modules/`, `bin/`, `obj/`,
  `*.log`, `.DS_Store`, or Hive test boxes (`**/test/_hive_test*/`).
- Generated code (`.g.dart`, `.freezed.dart`) ships only alongside its source
  change, after `dart run build_runner build`.

---

## 9. Scope & Diff Discipline

- The task's verbs define scope. "Fix" means fix — not improve.
- No "while I'm here" changes, no opportunistic refactors.
- Out-of-scope findings → `docs/followups.md` **and** a Plane work item.
  Never fixed inside the current branch.

---

## 10. Plane Tracking (Mandatory)

- Project identifier: `DAFTARI`
- Every follow-up, bug, or debt item becomes a Plane work item with a priority
  and label derived from the task (never a default).
- Lifecycle: `Backlog → Todo → Planning → In Progress → Review → Done`.
- Never mark Done before the user merges and Gate 2 evidence exists.
- Never delete work items.

```bash
planecli work-item create "Short imperative title" \
  --project DAFTARI --state "Backlog" --priority medium \
  --labels feature --description "Context: branch, file path, line"
```

---

## 11. Skill Routing

| Situation | Skill |
|-----------|-------|
| Every commit | `emoji-commit` |
| Any implementation task | `implement-review-ship` (mandatory) |
| Phase/feature complete | `implement-review-ship` → `filling-gaps` → Gate 1 |
| Merge into `development`/`master` | `merge-message` draft only; the user merges |
| Bug found | `systematic-debugging` |
| Claiming done | `verification-before-completion` |
| New feature/bugfix logic | `test-driven-development` |
| Commit/branch review | `commit-review` (supplementary) |
| Future work found | `planecli work-item create` |
| Work done / state change | `planecli work-item update --state` |

---

## 12. Communication Mode

- **Caveman mode is the startup default** (global §12) unless the user says
  "stop caveman" or "normal mode".
- Caveman applies to chat only. Code, commits, PR bodies, security findings, and
  destructive confirmations use normal clarity.

---

## 13. Path Quoting (Mandatory)

`/mnt/ALL/Flutter Projects/` contains spaces. **Quote every path** in shell
commands.

```bash
# Correct
cd "/mnt/ALL/Flutter Projects/Worktrees/daftari_worktrees/feat-migrate-to-melos"

# Wrong
cd /mnt/ALL/Flutter Projects/Worktrees/daftari_worktrees/feat-migrate-to-melos
```
