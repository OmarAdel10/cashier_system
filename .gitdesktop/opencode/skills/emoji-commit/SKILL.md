---
name: emoji-commit
description: >
  General-purpose git commit workflow with intelligent auto-staging. Splits unrelated
  working-tree changes into separate emoji + Conventional Commits commits. Works in any
  git repo, not project-specific. Use when user says "commit", "git commit", "/commit",
  or when unstaged changes are detected. Triggers on change detection, manual invocation,
  or when user asks for a commit.
---

Stage and commit changes intelligently. Splits unrelated working-tree changes into
separate emoji + Conventional Commits commits, each with a mandatory body and optional
warnings block. The diff IS the source of truth — parse first, then group, stage, and
commit.

## Workflow

### Step 1: Inspect the working tree

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
```

Read the full diff for both staged and unstaged sections. Build a complete picture
before deciding anything.

### Step 2: Group changes into commit units

A "commit unit" is a set of file changes that form a single coherent intent. Group
using these signals, in order of precedence:

1. **Logical intent** — what does the change do? A bug fix and an unrelated refactor
   are two units, even if both touch the same file.
2. **Directory/module boundary** — `src/auth/...` and `src/payments/...` are different
   units unless they share a feature.
3. **Change type** — `feat`, `fix`, `refactor`, `test`, `docs` are distinct units.
4. **Staging status** — files already staged and files newly modified may be one unit
   if they share intent, separate units if not.

Special cases:
- **New file + its test file** → typically ONE unit (feat with test).
- **New file + its test file in different module** → TWO units only if the test stands
  alone (e.g. integration test in `tests/` vs unit test colocated).
- **Refactor + new feature in same file** → TWO units. Stage hunks separately with
  `git add -p` if hunks are interleaved. If hunks cannot be cleanly separated, surface
  to user and ask whether to split or commit together.
- **Lockfile / generated file changes** → group with the commit that caused the change
  (dep add/update), or as standalone `chore` if unclear.
- **Untracked files (??)** → include in the most relevant unit, or standalone `feat`
  if a new file with no clear parent.

### Step 3: Decide commit count

| Situation                                       | Action                          |
|-------------------------------------------------|---------------------------------|
| All changes share one intent                    | 1 commit, stage all             |
| 2+ unrelated intents                            | N commits, one per intent       |
| Single intent but multiple change types         | Split by type (e.g. refactor → feat) |
| Interleaved hunks in same file, different intent| `git add -p` per hunk group, or surface to user |
| Untracked file with no clear parent             | Standalone `feat` or surface     |

If splitting is needed but ambiguous (e.g. 3 small changes that could be 1 or 3
commits), surface the plan to the user before running.

### Step 4: Stage and commit per unit

For each unit:
1. `git add <files>` (or `git add -p` for hunk-level staging).
2. `git diff --cached --stat` to confirm staged set matches intent.
3. Generate the message (see Commit Generation below).
4. Run the validation checklist.
5. Commit: `git commit -F <tmpfile>` (multi-line body needs a file, not `-m`).
6. Confirm with `git log -1 --stat` before moving to the next unit.

### Step 5: Verify

```bash
git status
git log --oneline -5
```

Working tree should be clean (or only contain untracked files the user chose to keep).
Each new commit should map cleanly to one unit.

## Commit Generation

Per-unit message construction:

1. Classify the dominant change type. Pick one emoji + one Conventional Commits type.
2. Derive scope from the touched directory or module (e.g. `auth`, `api`, `ui`, `cli`,
   `db`). Omit only if truly cross-cutting.
3. Write subject: `<emoji> <type>(<scope>): <imperative summary>` — under 50 chars,
   imperative mood, no trailing period.
4. Write body: bulleted list of what changed and why. Bullets use `-` not `*`. Wrap at
   72 chars. Cover: functional changes, architectural/state-engine impacts, breaking
   changes or migration notes.
5. Append `⚠️ WARNINGS` block ONLY if diff contains secrets, credentials, console logs
   left in production code, or outstanding TODOs.
6. Run the validation checklist before output.

## Emoji Legend (gitmoji default — project can override)

| Emoji | Type        | Use for                                        |
|-------|-------------|------------------------------------------------|
| ✨    | feat        | New feature or capability                      |
| 🐛    | fix         | Bug fix                                        |
| 📝    | docs        | Documentation only changes                     |
| 💄    | style       | Cosmetic / formatting / UI tweaks              |
| ♻️    | refactor    | Code change that neither fixes bug nor adds feat|
| ⚡    | perf        | Performance improvement                       |
| 🔧    | chore       | Tooling, build, deps, config                   |
| ✅    | test        | Adding or fixing tests                         |
| 🚀    | ci          | CI/CD pipeline changes                         |
| 🗑️    | revert      | Revert a prior commit                          |

When the host project defines its own emoji convention (CONTRIBUTING.md, spec file,
`.gitmessage`), prefer that. Fall back to gitmoji when no project rule is found.

## Formatting Rules (strict)

- **Subject line:** under 50 characters, imperative mood ("add", "fix", "remove" — not
  "added", "adds", "adding"), no trailing period.
- **Emoji prefix:** one emoji, then single space, then type(scope): summary.
- **Body bullets:** functional changes + architectural impacts. Use `-` not `*`.
- **Warnings block:** include ONLY when secrets, credentials, console logs, or TODOs
  appear in staged diff. Be specific: `<path>:<line> — <description>`.
- **Line wrap:** 72 chars per line.
- **Character escaping:** NEVER use double quotes (`"`) anywhere in the commit payload
  — subject, body, warnings block, footers. Use single quotes (`'`) for all string
  literals. Applies to every section without exception.

## Commit Template

```text
<emoji> <type>(<scope>): <summary>

* Functional change one.
* Functional change two.
* Architectural or state-engine impact.

⚠️ WARNINGS (include ONLY if applicable)
* Secret: <path>:<line> — <description>
* Console log: <path>:<line> — <description>
* Outstanding TODO: <path>:<line> — <description>
```

## Examples

### Example 1: Single intent, one commit

Working tree: 3 files in `src/inventory/`, all part of a new column layout.

```bash
git add src/inventory/
git commit -F /tmp/msg
```

```text
✨ feat(inventory): split inventory into two side-by-side columns

* Normal product grid on left, quick-add tiles on right.
* Responsive layout reflow for narrow viewports.
* State: bloc emits unchanged shape; UI derives layout from viewport.
```

### Example 2: Unrelated changes, two commits

Working tree: `src/auth/oauth.ts` (bug fix) + `lib/utils/strings.dart` (refactor).

```bash
# Commit 1
git add src/auth/oauth.ts
git commit -F /tmp/msg1   # 🐛 fix(auth): ...

# Commit 2
git add lib/utils/strings.dart
git commit -F /tmp/msg2   # ♻️ refactor(utils): ...
```

### Example 3: Feat + its test, one commit

Working tree: `src/auth/oauth.ts` (new handler) + `src/auth/__tests__/oauth.test.ts`.

```bash
git add src/auth/
git commit -F /tmp/msg    # ✨ feat(auth): wire OAuth callback handler (test included)
```

### Example 4: Interleaved hunks, surface to user

Working tree: `src/payments/processor.ts` has a refactor hunk + a new-feature hunk
interleaved in the same function. `git add -p` would be required, OR the user must
decide whether to split the file or commit as one. Surface this and ask.

### Example 5: With warnings

```text
✨ feat(auth): wire OAuth callback handler

* New OAuthCallbackHandler in src/auth/.
* Persists refresh token to secure storage.
* State: AuthBloc transitions Unauthenticated → Authenticated on success.

⚠️ WARNINGS
* Console log: src/auth/oauth_callback.ts:42 — console.log(token) leaks token to logcat.
```

### Example 6: Breaking change

```text
✨ feat(api)!: rename /v1/orders to /v1/checkout

* Route moved; old path returns 410 after deprecation date.
* Clients must update base URL before 2026-09-01.

BREAKING CHANGE: /v1/orders is removed. Update to /v1/checkout.
```

## Validation Checklist (run before each commit)

- [ ] Subject line ≤50 chars
- [ ] Single emoji at start, matches the type
- [ ] Conventional Commits type present in subject
- [ ] Scope in parentheses (or omitted deliberately with reason)
- [ ] Imperative mood in subject, no trailing period
- [ ] Body bullets use `-` not `*`
- [ ] WARNINGS block present ONLY if triggered
- [ ] Breaking changes use `!` after type/scope AND `BREAKING CHANGE:` footer
- [ ] Zero double quotes anywhere in the entire commit payload — only single quotes
- [ ] Staged files match the unit's intent (no unrelated files snuck in)

## Boundaries

This skill DOES:
- Auto-stage unstaged changes by grouping them into coherent commit units.
- Run `git add` (file-level and hunk-level with `-p` when needed).
- Run `git commit` using `-F <tmpfile>` for multi-line messages.
- Split unrelated changes into multiple commits.

This skill does NOT:
- Push (user runs `git push` explicitly).
- Amend prior commits unless the user explicitly asks.
- Switch branches, rebase, or merge.
- Stage files matching `.gitignore` (respect ignore rules).
- Force-push or run destructive operations.

When the working tree has changes the skill cannot confidently group (interleaved
hunks, ambiguous intent, or partial-branch state), it surfaces the situation to the
user with a clear plan and waits for confirmation before staging or committing.

Disengage: say "stop emoji-commit" or "normal commit" to revert to plain Conventional
Commits without emoji prefix, mandatory body, warnings block, or auto-staging.
