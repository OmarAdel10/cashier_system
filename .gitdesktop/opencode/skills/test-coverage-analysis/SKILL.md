---
name: test-coverage-analysis
description: >
  Analyze feature branch changes and map untested code. Generate test
  implementation plans for uncovered functions/widgets/components. Review
  existing tests for quality and optimization gaps. Use when feature
  implementation is done and needs test coverage assessment, or when
  user says "analyze test coverage", "find untested code", "test plan",
  "coverage report", or invokes /test-coverage-analysis.
---

# Test Coverage Analysis

Analyze the current feature branch diff. Find functions, classes, widgets, and components without tests. Draft implementation plans. Review existing tests for gaps and optimization. No mutation.

## Mode Detection

Same as commit-review skill:

| Input | Mode |
|-------|------|
| Argument passed (SHA, `HEAD~3`, branch name) | Single commit |
| No argument, HEAD on feature branch | Full branch diff |
| No argument, HEAD on base branch | Error — ask for input |

Base branches: `main`, `master`, `develop`, `development`, `staging`, `production`, `trunk`

## Workflow

### Phase 1 — Discovery

1. Detect project root, branch, base, mode
2. Compute diff: `git diff <base>..HEAD` (branch mode) or `git diff <ref>^..<ref>` (commit mode)
3. List changed source files only (exclude tests, configs, docs, assets)
4. Detect stack from manifest files, identify test runner:
   - `jest.config.*` / `vitest.config.*` / `jasmine.json` → JS/TS test runner
   - `pytest.ini` / `setup.cfg` `[tool:pytest]` / `pyproject.toml` `[tool.pytest]` → pytest
   - `pubspec.yaml` with `dev_dependencies: flutter_test` → Flutter
   - `Cargo.toml` with `[dev-dependencies]` → Rust
   - `go.mod` → Go
   - `phpunit.xml*` → PHPUnit
   - `Gemfile` with `rspec` → RSpec
   - `build.gradle*` with `testImplementation` → JUnit/Spock
5. Detect test naming conventions from existing test files:
   - `*.test.*`, `*.spec.*`, `*_test.*`, `test_*.py`, `*Test.php`, `*_test.dart`
   - Directory: `__tests__/`, `tests/`, `test/`, adjacent to source
6. Read intent docs (SPEC.md, DESIGN.md, REQUIREMENTS.md) for test expectations

### Phase 2 — Map source to test files

For each changed source file:

1. Determine expected test file path(s) based on detected conventions
2. Check if test file exists
3. If exists: read the test file, parse test names/descriptions, count assertions
4. If missing: flag as uncovered

Output a mapping table:

| Source file | Test file | Status | Tests found |
|-------------|-----------|--------|-------------|
| src/auth/login.ts | src/__tests__/login.test.ts | ✅ Covered | 3 tests |
| src/auth/register.ts | — | ❌ Missing | — |

### Phase 3 — Parse source for testable units

For each source file (covered or not), extract testable units:
- **Functions** (named, exported) — by name and signature
- **Classes** — by name, methods list
- **React/Vue/Svelte components** — by name and props
- **Flutter widgets** — by class name
- **API routes/endpoints** — by method + path
- **Utility functions** — by name
- **Hooks** (React, Vue) — by name
- **Error handlers, middleware** — by name

For each unit, note:
- Return type / output
- Parameters / inputs
- Side effects (I/O, DB, network, file system)
- Error paths
- Edge cases evident from signature

### Phase 4 — Analyze coverage

For each testable unit, classify:

| Classification | Meaning |
|---------------|---------|
| **✅ Tested — sufficient** | Good assertions, covers happy path + edge cases |
| **⚠️ Tested — partial** | Missing edge cases, error paths, or boundary conditions |
| **🔴 Tested — weak** | Trivial assertions only, doesn't test actual logic |
| **❌ Not tested** | No test exists |
| **ℹ️ Not testable** | Pure type/interface/constant, no logic |

### Phase 5 — Generate test plan

For each untested or weak-tested unit, generate a plan entry:

```markdown
### `functionName` (path/to/file.dart:42)
**Type:** async function / widget / API handler
**Test status:** ❌ Not tested | ⚠️ Partial

**Test plan:**
1. [Happy path] Call with valid input → expect expected output
2. [Error path] Call with null/invalid → expect exception/fallback
3. [Edge case] Call with boundary value → expect correct handling
4. [Side effect] Verify DB write / API call / file write behavior
5. [State change] Verify component/widget renders correctly for each state
```

### Phase 6 — Review existing tests

For each existing test file, evaluate:
- Assertion quality (specific vs generic)
- Edge case coverage (nulls, empties, boundaries, errors)
- Test isolation (no shared mutable state)
- Test speed (no unnecessary I/O, network)
- Flakiness potential (timing, ordering, external dependencies)
- Duplication (repeated setup/assertion patterns)
- Naming clarity (describes behavior, not implementation)

### Phase 7 — Output report

```markdown
# Test Coverage Analysis Report

**Mode:** single-commit | full-feature-branch
**Target:** <sha> | <branch> ← <base>
**Stack:** <language> / <framework> (test runner: <runner>)
**Coverage summary:** X% of changed source files have tests
**Testable units found:** X total | Y tested | Z untested

## Coverage Map
| Source | Test | Status | Units |
|--------|------|--------|-------|

## Untested Units — Implementation Plan
| Priority | Unit | File | Type | Test plan |
|----------|------|------|------|-----------|
| High | <name> | path:NN | function | 5 test cases |
| Medium | <name> | path:NN | widget | 3 test cases |

## Existing Tests — Review
| Test file | Verdict | Issues |
|-----------|---------|--------|
| path/test_file.test.ts | ⚠️ Partial | Missing error paths |

## Implementation Plan (ordered by priority)
### Priority 1 — High (no tests for core logic)
[Detailed plan per unit]

### Priority 2 — Medium (partial coverage)
[Detailed plan per unit]

### Priority 3 — Low (weak tests, optimization)
[Detailed plan per unit]
```

## Rules

- Only analyze files changed in the diff. No scope creep.
- Detect test conventions from existing project tests — don't assume.
- For untested pure types/interfaces/constants, mark as ℹ️ Not testable (skip plan).
- Every unit in the plan must include: happy path, error path, edge case.
- For existing tests, every review must cite specific lines.
- Do not edit any files. Read-only.
- If test runner is undetectable, ask user.
