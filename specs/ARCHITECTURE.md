# System Architecture & Technical Specification
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Architectural Framework
The system implements **Clean Architecture** organized around a **Feature-First** structural paradigm. Each system module (`checkout`, `inventory`, `sales_history`, `settings`, `shortcuts`) must be strictly segregated into independent computational layers to satisfy SOLID design principles.

```
lib/
├── core/                      # Shared cross-cutting concerns
│   ├── error/                 # Failure hierarchy
│   ├── theme/                 # Design tokens (spacing, text styles, app theme)
│   └── widgets/               # Reusable widgets (SectionCard, AnimatedCounter, ValidatedField, AppEmpty, AppLoading, AppError)
└── features/
└── [feature_name]/
├── data/                      # Data Transfer Objects (DTOs), Services, Repo Impl
│   ├── models/                # JSON/Hive serializable DTOs
│   ├── services/              # Business services (e.g., LocalizationService)
│   └── repositories/          # Repository implementations
├── domain/                    # Pure Business Entities, Abstract Contracts
│   ├── entities/              # Immutable domain entities
│   └── repositories/          # Abstract repository interfaces
└── presentation/              # HydratedBLoC/Cubit state logic, UI Layout Widgets
├── bloc/                      # Bloc event, state, and bloc class files
└── views/                     # UI screen widgets
```

### 2. Concrete Technology Stack 
* **UI Framework:** Flutter Desktop (Native Windows Compilation targeting C++ engine binary).
* **State Management & Local Cache Engine:** HydratedBLoC running on top of a pure Dart Hive key-value storage layout. State modifications automatically serialize asynchronously directly to the local disk in JSON formats.
* **Hive Encryption:** All Hive boxes encrypted via `flutter_secure_storage`-derived key.
* **Barcode Layout Engine:** `barcode_widget` package using native vector rendering mechanics.
* **Barcode Export:** `RenderRepaintBoundary.toImage()` for PNG capture; `file_picker` for directory selection.
* **UUID Generation:** `uuid` package for entity IDs (shift entities, receipts).
* **Localization Implementation Engine:** Dedicated `LocalizationService` class housing an $O(1)$ `Map<String, Map<String, String>>` structural dictionary (bypassing `intl` code-generation to keep memory profiles minimal). The service exposes a `translate(String key, {String? languageCode, List<String>? params})` method and static `supportedLanguages` getter. `SettingsWorkspace` UI reads locale from `SettingsState.settings.languageCode` and passes it to the service for string resolution (`localizationService.translate(key)`). Parameter interpolation via `{0}`, `{1}` etc. is supported through the optional `params` list.
* **Core Shared Widgets:**
  * `SectionCard` (`lib/core/widgets/section_card.dart`): Universal card container with optional notch title, actions, configurable padding/sizing/flex fit. Renders as `Card` with `surfaceContainerLow` background, `outlineVariant` border, 12px radius.
  * `AnimatedCounter` (`lib/core/widgets/animated_counter.dart`): Lightweight text value transition via `AnimatedSwitcher` + `FadeTransition` (200ms).
  * `ValidatedField` (`lib/core/widgets/validated_field.dart`): Rule-based validation with visual state feedback (none/valid/invalid), prefix icons, input formatters, and last-field submission.

### 3. Data Structures & Performance Optimization Rules 

#### Rule 1: O(1) Fast Inventory Lookup Map
To ensure lightning-fast item ingestion during high-volume cashier rushes on poor hardware, the central application state must store products inside an optimized **Hash Map** layout rather than a linear array list.
* **Data Layout:** `Map<String, ProductEntity>` where the **Key is the Barcode String**.
* **Performance Baseline:** Search evaluation runs at constant $O(1)$ time complexity, ensuring instant item retrieval whether the database contains 100 entries or 30,000 stationery products.
#### Rule 2: Segmented State Memory Allocation
To optimize execution memory profiles on 4GB RAM machines, the application state splits indexation upon boot:
1. `inventoryMap`: Core key-value matrix mapping barcodes directly to entities for backend business calculations.
2. `quickTileList`: A pre-filtered sub-array tracking exclusively entries tagged with `isQuickTile == true` to allow instant, calculation-free UI drawing loops on the Checkout Dashboard. Maximum 10 items.

#### Rule 3: Fixed-Point Financial Precision Math
To completely eradicate binary floating-point computation rounding anomalies (`double` precision leakage), the system enforces strict integer manipulation tracking the lowest Egyptian monetary subdivision (Piastres / قروش).
* **Formula:** Internal Value = EGP String Value * 100 *
* *Example:* A notebook retailing at `15.75 EGP` evaluates internally as the absolute integer `1575`. A single photocopy service costing `0.50 EGP` evaluates as the integer `50`. Division operations or decimal formatting maps occur exclusively at the visual presentation layer border (`displayString = value / 100`).
* **`PriceHelper.format(int piastres, {String languageCode = 'en'})`:** Accepts an optional `languageCode` parameter for locale-aware currency display. Arabic locale produces `9.99 ج.م`, English produces `EGP 9.99`. The `CashDrawerAssistant`, `CheckoutTowerPanel`, `CartTableWidget`, and `QuickTilesGrid` all pass `languageCode: langCode` when formatting.

#### Rule 4: Constant Localization & Application Properties Registry 
* The active local dictionary utilizes nested key lookup strings: `translationMap[currentLanguageCode][uiLabelKey]`.
* Because execution passes directly through standard Dart Map pointers, language switches alter the state immediately with zero layout recalculation overhead.

### 4. Design Patterns Mandate
* **Repository Pattern:** Structural separation decoupled via abstract contracts. The presentation layer state engines are explicitly blind to Hive configurations, communicating only via `ISettingsRepository` (or feature-specific interfaces). All repository methods must surface failures via the typed `Failure` hierarchy (see Section 6) — raw exceptions are forbidden past the data layer.
* **Bloc Pattern:** Each feature uses a dedicated sealed `Event` union and `State` wrapper with a `Status` enum (`initial`, `loading`, `ready`, `error`). The `HydratedBloc` handles automatic JSON serialization to disk.
* **Command Pattern:** Cart transactional events (addition, adjustments, deductions) are processed as individual event requests sent to the Checkout BLoC, allowing decoupled calculation testing.

### 5. Settings Feature Architecture (Implemented)

```
App (MaterialApp)
└── MultiBlocProvider
    ├── BlocProvider<SettingsBloc> (dispatches LoadSettings on create)
    └── BlocProvider<InventoryBloc> (dispatches LoadInventory)
        └── BlocProvider<CheckoutBloc> (injects generateOrderNumber, seeds initial tax)
            └── BlocListener<SettingsBloc, SettingsState> (tax changes → SetTaxPercent)
                └── ValueListenableBuilder<int> (_selectedIndexNotifier)
                    └── GlobalShortcutGate
                        └── BarcodeScannerGate
                            └── Scaffold
                                ... (AppShell layout)

AppShell
├── ValueNotifiers:
│   ├── _selectedIndexNotifier (int, default 0) — tab switch
│   ├── _isSearchOpenNotifier (bool, default false) — overlay state
│   ├── _barcodeInjectionNotifier (String) — scanner→overlay bridge
│   ├── _discountFocusTrigger (int) — shortcut→discount focus bridge
│   └── _cartFocusTrigger (int) — discount submit→cart focus bridge
├── BlocListener<SettingsBloc> — syncs taxEnabled/taxPercent → CheckoutBloc.SetTaxPercent
└── NavRail
    ├── 0: Shopping Cart → CheckoutWorkspace
    ├── 1: Package → InventoryWorkspace
    ├── 2: Chart Bar → SalesHistoryWorkspace (placeholder)
    └── 3: Gear → SettingsWorkspace
```

#### AppSettingsEntity (11 fields)

| Field | Type | Default | Description |
|---|---|---|---|---|
| `languageCode` | String | `'ar'` | UI language |
| `isDarkMode` | bool | `false` | Theme toggle |
| `storeName` | String | `''` | Store name for receipts |
| `receiptFootnote` | String | `''` | Receipt footer text |
| `customBindings` | Map<String, List<String>> | `const {}` | User-overridden keyboard shortcut combos |
| `taxEnabled` | bool | `false` | Master tax toggle |
| `taxPercent` | int | `0` | Tax rate percentage (0-100) |
| `autoPrintEnabled` | bool | `false` | Auto-print toggle (stub) |
| `orderCounter` | int | `0` | Daily sequential order counter |
| `lastOrderDate` | String | `''` | Last order date (YYYY-MM-DD) for counter reset |
| `barcodeDownloadPath` | String | `''` | Download directory for barcode label PNG exports |
| `exportDirectoryPath` | String | `''` | Unified export directory for receipts and barcode PNGs (Windows absolute path) |
| `saveReceiptAsImage` | bool | `false` | Auto-save receipt as PNG image after sale confirmation |
| `storeAddress` | String | `''` | Store address printed on receipt headers |
| `storePhoneNumber` | String | `''` | Store phone number printed on receipt headers |
| `logoSvgPath` | String | `''` | File path to store logo SVG for receipt branding |
| `receiptPrinterName` | String | `''` | Selected thermal receipt printer name (empty = system default) |
| `barcodePrinterName` | String | `''` | Selected barcode label printer name (empty = system default) |

#### SettingsBloc

| Events | State fields | Hydration |
|---|---|---|
| `LoadSettings` | `status: SettingsStatus (initial, loading, ready, error)` | `fromJson` → `AppSettingsModel.fromJson` → `toEntity` |
| `LanguageToggled` | `settings: AppSettingsEntity` | `toJson` → `AppSettingsModel.toJson` |
| `ThemeToggled` | `failure: Failure?` | Repository: `SettingsRepository` (Hive `Box<AppSettingsModel>`) |
| `StoreNameChanged` | | |
| `ReceiptFootnoteChanged` | | |
| `AddCustomBinding(action, combo)` | Conflict resolution: when adding a combo, removes from other actions | |
| `RemoveCustomBinding(action, combo)` | | |
| `ResetCustomBinding(action)` | Removes action from custom map entirely | |
| `TaxToggled(bool)` | | |
| `TaxPercentChanged(int)` | | |
| `AutoPrintToggled(bool)` | | |
| `SetBarcodeDownloadPath(String)` | | Sets download directory for barcode label PNG exports |
| `AutoPrintToggled(bool)` | | Enable/disable automatic thermal receipt printing |
| `SaveReceiptAsImageToggled(bool)` | | Enable/disable receipt PNG export on sale confirm |
| `SetExportDirectoryPath(String)` | | Sets unified export directory (validated Windows path) |
| `StoreAddressChanged(String)` | | Updates store address on receipt header |
| `StorePhoneNumberChanged(String)` | | Updates store phone on receipt header |
| `LogoSvgPathChanged(String)` | | Sets store logo SVG file path |
| `ReceiptPrinterNameChanged(String)` | | Sets selected receipt printer name |
| `BarcodePrinterNameChanged(String)` | | Sets selected barcode label printer name |
| `UpdateOrderCounter(counter, date)` | | |

### 5b. Settings Workspace Layout (10 Sections)

```
SettingsWorkspace
└── SectionCard(title: settings, mainAxisSize: max)
    └── SingleChildScrollView
        ├── General Section        → storeName TextField, receiptFootnote TextField
        ├── Appearance Section      → dark mode Switch
        ├── Localization Section    → SegmentedButton (AR/EN), RTL/LTR banner
        ├── Tax Section             → enable Switch + rate TextField (conditionally shown)
        ├── Printing Section        → auto-print Switch
        ├── Barcode Download Path   → folder picker + path display (FilledButton.tonalIcon)
        ├── Keyboard Shortcuts      → 6 groups: Navigation, Search, Cash Drawer, Cart,
        │                             Quick Tiles, Inventory (see 5e)
        └── Reset All Data          → subtitle + destructive ElevatedButton + confirmation dialog
```

### 5c. Inventory Feature Architecture (Implemented)
```
App (MaterialApp)
└── MultiBlocProvider
    ├── BlocProvider<SettingsBloc>  (dispatches LoadSettings)
    └── BlocProvider<InventoryBloc> (dispatches LoadInventory)
        └── BlocBuilder<InventoryBloc, InventoryState>
            └── InventoryWorkspace
                └── SectionCard (title + actions in notch, replaces AppBar)
                    ├── Status switch: loading → AppLoading | error → AppError | ready → _buildContent
                    ├── Search active: single vertical ListView of _ProductCard
                    └── Normal mode: Row with two Expanded columns
                        ├── Left: _ProductColumn(title: "Normal Products") → non-quick-tile items
                        └── Right: _ProductColumn(title: "Quick Access")  → quick-tile items
                            └── Each column: Container(theme.cardColor, dividerColor border, 12px radius)
                                ├── Text(title) header
                                └── Expanded → ListView of _ProductCard widgets

InventoryBloc
├── Events: LoadInventory, AddProduct, DeleteProduct, SearchProducts, ToggleQuickTile, UpdateTileColor
├── State: InventoryState { inventoryMap, quickTileList, searchResults, searchQuery, status, failure? }
├── HydratedBloc fromJson/toJson → serializes inventory as JSON list of AppProductModel
└── Repository: InventoryRepository (Hive Box<AppProductModel>) → per-barcode keys

ProductEntity (domain)
├── Fields: barcode (required), name (required), price, stock, notes, isQuickTile, tileColorHex
├── copyWith(), ==, hashCode
└── AppProductModel extends ProductEntity (Hive TypeAdapter typeId=1, JSON, field 6=notes)

ProductFormDialog (StatefulWidget)
├── Auto-fills barcode with random 12-digit number (first digit non-zero)
├── Live BarcodeWidget preview (code128, renders when ≥6 characters)
├── 8-color predefined palette shown when isQuickTile toggled
├── Quick-tile toggle hidden if _currentQuickTileCount >= 10 (new/untoggled products)
├── Fields: barcode, name, price, stock, notes + isQuickTile switch + color picker
├── BarcodeLabelTemplate (below preview) — styled label showing store name, barcode,
│   product name + notes, and price in locale-aware currency
├── "Save Barcode" button — triggers BarcodeExportCubit.export() via BarcodeExportService
└── BarcodeExportCubit scoped to dialog lifecycle (idle → exporting → success/failure → idle)

BarcodeExportCubit (inventory feature)
├── States: BarcodeExportIdle, BarcodeExporting, BarcodeExportSuccess(filePath), BarcodeExportFailure(message)
├── export({repaintKey, barcode, downloadPath}) → emits sequence through states
└── reset() → back to idle

BarcodeExportService (inventory data layer)
├── exportLabel({repaintKey, barcode, downloadPath}) → Either<Failure, String>
├── Captures RenderRepaintBoundary → toImage(pixelRatio: 2.0) → byteData → PNG bytes
├── Sanitizes barcode for filename, appends timestamp suffix → barcode_<sanitized>_<timestamp>.png
└── Uses dart:io File for write

BarcodeLabelTemplate (widget)
├── Props: ProductEntity product, String storeName, String langCode
├── Renders: store name (optional) → code128 barcode → barcode text → product name + notes → price
├── Fixed 300px width, white background, rounded corners
└── RTL-aware via Directionality override based on langCode
```

### 5d. Checkout Feature Architecture (Implemented)
```
App → GlobalShortcutGate → BarcodeScannerGate → Scaffold
└── Column
    ├── SizedBox(height: Spacing.lg)
    └── Expanded → Row
        ├── SectionCard → _NavRail (72px fixed width)
        ├── Container(width: 1, dividerColor)
        ├── Expanded(flex: 7) → CheckoutWorkspace (or Inventory/Settings)
        ├── [if checkout] Container(width: 1, dividerColor)
        └── [if checkout] ConstrainedBox(minWidth: 360, maxWidth: 500) → CheckoutTowerPanel
            ├── SectionCard (receipt, mainAxisSize.max)
            │   ├── Order number (#ORD-XXXXX) if present
            │   ├── Centered store name + receipt icon + title (+ checkmark when confirmed)
            │   ├── Numbered item list (quantity × price + line total)
            │   ├── Divider + Summary footer
            │   │   ├── Items count + subtotal via AnimatedCounter
            │   │   ├── Discount (if >0): "(X%) -EGP Y.YY" in red
            │   │   ├── Tax (if enabled): "+EGP Y.YY (X%)"
            │   │   └── Total via AnimatedCounter (bold)
            │   └── Receipt footnote
            └── SizedBox(height: Spacing.sm)
            └── SectionCard (cash drawer)
                └── CashDrawerAssistant
                    ├── Amount due in heading1
                    ├── Paid amount + change display
                    ├── Cash buttons: [5][10][20][50] / [100][200][C]
                    ├── Discount TextField (digits only, real-time dispatch)
                    └── Confirm ElevatedButton (styled)

CheckoutBloc
├── Constructor: {String Function()? generateOrderNumber}
├── Initial state: CheckoutStatus.ready, CartEntity.create()
├── Events:
│   ├── AddToCart(barcode, name, unitPricePiastres)
│   ├── UpdateQuantity(barcode, quantity)
│   ├── RemoveFromCart(barcode)
│   ├── ClearCart
│   ├── SetAmountPaid(piastres)          — replaces, not adds
│   ├── ClearAmountPaid
│   ├── ConfirmSale
│   ├── SetDiscount(int percent)          — clamps 0-100, clears amountPaid
│   └── SetTaxPercent(int percent)        — clamps 0-100
├── State: CheckoutState
│   ├── status: CheckoutStatus (initial|ready|error|confirmed)
│   ├── cart: CartEntity?
│   ├── amountPaidPiastres: int?
│   ├── discountPercent: int (default 0)
│   ├── orderNumber: String? (set on confirm)
│   ├── taxPercent: int (default 0)
│   └── failure: Failure?
│   └── Computed getters:
│       ├── subtotalPiastres → cart?.subtotalPiastres ?? 0
│       ├── discountAmount → (subtotalPiastres * discountPercent / 100).round()
│       ├── afterDiscountPiastres → subtotalPiastres - discountAmount
│       ├── taxAmount → (afterDiscountPiastres * taxPercent / 100).round()
│       ├── totalPiastres → afterDiscountPiastres + taxAmount
│       ├── changePiastres → max(0, (amountPaidPiastres ?? 0) - totalPiastres)
│       └── isPaid → amountPaidPiastres != null && amountPaidPiastres >= totalPiastres
├── Guards on ConfirmSale: cart not null, cart not empty, _confirmInProgress flag
├── generateOrderNumber: reads ShiftBloc state, uses shift.orderCount,
│   dispatches IncrementShiftOrderCount(shift.id) to increment,
│   returns "ORD-${orderCount.padLeft(5, '0')}"
  └── On confirm: emit confirmed + orderNumber → CheckoutConfirmationDialog (optimistic)
      ├── ReceiptsBloc ReceiptCreated → success icon (check_circle), auto-dismiss 2s → ClearCart
      └── ReceiptsBloc ReceiptPersistenceFailure → error icon (failure), manual dismiss → ClearCart

CheckoutConfirmationDialog (StatefulWidget)
├── PopScope(canPop: false) / (canPop: true on failure)
├── Listens to ReceiptsBloc for receipt creation status
├── Optimistic on open: shows `CircularProgressIndicator` + "Processing sale..." with no icon
├── Transitions to success or error variant once `ReceiptsBloc` responds
├── Success: auto-dismiss via Future.delayed(2 seconds)
├── Failure: user must dismiss manually (close button or timeout)
├── Icon: check_circle (success, 64px green) / error (failure, 64px red)
└── Message text in title-large style + error detail on failure

CartTableWidget (replaces CartItemTile)
├── 4-column Table (No. / Name / Qty / Price) with FlexColumnWidth constants
├── AnimatedList + SizeTransition + FadeTransition (300ms) for insert/remove animations
├── Local ValueNotifier<int> _selectedIndex — keyboard row selection (NOT in BLoC state)
├── Local ValueNotifier<int> _editingIndex — inline edit mode tracker
├── Scoped Shortcuts: arrowUp/arrowDown/delete/enter → cart manipulation Intents
├── ValueNotifier<bool> edit mode + FilteringTextInputFormatter.digitsOnly for qty editing
├── Tap-to-edit inline TextField, submit/focus-loss commits only if _hasTyped
└── Total footer row with AnimatedCounter values

PriceHelper
├── fromDouble(double) → int (piastres)
└── format(int piastres, {String languageCode = 'en'}) → locale-aware string (Arabic: "X.XX ج.م", English: "EGP X.XX")
```

### 5e. Keyboard Shortcuts Feature Architecture (Implemented)

```
lib/features/shortcuts/
├── intents.dart                  # 18 Intent subclasses
├── default_bindings.dart         # Map<String, List<String>> of action→key-combos
├── helpers/
│   ├── key_binding_parser.dart   # parseKeyCombo / buildComboString / displayCombo
│   └── binding_resolver.dart     # findConflict / resolveBindingConflicts
└── presentation/
    └── widgets/
        ├── global_shortcut_gate.dart   # Core Shortcuts+Actions dispatcher + overlay manager
        ├── global_search_overlay.dart   # Search modal overlay widget
        └── key_capture_dialog.dart      # Key combo recording dialog
```

#### Intents (18 classes)

| Intent | Action | Dispatch Target |
|---|---|---|
| `NavigateToCheckoutIntent` | F1 | `selectedIndexNotifier.value = 0` |
| `NavigateToInventoryIntent` | F2 | `selectedIndexNotifier.value = 1` |
| `NavigateToSalesIntent` | F3 | `selectedIndexNotifier.value = 2` |
| `NavigateToSettingsIntent` | F4 | `selectedIndexNotifier.value = 3` |
| `ToggleSearchOverlayIntent` | F5 | Create/remove overlay entry |
| `SelectNextCartItemIntent` | Down | Increment cart `_selectedIndex` |
| `SelectPrevCartItemIntent` | Up | Decrement cart `_selectedIndex` |
| `RemoveSelectedCartItemIntent` | Delete | Dispatch `RemoveFromCart` |
| `ConfirmSaleIntent` | F12/Space | Dispatch `ConfirmSale` |
| `ActivateQuickTileIntent(i)` | Alt+1..0 | Dispatch `AddToCart` from quickTileList[i] |
| `AddProductIntent` | Ctrl+N | Show ProductFormDialog (inventory tab only) |
| `FocusDiscountIntent` | Ctrl+D | Increment `_discountFocusTrigger` |
| `EditCartItemQuantityIntent` | Enter | Toggle inline edit mode |
| `SetAmountPaid5EG..200EGIntent` | (user config) | Dispatch `SetAmountPaid(current + N)` |
| `ClearAmountPaidIntent` | (user config) | Dispatch `ClearAmountPaid` |
| `ClearSearchIntent` | (user config) | Clear search overlay text |

#### Default Bindings Map

```
nav.checkout → ["f1"]
nav.inventory → ["f2"]
nav.sales → ["f3"]
nav.settings → ["f4"]
search.toggle → ["f5", "/", "ctrl+f"]
cart.confirm → ["f12", "space"]
cart.selected.up → ["arrowUp"]
cart.selected.down → ["arrowDown"]
cart.selected.delete → ["delete"]
cart.quick.1..10 → ["alt+1"]..["alt+0"]
inventory.addProduct → ["ctrl+n"]
cart.discount → ["ctrl+d"]
cart.selected.edit → ["enter"]
cart.amount.{5eg..200eg,clear} → []  (empty — user-configurable only)
search.clear → []
```

#### Key Binding Parser
* **`parseKeyCombo(String)` → `SingleActivator`:** Splits on `+`, last token is key, rest are modifiers (`control`, `alt`, `shift`, `meta`). Maps via `_keyMap` (f1-f12, space, enter, escape, delete, arrows, letters, digits, `/`). Falls back to `LogicalKeyboardKey.help` if unknown.
* **`buildComboString(LogicalKeyboardKey, {ctrl, alt, shift, meta})` → String:** Reverse of parse.
* **`displayCombo(String)` → String:** Human-friendly display: `ctrl`→`Ctrl`, `arrowUp`→`↑`, `delete`→`Del`, `space` →`Space`, etc.

#### Binding Resolver
* **`findConflict(bindings, actionToken, keyCombo)` → String?:** Scans all actions for one that already uses the same combo.
* **`resolveBindingConflicts(currentBindings, actionToken, keyCombo)` → Map:** Removes conflicting entries, then sets new binding. Used by the settings key capture flow.

#### GlobalShortcutGate Core Flow
```
Physical Key Press
  → Flutter Shortcuts widget matches ShortcutActivator to Intent
  → Actions widget dispatches to CallbackAction
  → CallbackAction runs one of:
      • Set ValueNotifier (nav index, focus trigger, overlay state)
      • Read Bloc state + dispatch bloc event (confirm, amount, cart)
      • Call callback (onAddProduct)
```

---

### 6. Typed Failure Class System (Domain Layer Mandate)

The domain layer must define a sealed `Failure` hierarchy so that presentation-layer state engines (Bloc/Cubit) never receive raw `Exception` or `Error` objects. Repository implementations are the **single boundary** that translates raw Dart/Flutter exceptions into typed `Failure` subclasses before any data leaves the data layer.

#### 6.1 Base Class Contract
* **Declaration:** `sealed class Failure` in `lib/core/error/failure.dart` (cross-cutting core module, not per-feature).
* **Equality & Logging:** Each `Failure` subclass must override `==`, `hashCode`, and `toString()`. `toString()` must include the failure type name and all carried fields — the bloc layer relies on this for the centralized `ErrorReporter` log sink.
* **No Stack Traces In Presentation:** `Failure` carries semantic fields only. Stack traces stay inside the data layer and are routed to the `ErrorReporter` log sink; the bloc and view layers never see them.

#### 6.2 Canonical Subclasses
* `DatabaseFailure` — wraps Hive I/O errors, disk failures, JSON serialization errors, and box-open failures.
	* Carried fields: `message` (`String`), `cause` (`Object?`, optional original error).
	* Example triggers: `HiveError` on read, `PathProviderException` when the disk is unavailable, `TypeError` from a malformed `fromJson`.
* `ItemNotFoundFailure` — wraps lookup misses where a barcode or SKU returns `null`.
	* Carried field: `barcode` (`String`, the queried key).
	* Example trigger: cashier scans a barcode that does not exist in the `inventoryMap`.
* `ValidationFailure` — wraps input rejection from form validation or invariant checks.
	* Carried fields: `field` (`String`, the offending field name), `reason` (`String`, localized or canonical reason code).
	* Example trigger: `storeName` empty after trim, `receiptFootnote` exceeding the allowed character cap, invalid currency string in the cash drawer assistant.

#### 6.2a AuthenticationFailure (4th Canonical Subclass)

* `AuthenticationFailure` — wraps login validation, RBAC violations, and user-management errors.
  * Carried fields: `message` (`String`), `reason` (`AuthFailureReason` enum).
  * `AuthFailureReason` values: `invalidCredentials`, `userNotFound`, `duplicateUsername`, `weakPassword`, `wrongCurrentPassword`, `cannotDeleteSelf`, `unauthorized`, `invalidUsername`.

New feature-specific failures beyond the four canonical subclasses are permitted but must extend `Failure` and live in `lib/core/error/`. The four subclasses above are the **mandatory minimum** that every feature must be capable of producing.

#### 6.3 Repository Mapping Rule
* **Boundary Rule:** A repository implementation method that performs I/O (Hive read/write, JSON parse, external service call) must wrap its body in a `try`/`catch` and translate every caught object into the appropriate `Failure` subclass. Methods that do not perform I/O (pure in-memory transforms) need no translation.
* **Return Type Rule:** All repository methods that can fail must return `Future<Either<Failure, T>>` (or `Stream<Either<Failure, T>>` for reactive sources). `Either` is the canonical error monad for this codebase; the left side carries the `Failure`, the right side carries the success value. `T` may be `void` for operations with no return value (`Either<Failure, void>`).
* **BLoC Consumption Rule:** The presentation layer must use a `fold` (or equivalent) on the `Either` to dispatch a `Status.error` state carrying the `Failure`. Raw `try`/`catch` in the bloc is **forbidden** — every error path must arrive via a typed `Failure`.
* **Telemetry Rule:** When a `Failure` is constructed, the repository must log it through the `ErrorReporter` log sink with the failure type, message, and (for `DatabaseFailure`) the original `cause`. The presentation layer must not duplicate this log.

#### 6.4 Anti-Patterns (Explicitly Forbidden)
* Throwing `Exception` or `Error` across the data-layer boundary.
* Returning `null` to signal failure — the absence of a value must surface as a typed `Failure` (e.g., a barcode lookup that yields `null` produces `ItemNotFoundFailure`, never a nullable return type).
* Catching `Object` in the bloc layer to translate to UI strings.
* Stringly-typed error codes — the type system is the contract; a `String` error code field is not an acceptable substitute for a `Failure` subclass.

---

### 5f. Auth & Shift Feature Architecture (New)

```
main.dart (root)
└── BlocProvider<AuthBloc> (dispatches CheckAuth on create)
    └── BlocBuilder<AuthBloc, AuthState>
        ├── (initial | loading) → AppLoading
        ├── (setupRequired) → FirstTimeSetupScreen
        ├── (unauthenticated | passwordChangeRequired) → LoginScreen
        └── (authenticated user) → AppShell(user)
            └── RepositoryProvider<IInventoryRepository>  ← provides IInventoryRepository for ReceiptsBloc
                └── BlocProvider<ReceiptsBloc>
                    ├── ReceiptsRepository (Hive 'receipts' box)
                    ├── IInventoryRepository (stock decrement)
                    └── IRefundsRepository (Hive 'refunds' box)
                    └── MultiBlocListener
                        ├── BlocListener<SettingsBloc> (tax changes → SetTaxPercent)
                        ├── BlocListener<ShiftBloc> (ShiftEnded → LogoutRequested)
                        ├── BlocListener<ShiftBloc> (orphan recovered → snackbar)
                        ├── BlocListener<CheckoutBloc> (confirmed → CreateReceipt)
                        └── BlocListener<ReceiptsBloc> (error → CheckoutConfirmationDialog failure)
                            └── AppShell(user) — returns Scaffold with NavRail + workspace
```

#### AuthBloc (plain Bloc, not Hydrated)

| Events | State Fields | Notes |
|---|---|---|
| `CheckAuth` | `status: AuthStatus (initial, loading, authenticated, unauthenticated, setupRequired)` | Seed users created lazily on first `getAll()` call via `__seeded__` marker key. If `__setup_completed__` absent, emit `setupRequired` |
| `CompleteAdminSetup(password)` | | Validates min 8 chars, hashes password, saves admin user with `mustChangePassword: false`, writes `__setup_completed__` marker, emits `authenticated` |
| `LoginRequested(username, password)` | `user: UserEntity?` | Password: PBKDF2-HMAC-SHA256 (100k iterations) hex compare against salted hash |
| `LogoutRequested` | `failure: Failure?` | No hydrate — session-only |
| `LoadUsers` | `users: List<UserEntity>` | Fetches all users for admin UI |
| `CreateUser(username, password, role)` | | Admin only. Validates username (3-30 chars, alphanumeric + underscore). Password min 8 chars. Auto-generates salt |
| `ChangePassword(username, currentPassword, newPassword)` | | Admin re-auth required. Min 8 chars for new password. Sets `mustChangePassword: false` |
| `DeleteUser(username)` | | Cannot delete self |

**Rate Limiting:** `_failedAttempts` counter tracks consecutive failures. At ≥3 failures, exponential backoff lockout = `_failedAttempts * 2` seconds. Resets on successful login. Username validated client-side via `RegExp(r'^[a-zA-Z0-9_]{3,30}$')`.

**AuthRepository (Hive `auth_users` box):**
- `getAll()` → `Either<Failure, List<UserEntity>>` (seeds users via `__seeded__` marker key if absent — seed users get `mustChangePassword: true`)
- `getByUsername(username)` → `Either<Failure, UserEntity?>`
- `save(user)` → `Either<Failure, void>` (auto-generates `passwordSalt` via PBKDF2 `generateSalt()` if empty)
- `delete(username)` → `Either<Failure, void>`
- `isSetupCompleted()` → `Either<Failure, bool>` (checks `__setup_completed__` marker key. If `__seeded__` exists without `__setup_completed__`, auto-migrates existing installs by writing the marker)
- `completeSetup(admin)` → `Either<Failure, void>` (writes admin user with chosen password + `mustChangePassword: false`, writes `__setup_completed__` marker)

**UserEntity:**
```dart
class UserEntity {
  final String username;
  final String passwordHash;   // PBKDF2-HMAC-SHA256 hex (100k iterations)
  final String passwordSalt;   // 32-byte random salt (encoded as 64-character hex), auto-generated on save if empty
  final bool mustChangePassword;  // true for seed users, reset on password change
  final UserRole role;
  final DateTime createdAt;
}
```

**UserRole enum:** `enum UserRole { admin, cashier }`

#### ShiftBloc (plain Bloc, not Hydrated)

| Events | State Fields | Notes |
|---|---|---|
| `StartShift` | `status: ShiftStatus (initial, loading, active, ended, error)` | Auto-closes orphan if found (End active $\rightarrow$ Start new) |
| `EndShift` | `shift: ShiftEntity?` | Sets endedAt = now, removes from `active_shifts` box |
| | `failure: Failure?` | Guard against duplicate StartShift (loading/active check) |
| `IncrementShiftOrderCount(shiftId)` | | Increments orderCount on the active shift entity |

**ShiftsRepository (Hive `shifts` box + companion `active_shifts` box):**
- `getActiveShift(username)` → `Either<Failure, ShiftEntity?>` (O(1) via companion `active_shifts` box mapping username→shiftId)
- `getByMonth(year, month)` → `Either<Failure, List<ShiftEntity>>` (filter by startedAt year/month)
- `save(shift)` → `Either<Failure, void>` (Hive upsert — single method for create/update. Also updates `active_shifts` box: inserts key on start, deletes on end)

**ShiftEntity:**
```dart
class ShiftEntity {
  final String id;             // UUID v4
  final String username;
  final DateTime startedAt;
  final DateTime? endedAt;     // null = active shift
  final int openingFloat;      // piastres, default 0
  final int orderCount;        // daily sequential order counter, default 1
}
```

#### Nav Architecture

```dart
enum NavDestination { checkout, inventory, sales, settings }

final Map<UserRole, List<NavDestination>> roleNavMap = {
  UserRole.admin: [NavDestination.sales, NavDestination.settings], // Default: Sales
  UserRole.cashier: [
    NavDestination.checkout,
    NavDestination.inventory,
    NavDestination.sales,
    NavDestination.settings,
  ], // Default: Checkout
};
```

**AppShell changes:**
- `_selectedIndexNotifier` replaced with `_currentDestination` (`ValueNotifier<NavDestination>`)
- `_NavRail` receives `List<NavDestination> allowedDestinations` + `ValueNotifier<NavDestination>`
- End Shift button separate from `allowedDestinations`, always rendered
- `_buildWorkspace` replaced by `IndexedStack` with 4 children (0=checkout, 1=inventory, 2=sales, 3=settings)
- Stack index = `NavDestination.values.indexOf(dest)` — stable across roles
- F1-F4: shortcut checks `allowedDestinations.contains(dest)` before setting `_currentDestination`

#### New Failure Subclasses (in `lib/core/error/failure.dart`)

| Class | Fields | Triggers |
|---|---|---|
| `AuthenticationFailure` | `message: String`, `reason: AuthFailureReason (invalidCredentials, userNotFound, duplicateUsername, weakPassword, wrongCurrentPassword, cannotDeleteSelf, unauthorized, invalidUsername)` | Login failure, RBAC violation, user mgmt validation, rate limiting lockout |
| `ReceiptPersistenceFailure` | `message: String`, `cause: Object?` | Hive save error during receipt creation |
| `RefundLockFailure` | `receiptId: String`, `currentStatus: ReceiptStatus`, `message: String` | Refund/modify action on receipt where `status != active` |

### 5g. Receipts Feature Architecture (New)

```
lib/features/receipts/
├── data/
│   ├── models/
│   │   ├── app_receipt_model.dart           # AppReceiptModel + Adapter (typeId=4)
│   │   ├── app_refund_model.dart            # AppRefundModel + Adapter (typeId=5)
│   │   └── receipt_item_adapter.dart        # ReceiptItemAdapter (typeId=6)
│   └── repositories/
│       ├── receipts_repository_impl.dart    # Hive 'receipts' box
│       └── refunds_repository_impl.dart     # Hive 'refunds' box
├── domain/
│   ├── entities/
│   │   ├── receipt_entity.dart
│   │   ├── receipt_item.dart
│   │   └── refund_entity.dart              # RefundEntity + RefundType enum
│   └── repositories/
│       ├── receipts_repository.dart         # abstract IReceiptsRepository
│       └── refunds_repository.dart          # abstract IRefundsRepository
└── presentation/
    └── bloc/
        ├── receipts_bloc.dart
        ├── receipts_event.dart
        └── receipts_state.dart
```

#### ReceiptsBloc (plain Bloc, not Hydrated)

| Events | State Fields | Notes |
|---|---|---|
| `CreateReceipt(...)` | `status: ReceiptBlocStatus (initial, loading, ready, error)` | **Atomic sequence:** 1. Save `ReceiptEntity` (`stockUpdated: false`) $\rightarrow$ 2. If success, iterate items and call `IInventoryRepository.updateStock` $\rightarrow$ 3. If all stock updates attempted, update `stockUpdated: true` and save again $\rightarrow$ 4. Only then emit `ready` (triggering UI confirmation) |
| `LoadReceipts` | `receipts: List<ReceiptEntity>?` | |
| `LoadReceiptsByMonth(year, month)` | `failure: Failure?` | In-memory filter on `receipts` box |
| `ProcessRefund(receipt)` | | Guard: blocks `returned` receipts with `RefundLockFailure`. Guard: blocks cross-shift refunds (receipt.shiftId != current shift). On success: restores stock, creates RefundEntity, sets status to `returned`. |
| `ModifyReceipt(receipt, items, subtotal)` | | Guard: blocks `returned` receipts with `RefundLockFailure`. Only `active` receipts can be modified directly. On success: recalculates totals, increments modificationCount, sets status to `modified`. |
| `AuthorizedModifyReceipt(receipt, items, subtotal, adminPassword)` | | Admin-authorized modification path. Requires adminPassword (already PBKDF2-hashed from `_AdminPasswordDialog`). Guard: blocks `returned` receipts. On success: same as ModifyReceipt. Used when receipt status is `modified` (requires admin authorization) or when cashier needs admin override. |

**ReceiptsRepository (Hive `receipts` box):**
- `save(receipt)` → `Either<Failure, void>`
- `getAll()` → `Either<Failure, List<ReceiptEntity>>`
- `getByShift(shiftId)` → `Either<Failure, List<ReceiptEntity>>`
- `getByMonth(year, month)` → `Either<Failure, List<ReceiptEntity>>` (filter by createdAt year/month)
- `getByDate(date)` → `Either<Failure, List<ReceiptEntity>>` (all receipts for a specific date — used for today's summary)

**ReceiptEntity:**
```dart
class ReceiptEntity {
  final String id;                 // UUID v4
  final String shiftId;
  final String orderNumber;        // "ORD-00001"
  final List<ReceiptItem> items;
  final int subtotalPiastres;
  final int discountPiastres;
  final int taxPiastres;
  final int totalPiastres;
  final DateTime createdAt;
  final String username;
  final bool stockUpdated; // Defaults to false; set to true after all inventory updates complete
  final ReceiptStatus status; // active, returned, modified; default active
  final int modificationCount; // number of times modified, default 0
}
```

**ReceiptItem:**
```dart
class ReceiptItem {
  final String name;
  final String barcode;
  final int quantity;
  final int unitPricePiastres;
  int get totalPiastres => quantity * unitPricePiastres;
}
```

**IInventoryRepository (stock decrement contract):**
```dart
abstract class IInventoryRepository {
  Either<Failure, void> updateStock(String barcode, int deltaQuantity);
}
```
Existing `InventoryRepository` implements this. ReceiptsBloc receives it via constructor injection.

#### Cross-Feature Registration

ReceiptsBloc needs both repositories injected:
```dart
ReceiptsBloc({
  required ReceiptsRepository receiptsRepo,
  required IInventoryRepository inventoryRepo,
})
```

Registration in `main.dart` / `app.dart`:
```dart
BlocProvider(
  create: (ctx) => ReceiptsBloc(
    receiptsRepo: ReceiptsRepositoryImpl(),
    inventoryRepo: ctx.read<InventoryRepository>(),  // implements IInventoryRepository
  ),
)
```

#### Post-Receipt Inventory Refresh

After a receipt is created (on `ReceiptBlocStatus.ready`), `AppShell` dispatches `RefreshInventory` to `InventoryBloc`. This ensures the inventory list reflects the stock decrement immediately. `RefreshInventory` is defined in `lib/features/inventory/presentation/bloc/inventory_event.dart` and re-loads all products from the Hive inventory box.

### 5h. Sales Analytics Feature Architecture (New — Phase 6)

```
lib/features/sales/
├── domain/
│   └── entities/          # (no new entities — uses ReceiptEntity)
└── presentation/
    ├── bloc/
    │   ├── sales_bloc.dart
    │   ├── sales_event.dart
    │   └── sales_state.dart
    └── views/
        └── sales_workspace.dart
```

#### SalesBloc (plain Bloc, not Hydrated)

| Events | State Fields | Notes |
|---|---|---|
| `LoadTodaySummary` | `status: SalesStatus (initial, loading, ready, error)` | Query: `receiptsBox.values.where((r) => isSameDay(r.createdAt, now))`. Sum `totalPiastres` and count items. |
| `LoadMonth(year, month)` | `todaySummary: TodaySummary?` | Query: `receiptsBox.values.where((r) => r.createdAt.year == year && r.createdAt.month == month)`. Group by month. |
| `LoadShiftReceipts(shiftId)` | `shiftReceipts: List<ReceiptEntity>?` | Query: `ReceiptsRepository.getByShift(shiftId)` sorted desc. Used by cashier view. |
| | `monthData: MonthData?` | |
| | `failure: Failure?` | |

**TodaySummary:** `{ receiptCount: int, totalPiastres: int, itemsSold: int }`
**MonthData:** `{ year: int, month: int, receipts: List<ReceiptEntity>, totalPiastres: int }`
**DayGroup:** `{ date: DateTime, cashiers: List<CashierDayGroup> }`
**CashierDayGroup:** `{ username: String, shifts: List<ShiftGroup> }`
**ShiftGroup:** `{ shiftId: String, startedAt: DateTime, endedAt: DateTime?, receipts: List<ReceiptEntity> }`
**MonthGroupedData:** `{ year: int, month: int, totalPiastres: int, receiptCount: int, days: List<DayGroup> }`

SalesBloc wraps `ReceiptsRepository` for receipt read access and `ShiftsRepository` for shift data (used to group receipts by shift in grouped views). It does NOT own any write operations.

---
### 5i. Inventory Invariants & Refunds Domain

#### Stock Calculation Logic
To provide historical context in the Admin Sales view, the system derives the "Stock Before Selling" using the following formula:
$\text{Total Stock Before Selling} = \text{Current Stock} + \text{Total Volume Sold}$

#### Refunds Domain
* **Receipt Status Machine:**
    - `enum ReceiptStatus { active, returned, modified }`
    - All new receipts start as `active`.
* **RefundEntity:** `id` (UUID), `originalReceiptId` (UUID), `refundDate` (DateTime), `amountRestored` (int piastres), `type` (Full/Partial).
* **Double-Refund Lock:** `returned` receipts throw `RefundLockFailure` on any mutating action (refund or modify). `modified` receipts block further modification but allow refund. Only `active` receipts accept both refund and modification freely.
* **Modification Flow:**
    1. Only `active` receipts accept direct modification. `modified` receipts require admin authorization via `AuthorizedModifyReceipt`. `returned` receipts are locked.
    2. Calculate delta (Original Qty - New Qty).
    3. Call `IInventoryRepository.updateStock(barcode, delta)`.
    4. Recalculate totals $\rightarrow$ update `ReceiptEntity` $\rightarrow$ set `status = modified`, increment `modificationCount`.
* **Stock Restoration:** All refund/modification operations must call `IInventoryRepository.updateStock` with a positive `deltaQuantity` to restore inventory.

### 5j. Hive Box Summary

| Box Name | Entity | Feature | Notes |
|---|---|---|---|---|
| `auth_users` | `UserEntity` → `AppUserModel` | Auth | Lazy seed on first read via `__seeded__` marker key. `__setup_completed__` marker tracks admin password initialization |
| `shifts` | `ShiftEntity` → `AppShiftModel` | Auth/Shift | O(1) key = UUID |
| `active_shifts` | `String` (username → shiftId) | Auth/Shift | Companion index box for O(1) `getActiveShift()` |
| `settings` | `AppSettingsModel` | Settings | HydratedBloc auto-serialize. TypeAdapter typeId=0, fields 0-16 (incl. exportDirectoryPath, saveReceiptAsImage, storeAddress, storePhoneNumber, logoSvgPath, receiptPrinterName, barcodePrinterName) |
| `inventory` | `AppProductModel` | Inventory | HydratedBloc auto-serialize. TypeAdapter typeId=1, field 6=notes |
| `receipts` | `ReceiptEntity` → `AppReceiptModel` | Receipts | O(1) key = UUID. Requires `ReceiptItemAdapter` (typeId=6) for `List<ReceiptItem>` serialization. |
| `refunds` | `RefundEntity` → `AppRefundModel` | Refunds | O(1) key = UUID |

### 5k. Dependency Graph

```
auth-and-shifts (standalone)
  └── auth_repository, shifts_repository
  └── no dependencies on other features

receipts (depends on: auth-and-shifts)
  └── requires shiftId to create receipts
  └── requires IInventoryRepository (from inventory feature)
  └── CheckoutBloc emits confirmed → ReceiptsBloc.CreateReceipt

sales-analytics (depends on: receipts)
  └── read-only queries on ReceiptsRepository
  └── no write operations

print-server (standalone, Windows-only)
  └── .NET 8 Minimal API sidecar (PrintServer.exe)
  └── Flutter: PrintServerManager (sidecar lifecycle), PrintService (HTTP client)
  └── requires Kestrel on 127.0.0.1:5150
  └── adds settings UI: PrintingSection, ExportDirectorySection, AdminGeneralSection

drm-licensing (standalone, cross-cutting)
  └── LicenseEngine, Ed25519Verifier, HwidProvider
  └── dual storage: SecureStorageAdapter + FileBackupAdapter
  └── activation gating: ShiftBloc.StartShift, CheckoutBloc.ConfirmSale
```

### 5l. Feature Branch Order

1. `feature/auth-and-shifts` — AuthBloc, ShiftBloc, UserEntity, ShiftEntity, AuthRepository, ShiftsRepository, LoginScreen, FirstTimeSetupScreen, User Management section, role-based nav, End Shift flow, orphan recovery, first-time admin setup
2. `feature/receipts` — ReceiptsBloc, ReceiptEntity, ReceiptsRepository, IInventoryRepository adapter, BlocListener bridge in AppShell, stock decrement
3. `feature/sales-analytics` — SalesBloc, SalesWorkspace (admin + cashier views), TodaySummaryBar, MonthBrowser
4. `feature/print-server` — .NET 8 sidecar for thermal receipt + barcode printing, Flutter PrintService client, settings UI (printing, export dir, store identity), receipt reprint button
5. `feature/drm-licensing` — Offline Ed25519 licensing system, activation screen, HWID binding, dual storage with self-healing, operational gating

---

### 5m. Print Server Architecture (Implemented)

```
┌──────────────────────────────────────────────────────────────┐
│  Flutter App (Dart)                                          │
│                                                              │
│  main.dart                                                   │
│    └── PrintServerManager (sidecar lifecycle manager)        │
│          └── spawns/kills PrintServer.exe via Process.start  │
│                                                              │
│  PrintService (HTTP client)                                  │
│    └── GET  /api/printing/local-printers                     │
│    └── POST /api/printing/receipt                            │
│    └── POST /api/printing/barcode                            │
│                                                              │
│  Settings UI (Bloc-based)                                    │
│    ├── PrintingSection         — auto-print toggle, printer  │
│    │                             dropdowns (receipt/barcode) │
│    ├── ExportDirectorySection  — export path with Windows    │
│    │                             drive-letter regex validation│
│    └── AdminGeneralSection     — store identity (name, addr, │
│                                  phone, SVG logo, footnote)  │
│                                                              │
│  ReceiptDetailDialog                                         │
│    └── Reprint button (admin/cashier guard)                  │
│    └── Builds receipt JSON payload → PrintService.printReceipt│
└──────────────────────┬───────────────────────────────────────┘
                       │ HTTP :5150
┌──────────────────────▼───────────────────────────────────────┐
│  .NET 8 Minimal API — PrintServer/                           │
│                                                              │
│  Program.cs (Kestrel on 127.0.0.1:5150, rate limiter 30/s)  │
│    ├── GET  /api/printing/local-printers → PrinterService    │
│    ├── POST /api/printing/receipt        → PrinterService +  │
│    │                                       ImageExportService│
│    └── POST /api/printing/barcode        → PrinterService    │
│                                                              │
│  Services/                                                   │
│    ├── PrinterService.cs    — System.Drawing.Printing        │
│    │   ├── GetInstalledPrinters()                            │
│    │   ├── PrintReceipt() — GDI+ receipt layout (Consolas)   │
│    │   └── PrintBarcodeAsync() — Code128 via BarcodeLib      │
│    │                                                         │
│    └── ImageExportService.cs — SkiaSharp                     │
│        └── SaveReceiptAsPngAsync() — monochrome PNG export   │
│            ├── SkiaSharp.HarfBuzz for Arabic shaping          │
│            ├── SVG logo rendering via Svg.Skia               │
│            └── RTL layout mirroring (isRtl flag)             │
│                                                              │
│  Models/                                                     │
│    ├── ReceiptRequest.cs   — Items, finances, store info     │
│    └── BarcodeRequest.cs   — BarcodeData, product info       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

#### Print Server Manager (Flutter Core)

| File | Location | Responsibility |
|---|---|---|
| `PrintServerManager` | `lib/core/printing/print_server_manager.dart` | `Process.start('PrintServer.exe')` — sidecar lifecycle (start, stop, dispose), stdout/stderr logging |
| `PrintService` | `lib/core/printing/print_service.dart` | HTTP client via `dart:io` HttpClient — `getLocalPrinters()`, `printReceipt()`, `printBarcode()` |
| `PrintServer.csproj` | `PrintServer/PrintServer.csproj` | .NET 8 web SDK, SkiaSharp 2.88.9, SkiaSharp.HarfBuzz, BarcodeLib 2.4.0, Svg.Skia 2.0.0 |
| `Program.cs` | `PrintServer/Program.cs` | Kestrel host on `127.0.0.1:5150`, 3 endpoints, rate limiter (30 req/s) |

#### Settings Events (New — Print Server)

All dispatched from the UI sections below and handled by `SettingsBloc`:

| Event | UI Trigger | Side Effects |
|---|---|---|
| `AutoPrintToggled(bool)` | PrintingSection switch | Persists `autoPrintEnabled` |
| `SaveReceiptAsImageToggled(bool)` | PrintingSection switch | Persists `saveReceiptAsImage` |
| `SetExportDirectoryPath(String)` | ExportDirectorySection file picker | Validates Windows path regex, persists |
| `StoreAddressChanged(String)` | AdminGeneralSection text field | Persists `storeAddress` |
| `StorePhoneNumberChanged(String)` | AdminGeneralSection text field | Persists `storePhoneNumber` |
| `LogoSvgPathChanged(String)` | AdminGeneralSection file picker | Persists `logoSvgPath` |
| `ReceiptPrinterNameChanged(String)` | PrintingSection dropdown | Persists `receiptPrinterName` |
| `BarcodePrinterNameChanged(String)` | PrintingSection dropdown | Persists `barcodePrinterName` |

#### Financial Row Visibility Equations

Used in `PrinterService.cs` and `ImageExportService.cs` for receipt layout:

```
showSubtotal  = taxPiastres > 0 || discountPiastres > 0
showTax       = taxPiastres > 0
showDiscount  = discountPiastres > 0
Label         = "Grand Total" when subtotal shown, else "Total"
```

#### Windows Path Validation

Flutter-side regex enforced in `ExportDirectorySection`:
```
^[a-zA-Z]:\\(?:[^<>:"/\\|?*\n]+\\)*[^<>:"/\\|?*\n]*$
```

---

### 5n. DRM Licensing Architecture (Implemented)

```
lib/core/licensing/
├── domain/
│   ├── enums/license_status.dart        — LicenseStatus enum
│   └── entities/license_entity.dart     — LicenseEntity model (key, deviceId, activatedAt)
├── engine/
│   └── license_engine.dart              — LicenseEngine (orchestrator)
├── infrastructure/
│   ├── crypto/
│   │   ├── ed25519_verifier.dart        — Ed25519 signature verification
│   │   └── key_store.dart               — Embedded public key hex constant
│   ├── hwid/
│   │   ├── hwid_provider.dart           — Abstract HWID provider interface
│   │   └── windows_hwid_provider.dart   — Windows MachineGuid extraction
│   └── storage/
│       ├── license_storage.dart         — Abstract storage interface
│       ├── secure_storage_adapter.dart   — Primary: flutter_secure_storage
│       └── file_backup_adapter.dart      — Backup: XOR-obfuscated file
└── presentation/
    ├── activation_cubit.dart            — Cubit state machine (5 states)
    ├── activation_screen.dart           — Full-screen activation UI
    └── widgets/
        ├── activation_input.dart        — Key input form (base64url filtering)
        └── device_id_qr.dart            — QR code rendering (qr_flutter)
```

#### LicenseEngine Orchestrator

Central class with 4 injected dependencies:

| Dependency | Implementation | Purpose |
|---|---|---|
| `HwidProvider` | `WindowsHwidProvider` | Extracts machine-bound HWID via `reg query MachineGuid`, returns `CS-XXXX-XXXX` format |
| `LicenseStorage` (primary) | `SecureStorageAdapter` | Encrypted storage via `FlutterSecureStorage` (DPAPI on Windows) |
| `LicenseStorage` (backup) | `FileBackupAdapter` | XOR-obfuscated file at `getApplicationSupportDirectory()/CashierSystem/license.lic` |
| `Ed25519Verifier` | `Ed25519Verifier` | Offline asymmetric signature verification via `cryptography` package |

#### Key Methods

| Method | Behavior |
|---|---|
| `verifyLicense()` → `LicenseStatus` | Checks primary storage first, falls back to backup. Self-heals: if backup valid but primary corrupt, restores primary from backup. If device IDs mismatch → `tampered`. Both empty → `invalid`. |
| `quickVerify()` → `bool` | Fast path — reads only primary storage, checks device ID match. Used in hot paths (shift start, checkout confirm). |
| `activate(String key)` → `Future<void>` | Gets device ID, verifies key as Ed25519 signature of device ID, writes `LicenseEntity` to both storage providers. |
| `getDeviceId()` → `String` | Cached wrapper around `HwidProvider.getHardwareId()`. |

#### License Status Machine

```
┌──────────────┐
│  checking    │  Initial state during startup verification
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    valid     │     │   invalid    │     │   tampered   │
└──────────────┘     └──────┬───────┘     └──────┬───────┘
                            │                    │
                            ▼                    ▼
                    ActivationScreen      ActivationScreen
                    (enter key)           (tamper warning)
```

#### Activation Cubit State Machine

```
ActivationInitial
    │
    ▼ (checkLicense)
ActivationLoading
    │
    ├──→ ActivationSuccess (already licensed — skip)
    │
    └──→ ActivationDeviceReady(deviceId, status)
            │
            ▼ (submitActivationKey)
        ActivationLoading
            │
            ├──→ ActivationSuccess (key accepted → app unlocks)
            │
            └──→ ActivationError(message) (retry)
```

#### HWID Binding (Windows)

- Reads `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` via `reg query`
- Strips dashes, takes last 8 hex characters
- Formats as `CS-XXXX-XXXX`
- Zero admin required — reads standard registry key
- `HwidProvider` interface is abstract; only Windows is implemented

#### Cryptographic Verification

- Algorithm: Ed25519 (via Dart `cryptography` package)
- Public key embedded as hex string in `key_store.dart`
- Activation key = base64url-encoded Ed25519 signature of device ID
- Verification: decode key → construct `Signature` → verify against `utf8.encode(deviceId)`
- Signatures are offline-verifiable — no network call needed

#### Dual Storage with Self-Healing

| Storage | Location | Protection |
|---|---|---|
| Primary | `FlutterSecureStorage` key `license_data` | OS-level encryption (DPAPI/Keychain) |
| Backup | `<supportDir>/CashierSystem/license.lic` | XOR-obfuscated + base64 encoded |

**Self-healing flow in `verifyLicense()`:**
1. Read primary → valid + device ID match → return `valid`
2. Primary corrupt/mismatch → set `detectedTampered = true`
3. Read backup → valid + device ID match → restore primary from backup → return `valid`
4. Backup also mismatch → return `tampered`
5. Both empty → return `invalid`

#### Operational Gating

| Gating Point | File | Behavior |
|---|---|---|
| ShiftBloc.StartShift | `lib/features/auth/presentation/bloc/shift_bloc.dart` | `quickVerify()` — blocks shift start if license invalid |
| CheckoutBloc.ConfirmSale | `lib/features/checkout/presentation/bloc/checkout_bloc.dart` | `quickVerify()` — blocks sale confirm if license invalid |
| App startup | `lib/main.dart` | Silent async check — logs warning on tampered status |

#### Dependencies

| Package | Version | Purpose |
|---|---|---|
| `cryptography` | `^2.7.0` | Ed25519 signature verification |
| `qr_flutter` | `^4.1.0` | QR code generation for device ID display |
| `flutter_secure_storage` | `^9.2.4` | Encrypted primary license storage |

---



