# System Architecture & Technical Specification
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Architectural Framework
The system implements **Clean Architecture** organized around a **Feature-First** structural paradigm. Each system module (`checkout`, `inventory`, `sales_history`) must be strictly segregated into independent computational layers to satisfy SOLID design principles.

```
lib/
├── core/                      # Shared cross-cutting concerns
│   ├── error/                 # Failure hierarchy
│   ├── theme/                 # Design tokens (spacing, text styles, app theme)
│   └── widgets/               # Reusable widgets (SectionCard, AnimatedCounter, AppEmpty, AppLoading, AppError)
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
* **Barcode Layout Engine:** `barcode_widget` package using native vector rendering mechanics.
* **Localization Implementation Engine:** Dedicated `LocalizationService` class housing an $O(1)$ `Map<String, Map<String, String>>` structural dictionary (bypassing `intl` code-generation to keep memory profiles minimal). The service exposes a `translate(String key, {String? languageCode, List<String>? params})` method and static `supportedLanguages` getter. `SettingsWorkspace` UI reads locale from `SettingsState.settings.languageCode` and passes it to the service for string resolution (`localizationService.translate(key)`). Parameter interpolation via `{0}`, `{1}` etc. is supported through the optional `params` list.
* **Core Shared Widgets:**
  * `SectionCard` (`lib/core/widgets/section_card.dart`): Universal card container with optional notch title, actions, configurable padding/sizing/flex fit. Renders as `Card` with `surfaceContainerLow` background, `outlineVariant` border, 12px radius.
  * `AnimatedCounter` (`lib/core/widgets/animated_counter.dart`): Lightweight text value transition via `AnimatedSwitcher` + `FadeTransition` (200ms).

### 3. Data Structures & Performance Optimization Rules 

#### Rule 1: O(1) Fast Inventory Lookup Map
To ensure lightning-fast item ingestion during high-volume cashier rushes on poor hardware, the central application state must store products inside an optimized **Hash Map** layout rather than a linear array list.
* **Data Layout:** `Map<String, ProductEntity>` where the **Key is the Barcode String**.
* **Performance Baseline:** Search evaluation runs at constant $O(1)$ time complexity, ensuring instant item retrieval whether the database contains 100 entries or 30,000 stationery products.
#### Rule 2: Segmented State Memory Allocation
To optimize execution memory profiles on 4GB RAM machines, the application state splits indexation upon boot:
1. `inventoryMap`: Core key-value matrix mapping barcodes directly to entities for backend business calculations.
2. `quickTileList`: A pre-filtered sub-array tracking exclusively entries tagged with `isQuickTile == true` to allow instant, calculation-free UI drawing loops on the Checkout Dashboard.

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
└── BlocProvider<SettingsBloc>
    └── BlocBuilder<SettingsBloc, SettingsState>
        ├── Theme: AppTheme.light / AppTheme.dark (based on isDarkMode)
        ├── Locale: Locale(languageCode)
        ├── localizationsDelegates: GlobalMaterialLocalizations.delegates
        └── Home: SettingsWorkspace
            └── SectionCard (title + actions in notch, replaces AppBar)
                ├── SingleChildScrollView → _SettingsSection cards
                │   ├── General Section (storeName, receiptFootnote)
                │   ├── Appearance Section (dark mode switch)
                │   └── Localization Section (EN/AR segmented button)
                └── Each interaction → Bloc event → HydratedBloc auto-save

SettingsBloc
├── Events: LanguageToggled, ThemeToggled, StoreNameChanged, ReceiptFootnoteChanged, LoadSettings
├── State: SettingsState { settings: AppSettingsEntity, status: SettingsStatus }
├── HydratedBloc fromJson/toJson → AppSettingsModel serialization
└── Repository: SettingsRepository (Hive Box<AppSettingsModel>) → Failure
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
├── Fields: barcode (required), name (required), price, stock, isQuickTile, tileColorHex
├── copyWith(), ==, hashCode
└── AppProductModel extends ProductEntity (Hive TypeAdapter typeId=1, JSON)

ProductFormDialog (StatefulWidget)
├── Auto-fills barcode with random 12-digit number (first digit non-zero)
├── Live BarcodeWidget preview (code128, renders when ≥6 characters)
├── 8-color predefined palette shown when isQuickTile toggled
└── Fields: barcode, name, price, stock + isQuickTile switch + color picker
```

### 5d. Checkout Feature Architecture (Implemented)
```
App → BarcodeScannerGate → Scaffold
└── Column
    ├── SizedBox(height: Spacing.lg)
    └── Expanded → Row
        ├── SectionCard → _NavRail (72px fixed width)
        ├── Container(width: 1, dividerColor)
        ├── Expanded(flex: 7) → CheckoutWorkspace (or Inventory/Settings)
        ├── [if checkout] Container(width: 1, dividerColor)
        └── [if checkout] ConstrainedBox(minWidth: 360, maxWidth: 500) → CheckoutTowerPanel
            ├── SectionCard (receipt, mainAxisSize.max)
            │   ├── Centered store name + receipt icon + title
            │   ├── Numbered item list (quantity × price)
            │   ├── Divider + Summary footer (item count + subtotal via AnimatedCounter)
            │   └── Receipt footnote
            └── SizedBox(height: Spacing.sm)
            └── SectionCard (cash drawer)
                └── CashDrawerAssistant
                    ├── Subtotal in heading1
                    ├── 2-row grid: [10][20][50][100] / [200][C]
                    └── Confirm ElevatedButton (styled)

CheckoutBloc
├── Initial state: CheckoutStatus.ready, CartEntity.create()
├── Events: AddToCart, UpdateQuantity, RemoveFromCart, ClearCart, SetAmountPaid, ClearAmountPaid, ConfirmSale
├── State: CheckoutState { status: CheckoutStatus (initial|ready|error|confirmed), cart: CartEntity?, amountPaidPiastres: int?, failure: Failure? }
│   ├── getter subtotalPiastres → cart?.subtotalPiastres ?? 0
│   ├── getter changePiastres → max(0, amountPaidPiastres - subtotalPiastres)
│   └── getter isPaid → amountPaidPiastres >= subtotalPiastres
└── ConfirmSale: sets status to confirmed → CheckoutWorkspace shows CheckoutConfirmationDialog (2s auto-dismiss) → ClearCart

CheckoutConfirmationDialog (StatefulWidget)
├── PopScope(canPop: false)
├── Auto-dismiss via Future.delayed(2 seconds)
├── Icon: check_circle (success) / error (failure), 64px
└── Message text in title-large style

CartTableWidget (replaces CartItemTile)
├── 4-column Table (No. / Name / Qty / Price) with FlexColumnWidth constants
├── AnimatedList + SizeTransition + FadeTransition (300ms) for insert/remove animations
├── ValueNotifier<bool> edit mode + FilteringTextInputFormatter.digitsOnly for qty editing
├── Tap-to-edit inline TextField, submit/focus-loss commits only if _hasTyped
└── Total footer row with AnimatedCounter values

PriceHelper
├── fromDouble(double) → int (piastres)
└── format(int piastres, {String languageCode = 'en'}) → locale-aware string (Arabic: "X.XX ج.م", English: "EGP X.XX")
```

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

New feature-specific failures are permitted (for example `AuthenticationFailure` in a future feature) but must extend `Failure` and live in `lib/core/error/`. The three canonical subclasses above are the **mandatory minimum** that every feature must be capable of producing.

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