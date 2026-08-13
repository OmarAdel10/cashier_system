# Global Development Environment & Branch Architecture Workspace

This file is the global operating contract for all agent work. Per-project
AGENTS.md / GEMINI.md / CLAUDE.md files may tighten these rules per stack,
but never loosen them. Where a per-project file conflicts with this file,
this file wins unless the user explicitly says otherwise.

---

## 1. Repository Core Path Infrastructure

- **Master Base Directory:** `/mnt/ALL/Flutter Projects/{project name}` — the canonical clone. Houses `development` and feature branches checked out directly (e.g. `feature/{feature name}`).
- **Worktree Target Matrix:** `/mnt/ALL/Flutter Projects/Worktrees/{project_name}_worktrees/{feat-{name}}/` — optional isolation pool for high-conflict parallel work. One directory per feature branch.
- **MANDATORY path quoting:** `/mnt/ALL/Flutter Projects/` contains spaces. Every shell command referencing it MUST quote the path. Never run unquoted.
- **Deprecated (do not create new work here):** `{project}.worktrees/` inside a master base, and any stray worktree directories outside the matrix. New work goes only into `Worktrees/{project_name}_worktrees/`.

## 2. Directory Identity Check (MANDATORY before any edit or command)

Before touching any file or running any git/flutter command, run:

```bash
pwd
git rev-parse --show-toplevel   # root of THIS checkout
git rev-parse --abbrev-ref HEAD # current branch
git status --porcelain          # must be clean or intentionally dirty
git worktree list               # all checkouts of this repo
```

Then classify where you are:

- `.git` is a **directory** → master base checkout.
- `.git` is a **file** (contains `gitdir:`) → worktree checkout; branch pinned per `git worktree list`.
- Path contains `/Worktrees/{project_name}_worktrees/` → worktree pool.

Never edit files in a checkout whose branch does not match the task's feature
branch. Wrong checkout = STOP and `cd` to the correct root first. Never
resolve roots by directory name alone (e.g. `CashierSystem` vs
`cashier_system_worktrees` are different checkouts).

## 3. Branch Lifecycle & Thread Isolation

- **`development`** is the canonical integration branch (remote-backed `origin/development`). Changes arrive ONLY via feature-branch merges. Direct commits to `development` are FORBIDDEN.
- **`master`** is the stable/release branch. Tagged releases (`v*`) are cut from it. It runs CI; only `master` runs CD (see §9).
- **Branch taxonomy (canonical — matches `merge-message` and `emoji-commit` skills):**
  - `feature/{kebab-case-name}` — new capability or screen
  - `fix/{kebab-case-name}` — bug remediation
  - `refactor/{kebab-case-name}` — non-functional rewrite
  - `perf/{kebab-case-name}` — performance work
  - `chore/{kebab-case-name}` — tooling, deps, config
  - `docs/{kebab-case-name}` — documentation only
  - `release/{version}` — cut from `development`, merged to `master`, tagged `v*`
- **Strict Thread Isolation:** every independent feature, custom module, or screen layout configuration resides on its own dedicated branch. Inter-branch leakage — commits touching another feature's domain — is strictly forbidden.
- **Work location:** default = feature branch checked out in the master base. Worktree mode is used ONLY when 2+ features run in parallel and touch overlapping files; then create with `git worktree add -b feature/{name} {matrix}/feat-{name}`. A branch can never exist in both the base and a worktree simultaneously.
- **Sync:** before merging, merge `origin/development` into the feature branch (prefer merge over rebase; rebase only with Git Workflow Master approval). Never rebase or force-push shared branches (`development`, `master`).
- **Conflict protocol:** a conflict touching another feature's domain = STOP and escalate to the orchestrator / user. Never resolve inline outside the branch's domain. `pubspec.lock` conflicts: keep `development`'s version, resolve manually, then `flutter pub get`.
- **NEVER DELETE BRANCHES.** No branch — local or remote — is ever deleted (`git branch -D/-d`, `git push origin --delete`, or any equivalent) for any reason, including after merge. Merged branches stay intact for audit and rollback.** UNLESS the user explicitly, in writing, tells you to delete a specific branch in the current session. This applies to both the master base and all worktrees.

## 4. Scope & Diff Discipline

- Read the task literally — the verbs define scope. "Fix" means fix, not improve. Deliver the smallest diff that solves the problem.
- No "while I'm here" changes, no unrelated refactors, no improvements disguised as fixes. Three similar lines beat a premature abstraction; extract a helper only at the fourth occurrence.
- **`git add -A` / `git add .` are FORBIDDEN.** Stage by explicit path only.
- **Leakage enforcement:** before every commit, run `git diff --staged` and confirm every staged file belongs to the current feature. Anything outside the domain gets unstaged, no exceptions.
- **Surface, don't smuggle:** out-of-scope findings (bugs, dead code, debt) are recorded as one-line follow-ups in `docs/followups.md` with file location — never fixed inside the current branch.
- Dependency upgrades get their own dedicated commit with justification, or their own branch.
- No defensive code for impossible cases. Validate only at system boundaries.

## 5. Commit Protocol (Automated Agent Commit Protocol)

- **Every** state change is committed via the `emoji-commit` skill — no manual `git commit` calls. Parse staged changes via `git diff --staged`, split unrelated changes into separate commits, format per the skill's rules.
- A commit is a **coherent unit**: it passes the FAST gate (§6). WIP/incomplete states stay uncommitted or explicitly marked WIP; they are never merged.
- Before committing, review the staged diff for secrets, keys, env files, and `print`/`debugPrint` outside tests.
- Never commit: `.dart_tool/`, `build/`, `.idea/`, `*.iml`, `*.log`, `.DS_Store`. Generated code (`.g.dart`, `.freezed.dart`) is committed ONLY in the same commit as its source change, after `dart run build_runner build`.

## 6. Flutter Verification Standards

### FAST GATE — before EVERY commit
1. `dart format --set-exit-if-changed lib test`
2. `flutter analyze` — must exit 0 (infos are failures)
3. No `print(`/`debugPrint(` outside tests in the staged diff
4. No secrets/keys/tokens in the staged diff

### FULL GATE — before EVERY merge into `development`
1. Feature branch synced from `origin/development` first
2. `dart format --set-exit-if-changed lib test`
3. `flutter analyze` — exit 0
4. `flutter test` — all pass, zero undocumented skips
5. `flutter build apk --debug` — compile proof (web/ios per project)
6. Scope audit: `git diff origin/development...HEAD --stat` must touch ONLY the branch's declared domains; anything else = leakage, split it off

### Engineering minimums
- `const` constructors wherever possible; no network/IO/parsing in `build()`; lazy lists; dispose all controllers.
- 60fps target; profile with `flutter run --profile` when in doubt.
- Secrets never in source: `flutter_secure_storage` only; no seed/key literals, no base64 assets.
- New features ship with tests in the same commit (unit for logic, widget for screens).

## 7. Specs Compliance

- The agent **MUST** follow the spec files (`specs/` — `PRD.md`, `ARCHITECTURE.md`, `DESIGN.md`, `USER_FLOW.md`, `DEVELOPMENT_ENVIRONMENT.md`) unless the user explicitly tells it otherwise.
- No out-of-spec features. No assumptions — when a spec is ambiguous, ask the user instead of guessing.
- Specs are the source of truth; implementation must be synced with them (§8, feature-completion protocol).

## 8. Review & Quality Gates

No gate may be skipped. Skipping requires explicit user approval, logged in the QA report. **Evidence before claims** — `verification-before-completion` discipline is mandatory at every gate.

### Gate 0 — Per-Commit Verification (cheap, mandatory)
- Run `verification-before-completion`: never claim "passing/done" without fresh command output in the same message.
- FAST gate (§6) + targeted tests of touched units. Full suite runs at Gate 1.

### Gate 1 — Pre-Merge Review (mandatory, BLOCKS merge)
Run when the feature branch is complete, before ANY merge into `development`:
1. `feature-summary` — handoff brief of the branch.
2. `qa-post-implementation` — integrates verification, Code Reviewer agent, security review, `test-coverage-analysis`, branch status.
3. **HALT:** QA Review Report surfaced; no fixes, no merge until user approval.
4. Severity policy: Critical/High → BLOCKED until fixed; Medium → fix before merge; Low/Info → may defer with note.
5. Merge readiness: clean tree, branch pushed and up to date, FULL gate green, specs synced, no secrets/TODOs in diff, QA status READY TO MERGE.

### Gate 2 — Post-Merge Verification (mandatory)
1. Re-run verification on merged `development` — branch-green is not merged-green.
2. Sync spec files to merged reality (via `filling-gaps` if needed).
3. Keep the merged branch intact (NEVER delete, per §3); remove its worktree if used (`git worktree remove` + `git worktree prune`).
4. Emit `feature-summary` handoff.

### Feature-Completion Protocol (mandatory after EVERY completed feature)
In order:
1. `qa-post-implementation` skill — full verification + review + security audit + handoff report.
2. `test-coverage-analysis` skill — map changed source to tests; close gaps for untested widgets/blocs/repos.
3. `filling-gaps` command — analyze the feature's commits vs the spec files and sync the specs with the actual code implementation.

### Merge Sequence (ordered, no skipping)
`feature-summary` → Gate 1 (`qa-post-implementation` + user approval) → resolve findings → re-verify → `merge-message` (merge overview) → `git merge --no-ff <feature> -F <msg>` → Gate 2.

### Definition of Done for a feature branch
- [ ] Working tree clean; branch pushed to `origin`
- [ ] Branch up to date with `origin/development`, no conflicts
- [ ] FULL gate green (`dart format`, `flutter analyze`, `flutter test`, build)
- [ ] Scope audit: only declared domains touched
- [ ] `test-coverage-analysis` PASS; changed units covered
- [ ] Specs synced with implementation (`filling-gaps`)
- [ ] No secrets, debug prints, or new TODO/FIXME in diff
- [ ] QA report: READY TO MERGE
- [ ] Merged to `development`; branch retained intact (never deleted, per §3), worktree cleaned, post-merge verified

## 9. CI/CD Pipeline Policy

- On starting a new branch or feature, the agent **MUST** check `.github/workflows/`. If no CI pipeline exists, the agent **MUST create one comprehensively** at `.github/workflows/{project-name}-ci.yml`.
- **CI runs on EVERY branch** (push triggers on all branches including `development` and `master`, plus pull requests). CI must include:
  - Formatting check (`dart format` with exit-if-changed)
  - Linting
  - `flutter analyze`
  - `flutter test`
- **Only `master` has a CD pipeline**: `.github/workflows/{project-name}-cd.yml` — build + deploy/release on push to `master` with `v*` tags.
- Feature branches and `development` never get CD.

## 10. Workflow Orchestration

- Pipeline model: PM (spec → features → per-feature task lists) → per-feature [Dev ↔ QA loop] → Gate 1 → merge → Gate 2.
- Default: one feature at a time (serial). Parallel only via the worktree matrix for disjoint file sets, coordinated with `dispatching-parallel-agents`; pre-check overlap with `git merge-tree`.
- Retry ladder: task fails ≤3 attempts with feedback, then the branch is blocked and a human checkpoint is raised.
- Agent roster (verified names in `~/.config/opencode/agents/`):

| Agent | When to use |
|-------|-------------|
| Agents Orchestrator | Full workflow pipeline management, Dev↔QA loops, quality gates |
| Senior Developer | Premium/feature implementation |
| Minimal Change Engineer | Surgical fixes, scope control, diff discipline |
| Code Reviewer | Pre-merge code review (correctness, security, performance, maintainability) |
| Codebase Onboarding Engineer | First run on unfamiliar repos, repo maps, entry points |
| qa-post-implementation | Gate 1/2 verification pipeline, review reports |
| testing-reality-checker | Evidence-based PASS/FAIL certification |
| testing-performance-benchmarker | Performance regression checks |
| engineering-git-workflow-master | Merge/rebase/worktree mechanics, conflict resolution |
| project-manager-senior | Spec → task decomposition |

## 11. Repository Orientation & Onboarding

- Fast Flutter first-read order: `pubspec.yaml` → `lib/main.dart` → `lib/` tree (note `lib/features/`, `lib/core/`, `lib/shared/`) → `test/` → `specs/`.
- `flutter pub get` must run per checkout — each checkout has its own `.dart_tool/`, `build/`, `pubspec.lock`; artifacts do not transfer between checkouts.
- Canonical root resolution: current checkout = `git rev-parse --show-toplevel`; master repo (from a worktree) = `git rev-parse --git-common-dir` minus the trailing `/worktrees/...` segment.
- Verify before claiming done in the CURRENT checkout: `flutter analyze` + `flutter test`.

## 12. Precedence & Skill Routing

- **Precedence:** this global file > per-project `AGENTS.md`/`GEMINI.md`/`CLAUDE.md` > skill defaults > model defaults. Per-project files may tighten, never loosen.

### Communication Mode (startup default)

- **Caveman mode is ALWAYS initialized at startup.** Every session begins in caveman mode (per `AGENTS.caveman.md` — see §1 of this file's sibling instructions file) unless the user explicitly says "stop caveman" or "normal mode". The agent MUST engage the `caveman` skill at session start before any other action.
- Caveman applies to chat responses only. Code, commits, PR descriptions, destructive confirmations, and security findings use normal clarity.

### Skill routing table

| Situation | Skill |
|-----------|-------|
| Every commit | `emoji-commit` |
| Every merge into `development` | `merge-message` |
| Feature complete | `qa-post-implementation` → `test-coverage-analysis` → `filling-gaps` |
| Bug found | `systematic-debugging` before proposing fixes |
| Claiming done/passing | `verification-before-completion` |
| New feature/bugfix logic | `test-driven-development` |
| Single commit or branch review | `commit-review` |
| Multi-task planning | `writing-plans` / `executing-plans` / `subagent-driven-development` |
