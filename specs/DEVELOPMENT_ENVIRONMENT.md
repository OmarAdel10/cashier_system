# Development Environment & Branch Architecture Workspace
## Project: Premium Stationery POS System (المكتبة)

### 1. Repository Core Path Infrastructure
* **Master Base Directory:** `/mnt/ALL/CashierSystem/` (Houses the master tracking layer).
* **Worktree Target Matrix:** `/mnt/ALL/CashierSystemWorktrees/` (Dynamic branch directory execution pool).

### 2. Feature Branching & Isolated Worktree Lifecycle
* **Strict Thread Isolation:** Every independent feature, custom module, or screen layout configuration must reside on its own dedicated, isolated Git branch. Inter-branch leakage or modifications to unrelated feature domains within a single branch is strictly forbidden.
* **Branch Work Location:** In current practice, feature branches are checked out directly inside the master base (`/mnt/ALL/CashierSystem/`) — e.g. `feature/inventory` — not in a separate worktree. The worktree target matrix `/mnt/ALL/CashierSystemWorktrees/` exists as an optional isolation pool but is currently empty/unused (no registered worktrees). Agents may use it for high-conflict parallel work; otherwise work in the main checkout.
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
* **Runs on:** `windows-latest` (both CI workflows use Windows)
* **Toolchain:** .NET SDK `8.0.x`, Flutter `stable` channel
* **Steps:**
  1. `flutter pub get`
  2. `flutter analyze` — static analysis gate
  3. `flutter test` — Flutter test suite
  4. `dotnet test PrintServer.Tests/PrintServer.Tests.csproj --configuration Release --blame-hang-timeout 2m` — .NET PrintServer test suite
* **Purpose:** Quality gate before merging into `development`.

#### 4b. Production Deployment (`master` branch)
* **File:** `.github/workflows/master.yml`
* **Trigger:** Pushes to `master` (standard and version tags `v*`)
* **Runs on:** `windows-latest` (required for .NET PrintServer builds)

| Condition | Action |
|---|---|
| Standard push to `master` (no version tag) | `shorebird patch windows` — OTA patch via Shorebird |
| Version tag push (`git push origin v1.0.0`) | 1. `flutter analyze` + full test gate (Flutter + .NET) runs first |
| | 2. `shorebird release windows -- --obfuscate --split-debug-info=symbols` — full Shorebird release |
| | 3. InnoSetup compile → `innosetup_config.iss` bundles Flutter exe + .NET PrintServer binaries |
| | 4. Upload `Output/Setup.exe` as artifact `CashierSystem-Windows-Setup` |
| | 5. Create GitHub Release (softprops/action-gh-release) with `Output/Setup.exe` attached + auto-generated release notes |

#### 4c. InnoSetup Installer
* **File:** `innosetup_config.iss`
* **Bundles:**
  * `build/windows/x64/runner/Release/cashier_system.exe` — Flutter Windows executable
  * All supporting DLLs, shaders, data folders from Flutter build
  * `PrintServer/bin/Release/net8.0/*` — Standalone .NET PrintServer sidecar binaries
* **Desktop shortcut:** Optional (unchecked by default)
* **Language:** English only (`Default.isl`)
* **Setup icon:** `assets/icon/pos_cashier_icon.ico`
* **Output:** `Output/Setup.exe`

#### 4d. Shorebird
* **Config:** `shorebird.yaml` linked as Flutter asset (pubspec `assets:`); `auto_update` left at default (enabled, OTA applied in background on launch)
* **API Token:** Stored in GitHub Secrets as `SHOREBIRD_TOKEN` and passed to the Shorebird CLI via `secrets.SHOREBIRD_TOKEN`
* **OTA Patching:** Standard pushes to `master` trigger instant Shorebird OTA patch without requiring user reinstall.

### 5. Build-Time Configuration

#### 5a. DRM Ed25519 Public Key
* **Required for runtime:** Every Flutter build must pass `--dart-define=ED25519_PUBKEY_HEX=<64-char-hex>`.
* **Development tool args:** Configured in `.vscode/launch.json` under `toolArgs`.
* **Failure behavior:** `Ed25519Verifier` throws `StateError` if key is empty — builds fail fast.
* **Security:** Private key held offline, never in repository. Each deployment can use a distinct key pair.

#### 5b. Explicit Hive Persistence & Encryption
* **Status:** Feature blocs are plain `Bloc`/`Cubit` classes. Settings and inventory state are persisted explicitly through Hive-backed repositories; `HydratedBloc` is not initialized or used.
* **Hive Encryption:** A 32-byte AES key is generated on first launch, persisted in `FlutterSecureStorage` (base64Url-encoded under key `hive_encryption_key`). All boxes opened with `HiveAesCipher(key)` via `encryptionCipher:` parameter (not deprecated `encryptionKey`). The `receipts` and `refunds` boxes use `LazyBox` for deferred loading — they are opened in `AppShell._openBoxes()` (`lib/presentation/app_shell.dart:107-126`) with the same cipher, NOT in `main.dart`; `audit_log` uses `LazyBox<String>` since entries are JSON strings.

#### 5c. main.dart Startup Sequence

```
1. WidgetsFlutterBinding.ensureInitialized()
2. Hive.initFlutter()
3. Register all hand-written TypeAdapters used by settings, inventory, auth, receipts, expenses, stations, sessions, zones, tables, and table rounds
4. Generate/persist 32-byte Hive encryption key in FlutterSecureStorage
5. Open all Hive boxes with HiveAesCipher:
  - settings, inventory, auth_users, shifts, active_shifts, product_categories
  - stations, session_records, floor_zones, tables, table_rounds
  - LazyBox<String>('audit_log') and LazyBox<AppExpenseModel>('expenses')
6. Create AuditService(box: auditBox)
7. `PrintServerFactory.create()` — selects the Windows, Linux, or no-op manager
8. Platform-specific PrintServer publish/check:
  - Windows: publish `PrintServer/PrintServer.csproj` to `build/windows/x64/runner/Debug/` when needed
  - Linux: publish `PrintServer.Linux/PrintServer.Linux.csproj` as self-contained `linux-x64` to `build/linux/x64/release/bundle/PrintServer/` when needed
9. Start the selected manager only when a usable executable exists
10. LicenseEngine (silent async license check)
11. runApp(App(...))  ← passes all repositories, managers, cipher
```

Key ordering constraint: the Hive encryption key must be generated before any box is opened. Feature blocs are created only after their repositories and boxes are available.

**Note — no codegen:** Hive TypeAdapters are hand-written in `lib/` and registered explicitly by `main.dart`. `hive_generator`/`build_runner` are dev-dependencies but unused — `dart run build_runner build` generates nothing. Adapter changes are manual edits (field index + count byte must stay balanced).

#### 5d. Windows PrintServer Build-on-Demand

During development, if `PrintServer.exe` is absent from the build output directory, `main.dart` automatically runs `dotnet publish PrintServer/PrintServer.csproj -c Debug -o build/windows/x64/runner/Debug/`. Candidate paths resolved by `PrintServerManager.start()` (in priority order):
1. Side-by-side with running `cashier_system.exe` (highest priority)
2. Installed production layout: `exeParent/PrintServer/PrintServer.exe` (Inno Setup places sidecar under `{app}\PrintServer`)
3. `build/windows/x64/runner/Debug/PrintServer.exe`
4. `build/windows/x64/runner/Release/PrintServer.exe`
5. `PrintServer/bin/Debug/net8.0/PrintServer.exe`
6. `PrintServer/bin/Release/net8.0/PrintServer.exe` (fallback)

#### 5e. Linux PrintServer and CUPS Integration

Linux uses a separate .NET 8 sidecar in `PrintServer.Linux/`, selected by
`PrintServerFactory` when `Platform.isLinux`. It is published as a
self-contained `linux-x64` binary, so the deployed machine does not need a
separate .NET runtime. During development, `main.dart` runs:

```text
dotnet publish PrintServer.Linux/PrintServer.Linux.csproj \
  -c Release -r linux-x64 --self-contained \
  -o build/linux/x64/release/bundle/PrintServer
```

The Linux manager (`lib/core/printing/print_server_manager_linux.dart`):

* probes and adopts a healthy sidecar already listening on `127.0.0.1:5150`;
* removes stale instances using Linux `ss`, `ps`, and `kill` tooling;
* launches `PrintServer.Linux` with `--parent-pid`, allowing the sidecar to
  terminate when the Flutter process exits or crashes;
* checks the health response and API version before accepting the process;
* searches side-by-side, installed `/opt/cashier-system/PrintServer/`, Flutter
  release-bundle, and `PrintServer.Linux/bin` locations.

`PrintServer.Linux` binds only to loopback, applies host filtering for
`127.0.0.1` and `localhost`, limits request bodies to 8 MiB, and rate-limits
the API to 30 requests per second. Printer discovery and output use CUPS via
`CupsPrinterService`. The Linux API exposes the same local routes as the
Windows client contract: health, local printers, receipt, barcode, ticket,
PNG, invoice PDF, sales-export PDF, and SVG validation. Receipt and PDF/image
rendering use the bundled Arabic fonts plus BidiReshapeSharp and HarfBuzz.

Linux runtime prerequisites are a working CUPS installation and `dotnet`
only when publishing from source. Production deployments use the
self-contained sidecar. The Linux Flutter runner is generated under
`linux/runner/` and is built with the standard Flutter Linux desktop toolchain.

#### 5f. Linux CI and Release Packaging

Linux validation runs in GitHub Actions on Ubuntu. The workflow installs the
Flutter/Linux desktop toolchain, `libcups2-dev`, and RPM tooling, then runs
Flutter analysis/tests, builds `PrintServer.Linux` for `linux-x64`, and runs
`PrintServer.Linux.Tests`. The Linux release workflow additionally builds the
Flutter Linux bundle and packages it as an AppImage and an RPM using
`packaging/linux/RPM/build-rpm.sh`. It verifies the RPM metadata/file list and
uploads the Linux artifacts. The Windows release workflow remains separate and
continues to produce the Inno Setup installer.

---
