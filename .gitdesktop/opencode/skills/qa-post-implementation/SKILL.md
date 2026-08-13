---
name: qa-post-implementation
description: >
  Post-implementation QA pipeline. Runs verification, code review, security audit, branch
  status, and handoff summary; produces one consolidated Review Report. Halt for approval
  before any code mutation. Project-agnostic — auto-detects stack, branch, intent docs.
  Use when user says "QA this", "post-implementation review", "review before merge",
  "ship check", "qa before merge", "pre-merge check", or invokes /qa-post-implementation.
  Also auto-triggers after a feature branch is ready for review.
---

# QA Post-Implementation (Skill)

Run after feature implementation finishes. Drive a deterministic QA pipeline end-to-end. Produce ONE consolidated report. No filler.

This skill does the same work as the `qa-post-implementation` agent, but is invoked as a slash command / `skill` tool call. It can invoke any tool, agent, sub-agent, skill, command, or MCP server the host exposes — and applies the same review-gate as the agent (no mutation before user approval).

## Invocation Surface

The skill is host-agnostic and may invoke any capability the host exposes:

- **Tools:** file ops (`read`, `edit`, `write`, `glob`, `grep`, `notebook_edit`), search (`webfetch`, `websearch`), shell (`bash`), language servers (`lsp`), host-specific (`apply_patch`, `codebase_search`, `read_file`, `terminal_cmd`, `browser_*`).
- **Agents / sub-agents:** dispatched via the host's `task` / `agent` tool — built-in (Code Reviewer, security roles, Explore, Plan, general-purpose), plugin agents, custom user agents, host-native agent harnesses.
- **Skills / slash commands:** any installed skill via the host's `skill` tool — Claude Code skills, opencode plugin skills, host slash commands.
- **External CLIs:** `gh`, `git`, `npm`, `pnpm`, `cargo`, `go`, `pytest`, `jest`, `playwright`, `curl`, `docker`, `kubectl`, `terraform`, `flutter`, `dart`, `slopwatch`, etc., invoked via shell.
- **MCP servers:** any connected server — its tools are part of the invocation surface.

## Hard Constraint — Review Gate

**The skill MUST NOT edit, modify, or execute any code until the user explicitly approves the findings and fix plan.**

Allowed during the review phase:
- `read`, `glob`, `grep`, `webfetch`, `websearch`, `lsp` — inspect code, logs, configs, history.
- `task` / `agent` — dispatch read-only sub-agents.
- `todowrite` / `todo` — track work, mark phases complete.
- `skill` invocations that are observational only.
- `bash` for read-only commands: `git status`, `git diff`, `git log`, `git show`, `gh pr view`, `gh pr checks`, `ls`, `cat`, `grep`, `rg`, `find`, `curl GET`, `kubectl get`, `docker ps`, dry-run flags, `--check`.

Disallowed until approval:
- `edit`, `write`, `notebook_edit` — no file mutation, anywhere in the repo, `.claude/`, or `.config/opencode/`.
- `bash` for mutating ops — no `git commit`, `git push`, `git merge`, `gh pr merge`, `npm install`, migrations, test runs that mutate state, `curl -X POST/PUT/DELETE/PATCH`, `kubectl apply`, `terraform apply`, `docker run` with writes.
- Sub-agents that mutate.
- Skills in action-taking mode: `simplify --fix`, `code-review --fix`, `code-review --comment`, anything that opens a PR, posts comments, pushes branches, or writes a config file.

**Workflow adjustment:**
1. Run all observation, analysis, sub-agent dispatch, and observational skill invocations.
2. Produce a single **Review Report** with:
   - All findings (verification, code quality, security, branch, handoff).
   - **Proposed Fix Plan** with exact file:line targets, diff sketches, effort estimate per item.
   - **Decision Matrix** per fix: severity, risk-of-fix, requires-test, owner, recommended action (`apply | defer | reject | discuss`).
3. **HALT.** Surface the report. Wait for explicit user approval (`apply all`, `apply #1, #3, defer #5`, `reject #2`, `proceed as-is`).
4. Only after approval: execute approved fixes, re-run verification, emit the final consolidated handoff report.

If the user says "skip review" or "proceed without review", log it in the Appendix and proceed — but never assume it.

## Sub-agent Safety Contract

When dispatching a sub-agent that could mutate, the skill MUST:

1. Restrict the sub-agent's tool list to `read-only` equivalents (drop `edit`, `write`, mutating `bash`, `apply_patch`, `notebook_edit`).
2. Inject a hard prompt constraint: "Do not edit files, do not run mutating commands, do not push, do not post. Return findings only."
3. If the host only offers the sub-agent with mutation tools, isolate it in `isolation: "worktree"` or a read-only sandbox, AND instruct it explicitly not to write back.
4. If neither option is available, defer the sub-agent until after approval and document the gap in the Appendix.

## Skill Safety Contract

Before invoking any skill, the skill MUST check the skill's action modes. Examples:

- `simplify --fix` → mutating. Use only post-approval.
- `code-review --fix` → mutating. Use only post-approval.
- `code-review --comment` → mutating. Use only post-approval.
- `code-review` (no flag) → observational, allowed in review phase.
- `verify` → observational if it only runs read-only checks; mutating if it persists artifacts. Inspect before use.
- `security-review` → observational.
- `init` / `review` / `run` → typically observational, but verify.
- Any skill that opens a PR, pushes a branch, comments on an issue, or writes a config file → mutating.

If a skill's effect is unclear, treat it as mutating and defer.

## External CLI Safety Contract

- Read-only CLIs (`git log`, `git diff`, `git show`, `gh pr view`, `gh pr checks`, `ls`, `cat`, `grep`, `rg`, `find`, `curl GET`, `kubectl get`, `docker ps`) → allowed.
- Mutating CLIs (`git commit`, `git push`, `git merge`, `gh pr merge`, `npm install`, `pip install`, `cargo build --release`, `pytest` with side effects, `kubectl apply`, `docker run` with writes, `curl -X POST/PUT/DELETE/PATCH`, `terraform apply`) → blocked until approval.

## MCP Server Safety Contract

- MCP tools classified by effect, not by name.
- Read tools (`fetch`, `get_*`, `list_*`, `search_*`, `read_*`) → allowed.
- Write tools (`create_*`, `update_*`, `delete_*`, `send_*`, `post_*`, `apply_*`) → blocked until approval.

## Dispatch Contract — Sub-agents Are Primary

The skill is an **integrator**, not a reviewer. Its job is to:

1. Gather the change set, specs, and context (Phase 0).
2. **Dispatch sub-agents** (Code Reviewer, Security, Spec Compliance, Test Coverage) in parallel via `task`.
3. Integrate their findings into one report.
4. Surface the report, halt, wait for approval.

**The skill MUST NOT perform primary code review, security analysis, or spec compliance checking itself.** It may do corroborating reads to confirm or refute a sub-agent's finding, but generating primary findings is out of scope. Skipping dispatch to "save time" is a contract violation.

## Workflow

Execute in order. Do not skip steps. Do not reorder.

### Phase 0 — Project Discovery (auto-detect, no hardcoded paths)

The skill is **project-agnostic**. Never assume a specific repo, worktree, or path. Discover everything from the host environment.

1. **Detect project root** — run from cwd, walk up until a project marker is found. Markers (priority order):
   - `.git/` (git repo)
   - `package.json` (Node/JS/TS), `pnpm-workspace.yaml`, `lerna.json`
   - `pubspec.yaml` (Flutter/Dart)
   - `pyproject.toml`, `setup.py`, `requirements.txt` (Python)
   - `Cargo.toml` (Rust)
   - `go.mod`, `go.work` (Go)
   - `pom.xml`, `build.gradle`, `build.gradle.kts` (JVM)
   - `composer.json` (PHP)
   - `Gemfile` (Ruby)
   - `*.csproj`, `*.sln` (.NET)
   - `mix.exs` (Elixir)
   - `Package.swift` (Swift)
   If cwd is outside any repo, ask the user.
2. **Detect branch + base** — `git rev-parse --abbrev-ref HEAD`, `git rev-parse --show-toplevel`, `git config --get remote.origin.url`. Base via `git symbolic-ref refs/remotes/origin/HEAD` or fallback to `main`/`master`/`develop`/`development` (whichever exists). If HEAD equals base, treat the working tree as the diff.
3. **Detect change set** — `git diff --name-status <base>...HEAD` and `git status --porcelain`. Split into: M, A, R, D, ??. Untracked files are included.
4. **Detect stack** — read manifest files for language, framework, test runner, lint tool, build tool.
5. **Detect intent documents** — `glob` for: `SPEC.md`, `DESIGN.md`, `ARCHITECTURE.md`, `REQUIREMENTS.md`, `README.md`, `docs/spec/`, `docs/adr/`, `docs/architecture/`, `.claude/specs/`, `CONTRIBUTING.md`. Read each that exists. Skip silently if none.
6. **Detect monorepo layout** — `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `turbo.json`, `go.work`, or `Cargo.toml [workspace]`. Run discovery per workspace affected.
7. **Detect CI** — `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/`, `buildkite/`. Read the relevant pipeline to know what runs.
8. **Detect tooling** — preferred test runner, lint, typecheck, format commands.

**Output of Phase 0** (top of report):

```markdown
## Project Context
- **Project root:** <abs path>
- **Repo:** <remote URL or "local only">
- **Branch:** <name> ← <base>
- **Stack:** <lang>/<framework> (<test runner>, <linter>, <typecheck>)
- **Monorepo:** yes/no, workspaces: [...]
- **Intent docs found:** [list with paths, or "none"]
- **CI:** <system> (<status if detectable>)
- **Change set:** M=<n> A=<n> R=<n> D=<n> ??=<n> (total <n> files)
```

If Phase 0 cannot complete, halt and ask the user to `cd` into a project or pass `--path`.

### Phase 1 — Scope

1. Use the change set from Phase 0.
2. Use intent documents from Phase 0. If none, note it and proceed code-only.
3. Detect sensitive surface area (auth, crypto, payments, PII, network, file upload, eval, IPC, contract, on-chain).
4. Classify feature type: web-app, api, cli, library, infra, smart-contract, data-pipeline, ml/ai, mobile, other.
5. Pick security sub-agent by surface:
   - Web/API/Mobile → `application-security-engineer`
   - Infra/Cloud/Network → `senior-secops-engineer`
   - System design / zero-trust / threat model → `security-architect`
   - PII / GDPR / HIPAA / SOC2 → `compliance-auditor`
   - Solidity / Move / on-chain → `blockchain-security-auditor`
   - Default → `security-architect`

### Phase 2 — Skills (observational only)

Invoke each via `skill` (no action flags) before its phase. Capture results.

1. `verification-before-completion` — drive the change end-to-end, observe behavior.
2. `requesting-code-review` — request structured code review; wait for findings.
3. `finishing-a-development-branch` — check merge readiness, CI, conflicts.
4. `feature-summary` — produce user-facing handoff summary.

Additional skills allowed when context demands (`security-review`, `code-review`, `simplify`, `verify`, `init`, `review`). Skip action-taking flags.

### Phase 3 — Sub-agents (dispatch read-only, collect findings)

**MANDATORY.** Parallel via `task`. The skill integrates; sub-agents produce primary findings.

**Required sub-agents:**

1. **Code Reviewer** (always) — host's `code-reviewer` / `code-review` agent. Pass:
   - Project root, branch, base, full diff.
   - Intent docs from Phase 0.
   - Sensitive surface from Phase 1.
   - Instruction: severity-tagged (Critical/High/Medium/Low/Info), file:line, CWE/OWASP where relevant, no scope creep, raw findings list, compare implementation vs spec.
2. **Security Sub-agent** (always, role from Phase 1.5) — `task`. Pass:
   - Project root, threat model scope.
   - Diff + new files.
   - Spec excerpts covering auth, crypto, PII, payments, network, file upload, eval, IPC, contract, on-chain.
   - Instruction: STRIDE-style, severity-tagged, file:line, repro/PoC.

**Optional sub-agents** (when user opts in via scope flag, e.g. `code-review+security`):

3. **Spec Compliance Agent** — `general-purpose` / `Explore`. Compare every spec requirement to the implementation. Surface missing functionality, role mismatches, infrastructure gaps, localization gaps, state-preservation mismatches, dialog/UX patterns that violate spec.
4. **Test Coverage Agent** — `Explore` / `general-purpose`. Map `file → test` pairs. Report coverage delta.
5. **Additional sub-agents** — `Plan` for refactor proposals, `general-purpose` for blast-radius scan, specialized security roles.

If user invoked with a scope flag (e.g. `code-review+security`), optional sub-agents are skipped; report marks omitted sections. The Phase 5 report always includes the **Project Context** block.

The skill's job is to **integrate** sub-agent outputs. It may do corroborating reads but not primary review. Every report section cites the sub-agent that produced it. Missing sub-agent → section "not run" → report incomplete.

### Phase 4 — Synthesize

Merge findings from all sources. Deduplicate by file:line. Resolve conflicts (verification failure trumps review nit). Rank by severity.

### Phase 5 — Review Report (HALTs here for approval)

Emit the Review Report with Decision Matrix. HALT. Do not execute fixes.

### Phase 6 — Execute (only after explicit approval)

Apply approved Decision Matrix items. Re-verify. Emit the final consolidated handoff report.

## Report Format

```markdown
# QA Post-Implementation Report

**Feature:** <name>
**Branch:** <branch> ← <base>
**Date:** <YYYY-MM-DD>
**Status:** ✅ READY TO MERGE | ⚠️ MERGE WITH FIXES | ❌ BLOCKED
**Risk Level:** Critical | High | Medium | Low
**Phase:** Review (awaiting approval) | Final (post-approval, with applied fixes)
**Scope invoked:** <full | code-review+security | code-review-only | etc.>

## 0. Project Context
- **Project root:** <abs path>
- **Repo:** <remote URL or "local only">
- **Branch:** <name> ← <base>
- **Stack:** <lang>/<framework> (<test runner>, <linter>, <typecheck>)
- **Monorepo:** yes/no, workspaces: [...]
- **Intent docs found:** [list with paths, or "none"]
- **CI:** <system> (<status if detectable>)
- **Change set:** M=<n> A=<n> R=<n> D=<n> ??=<n> (total <n> files)
- **Sensitive surface area:** <list from Phase 1>
- **Security role selected:** <name>

## 1. Executive Summary
<2-5 lines: what was built, overall verdict, top blocker if any>

## 2. Verification
- **Acceptance criteria:** Met / Partial / Not Met
- **End-to-end behavior:** <observed>
- **Tests:** passed X / failed Y / skipped Z
- **Evidence:** <commands run, outputs, screenshots, log excerpts>
- **Open issues:** <list>

## 3. Code Quality (Code Reviewer)
| Severity | File:Line | Finding | Suggested Fix |
|----------|-----------|---------|---------------|
| Critical | path:NN | <one line> | <one line> |
| High     | path:NN | <one line> | <one line> |
| Medium   | path:NN | <one line> | <one line> |
| Low      | path:NN | <one line> | <one line> |

## 4. Security (<subagent name>)
- **Threat model scope:** <in/out>
- **Findings:** <same severity table>
- **Attack surface touched:** <endpoints, inputs, secrets, auth>
- **Compliance notes:** <if any>

## 5. Branch Status
- **Commits ahead of base:** N
- **CI status:** green/red/pending
- **Merge conflicts:** none/present
- **Uncommitted changes:** none/present
- **Cleanup needed:** <list or none>

## 6. Handoff Summary
- **User-facing change:** <1-2 sentences>
- **How to use:** <steps>
- **Rollback plan:** <steps>
- **Follow-ups:** <list>

## 7. Proposed Fix Plan + Decision Matrix
| # | Severity | Fix target (file:line) | Diff sketch | Risk-of-fix | Needs test | Recommended action | Owner |
|---|----------|------------------------|-------------|-------------|------------|--------------------|-------|
| 1 | Critical | path:NN | <sketch> | Low/Med/High | Y/N | apply / defer / reject / discuss | ? |

**Awaiting approval.** Reply with one of:
- `apply all` — execute every `apply` row
- `apply #1, #3` — execute specific rows
- `defer #5` — leave specific rows
- `reject #2` — drop specific rows
- `proceed as-is` — merge without fixes (logged as explicit risk acceptance)

## 8. Prioritized Action Items
1. **[Critical]** <action> — owner? — blocks merge
2. **[High]** <action> — owner? — blocks merge
3. **[Medium]** <action> — owner? — should fix before merge
4. **[Low]** <action> — owner? — nice to have
5. **[Info]** <action> — owner? — FYI

## 9. Appendix
- **Tools / agents / skills / CLIs / MCP endpoints invoked**, each tagged `read-only` or `mutating`, with phase (review vs post-approval) and reason.
- **Commands run** (full text).
- **Sub-agents dispatched** (with reason).
- **Skills loaded** (with reason).
- **Raw findings JSON** (truncated to relevant).
- **User's approval / override** (quoted verbatim, with timestamp).
```

## Rules

- **Single report.** No separate docs, no split deliverables.
- **Halt at Review.** Phase 5 produces the Review Report with Decision Matrix. Do not apply fixes until the user replies.
- **Evidence over opinion.** Quote exact output. file:line mandatory for findings.
- **Severity standard:** Critical = data loss / security breach / merge blocker. High = bug with user impact. Medium = code-quality issue. Low = nit. Info = FYI.
- **Reproducible.** Every Critical/High finding has repro steps or a failing test.
- **No silent drops.** If a phase is skipped, state why in the report.
- **Determinism.** Same inputs → same report structure. Vary only findings.
- **Length cap.** Report under 600 lines. Truncate raw logs; quote decisive lines.
- **Effect-based classification.** Classify every tool/agent/skill/CLI/MCP by effect, not by name.
- **Project-agnostic.** Auto-detect everything from cwd. No hardcoded paths.

## Failure Modes

- Verification fails → status ❌ BLOCKED. Stop merge. List blockers first.
- Security Critical → status ❌ BLOCKED. Do not soften.
- CI red → status ⚠️ MERGE WITH FIXES unless transient.
- Cannot load a required skill → log in report, downgrade confidence.
- Cannot dispatch a sub-agent → report which one, mark its section "not run", continue.
- Project root not detectable → halt, ask user to `cd` or pass `--path`.
- User replies ambiguously → ask for explicit per-row decision before executing.
