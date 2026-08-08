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
* **Hive Encryption:** All Hive boxes encrypted via `HiveAesCipher` using a 32-byte key generated on first run and persisted in `flutter_secure_storage`. Boxes opened with `encryptionCipher: cipher` parameter (not deprecated `encryptionKey`).
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
├── Hive LazyBoxes (opened in initState via _openBoxes):
│   ├── LazyBox<AppReceiptModel>('receipts', encryptionCipher: cipher)
│   └── LazyBox<AppRefundModel>('refunds', encryptionCipher: cipher)
├── ValueNotifiers:
│   ├── _selectedDestination (ValueNotifier<NavDestination>, default = role's first) — tab switch
│   ├── _isSearchOpenNotifier (bool, default false) — overlay state
│   ├── _barcodeInjectionNotifier (String) — scanner→overlay bridge
│   ├── _discountFocusTrigger (int) — shortcut→discount focus bridge
│   └── _cartFocusTrigger (int) — discount submit→cart focus bridge
├── BlocListener<SettingsBloc> — syncs taxEnabled/taxPercent → CheckoutBloc.SetTaxPercent
├── BlocListener<CheckoutBloc> (confirmed) → dispatches CreateReceipt with taxPercent/discountPercent
├── BlocListener<ReceiptsBloc> (ready after loading) → RefreshInventory + auto-print via ReceiptPrintHelper
├── BlocListener<ShiftBloc> (ended) → LogoutRequested
├── BlocListener<ShiftBloc> (orphanRecovered) → snackbar (once, not every sale)
├── BlocListener<ShiftBloc> (error) → error snackbar
└── NavRail (role-based, see 5f)
    ├── 0: Shopping Cart → CheckoutWorkspace
    ├── 1: Package → InventoryWorkspace
    ├── 2: Chart Bar → SalesWorkspace
    ├── 3: Gear → SettingsWorkspace
    └── End Shift (signOut icon, always at bottom)
```

#### AppSettingsEntity (18 fields)

| Field | Type | Default | Description |
|---|---|---|---|---|---|
| `languageCode` | String | `'ar'` | UI language |
| `isDarkMode` | bool | `false` | Theme toggle |
| `storeName` | String | `''` | Store name for receipts |
| `receiptFootnote` | String | `'Thanks'` | Receipt footer text |
| `customBindings` | Map<String, List<String>> | `const {}` | User-overridden keyboard shortcut combos |
| `taxEnabled` | bool | `false` | Master tax toggle |
| `taxPercent` | int | `0` | Tax rate percentage (0-100) |
| `autoPrintEnabled` | bool | `false` | Auto-print toggle (stub) |
| `orderCounter` | int | `0` | Daily sequential order counter |
| `lastOrderDate` | String | `''` | Last order date (YYYY-MM-DD) for counter reset |
| `exportDirectoryPath` | String | `''` | Unified export directory for receipts and barcode PNGs (Windows absolute path) |
| `saveReceiptAsImage` | bool | `false` | Auto-save receipt as PNG image after sale confirmation |
| `storeAddress` | String | `''` | Store address printed on receipt headers |
| `storePhoneNumber` | String | `''` | Store phone number printed on receipt headers |
| `logoSvgData` | String? | `null` | Base64-encoded SVG content for receipt logo branding (replaces deprecated `logoSvgPath`) |
| `receiptPrinterName` | String? | `null` | Selected thermal receipt printer name (null = system default) |
| `barcodePrinterName` | String? | `null` | Selected barcode label printer name (null = system default) |
| `barcodeActionPreference` | String | `'printDirect'` | Presets the product-form barcode-label export action: `'printDirect'` (direct label print) or `'savePng'` (PNG export). Read only at `product_form_dialog.dart:255-260`. Does NOT affect scanner/cart behavior — scanning always adds to cart directly. |

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
| `AutoPrintToggled(bool)` | | Enable/disable automatic thermal receipt printing |
| `SaveReceiptAsImageToggled(bool)` | | Enable/disable receipt PNG export on sale confirm |
| `SetExportDirectoryPath(String)` | | Sets unified export directory (validated Windows path) |
| `StoreAddressChanged(String)` | | Updates store address on receipt header |
| `StorePhoneNumberChanged(String)` | | Updates store phone on receipt header |
| `LogoSvgChanged(String?)` | | Sets base64-encoded store logo SVG data (replaces path-based) |
| `ReceiptPrinterNameChanged(String?)` | | Sets selected receipt printer name |
| `BarcodePrinterNameChanged(String?)` | | Sets selected barcode label printer name |
| `BarcodeActionPreferenceChanged(String)` | | Sets barcode-label export action: `'printDirect'` or `'savePng'` (product-form preset) |
| `UpdateOrderCounter(counter, date)` | | |

### 5b. Settings Workspace Layout (9 Sections — admin view; non-admin sees Appearance, Localization, Shortcuts only)

```
SettingsWorkspace
└── SectionCard(title: settings, mainAxisSize: max)
    └── SingleChildScrollView
        ├── User Management Section  → user list + add/change-password (admin only, first section)
        ├── Admin General Section    → storeName TextField, receiptFootnote TextField, store
        │                              address, phone, SVG logo picker (admin only)
        ├── Appearance Section       → dark mode Switch (ThemeToggled)
        ├── Localization Section     → SegmentedButton (AR/EN), RTL/LTR banner (LanguageToggled)
        ├── Tax Section              → enable Switch + rate TextField (admin only, conditionally shown)
        ├── Printing Section         → auto-print Switch, save-as-image Switch, printer dropdowns
        │                              (receipt + barcode) (admin only)
        ├── Export Directory Section → unified path + folder picker (admin only)
        ├── Reset All Data           → subtitle + destructive ElevatedButton + confirmation dialog (admin only)
        └── Keyboard Shortcuts       → 6 groups: Navigation, Search, Cash Drawer, Cart,
                                       Quick Tiles, Inventory (see 5e)
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
├── Events (8): LoadInventory, AddProduct, DeleteProduct, SearchProducts, ToggleQuickTile,
│   UpdateTileColor, LookupProduct (barcode lookup for checkout; inventory_event.dart:52),
│   RefreshInventory (reload all products — dispatched by AppShell after receipt ready; :57)
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
│   ├── ClearCart                        — resets _confirmInProgress, discountPercent,
│   │                                      amountPaid; preserves taxPercent only
│   │                                      (checkout_bloc.dart:95-101)
│   ├── SetAmountPaid(piastres)          — replaces, not adds; rejects negative but
│   │                                      accepts zero; no cap vs totalPiastres
│   │                                      (checkout_bloc.dart:104)
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
│       ├── taxAmount → (subtotalPiastres * taxPercent / 100).round()
│       ├── totalPiastres → subtotalPiastres - discountAmount + taxAmount
│       ├── changePiastres → max(0, (amountPaidPiastres ?? 0) - totalPiastres)
│       └── isPaid → amountPaidPiastres != null && amountPaidPiastres >= totalPiastres
├── Guards on ConfirmSale (bloc): _confirmInProgress single-flight flag, license
│   verifyLicense() != valid → DatabaseFailure. NO isPaid guard — no ValidationFailure
│   `insufficient_payment` exists; sale confirms with zero amount paid
│   (cash_drawer_assistant.dart:276-279 gates the button instead:
│   enabled only when total > 0 && status != confirmed). isPaid getter exists on
│   CheckoutState but is unused by ConfirmSale. _confirmInProgress reset on ClearCart
│   and license failure
├── generateOrderNumber: reads ShiftBloc state, uses shift.orderCount,
│   dispatches IncrementShiftOrderCount(shift.id) to increment,
│   returns "ORD-${orderCount.padLeft(5, '0')}"; hardcoded fallback 'ORD-00001'
│   when no active shift (app.dart:158)
  └── On confirm: emit confirmed + orderNumber → CheckoutConfirmationDialog (optimistic)
      ├── ReceiptsBloc ReceiptCreated → success icon (check_circle), auto-dismiss 2s → ClearCart
      └── ReceiptsBloc ReceiptPersistenceFailure → error icon (failure), manual dismiss → ClearCart

CheckoutConfirmationDialog (StatefulWidget)
├── PopScope(canPop: false) / (canPop: true on failure)
├── Listens to ReceiptsBloc for receipt creation status
├── Optimistic on open: shows `CircularProgressIndicator` + "Processing sale..." with no icon
├── Transitions to success or error variant once `ReceiptsBloc` responds
├── Success: auto-dismiss via Future.delayed(2 seconds); error auto-dismisses after 5 seconds
│   (checkout_confirmation_dialog.dart:33-35, 66-68)
├── Failure: auto-dismisses after 5s — no manual dismissal required (dismiss button still offered)
├── Dismiss button (close X) appears after 3 seconds for BOTH success and error variants (:36-38)
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

CartItemEntity (checkout domain entity, lib/features/checkout/domain/entities/cart_item_entity.dart)
├── Fields: barcode (String), name (String), quantity (int, default 1),
│   unitPricePiastres (int)
├── totalPiastres → quantity * unitPricePiastres
└── copyWith() + ==/hashCode
```

### 5e. Keyboard Shortcuts Feature Architecture (Implemented)

```
lib/features/shortcuts/
├── intents.dart                  # 21 Intent subclasses
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

#### Intents (21 classes)

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

#### 6.2b Feature-Specific Failures (Receipts)
 
* `RefundLockFailure` — rejects refund/modify on a locked receipt (`status != active`).
	* Carried fields: `message` (`String`), `receiptId` (`String`), `currentStatus` (`ReceiptStatus`).
	* Example trigger: `ProcessRefund` on a `returned` receipt or a cross-shift refund; surfaced by the refund confirmation dialog as the "already returned or modified" error dialog.
 
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
main.dart (root, startup sequence):
  ┌─ Hive.initFlutter()
  ├─ Register all TypeAdapters (settings, product, user, shift, receipt, refund, receipt_item)
  ├─ Generate/persist 32-byte encryption key in FlutterSecureStorage
  ├─ Open all Hive boxes with HiveAesCipher:
  │   ├── Box<AppSettingsModel>('settings', encryptionCipher: cipher)
  │   ├── Box<AppProductModel>('inventory', encryptionCipher: cipher)
  │   ├── Box<AppUserModel>('auth_users', encryptionCipher: cipher)
  │   ├── Box<AppShiftModel>('shifts', encryptionCipher: cipher)
  │   ├── Box<String>('active_shifts', encryptionCipher: cipher)
  │   └── LazyBox<String>('audit_log', encryptionCipher: cipher)
  ├─ AuditService(box: auditBox)
  ├─ HydratedBloc.storage = HydratedStorage.build(...)  ← must be AFTER Hive init
  ├─ ensurePrintServerBuilt() — publishes .NET project to build/ if missing
  ├─ PrintServerManager.start() — multi-candidate path resolution
  ├─ LicenseEngine (silent async check — logs tamper warning)
  └─ runApp(App(...))

App (MaterialApp)
└── RepositoryProvider<AuditService>  ← cross-cutting audit access
    └── RepositoryProvider<IAuthRepository>  ← for receipts auth checks
        └── MultiBlocProvider
            ├── BlocProvider<AuthBloc> (dispatches CheckAuth on create)
            └── BlocProvider<SettingsBloc> (dispatches LoadSettings on create)
                └── BlocProvider<InventoryBloc> (dispatches LoadInventory)
                    └── BlocProvider<CheckoutBloc> (injects generateOrderNumber)
                        └── BlocProvider<ShiftBloc> (receives username from AuthState)
                            └── BlocBuilder<AuthBloc, AuthState>
                                ├── (initial | loading) → AppLoading
                                ├── (setupRequired) → OnboardingFlow
                                ├── (unauthenticated | passwordChangeRequired) → LoginScreen
                                └── (authenticated user) → AppShell(user, hiveCipher)
                                    └── _openBoxes() → LazyBox<AppReceiptModel>('receipts') + LazyBox<AppRefundModel>('refunds')
                                    └── RepositoryProvider<IInventoryRepository>
                                        └── MultiBlocProvider
                                            ├── BlocProvider<ReceiptsBloc>
                                            │   ├── ReceiptsRepositoryImpl(box: LazyBox) (stock decrement)
                                            │   ├── IInventoryRepository (stock decrement)
                                            │   ├── RefundsRepositoryImpl(box: LazyBox)
                                            │   ├── IAuthRepository (admin re-auth for modifications)
                                            │   ├── getCurrentShiftId callback
                                            │   └── AuditService? (nullable)
                                            └── BlocProvider<SalesBloc>
                                                ├── ReceiptsRepositoryImpl(box: LazyBox)
                                                └── ShiftsRepositoryImpl(box: Box, activeBox: Box)
                                                └── MultiBlocListener
                                                    ├── BlocListener<SettingsBloc> (tax changes → SetTaxPercent)
                                                    ├── BlocListener<ShiftBloc> (ShiftEnded → LogoutRequested)
                                                    ├── BlocListener<ShiftBloc> (orphan recovered → snackbar, once)
                                                    ├── BlocListener<ShiftBloc> (error → error snackbar)
                                                    ├── BlocListener<CheckoutBloc> (confirmed → CreateReceipt)
                                                    ├── BlocListener<ReceiptsBloc> (ready → RefreshInventory + auto-print)
                                                    └── BlocListener<ReceiptsBloc> (error → CheckoutConfirmationDialog failure)
                                                        └── AppShell(user, hiveCipher) — Scaffold + NavRail + IndexedStack workspace
```

#### AuthBloc (plain Bloc, not Hydrated)

| Events | State Fields | Notes |
|---|---|---|
| `CheckAuth` | `status: AuthStatus (initial, loading, authenticated, unauthenticated, passwordChangeRequired, setupRequired)` | Seeds the admin user lazily on first `getAll()` call via `__seeded__` marker key. If `__setup_completed__` absent, emit `setupRequired` → 3-step onboarding flow (Welcome → Features → Admin Setup). `passwordChangeRequired` (auth_state.dart:4) routes to LoginScreen, which shows a failure banner — there is no change-password UI |
| `CompleteAdminSetup(password)` | | Validates min 8 chars, hashes password, saves admin user with `mustChangePassword: false`, writes `__setup_completed__` marker, emits `authenticated` |
| `LoginRequested(username, password)` | `user: UserEntity?` | Password: PBKDF2-HMAC-SHA256 (100k iterations) hex compare against salted hash |
| `LogoutRequested` | `failure: Failure?` | No hydrate — session-only |
| `LoadUsers` | `users: List<UserEntity>` | Fetches all users for admin UI |
| `CreateUser(username, password, role)` | | Admin only. Validates username (3-30 chars, alphanumeric + underscore). Password min 8 chars. Auto-generates salt |
| `ChangePassword(username, currentPassword, newPassword)` | | Admin re-auth required. Min 8 chars for new password. Sets `mustChangePassword: false` |
| `DeleteUser(username)` | | Cannot delete self |

**Rate Limiting:** `_failedAttempts` counter tracks consecutive failures. At ≥3 failures, exponential backoff lockout = `_failedAttempts * 2` seconds. Resets on successful login. Username validated client-side via `RegExp(r'^[a-zA-Z0-9_]{3,30}$')`.

**AuthRepository (Hive `auth_users` box):**
- `getAll()` → `Either<Failure, List<UserEntity>>` (seeds the admin user via `__seeded__` marker key if absent — the seed user gets `mustChangePassword: true`; cashiers are created later via User Management)
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
  final bool mustChangePassword;  // true for the seeded admin, reset on password change
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
  UserRole.admin: [
    NavDestination.sales,
    NavDestination.inventory,
    NavDestination.settings,
  ], // Default: Sales
  UserRole.cashier: [
    NavDestination.checkout,
    NavDestination.sales,
    NavDestination.settings,
  ], // Default: Checkout (inventory is admin-only)
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
| `CreateReceipt(shiftId, orderNumber, items, subtotalPiastres, discountPiastres, taxPiastres, totalPiastres, username, taxPercent, discountPercent)` | `status: ReceiptBlocStatus (initial, loading, ready, error)` | **Double-save sequence** (receipts_bloc.dart:159-204): 1. Save `ReceiptEntity` (`stockUpdated: false`) $\rightarrow$ 2. Iterate items, call `IInventoryRepository.updateStock`, collect failed barcodes into `stockFailedBarcodes` $\rightarrow$ 3. Save again with `stockUpdated: stockFailedBarcodes.isEmpty` and persisted `stockFailedBarcodes` — receipt is persisted even when stock decrement fails $\rightarrow$ 4. **On stock failure emits `error` (`DatabaseFailure`) and returns WITHOUT appending to `state.receipts`** — the stock-failed sale is invisible in the UI until reload; only on success appends to `state.receipts` (:230-236) and emits `ready`. Cross-validation before sequence (`_validateReceiptFinances`, :104-131) enforces BOTH `Σ(qty × unitPricePiastres) == subtotalPiastres` AND `total == subtotal - discount + tax` — emits `ValidationFailure` on either mismatch. |
| `LoadReceipts` | `receipts: List<ReceiptEntity>` (non-nullable, default `[]`) | |
| `LoadReceiptsByMonth(year, month)` | `failure: Failure?` | In-memory filter on `receipts` box |
| `ProcessRefund(receipt, type, amountRestored)` | | Dispatched by the refund confirmation dialog with hardcoded `type: RefundType.full` and `amountRestored: totalPiastres` — no full/partial selector exists in the UI. Guard: blocks `returned` receipts with `RefundLockFailure`. Guard: blocks cross-shift refunds — also `RefundLockFailure` with `currentStatus` set (receipt.shiftId != current shift; shift guard exists on refund ONLY, not on modify). On success: restores stock, creates RefundEntity, sets status to `returned`. |
| `ModifyReceipt(receipt, items, subtotal)` | | Guard: blocks ANY status != `active` with `RefundLockFailure` (receipts_bloc.dart:391) — not just `returned`. Only `active` receipts can be modified directly. Cross-validation enforces `total == subtotal - discount + tax`. Cannot add items absent from original receipt — emits `DatabaseFailure` 'Item not found in original receipt' (:425-435). On success: recalculates totals, increments modificationCount, sets status to `modified`. |
| `AuthorizedModifyReceipt(receipt, items, subtotal, adminPassword)` | | Admin-authorized modification path. Requires adminPassword (PBKDF2-hashed via `hashPassword(adminPassword, adminUser.passwordSalt)` — constant-time compare against stored hash). Guard: blocks only `returned` receipts (:499). Cross-validation enforces `total == subtotal - discount + tax`. Cannot add new items — same 'Item not found in original receipt' guard (:575-585). On success: same as ModifyReceipt. Used when receipt status is `modified` (requires admin authorization) or when cashier needs admin override. |
| `retryPendingStockUpdates()` | (method, not event) | Called on startup by `AppShell` via `unawaited(bloc.retryPendingStockUpdates())` (receipts_bloc.dart:58-102). Finds all receipts with `stockUpdated == false`, retries stock decrements. Re-saves receipts with narrowed `stockFailedBarcodes` on partial success; only fully clears (`stockUpdated: true`, barcodes cleared) when ALL items succeed. Caveat: a receipt with empty `stockFailedBarcodes` but `stockUpdated == false` (crash between double-save) retries ALL items; unknown barcodes fall back to a zero-quantity item via `firstWhere` `orElse` and never resolve — stuck pending forever. |

**Single-flight guard:** `_isProcessing` flag — concurrent `CreateReceipt`/`ProcessRefund`/`ModifyReceipt`/`AuthorizedModifyReceipt` events are silently dropped while one is running (receipts_bloc.dart:138, 287, 384, 492). No queueing, no error emitted.

**ReceiptsRepository (Hive `receipts` box):**
- `save(receipt)` → `Either<Failure, void>`
- `getAll()` → `Either<Failure, List<ReceiptEntity>>`
- `getByShift(shiftId)` → `Either<Failure, List<ReceiptEntity>>`
- `getByMonth(year, month)` → `Either<Failure, List<ReceiptEntity>>` (filter by createdAt year/month)
- `getByDate(date)` → `Either<Failure, List<ReceiptEntity>>` (all receipts for a specific date — used for today's summary)
- `getByStockNotUpdated()` → `Either<Failure, List<ReceiptEntity>>` (filters `stockUpdated == false` — used for startup retry)

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
  final int taxPercent;            // Snapshot of tax rate at time of sale (default 0)
  final int discountPercent;       // Snapshot of discount rate at time of sale (default 0)
  final DateTime createdAt;
  final String username;
  final bool stockUpdated; // Defaults to false; set to true after all inventory updates complete
  final List<String> stockFailedBarcodes; // Barcodes whose stock decrement failed; default []
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

ReceiptsBloc needs repositories and optional AuditService injected:
```dart
ReceiptsBloc({
  required IReceiptsRepository receiptsRepo,
  required IInventoryRepository inventoryRepo,
  required IRefundsRepository refundsRepo,
  required IAuthRepository authRepo,
  required String Function() getCurrentShiftId,
  AuditService? auditService,
})
```

Registration in `app_shell.dart` (also triggers startup stock retry):
```dart
BlocProvider(
  create: (ctx) {
    final bloc = ReceiptsBloc(
      receiptsRepo: ReceiptsRepositoryImpl(box: receiptsBox),   // LazyBox
      inventoryRepo: ctx.read<IInventoryRepository>(),
      refundsRepo: RefundsRepositoryImpl(box: refundsBox),      // LazyBox
      authRepo: ctx.read<IAuthRepository>(),
      getCurrentShiftId: () => ctx.read<ShiftBloc>().state.shift?.id ?? '',
      auditService: ctx.read<AuditService>(),
    );
    unawaited(bloc.retryPendingStockUpdates());
    return bloc;
  },
)
```

#### Post-Receipt Inventory Refresh

After a receipt is created (on `ReceiptBlocStatus.ready`), `AppShell` dispatches `RefreshInventory` to `InventoryBloc`. This ensures the inventory list reflects the stock decrement immediately. `RefreshInventory` is defined in `lib/features/inventory/presentation/bloc/inventory_event.dart` and re-loads all products from the Hive inventory box.

#### Auto-Print Listener (app_shell.dart:283-321)

`BlocListener<ReceiptsBloc>` fires on ANY loading→ready transition (`listenWhen`), not just sale creation — `LoadReceipts`/`LoadReceiptsByMonth` also trigger it. It reads `state.receipts.last`, so a stale receipt can be auto-printed on list loads, not only after sales. Gated by `settings.autoPrintEnabled || settings.saveReceiptAsImage` (:291). Skipped entirely on the stock-failure error path (no receipt appended to state).

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
| `LoadMonth(year, month)` | `todaySummary: TodaySummary?` | Query: `receiptsBox.values.where((r) => r.createdAt.year == year && r.createdAt.month == month)`. Group by month into `MonthGroupedData`. |
| `LoadShiftReceipts(shiftId)` | `shiftReceipts: List<ReceiptEntity>?` | Query: `ReceiptsRepository.getByShift(shiftId)` (insertion order, no sort). Used by cashier view. |
| | `monthData: MonthGroupedData?` | (No `LoadMonths` event exists — monthly summary bar uses `LoadMonth(year, month)`; MonthBrowser issues six individual `LoadMonth` calls.) |
| | `monthData: MonthGroupedData?` | |
| | `failure: Failure?` | |

**TodaySummary:** `{ receiptCount: int, totalPiastres: int, itemsSold: int }`
**MonthGroupedData:** `{ year: int, month: int, totalPiastres: int, receiptCount: int, itemsSold: int, days: List<DayGroup> }`
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
* **Double-Refund Lock:** `returned` receipts throw `RefundLockFailure` on any mutating action (refund or modify). `modified` receipts block further modification but allow refund. Only `active` receipts accept both refund and modification freely. Guard granularity differs by path: `ModifyReceipt` blocks ANY `status != active` (receipts_bloc.dart:391), `AuthorizedModifyReceipt` blocks only `returned` (:499), `ProcessRefund` blocks only `returned` plus cross-shift receipts (:294-306). The shift guard exists on refund ONLY — modify has no shift check.
* **Modification Flow:**
    1. Only `active` receipts accept direct modification. `modified` receipts require admin authorization via `AuthorizedModifyReceipt`. `returned` receipts are locked.
    2. Every item in the new list must exist on the original receipt — otherwise `DatabaseFailure` 'Item not found in original receipt' (:425-435, :575-585). New items cannot be added by modification.
    3. Calculate delta (Original Qty - New Qty).
    4. Call `IInventoryRepository.updateStock(barcode, delta)`.
    5. Recalculate totals $\rightarrow$ update `ReceiptEntity` $\rightarrow$ set `status = modified`, increment `modificationCount`.
* **Stock Restoration:** `updateStock` delta is SIGNED — modify uses `delta = oldQty - newQty`, so increasing a quantity yields a NEGATIVE delta (further stock decrement); only refund restores inventory with a strictly positive delta.

### 5j. Hive Box Summary

| Box Name | Entity | Feature | Notes |
|---|---|---|---|---|
| `auth_users` | `UserEntity` → `AppUserModel` | Auth | Lazy seed on first read via `__seeded__` marker key — seeds the admin user only; cashiers are created via User Management. `__setup_completed__` marker tracks admin password initialization |
| `shifts` | `ShiftEntity` → `AppShiftModel` | Auth/Shift | O(1) key = UUID |
| `active_shifts` | `String` (username → shiftId) | Auth/Shift | Companion index box for O(1) `getActiveShift()` |
| `settings` | `AppSettingsModel` | Settings | HydratedBloc auto-serialize. TypeAdapter typeId=0, fields 0-18 — all 18: languageCode, isDarkMode, storeName, receiptFootnote, customBindings, taxEnabled, taxPercent, autoPrintEnabled, orderCounter, lastOrderDate, exportDirectoryPath, saveReceiptAsImage, storeAddress, storePhoneNumber, logoSvgData, receiptPrinterName, barcodePrinterName, barcodeActionPreference |
| `inventory` | `AppProductModel` | Inventory | HydratedBloc auto-serialize. TypeAdapter typeId=1, field 6=notes |
| `receipts` | `ReceiptEntity` → `AppReceiptModel` | Receipts | O(1) LazyBox key = UUID. Requires `ReceiptItemAdapter` (typeId=6) for `List<ReceiptItem>` serialization. Opened on demand in AppShell. |
| `refunds` | `RefundEntity` → `AppRefundModel` | Refunds | O(1) LazyBox key = UUID. Opened on demand in AppShell. |
| `audit_log` | `AuditEntry` (JSON string, no TypeAdapter) | Audit | Encrypted LazyBox. Entries serialized as JSON. 90-day pruning after every write, throttled to ≥1 min between prunes. |

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

audit-logging (cross-cutting, depends on: auth-and-shifts, receipts)
  └── AuditService wrapping Hive LazyBox<String>('audit_log')
  └── AuthBloc integration: login/logout/user management events
  └── ReceiptsBloc integration: receipt creation/stock failure events
  └── 90-day retention with automatic pruning on every write
```

### 5l. Feature Branch Order

1. `feature/auth-and-shifts` — AuthBloc, ShiftBloc, UserEntity, ShiftEntity, AuthRepository, ShiftsRepository, LoginScreen, User Management section, role-based nav, End Shift flow, orphan recovery, first-time admin setup (setup marker machinery)
2. `feature/onboarding` — 3-step onboarding flow (Welcome → Features → Admin Setup), OnboardingBloc, OnboardingFlow gate in `app.dart`, seed reduced to admin-only
3. `feature/receipts` — ReceiptsBloc, ReceiptEntity, ReceiptsRepository, IInventoryRepository adapter, BlocListener bridge in AppShell, stock decrement
4. `feature/sales-analytics` — SalesBloc, SalesWorkspace (admin + cashier views), SummaryBar, MonthBrowser
5. `feature/print-server` — .NET 8 sidecar for thermal receipt + barcode printing, Flutter PrintService client, settings UI (printing, export dir, store identity), receipt reprint button
6. `feature/drm-licensing` — Offline Ed25519 licensing system, activation screen, HWID binding, dual storage with self-healing, operational gating

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
│    └── POST /api/printing/save-png                           │
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
│    │      (handles both print + PNG; skipPrint/saveAsPng     │
│    │       flags control behavior)                           │
│    ├── POST /api/printing/save-png       → ImageExportService│
│    │      (PNG-only endpoint, used by Save PNG button)       │
│    └── POST /api/printing/barcode        → PrinterService    │
│                                                              │
│  Services/                                                   │
│    ├── PrinterService.cs    — System.Drawing.Printing        │
│    │   ├── GetInstalledPrinters()                            │
│    │   ├── PrintReceipt() — GDI+ receipt layout (Consolas)   │
│    │   ├── PrintBarcodeAsync() — Code128 via BarcodeLib      │
│    │   └── ResolvePrinterName() — falls back to first        │
│    │       installed printer when preferred missing;         │
│    │       returns null when none installed — no printer-    │
│    │       name validation surfaces to Flutter               │
│    │       (PrinterService.cs:257-274)                       │
│    │                                                         │
│    └── ImageExportService.cs — SkiaSharp                     │
│        └── SaveReceiptAsPngAsync() — white bg, black text,   │
│            │   gray meta/dividers (monochrome palette; no    │
│            │   blue/orange accent colors; SVG logo keeps     │
│            │   its own colors via Svg.Skia)                  │
│            ├── SkiaSharp.HarfBuzz for Arabic shaping         │
│            ├── LTR layout rendered unconditionally — IsRtl   │
│            │   is serialized but never read (no RTL mirror)  │
│            └── Filename `receipt_yyyyMMdd_HHmmss.png`        │
│                (second-precision — same-second saves         │
│                overwrite); missing dir auto-created via      │
│                Directory.CreateDirectory (ImageExport        │
│                Service.cs:19-22)                             │
│                                                              │
│  Models/                                                     │
│    ├── ReceiptRequest.cs   — 22 fields: items, subtotal,     │
│    │   discount, tax, total (piastres), tax_percent,         │
│    │   discount_percent, is_rtl, save_as_png, skip_print,    │
│    │   outputDirectory, printer_name, store identity (name,  │
│    │   addr, phone), logo_svg_data, footnote, order_number,  │
│    │   username, created_at, id, shift_started               │
│    └── BarcodeRequest.cs   — BarcodeData (DataAnnotations:   │
│        max 80 chars, printable-ASCII regex), product info    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

#### ReceiptPrintHelper (Flutter Core — Auto-Print Bridge)

| File | Location | Responsibility |
|---|---|---|
| `ReceiptPrintHelper` | `lib/core/printing/receipt_print_helper.dart` | Static utility: builds `ReceiptRequest` JSON payload from `ReceiptEntity` + `AppSettingsEntity`, dispatches to `PrintService`. Handles `skipPrint`/`saveAsPng` flags. |

ReceiptPrintHelper is a static helper called from `AppShell`'s `BlocListener<ReceiptsBloc>` after receipt creation succeeds. It orchestrates:
1. Building the receipt JSON payload (items, finances, taxPercent/discountPercent, store identity, RTL flag, logo SVG data)
2. Resolving the output directory (`exportDirectoryPath` or fallback to `~/Downloads`)
3. Calling `PrintService.printReceipt(payload)` with appropriate flags
4. Showing success/failure snackbar based on result

```dart
// Key method signatures
static Map<String, dynamic> buildPayload({ReceiptEntity, AppSettingsEntity, shiftStartedAt, outputDir, saveAsPng, skipPrint, printerName})
static Future<void> printReceipt({ReceiptEntity, AppSettingsEntity, shiftStartedAt, printerName})
static Future<String> saveAsPng({ReceiptEntity, AppSettingsEntity, shiftStartedAt})  // Returns file path
```

The `skipPrint` flag is set when `saveReceiptAsImage == true && !autoPrintEnabled` — user wants PNG only, no thermal print.

#### Print Server Manager (Flutter Core)

| File | Location | Responsibility |
|---|---|---|
| `PrintServerManager` | `lib/core/printing/print_server_manager.dart` | `Process.start('PrintServer.exe')` — sidecar lifecycle with multi-candidate path resolution (side-by-side with exe, build/ output, .NET bin). start/stop/dispose lifecycle management (no `/health` endpoint exists). |
| `PrintService` | `lib/core/printing/print_service.dart` | HTTP client via `dart:io` HttpClient — `getLocalPrinters()`, `printReceipt(payload)` (POST /receipt), `saveReceiptPng(payload)` (POST /save-png), `printBarcode()` (POST /barcode) |
| `PrintServer.csproj` | `PrintServer/PrintServer.csproj` | .NET 8 web SDK, SkiaSharp 2.88.9, SkiaSharp.HarfBuzz, BarcodeLib 2.4.0, Svg.Skia 2.0.0 |
| `Program.cs` | `PrintServer/Program.cs` | Kestrel host on `127.0.0.1:5150`, 4 endpoints (local-printers, receipt, save-png, barcode), rate limiter (30 req/s). POST /receipt returns `{ printed, pngPath }` where `printed = !SkipPrint && PrintReceipt(...)` — PNG save errors surface as HTTP 500 and print is still attempted (Program.cs:49-56) |

#### Settings Events (Full SettingsBloc Register — 21 Event Classes)

All dispatched from settings UI sections and handled by `SettingsBloc` (21 event classes in `settings_event.dart`, 20 handlers registered in `settings_bloc.dart` — `RefreshLocalPrinters` has no handler):

| Event | UI Trigger | Side Effects |
|---|---|---|
| `LoadSettings` | Bloc creation / SettingsWorkspace error retry | Loads settings from repository |
| `LanguageToggled(String)` | LocalizationSection SegmentedButton | Persists `languageCode` |
| `ThemeToggled(bool)` | AppearanceSection switch | Persists `isDarkMode` |
| `StoreNameChanged(String)` | AdminGeneralSection text field | Persists `storeName` |
| `ReceiptFootnoteChanged(String)` | AdminGeneralSection text field | Persists `receiptFootnote` |
| `AddCustomBinding(action, combo)` | ShortcutsSection key capture | Adds combo; removes it from conflicting actions |
| `RemoveCustomBinding(action, combo)` | ShortcutsSection key capture | Removes custom combo |
| `ResetCustomBinding(action)` | ShortcutsSection reset | Clears action's custom combos entirely |
| `TaxToggled(bool)` | TaxSection switch | Persists `taxEnabled` |
| `TaxPercentChanged(int)` | TaxSection rate field | Persists `taxPercent` |
| `AutoPrintToggled(bool)` | PrintingSection switch | Persists `autoPrintEnabled` |
| `SaveReceiptAsImageToggled(bool)` | PrintingSection switch | Persists `saveReceiptAsImage` |
| `SetExportDirectoryPath(String)` | ExportDirectorySection file picker | Validates Windows path regex, persists |
| `StoreAddressChanged(String)` | AdminGeneralSection text field | Persists `storeAddress` |
| `StorePhoneNumberChanged(String)` | AdminGeneralSection text field | Persists `storePhoneNumber` |
| `LogoSvgChanged(String?)` | AdminGeneralSection file picker | Persists `logoSvgData` (base64 SVG) |
| `ReceiptPrinterNameChanged(String)` | PrintingSection dropdown | Persists `receiptPrinterName` |
| `BarcodePrinterNameChanged(String)` | PrintingSection dropdown | Persists `barcodePrinterName` |
| `RefreshLocalPrinters` | (declared, settings_event.dart:102) | No handler registered and no dispatch site — dead/unused event class |
| `BarcodeActionPreferenceChanged(String)` | ProductFormDialog barcode action selector | Persists `barcodeActionPreference` |
| `UpdateOrderCounter(counter, date)` | Internal (no UI dispatch — counter advanced via `ShiftBloc.IncrementShiftOrderCount`) | Persists `orderCounter` + `lastOrderDate` |

#### Financial Row Visibility Equations

Used in `PrinterService.cs` and `ImageExportService.cs` for receipt layout:

```
showSubtotal  = taxPiastres > 0 || discountPiastres > 0
showTax       = taxPiastres > 0
showDiscount  = discountPiastres > 0
Label         = "Total" — always; "Grand Total" appears nowhere
                (PrinterService.cs:149, ImageExportService.cs:353)
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
│   └── entities/license_entity.dart     — LicenseEntity model (deviceId, activationSignature, activatedAt)
├── engine/
│   └── license_engine.dart              — LicenseEngine (orchestrator)
├── infrastructure/
│   ├── crypto/
│   │   ├── ed25519_verifier.dart        — Ed25519 signature verification
│   │   └── key_store.dart               — Build-time public key via `--dart-define=ED25519_PUBKEY_HEX`
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
| `verifyLicense()` → `LicenseStatus` | Checks primary storage first, falls back to backup. Self-heals: if backup valid but primary corrupt, restores primary from backup. Calls `_validateEntity()` which verifies Ed25519 signature (not just device ID match) — if signature fails → `tampered`. Both empty → `invalid`. |
| `verifyLicense()` → `LicenseStatus` | Runtime gating reuse — `ShiftBloc.StartShift` (`shift_bloc.dart:30`) and `CheckoutBloc.ConfirmSale` (`checkout_bloc.dart:118`) call it directly; any status != `valid` blocks with a `DatabaseFailure`. |
| `activate(String key)` → `Future<bool>` | Gets device ID, verifies key as Ed25519 signature of device ID, writes `LicenseEntity` to both storage providers. Returns `true` only when the key verifies and both storages are written; `false` on invalid key or failure. |
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
- Public key injected at build time via `--dart-define=ED25519_PUBKEY_HEX=<hex>` in `key_store.dart`
- Activation key = base64url-encoded Ed25519 signature of device ID
- Verification: decode key → construct `Signature` → verify against `utf8.encode(deviceId)`
- Runtime re-verification: `_validateEntity()` calls `Ed25519Verifier.verifySignature()` on every license check (not just activation). Stored signature must verify against current device ID — prevents key rotation attacks and storage tampering.
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
| ShiftBloc.StartShift | `lib/features/auth/presentation/bloc/shift_bloc.dart` | `verifyLicense()` — blocks shift start if license invalid (emits `DatabaseFailure`) |
| CheckoutBloc.ConfirmSale | `lib/features/checkout/presentation/bloc/checkout_bloc.dart` | `verifyLicense()` — blocks sale confirm if license invalid (emits `DatabaseFailure`) |
| App UI gate (hard) | `lib/app.dart` | `_checkLicense()` in `initState` → `verifyLicense()`; spinner while `checking`; unless `valid`, the entire app is replaced by `ActivationScreen` |
| App boot (silent) | `lib/main.dart` | `silentLicenseCheck()` fire-and-forget — logs warning on tampered status |

#### Dependencies

| Package | Version | Purpose |
|---|---|---|
| `cryptography` | `^2.7.0` | Ed25519 signature verification |
| `qr_flutter` | `^4.1.0` | QR code generation for device ID display |
| `flutter_secure_storage` | `^9.2.4` | Encrypted primary license storage |

---

### 5o. Audit Logging Architecture (Implemented)

```
lib/core/audit/
├── audit_event.dart          # AuditEventType enum + AuditEntry data class
└── audit_service.dart        # AuditService (log, getRecent, _pruneOld)
```

#### AuditEntry Model

```dart
class AuditEntry {
  final DateTime timestamp;
  final AuditEventType type;
  final String? username;
  final String details;
  final bool success;
}
```

JSON-serialized via `toJson()`/`fromJson()` — stored as strings in Hive `LazyBox<String>`.

#### AuditEventType Enum

| Value | Source | Logged When |
|---|---|---|
| `login` | AuthBloc | Successful login |
| `loginFailed` | AuthBloc | Failed login (user not found / wrong password / exception) |
| `logout` | AuthBloc | User logged out |
| `userCreated` | AuthBloc | Admin creates new user |
| `userDeleted` | AuthBloc | Admin deletes user |
| `passwordChanged` | AuthBloc | Self password change or admin-reset |
| `receiptCreated` | ReceiptsBloc | Receipt persisted (`receipt ID: N items, totalPiastres`) |
| `stockUpdateFailed` | ReceiptsBloc | Stock decrement failed for N items during receipt creation |
| `stockRetryResolved` | ReceiptsBloc | Startup retry successfully resolved pending stock |

#### AuditService

| Method | Behavior |
|---|---|
| `log(type, {username?, details, success})` | Creates `AuditEntry`, writes JSON to `LazyBox<String>('audit_log')`, runs `_pruneOld()` |
| `getRecent({limit})` | Returns newest-first entries up to `limit` |

**90-Day Retention:** `_pruneOld()` computes `cutoff = DateTime.now() - 90 days`, deletes all entries with `timestamp.before(cutoff)`. Runs after every `log()` call but is throttled: the scan is skipped when the last prune was < 1 minute ago (`_lastPrune` timestamp). O(n) full-scan per non-throttled write.

#### Wiring

```
main.dart
  └─ Hive.openLazyBox<String>('audit_log', encryptionCipher: cipher)
  └─ AuditService(box: box)
  └─ App(auditService: auditService)

app.dart
  └─ RepositoryProvider<AuditService>.value(value: auditService)
       └─ AuthBloc receives AuditService? via constructor (nullable, `?.`)
       └─ ReceiptsBloc receives AuditService? via constructor (nullable, `?.`)
```

#### Dependencies

None beyond `Hive` (already a core dependency). No new packages required.


---

### 5f. PlayStation Feature Architecture (Implemented)

**Domain** (`lib/features/checkout/domain/`):
- `StationEntity` — full value object (==/hashCode); `copyWith` uses an `_unset` Object sentinel so nullable session fields can be explicitly cleared; `currentTotalPiastres` is tier-aware via `_activeHourlyRate` (multi → `multiHourlyRate`).
- `SessionRecordEntity` — billing record; value equality.
- `IStationRepository` — `updateStationStatus(id, status, {sessionStartTime, isFixedDuration, fixedDurationMinutes, overtimeStartMinutes, sessionTier})`; null clears, sentinel keeps.
- `ISessionRecordRepository` — `getSessionRecords(limit)`, `saveSessionRecord`, `deleteSessionRecord`.

**Data** (`data/repositories/`, `data/models/`): Hive-backed `StationRepositoryImpl` + `SessionRecordRepositoryImpl` with `AppStationModel` / `AppSessionRecordModel` adapters (Hive typeIds 7/8 — no collision with existing 0-6).

**Presentation**:
- `StationBloc` (bloc/station_bloc.dart): `LoadStations`, `StartSession`, `EndSession`, `ConvertToOpenSession`, `SaveStation`, `DeleteStation`. Missing station/no active session → emit `DatabaseFailure` state (no `StateError`). `_buildSessionRecord` only when `sessionStartTime != null`; end clears `overtimeStartMinutes`/`fixedDurationMinutes` in repo too.
- `SessionRecordBloc` (cap default 100): `_onCreate` saves then reloads; state equality uses `listEquals(records)` so same-length updates still emit.
- `AutoConversionService`: 30s periodic scan; fixed-duration sessions past booked minutes → `ConvertToOpenSession`. Hosted by `AutoConversionHost` (disposes timer).
- Wiring: `StationWorkspace` grid in checkout (playstation business type), AppShell `BlocListener<StationBloc>` persists `lastCompletedSession` via `CreateSessionRecord` (shiftId/username attached), Sales workspace listens to reload session records (limit 20).

**Persistence contract:** end-session repo call clears `sessionStartTime`, `isFixedDuration`, `fixedDurationMinutes`, `overtimeStartMinutes`, `sessionTier` — state and Hive always agree.

---

### 5g. Grid-Mode Checkout Architecture (Implemented)

- `ProductCategoryGrid` (`lib/features/checkout/presentation/widgets/product_category_grid.dart`) — stateful: `ValueNotifier<String>` search, `ValueNotifier<String?>` selected category, `_favoriteNodes` map (per-favorite `FocusNode`s, disposed with grid); `focusIndexForAlt(FocusNode fallback, int slotIndex)` focus contract; consumes `BlocBuilder<InventoryBloc>` products + `state.quickTileList` for the favorites strip (`favoritesStripEnabled` via `context.select`).
- `CheckoutWorkspace` now stateful: `_gridFocusNode` (auto-focus gated to grid modes, post-frame), `_gridKey` GlobalKey for Alt-slot focus routing; `_FavoritesSlotIntent` + `Shortcuts`/`Actions`/`FocusTraversalGroup` keyboard layer (Alt+1..0 → favorites slots); grid layout Row cart:grid (2:5).
- `BarcodeScannerGate.enabled` — `initState` skips listener/focus attach, `build` returns child unwrapped when disabled; `app_shell` computes `enabled: !isGridMode` from `SettingsBloc`.
- Dropped: `AddTimedItem` event/handler, `TimeBillingDialog` — cart billing is scanner/quick-tile only; playstation uses station sessions.
- Settings: `favoritesStripEnabled` on `AppSettingsEntity` (default false), Hive adapter key 21 (writeByte count 23), `FavoritesStripToggled`-style event wired via settings bloc; no UI toggle yet (settings surface comes with settings refinements).

---

### 5h. Business-Adaptive Inventory (Implemented)

- `InventoryWorkspace` switches on `BusinessType`: retail `_buildContent`, fnb `_buildFnbContent` (3 columns: `_CategorizedColumn` groups by `category` ordering by CategoryBloc list then encounter order), playstation = `Column` [restored `_buildStations` + `_buildFlatContent` (products list, priceSuffix `inventory.perHour`)].
- `ProductCard.priceSuffix` optional param appends translated suffix to the price string.
- Product form (`ProductFormBody` + `ProductFormDialog`): `BusinessTypeFormMode` resolved via `context.select<SettingsBloc>` once; barcode label preview, barcode/stock fields, category dropdown, favorites toggle conditionally rendered; submit computes auto-barcode `generateAutoBarcode()` when `!barcodesEnabled` and product is new; stock passes through when `!stockEnabled`.
- Barcode generator: pure Dart `lib/features/inventory/domain/helpers/barcode_generator.dart` — `auto-<micros>`; `isAutoBarcode` prefix check.
- CategoryBloc: single app-shell global instance; inventory dialogs consume it via `BlocProvider.value` (no per-dialog instances; FnB grouping stays fresh after management).
