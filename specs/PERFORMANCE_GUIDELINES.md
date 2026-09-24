# Flutter Performance & Architecture Guidelines
## Project: Cashier System

### 1. Bloc State Selection: `context.select` over `context.watch`

**Rule:** Always use `context.select` with a field-level selector instead of `context.watch` on the entire Bloc state.

```dart
// BAD — rebuilds on any SettingsState change
final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

// GOOD — rebuilds only when languageCode changes
final langCode = context.select(
  (SettingsBloc b) => b.state.settings.languageCode,
);
```

**Rationale:** `context.watch` rebuilds the entire widget subtree on every Bloc state emission. `context.select` only rebuilds when the specific selected value changes — critical for widgets that only read one field (e.g., language code, tax percent) while other fields change frequently.

### 2. Local UI State: `ValueNotifier` over `setState`

**Rule:** Use `ValueNotifier<T>` + `ValueListenableBuilder` for local UI state instead of `setState` in `StatefulWidget`.

```dart
// BAD — rebuilds entire StatefulWidget
bool _submitting = false;
setState(() => _submitting = true);

// GOOD — only rebuilds the specific subtree
final _submittingNotifier = ValueNotifier(false);
_submittingNotifier.value = true;
ValueListenableBuilder<bool>(
  valueListenable: _submittingNotifier,
  builder: (_, submitting, __) => submitting ? LinearProgressIndicator() : SizedBox(),
);
```

**Rationale:** `setState` triggers a full rebuild of the widget and all its children. `ValueNotifier` + `ValueListenableBuilder` scopes rebuilds to only the widgets that depend on that value.

**Grouping Rule:** Group related boolean/numeric UI state fields into immutable `copyWith` classes:

```dart
// Mirrors CaptureState in lib/features/shortcuts/presentation/widgets/key_capture_dialog.dart:8-42
class CaptureState {
  final LogicalKeyboardKey? capturedKey;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;
  final bool hasCaptured;

  const CaptureState({
    this.capturedKey,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.hasCaptured = false,
  });

  CaptureState copyWith({
    LogicalKeyboardKey? capturedKey,
    bool? ctrl,
    bool? alt,
    bool? shift,
    bool? meta,
    bool? hasCaptured,
  }) {
    return CaptureState(
      capturedKey: capturedKey ?? this.capturedKey,
      ctrl: ctrl ?? this.ctrl,
      alt: alt ?? this.alt,
      shift: shift ?? this.shift,
      meta: meta ?? this.meta,
      hasCaptured: hasCaptured ?? this.hasCaptured,
    );
  }
}

// Single notifier instead of 6
final _state = ValueNotifier(CaptureState());
```

### 3. Widget Extraction: No Private Inline Widgets Beyond ~20 Lines

**Rule:** Extract any private widget exceeding ~20 lines to a standalone public file in `widgets/` subdirectory.

```dart
// BAD — inline _FooWidget bloating parent file
class _MyWidget extends StatelessWidget { /* 25 lines */ }

// GOOD — extracted file
// lib/features/checkout/presentation/widgets/my_widget.dart
class MyWidget extends StatelessWidget {
  final String langCode;
  final VoidCallback onTap;
  // ...
}
```

**Explicit Dependencies:** Extracted widgets receive dependencies as explicit constructor parameters — they do NOT call `context.watch` or `context.read` for their inputs. This makes them testable and decouples them from ancestor widget structure.

### 4. `BlocBuilder` + `buildWhen`: Narrow Rebuild Scope

**Rule:** Add a `buildWhen` predicate to every `BlocBuilder` that does not need to rebuild on every state change.

```dart
BlocBuilder<SalesBloc, SalesState>(
  buildWhen: (prev, curr) =>
    prev.status != curr.status ||
    prev.todaySummary != curr.todaySummary ||
    prev.shiftReceipts != curr.shiftReceipts ||
    !listEquals(prev.months, curr.months),
  builder: (context, state) { /* ... */ },
);
```

**Rationale:** Without `buildWhen`, `BlocBuilder` rebuilds on every emission including background events (e.g., `LoadTodaySummary` triggering while `LoadShiftReceipts` is already displayed).

### 5. Hive API: `encryptionCipher` over `encryptionKey`

**Rule:** Always pass `HiveAesCipher(key)` via the `encryptionCipher:` parameter — never the raw `encryptionKey:` parameter.

```dart
// CURRENT
final cipher = HiveAesCipher(encryptionKey);
final settingsBox = await Hive.openBox<AppSettingsModel>(
  'settings',
  encryptionCipher: cipher,
);
```

All Hive boxes opened at startup follow this pattern — the encrypted settings,
inventory, auth, shift, category, station, session, zone, table, round, audit,
and expense boxes opened by `main.dart`, plus the encrypted receipts/refunds
lazy boxes opened by `AppShell`.

### 6. State Widgets: Prefer `AppEmpty` / `AppLoading` / `AppError`

**Rule:** Use the canonical shared state widgets from `lib/core/widgets/` instead of ad-hoc inline state rendering.

| Widget | File | Use Case |
|---|---|---|
| `AppLoading` | `lib/core/widgets/app_loading.dart` | Medium-to-long operations — 2px hairline `LinearProgressIndicator` |
| `AppEmpty` | `lib/core/widgets/app_empty.dart` | Empty state — Duotone icon + headline + body + optional action |
| `AppError` | `lib/core/widgets/app_error.dart` | Error state — warning/xCircle icon + headline + retry `ElevatedButton` |

**Banned:** `CircularProgressIndicator` for full-screen/block-level loading states (continuous spin loop causes frame drops on integrated graphics). Full-screen and block-level loading must use `AppLoading` — the 2px hairline bar (`lib/core/widgets/app_loading.dart:23`) — or the typographic-only pattern (see `DESIGN.md` §6.2).

**Allowed:** `CircularProgressIndicator` as an in-button spinner for async actions (e.g., login submit, save dialog confirm) or as a small transient dialog status indicator.

**Current-state inventory (15 usages in `lib/`):**

| File:Line | Context | Status |
|---|---|---|
| `login_screen.dart:127` | login submit button spinner | Allowed (in-button) |
| `activation_input.dart:91` | activation key submit button spinner | Allowed (in-button) |
| `receipt_detail_dialog.dart:366` | dialog action button spinner | Allowed (in-button) |
| `checkout_confirmation_dialog.dart:97` | checkout dialog status spinner (64×64) | Allowed (in-dialog status) |
| `refund_confirmation_dialog.dart:150` | refund confirm button spinner | Allowed (in-button) |
| `month_card.dart:77` | month card action spinner | Allowed (in-button) |
| `order_total_section.dart:68` | pay button spinner | Allowed (in-button) |
| `printing_section.dart:148` | print test button spinner | Allowed (in-button) |
| `admin_general_section.dart:163` | settings save button spinner | Allowed (in-button) |
| `add_user_dialog_actions.dart:33` | add-user confirm button spinner | Allowed (in-button) |
| `change_password_dialog_actions.dart:33` | change-password confirm button spinner | Allowed (in-button) |
| `onboarding_setup_screen.dart:156` | setup submit button spinner | Allowed (in-button) |
| `app.dart:99` | license-check full-screen splash | **Violation — use `AppLoading`** |
| `activation_screen.dart:104` | activation block-level state | **Violation — use `AppLoading`** |
| `user_management_section.dart:54` | user-list block-level loading | **Violation — use `AppLoading`** |

### 7. Known Deviations & Hot Paths (current state, filed for optimization)

The behaviors below are **current code reality** and are documented here as acknowledged debt — not as sanctioned practice. Each is filed for optimization; do not treat this section as an allowance to introduce similar patterns.

1. **Per-sale stock mutation is sequential per-item Hive get+put**, and the receipt is written twice per sale (initial save + post-stock-update save): `lib/features/receipts/presentation/bloc/receipts_bloc.dart:188-197,177,204`; per-item get+put in `lib/features/inventory/data/repositories/inventory_repository.dart:123-150`. The same per-item pattern repeats on refund (`receipts_bloc.dart:322-329`) and modify (`receipts_bloc.dart:439,589`).
2. **Post-sale `RefreshInventory` performs 2 full Hive scans** (inventory + quick tiles) plus a full-inventory JSON hydration write (`lib/presentation/app_shell.dart:288`; `lib/features/inventory/presentation/bloc/inventory_bloc.dart:128-146,170-189`).
3. **Search emits per keystroke with status `ready`**, triggering a full-inventory JSON hydration write per keystroke (`lib/features/inventory/presentation/bloc/inventory_bloc.dart:89-101`).
4. **`audit_log` writes are unbounded-ish**: every `log()` = LazyBox `add` + O(n) prune scan with per-entry `getAt` disk reads, rate-limited to once/minute max (`lib/core/audit/audit_service.dart:25-26,46-59`). Fires per sale and per stock failure.
5. **Unbounded in-memory receipts state**: `receipts_bloc.dart:230-235` appends to `state.receipts` without trimming, while `LoadReceipts` caps at 500 (`lib/features/receipts/data/repositories/receipts_repository_impl.dart:43-56`). `SalesBloc` additionally accumulates full `MonthGroupedData` + `shiftReceipts` + `todaySummary` duplicates.
6. **8 `BlocBuilder`s lack `buildWhen`** (violates §4): `lib/features/checkout/presentation/views/checkout_workspace.dart:44`, `lib/features/shortcuts/presentation/widgets/global_shortcut_gate.dart:72`, `lib/app.dart:182`, `lib/app.dart:201`, `lib/presentation/app_shell.dart:503`, `lib/features/auth/presentation/widgets/user_management_section.dart:25`, `lib/features/checkout/presentation/widgets/quick_tiles_grid.dart:24`, `lib/features/inventory/presentation/views/product_form_dialog.dart:401`.
7. **20 private inline widgets, several >20 lines** (violates §3), e.g., `_QuickTile` (`quick_tiles_grid.dart:60-110`), `_CartTableRow` (`cart_table_widget.dart:358`), `_NavRail`/`_NavRailItem` (`app_shell.dart:454,527`), `_CashButton` (`cash_drawer_assistant.dart:291`), `_ReceiptHeader`/`_ReceiptBody`/`_ReceiptSummary` (`checkout_tower_panel.dart`). Extracted widgets call `context.read`/`context.select` directly, contradicting the Explicit Dependencies clause (`quick_tiles_grid.dart:22,67,74`, `lib/features/receipts/presentation/widgets/status_badge.dart:16`, `checkout_tower_panel.dart:26-27`, `lib/features/sales/presentation/widgets/shift_receipt_list.dart:125`, `lib/features/receipts/presentation/widgets/receipt_detail_dialog.dart:43`, `lib/features/auth/presentation/widgets/user_card.dart:133`).
8. **`UpdateOrderCounter` event is dead code** — order counter lives in `ShiftBloc`. Event defined (`lib/features/settings/presentation/bloc/settings_event.dart:61`) and handler registered (`lib/features/settings/presentation/bloc/settings_bloc.dart:163-171`) but never dispatched; `lib/app.dart:155-162` delegates to `IncrementShiftOrderCount` instead (`lib/features/auth/presentation/bloc/shift_bloc.dart:98-109`).
9. **All receipt queries scan the full LazyBox with per-entry `getAt`**: `getAll`/`getByShift`/`getByMonth`/`getByDate`/`getByStockNotUpdated` (`lib/features/receipts/data/repositories/receipts_repository_impl.dart:43-125`); startup `retryPendingStockUpdates` adds another full scan (`lib/presentation/app_shell.dart:178`, `lib/features/receipts/presentation/bloc/receipts_bloc.dart:58-102`).

10. **ReceiptsBloc second save after stock updates**: The receipt is written a second time after stock decrement attempts to persist `stockUpdated` and `stockFailedBarcodes` flags (`lib/features/receipts/presentation/bloc/receipts_bloc.dart:227-240`). This doubles the write cost per sale. If the second save fails, the error is emitted but the receipt already exists with `stockUpdated: false`.

11. **Empty barcode checks in stock retry/decrement loops**: Both `retryPendingStockUpdates` and `CreateReceipt` stock decrement now skip items with empty barcodes (`lib/features/receipts/presentation/bloc/receipts_bloc.dart:67,214`). While this prevents errors on malformed items, it adds a branch per item in hot paths.

---

### 8. Cloudflare Workers Backend Performance Considerations

#### 8.1 Network Latency & Caching
* **API Calls:** All Cloudflare Workers calls (daftari-api, daftari-realtime) add network latency. Use `context.select` to minimize rebuilds while waiting for responses.
* **Auth Token Reuse:** Firebase ID tokens are cached by Firebase Auth; `ApiClient` passes the same token for all requests in a session -- no redundant token refresh.
* **In-Memory Analytics Queue:** `AnalyticsService` batches up to 50 events before flushing -- reduces HTTP overhead. Queue lost on app close (acceptable for analytics).

#### 8.2 HWID Provider Performance
* **Windows WMI:** `WindowsHwidProvider` runs 5 `wmic` processes sequentially. Cache the HWID after first successful retrieval -- `LicenseEngine.getDeviceId()` already caches.
* **Linux System Files (Experimental / Development Only):** `LinuxHwidProvider` reads multiple files (`/etc/machine-id`, `/proc/cpuinfo`, etc.) and optionally runs `dmidecode`/`lsblk`. Cache result; avoid `dmidecode` in hot paths (requires root). Linux HWID support is experimental/development only.
* **Fallback Cost:** Stub providers are O(1) -- no performance concern.

#### 8.3 Theme Manager Performance
* **ThemeData Construction:** `ThemeManager._loadTheme()` creates new `ThemeData` on each switch. Acceptable for user-initiated theme changes (rare). Do NOT call in build methods.
* **Style Lists:** `getReceiptStyles()`, `getInvoiceStyles()`, `getExportStyles()` return new lists each call. Cache if called frequently.
* **RecommendedBadge:** `getRecommendedBadge()` is O(1) switch -- negligible.

#### 8.4 Migration Framework Performance
* **MigrationRunner:** Runs once at startup. Dry-run mode available for CI validation without side effects.
* **Retry Backoff:** Exponential backoff (100ms, 200ms, 400ms) prevents hammering on transient failures.
* **Rollback:** Reverse-order execution; each `down()` should be fast (typically no-op for box creation migrations).

#### 8.5 Print Service Refactor Performance
* **Factory Singleton:** `PrintServiceFactory.instance` returns cached instance -- avoids repeated platform detection.
* **HTTP Client Reuse:** Each platform service (`WindowsPrintService`, `LinuxPrintService`, etc.) uses a single `http.Client` -- connection pooling via `http` package.
* **Timeouts:** Linux service (Experimental / Development Only) has explicit timeouts (10s GET, 30s POST) -- prevents hanging on unresponsive PrintServer.
* **SVG Validation:** 500KB size limit on SVG validation -- prevents DoS via oversized payloads.

#### 8.6 Shard Manager Performance
* **Tiered Checks:** `ShardManager.checkTenantLimit()` and `checkTotalDbLimit()` are pure math -- O(1), no I/O.
* **Integration Point:** Call before large writes (e.g., bulk CSV import, sales export) to prevent quota exhaustion.

#### 8.7 Pricing Tier Device Limits
* **Client-Side Pre-Check:** `DeviceLimitChecker.checkDeviceLimit()` is O(1) -- use before calling `SessionSyncService.startSession()` to avoid 409 round-trip.
* **Server-Side Enforcement:** Actual limit enforced at `/sessions/start` -- client check is optimization only.

---

### 9. Updated Known Deviations (Hot Paths)

12. **HWID Provider not cached in SessionSyncService**: `SessionSyncService.startSession()` calls `HwidProvider.getHwid()` directly each time. Should cache HWID at app startup and reuse.
13. **Analytics queue flush on every event**: `AnalyticsService.track()` flushes immediately (no debounce). Consider batching with 5s debounce for high-frequency events.
14. **PrintServiceFactory.create() called per print operation**: Consumers call `create()` instead of using singleton `instance`. Each call does platform detection (cheap but unnecessary).
15. **ThemeManager style lists recreated on each access**: `getReceiptStyles()`/`getInvoiceStyles()`/`getExportStyles()` allocate new lists. Cache with `late` initializers if accessed frequently.
16. **EnvConfig/FlavorConfig static late fields**: Initialized once at startup -- no runtime overhead after init.
