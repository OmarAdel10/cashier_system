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

### 5. Build-Time Configuration

#### 5a. DRM Ed25519 Public Key
* **Required for runtime:** Every Flutter build must pass `--dart-define=ED25519_PUBKEY_HEX=<64-char-hex>`.
* **Development tool args:** Configured in `.vscode/launch.json` under `toolArgs`.
* **Failure behavior:** `Ed25519Verifier` throws `StateError` if key is empty — builds fail fast.
* **Security:** Private key held offline, never in repository. Each deployment can use a distinct key pair.

#### 5b. HydratedBloc Initialization & Hive Encryption
* **Status:** `HydratedBloc.storage` is initialized in `main.dart` after Hive setup and before bloc creation.
* **Reason:** `SettingsBloc` and `InventoryBloc` extend `HydratedBloc` — storage must be initialized before any bloc is instantiated.
* **Impact:** Enables automatic JSON serialization/deserialization of bloc state to Hive.
* **Hive Encryption:** A 32-byte AES key is generated on first launch, persisted in `FlutterSecureStorage`. All boxes opened with `HiveAesCipher(key)` via `encryptionCipher:` parameter (not deprecated `encryptionKey`). `receipts` and `refunds` boxes use `LazyBox` for deferred loading; `audit_log` uses `LazyBox<String>` since entries are JSON strings.

#### 5c. main.dart Startup Sequence

```
1. WidgetsFlutterBinding.ensureInitialized()
2. Hive.initFlutter()
3. Register all TypeAdapters (settings, product, user, shift, receipt, refund, receipt_item)
4. Generate/persist 32-byte Hive encryption key in FlutterSecureStorage
5. Open all Hive boxes with HiveAesCipher:
   - Box<AppSettingsModel>('settings')
   - Box<AppProductModel>('inventory')
   - Box<AppUserModel>('auth_users')
   - Box<AppShiftModel>('shifts')
   - Box<String>('active_shifts')
   - LazyBox<String>('audit_log')
6. Create AuditService(box: auditBox)
7. HydratedBloc.storage = HydratedStorage.build(...)  ← AFTER Hive boxes opened
8. ensurePrintServerBuilt() — publishes .NET project to build/ if PrintServer.exe missing
9. PrintServerManager.start() — multi-candidate path resolution
10. LicenseEngine (silent async license check)
11. runApp(App(...))  ← passes all repositories, managers, cipher
```

Key ordering constraint: `HydratedBloc.storage` must be initialized AFTER `Hive.initFlutter()` because HydratedBloc uses Hive internally. The Hive encryption key must be generated before any box is opened.

#### 5d. PrintServer.exe Build-on-Demand

During development, if `PrintServer.exe` is absent from the build output directory, `main.dart` automatically runs `dotnet publish PrintServer/PrintServer.csproj -c Debug -o build/windows/x64/runner/Debug/`. Candidate paths resolved by `PrintServerManager.start()`:
1. Side-by-side with running `cashier_system.exe` (highest priority)
2. `build/windows/x64/runner/Debug/PrintServer.exe`
3. `build/windows/x64/runner/Release/PrintServer.exe`
4. `PrintServer/bin/Debug/net8.0/PrintServer.exe`
5. `PrintServer/bin/Release/net8.0/PrintServer.exe` (fallback)

---
