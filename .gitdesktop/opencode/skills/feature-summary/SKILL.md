---
name: feature-summary
description: >
  Generate a self-contained handoff brief of everything done in the current
  feature branch / session, formatted for an orchestrator agent to consume.
  Distills commits, file scope, tests, and open work into one pasteable block.
  Works in any git repo; test runner auto-detected (flutter / npm / pytest / go / cargo).
  Trigger: "summary for orchestrator", "handoff brief", "feature summary",
  "session recap", "wrap up this branch", "give me the rundown", "status report".
---

# feature-summary

Produce a handoff brief that an orchestrator agent can read cold and resume work from. Output is a single fenced block — paste-ready, no extra prose.

## What to gather

Run in parallel, then synthesize:

1. **Branch state**
   - `git status` — clean / dirty
   - `git rev-parse --abbrev-ref HEAD` — branch name
   - `git log <base>..HEAD --oneline` — commits on the feature branch
   - `git log -1 <base> --oneline` — base commit
   - **Base detection:** `main` → `master` → `develop` (whichever exists locally or on origin). If none, ask before assuming.

2. **File scope** — `git diff --stat <base>...HEAD` for totals, then `git diff --name-status <base>...HEAD` for the per-file table (A/M/D/R).

3. **Commit narratives** — `git log <base>..HEAD --format="%n=== %h %s ===%n%b"` for full messages. Group into logical chunks (entity → model → repo → bloc → view → integration, or whatever the stack's natural layering is).

4. **Test state** — auto-detect runner from project markers:
   - `pubspec.yaml` → `flutter test` (or `dart test` if no `flutter:` section)
   - `package.json` with `test`/`jest`/`vitest` script → that script; else `npm test`
   - `pyproject.toml` / `pytest.ini` / `setup.py` → `pytest --tb=line -q`
   - `go.mod` → `go test ./... 2>&1 | tail -30`
   - `Cargo.toml` → `cargo test --no-fail-fast 2>&1 | tail -30`
   - `Makefile` with `test:` target → `make test`
   - None of the above → list "test runner: not detected" and skip
   Capture: total/passed/failed + shortest decisive error line if any.

5. **Test files added** — `git diff --name-only <base>...HEAD | grep -iE '(test|spec|_test\.|\.spec\.)'`

6. **Spec / doc deltas** — `git diff --name-only <base>...HEAD | grep -iE '(spec|doc|readme|changelog)'` for anything the orchestrator should know changed in the contract.

7. **Uncommitted work** — `git status --porcelain` (if anything dirty, surface it; otherwise omit the section).

8. **TODO / open threads** — grep the diff for `TODO|FIXME|XXX|HACK` markers (`git diff <base>...HEAD | grep -nE '(TODO|FIXME|XXX|HACK):'`).

## Output format

One fenced ` ```handoff ` block, this exact shape:

```handoff
BRANCH: <name>  BASE: <base>@<sha>  STATUS: <clean|dirty>
COMMITS: <N>  FILES: +<A>/-<D>  TESTS: <runner> <passed>/<total> [<failing>]

## Goal
<1-2 lines: what this feature/session is trying to ship>

## What shipped
<bulleted, in stack order — domain → data → presentation → integration, or whatever fits the repo>

## Files touched
<A|M|D|R  path/to/file>  (one per line, grouped by feature area)

## Test status
- <runner>: <passed>/<total> pass
- <notable coverage gaps, if any>

## Open threads
- <uncommitted work, TODOs in diff, follow-up tasks>

## Suggested next step
<one line — what an orchestrator should do first when picking this up>
```

## Rules

- **Single block.** No prose before or after the ` ```handoff ` fence. The orchestrator only reads the block.
- **Caveman-compressed** by default — fragments OK, drop articles. If the user asks for `prose` or `detailed`, switch to full sentences (still one block).
- **Cite commits by short SHA** (`a9625fd`) so the orchestrator can `git show` them.
- **Group by feature area**, not by commit order, when commits are small/atomic.
- **Surface, don't fix** — open threads are listed, not resolved.
- **Skip empty sections** — if no uncommitted work, no TODO markers, no spec changes, drop the section entirely. Don't write "None" padding.
- **Verify before claiming tests pass.** Run the suite. If it fails, say so with the shortest decisive error line.
- **One invocation per handoff.** Don't re-run on partial diffs.
- **Repo-agnostic.** Works in any git repo. Runner auto-detect, base-branch auto-detect. If detection fails, say so explicitly and ask — don't guess.

## Example output

```handoff
BRANCH: feature/inventory  BASE: master@29e924e  STATUS: clean
COMMITS: 8  FILES: +5293/-140  TESTS: flutter 42/42

## Goal
Ship Inventory feature: domain entity → Hive model → repo → HydratedBloc → workspace UI, with full ar/en localization.

## What shipped
- Domain: `ProductEntity` (ef7c7bc) with name/qty/price fields
- Data: `AppProductModel` Hive typeId=1, JSON+Hive codecs (2b1732b)
- Repo: `InventoryRepository` implementing `IInventoryRepository` (189978a, 213-line test)
- Bloc: `InventoryBloc` w/ HydratedBloc persistence + `LoadInventory`/`AddProduct`/... (62a8e17, 180-line test)
- UI: `InventoryWorkspace` two-column (normal + quick tiles), `ProductFormDialog` (4985467, a9625fd)
- i18n: 22 keys ar+en, `{0}` param interpolation, `LoadInventory` dispatched in `app.dart` (6ca63fa)
- Cleanup: removed unused imports (5a4bec7)

## Files touched
A  lib/features/inventory/domain/entities/product_entity.dart
A  lib/features/inventory/data/models/app_product_model.dart
A  lib/features/inventory/data/repositories/inventory_repository.dart
A  lib/features/inventory/presentation/bloc/inventory_bloc.dart
A  lib/features/inventory/presentation/bloc/inventory_event.dart
A  lib/features/inventory/presentation/bloc/inventory_state.dart
A  lib/features/inventory/presentation/views/inventory_workspace.dart
A  lib/features/inventory/presentation/views/product_form_dialog.dart
A  lib/features/inventory/presentation/views/inventory_workspace_test.dart
A  test/features/inventory/...
M  lib/app.dart
M  lib/main.dart
M  lib/presentation/app_shell.dart
A  specs/DEVLOPMENT_ENVIRONMENT.md
A  specs/PRD.md
A  specs/USER_FLOW.md

## Test status
- flutter test: 42/42 pass
- Coverage: entity + model + repo + bloc + workspace all have dedicated test files

## Suggested next step
Run `flutter analyze` then wire inventory into AppShell navigation if not already routed.
```

## Boundaries

- **Read-only.** Queries git + test runner, never touches source.
- **No commits, no pushes.** Handoff is informational; the orchestrator decides.
- **Caveman default**, prose on request. Honor user's dominant language.
