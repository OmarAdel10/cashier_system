# Development Environment & Branch Architecture Workspace
## Project: Premium Stationery POS System (المكتبة)

### 1. Repository Core Path Infrastructure
* **Master Base Directory:** `/mnt/ALL/CashierSystem/` (Houses the master tracking layer).
* **Worktree Target Matrix:** `/mnt/ALL/CashierSystemWorktrees/` (Dynamic branch directory execution pool).

### 2. Feature Branching & Isolated Worktree Lifecycle
* **Strict Thread Isolation:** Every independent feature, custom module, or screen layout configuration must reside on its own dedicated, isolated Git branch. Inter-branch leakage or modifications to unrelated feature domains within a single branch is strictly forbidden.
* **Worktree Creation Pattern:** For every new task, a matching physical path must be allocated in the target directory matrix before execution begins.
* **Integration Rule:** Completed features are structurally synchronized exclusively via a unified `git merge` execution back into the core `development` branch, backed by an explicit merge overview summary.

### 3. Automated Agent Commit Protocol
Every micro-incremental state change must be committed using the standard structural template below. The agent must parse staged changes via `git diff --staged` and format the string precisely:

```text
<emoji> <type>(<scope>): <summary>

* Detailed bulleted list of functional implementations.
* Architectural impacts or state engine changes.

⚠️ WARNINGS (Include ONLY if secrets, console logs, or outstanding TODOs are caught in diff review)

#### Commit Legend Reference
* 🐣 `feat` : Structural system updates / screen implementations
* 🐞 `fix` : Execution bug remediation logic
* 📄 `docs` : Updates to specification configurations
* 🎨 `style` : Aesthetic layout tweaks / visual properties adjustments
* ✏️ `refactor` : Non-functional core optimization rewrites
* ⚡ `perf` : Speed enhancements for weak hardware performance baselines
* 🏗️ `chore` : Internal package builds / script dependencies mapping
```

#### Formatting Matrix Restrictions
* **Subject line:** Under 50 absolute characters, imperative mood string profile.
* **Character Escaping Rule:** Never write standard double quotes (`"`) anywhere in the commit payload block; enforce single quote (`'`) representation exclusively.

### 4. CI/CD Pipeline

#### 4a. Development CI (`development` branch)
* **File:** `.github/workflows/development.yml`
* **Trigger:** Pushes and PRs targeting `development`
* **Steps:**
  1. `flutter pub get`
  2. `flutter analyze` — static analysis gate
  3. `flutter test` — Flutter test suite
  4. `dotnet test PrintServer.Tests` — .NET PrintServer test suite
* **Purpose:** Quality gate before merging into `development`.

#### 4b. Production Deployment (`master` branch)
* **File:** `.github/workflows/master.yml`
* **Trigger:** Pushes to `master` (standard and version tags `v*`)
* **Runs on:** `windows-latest` (required for .NET PrintServer builds)

| Condition | Action |
|---|---|
| Standard push to `master` (no version tag) | `shorebird patch windows` — OTA patch via Shorebird |
| Version tag push (`git push origin v1.0.0`) | 1. `shorebird release windows` — full Shorebird release |
| | 2. InnoSetup compile → `innosetup_config.iss` bundles Flutter exe + .NET PrintServer binaries |
| | 3. Upload `Output/Setup.exe` as build artifact |

#### 4c. InnoSetup Installer
* **File:** `innosetup_config.iss`
* **Bundles:**
  * `build/windows/x64/runner/Release/cashier_system.exe` — Flutter Windows executable
  * All supporting DLLs, shaders, data folders from Flutter build
  * `PrintServer/bin/Release/net8.0/*` — Standalone .NET PrintServer sidecar binaries
* **Desktop shortcut:** Optional (unchecked by default)
* **Output:** `Output/Setup.exe`

#### 4d. Shorebird
* **Config:** `shorebird.yaml` linked as Flutter asset
* **API Key:** Stored in GitHub Secrets as `SHOREBIRD_API_KEY`
* **OTA Patching:** Standard pushes to `master` trigger instant Shorebird OTA patch without requiring user reinstall.

---
