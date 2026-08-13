---
name: merge-message
description: >
  Draft the merge commit message that lands one branch into another
  (e.g. feature/shortcuts → development). Reads the landing commits
  from git, groups them by area, and produces one paste-ready message
  using the emoji + Conventional Commits format defined inline below.
  Bash and git are always available. Default target is `development`.
  Personal skill. Use when user says 'merge <branch> into development',
  'merge message', 'draft merge commit', 'prepare merge to dev',
  'merge overview', or asks for the merge commit message. Does NOT
  perform the merge.
---

# merge-message

Draft the merge commit message from a feature branch into the
integration branch. The git history between the two branches is the
source of truth. Bash and git are always available; no other tools
required. The skill never modifies state.

## Inputs

- **Source branch** — the branch being merged in. Detect with
  `git rev-parse --abbrev-ref HEAD` if checked out, else ask.
- **Target branch** — the branch being merged into. Default is always
  `development`. Override only if the user names a different target.

## Workflow

### 1. Gather the landing set

```bash
# Commits landing on target
git log <target>..<source> --oneline

# File scope totals
git diff --stat <target>...<source>

# Full per-commit messages for narrative
git log <target>..<source> --format='%n=== %h %s ===%n%b'

# Per-file change table (A/M/D/R)
git diff --name-status <target>...<source>

# Base commit on target
git log -1 <target> --format='%h %s'
```

### 2. Classify the merge

Read the commit subjects. Pick the dominant change type + emoji from
the **Emoji legend** below. The type describes what is being delivered,
not the merge mechanic. When the landing set is genuinely mixed, use
`feat` + 🐣.

**Scope** — derive from the source branch's leaf segment after the last
`/`. Strip leading `feature/`, `feat/`, `fix/`, `chore/`, `release/`,
`hotfix/`, `bugfix/` first; lowercase the remainder.

- `feature/shortcuts` → `shortcuts`
- `fix/cart-tax` → `cart-tax`
- `release/1.2.0` → `1.2.0`

### 3. Group by area

Cluster the landing commits into 3–8 bullets by what changed, not by
commit order. Group by feature area, layer, or component — whatever
fits the branch.

### 4. Compose the merge message

Three parts, in this order:

1. **Subject** — one line, ≤50 chars, imperative mood, no trailing
   period:
   ```
   🐣 feat(<scope>): merge <source> into <target>
   ```
   If too long, shorten `<source>` / `<target>` to the leaf segment.
   If still too long, drop the verb.

2. **Body** — bulleted overview, `-` bullets, grouped by area, 5–10
   lines max. Cover:
   - What new capability / fix / refactor ships
   - Modules or layers affected
   - Spec or contract impact (if `docs/`, `specs/`, `CHANGELOG.md`,
     `**/README.md` changed)
   - Test status — only if a runner was run; otherwise omit or write
     `Tests: not run`

3. **WARNINGS** — only if the landing diff actually contains:
   - Secrets, credentials, API keys, tokens
   - Stray debug output in production paths (`console.log`, `print(`,
     `debugPrint(`, `fmt.Println` outside tests)
   - Outstanding `TODO` / `FIXME` / `XXX` / `HACK` markers added by
     the branch
   Each warning: `<path>:<line> — <description>`. No padding.

### 5. Validate

- [ ] Subject length ≤ 50 chars
- [ ] Single emoji prefix matches the dominant change type
- [ ] Conventional Commits type present in subject
- [ ] Scope in parentheses, matches the branch domain
- [ ] Imperative mood in subject, no trailing period
- [ ] Body bullets use `-` not `*`
- [ ] WARNINGS block present ONLY if triggered
- [ ] **Zero double quotes** anywhere in the message — only single
   quotes for any string literal
- [ ] No raw dump of `git log` — narrative only
- [ ] Cite at most 3–5 short SHAs inline; do not list every commit
- [ ] Source + target branch names each appear once in the subject

## Emoji legend (authoritative)

| Emoji | Type      | Use for                                          |
|-------|-----------|--------------------------------------------------|
| 🐣    | feat      | Structural system updates / screen implementations |
| 🐞    | fix       | Execution bug remediation logic                  |
| 📄    | docs      | Specification configuration updates             |
| 🎨    | style     | Aesthetic layout / visual property tweaks        |
| ✏️    | refactor  | Non-functional core optimization rewrites       |
| ⚡    | perf      | Speed enhancements for weak hardware baselines   |
| 🏗️    | chore     | Internal package builds / dependency mapping    |

Mixed landing set → `feat` + 🐣.

## Output format

Print exactly one fenced code block, paste-ready. Then one shell hint:

````text
🐣 feat(<scope>): merge <source> into <target>

* <area>: <1-line summary> (<short-sha>[, <short-sha>])
* <area>: <1-line summary>
* <area>: <1-line summary>
* Specs: <files> (only if docs/specs changed)
* Tests: <runner> <passed>/<total> (only if run)

⚠️ WARNINGS (only if applicable)
* <path>:<line> — <description>
````

```bash
git merge --no-ff <source> -F /tmp/merge-msg
```

## Worked example

`feature/shortcuts` → `development`. Six commits landing across
shortcuts, settings, cart, and specs.

````text
🐣 feat(shortcuts): merge feature/shortcuts into development

* Shortcuts: wire global keyboard dispatcher, 18 intents, default
  bindings + conflict resolution (97e7816, 72076c6).
* Shortcuts: add cash drawer denominations and clear-search actions
  (dff6b3b).
* Settings: reset-all-data section, edit-quantity intent wiring
  (ffdfe27, 3ecd5c4).
* Cart: reclaim focus after discount submission; fix cart editing
  and discount bugs (803fa79, 16d927f).
* Specs: synchronize PRD, DESIGN, ARCHITECTURE, USER_FLOW with
  shipped shortcuts ground truth (e9504b0).
* Tests: not run.
````

```bash
git merge --no-ff feature/shortcuts -F /tmp/merge-msg
```

## Localization

Detect the user's dominant language from the most recent message.
Write prose (bullets, warnings) in that language. Keep technical
identifiers verbatim — branch names, file paths, commit SHAs, type
keywords (`feat`, `fix`), and the emoji prefix stay as-is.

## Boundaries

This skill DOES:
- Read git history (`log`, `diff`, `branch`, `status`, `show`) via bash.
- Print one paste-ready merge commit message.
- Suggest the `git merge --no-ff <source> -F <tmpfile>` command.

This skill does NOT:
- Execute `git merge`, `git checkout`, `git push`, `git pull`, or any
  state-changing git command.
- Amend, rebase, force-push, or rewrite history.
- Stage, commit, or modify any file in the working tree.
- Invent commits, files, or stats not in the actual diff. If the
  landing set is empty, say so and stop.
- Guess the target branch when the user explicitly names one — honor
  it. Default is `development` only when the user does not name a
  target.

## Disengage

Say "stop merge-message" or "plain merge message" to switch to a
minimal `Merge branch '<name>' into <target>` subject with no body,
no emoji, no overview, and no legend.
