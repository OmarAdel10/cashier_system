---
name: commit-review
description: >
  Use when a feature commit or full feature branch needs structured review.
  Supports single-commit mode (given a ref) and full-feature-branch mode
  (auto-detects base branch and diffs entire branch). User says "review
  this commit", "review my feature branch", "check this PR", "commit
  review", or invokes /commit-review.
---

# Commit Review

Review code by its diff — either a single commit or an entire feature branch. Run code review, security review, and verification. Produce one consolidated findings report. No mutation.

## Mode Detection

The skill auto-detects which mode to use:

| Input | Mode | Diff computed as |
|-------|------|-----------------|
| Commit ref passed (SHA, `HEAD~3`, branch name) | Single-commit | `git diff <ref>^..<ref>` (or `<ref>~1..<ref>`) |
| No ref passed, HEAD is on a feature branch | Full-feature-branch | `git diff <base>..HEAD` |
| No ref passed, HEAD is on a base branch (main/master/develop) | Error | Ask user to pass a commit ref or checkout a feature branch |

Detect feature branch by checking if current branch is one of the base names:
`main`, `master`, `develop`, `development`, `staging`, `production`, `trunk`

If HEAD is on a base branch and no ref given, halt and prompt user.

## Workflow

### Phase 1 — Gather context

1. Detect project root (walk up from cwd for `.git/` or manifest files)
2. Detect and report mode (single-commit vs full-feature-branch)
3. Determine base branch: `git symbolic-ref refs/remotes/origin/HEAD` or fallback to `main`/`master`/`develop`
4. Run `git log --oneline -10` for commit context
5. Compute diff:
   - Single-commit: `git diff <ref>^..<ref>`
   - Feature branch: `git diff <base>..HEAD`
6. List changed files: `git diff --stat` or `git show --stat`
7. Detect stack from manifest files (package.json, pyproject.toml, Cargo.toml, etc.)
8. Detect intent docs (SPEC.md, DESIGN.md, README.md near changed files)
9. Classify sensitive surface: auth, crypto, payments, PII, network, file I/O, eval, IPC

### Phase 2 — Dispatch skills

1. Load `verification-before-completion` skill — run tests/lint/typecheck on the changed code. Capture results.
2. Load `requesting-code-review` skill — verify the diff against requirements/intent docs. Capture gaps.

### Phase 3 — Dispatch sub-agents (parallel)

Dispatch BOTH in parallel via `task`:

1. **Code Reviewer** — pass the full diff, changed files list, stack info, intent docs, mode label. Instruction:
   - Review correctness, maintainability, performance, test coverage
   - Severity tags: 🔴 blocker, 🟡 suggestion, 💭 nit
   - Include file:line references
   - Scope = only what changed (single commit OR entire branch)

2. **Security Architect** — pass the full diff, changed files, sensitive surface classification, stack info, mode label. Instruction:
   - Threat model the diff: STRIDE-style analysis
   - Flag auth flaws, injection risks, data exposure, privilege issues
   - Severity tags: Critical / High / Medium / Low
   - Include file:line with repro logic

### Phase 4 — Synthesize

Merge all findings. Deduplicate by file:line. Rank by severity. Produce single report.

## Report Format

```markdown
# Commit Review Report

**Mode:** single-commit | full-feature-branch
**Target:** <sha> | <branch> ← <base>
**Files changed:** <count>
**Sensitive surface:** <detected categories>
**Verdict:** ✅ PASS | ⚠️ WARNINGS | ❌ BLOCKED

## Verification
<tests/lint/typecheck results>

## Code Review Findings (Code Reviewer)
| Severity | File:Line | Finding |
|----------|-----------|---------|

## Security Findings (Security Architect)
| Severity | File:Line | Finding |
|----------|-----------|---------|

## Consolidated Action Items
1. [Critical] <item> — blocks merge
2. [High] <item> — should fix
3. [Medium] <item> — should fix
4. [Low] <item> — nice to have
```

## Rules

- Review only what changed. No scope creep.
- If on a base branch with no ref given, halt and ask for input.
- If diff is empty, report it and stop.
- Every finding must include file:line.
- One report, no separate deliverables.
- Do not edit any files. Read-only operation.
- If a skill or sub-agent is unavailable, note it and continue.
