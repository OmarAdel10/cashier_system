# Product Requirement Document (PRD)
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Overview & Objectives
The objective is to build a premium, highly responsive, offline-first Desktop Point of Sale (POS) application tailored for Egyptian stationery and school supply stores ("مكتبة"). The system must run smoothly on low-resource legacy hardware running Windows 10, replacing traditional outdated software with a modern, fluid user experience.

### 2. Target Hardware & Constraints
* **Operating System:** Windows 10 Desktop (64-bit).
* **Hardware Baseline:** Low-end Intel Core i3/Celeron processors, 4GB RAM, integrated graphics.
* **Performance Requirement:** Constant 60 FPS UI rendering; minimal memory footprint; absolute zero lag during checkout scanning operations.

### 2a. Core Shared Widgets
* **SectionCard (`lib/core/widgets/section_card.dart`):** A reusable card wrapper with an optional notch title (rendered as a badge overlapping the card's top border), optional action row, configurable padding, main axis sizing, and child flex fit. Used as the structural container for every workspace (checkout cart, inventory, settings, tower panel receipt, nav rail). Renders as a `Card` with `surfaceContainerLow` background, 12px rounded corners, `outlineVariant` border, and `elevation: 1`. When `title` is set with `mainAxisSize: MainAxisSize.max`, the child is wrapped in a `Flexible` with the configured `childFit`.
* **AnimatedCounter (`lib/core/widgets/animated_counter.dart`):** A lightweight widget wrapping a `Text` in an `AnimatedSwitcher` with `FadeTransition` (200ms duration). Used for quantity, price, and total value transitions throughout the checkout flow to provide smooth visual feedback without GPU-intensive animations.
* **ValidatedField (`lib/core/widgets/validated_field.dart`):** A form field container with rule-based validation, visual state feedback (none/valid/invalid with colored icons), prefix icon slot, input formatters, and last-field submission support.

### 2b. Typography Extension
* **`heading3`:** Added to `TextStyles` — Cairo SemiBold, 20pt. Used for `SectionCard` notch titles and mid-level section headings.

### 3. Core Feature Scope (MVP)

#### Module A: Cashier Checkout Hub (Home Screen)
* **Headless Barcode Scanning Interceptor:** A global keyboard event listener must process input from a hardware barcode scanner automatically, regardless of which UI element currently holds focus.
* **Unknown Barcode Feedback:** When the scanner interceptor produces a barcode that does not exist in the `inventoryMap`, the system must surface a localized, dismissible error affordance (see `DESIGN.md` Section 6.4) — the cashier must never see a silent no-op on a missed scan, and the focus must remain on the scanner input so the next scan is captured immediately.
* **Empty Cart First-Launch State:** A new install with no inventory must present a localized empty state (see `DESIGN.md` Section 6.3) directing the cashier to the Product Management module rather than a blank canvas.
* **Unified SKU Registry Tracking:** Identical items share the same barcode. Modifying the item quantity increments or decrements that unified record. Distinct packaging levels (e.g., a single pen vs. an entire box of pens) are treated as separate products with distinct barcodes.
* **Transaction ID Generation:** `CartEntity.create()` generates a 15-character tx ID from `DateTime.now().microsecondsSinceEpoch` (10 digits) concatenated with a 5-digit zero-padded `Random.secure().nextInt(100000)`, then takes the **trailing** 15 chars (so the random suffix always survives truncation — the earlier leading-15 approach collided ~1% of the time within the same millisecond). `Random.secure()` provides cryptographically strong randomness from platform CSPRNG — prevents tx ID enumeration.
* **Dynamic Quick Actions Grid:** A dedicated panel housing large, color-coded interactive tiles for barcode-less sales (e.g., photocopying services, custom gift wrapping, loose colored paper sheets).
* **Cart Table Widget:** Cart items render in a structured `Table` widget with 4 columns (No., Name, Qty, Price) using fixed `FlexColumnWidth` ratios (1:4:1.5:2:2, with the 5th total column hidden). The table uses `AnimatedList` with `SizeTransition` + `FadeTransition` (300ms) for insert/remove animations. Column widths are extracted as a top-level `_cartColumnWidths` constant. Quantity cells use `ValueNotifier<bool>` for edit mode tracking and `FilteringTextInputFormatter.digitsOnly`. The widget also includes a total footer row with `AnimatedCounter` values. Individual `CartItemTile` (removed) is no longer used — all cart interactions go through `CartTableWidget`.
* **Quick Tiles:** Enlarged from 72x72 to 100x100. Font size increased from `caption` (11pt) to `heading2` with `FontWeight.w500`. Background uses `withValues(alpha: 0.6)` for subtle transparency. Tiles animate in with `TweenAnimationBuilder` (fade + scale, 300ms, `Curves.easeOut`). Tile grid wrapped in `SectionCard` with "Quick Items" title. Maximum 10 quick-tile items; at limit, the quick-tile toggle switch is hidden in the product form dialog.
* **Cash Drawer Assistant (Redesigned):** Quick-select monetary buttons in 2-row grid layout (first row: 5, 10, 20, 50 EGP; second row: 100, 200 EGP + Clear "C" button). Amounts display with locale-aware currency formatting. Confirm button uses styled `ElevatedButton` with `clipBehavior: Clip.antiAlias`, vertical padding `Spacing.lg`, `RoundedRectangleBorder` with `Spacing.md` radius and primary border side.
* **Checkout Lifecycle:** The `CheckoutBloc` initializes in `CheckoutStatus.ready` (not `initial`) with an empty `CartEntity`. On confirm, status transitions to `confirmed`. A `CheckoutConfirmationDialog` shows optimistically (neutral loading state: `CircularProgressIndicator` + "Processing sale...", no icon). On `ReceiptsBloc` success, dialog transitions to success state (check_circle, auto-dismiss 2s); on `ReceiptsBloc` failure (`ReceiptPersistenceFailure`), dialog transitions to error variant (error icon, failure reason, auto-dismiss 5s). Either case: after 2 seconds (or on failure, after the 5s auto-dismiss or manual dismissal), `ClearCart` resets to a fresh cart.
* **Guarded Confirmation:** `CheckoutBloc._onConfirmSale` guards against double-confirm race via a `_confirmInProgress` field-level bool (set true before emit, reset false on `ClearCart` or license failure). Confirming with an empty cart is a silent no-op. A `canConfirmSale` callback (wired in `app.dart`) requires an **active shift** — without one, confirm emits `CheckoutStatus.error` with a "No active shift. Start a shift before confirming a sale." failure instead of confirming. `ConfirmSale` also runs `LicenseEngine.verifyLicense()` when a license engine is injected — an invalid license blocks the sale with a license-verification failure (see Module K5). There is no `isPaid` guard in the bloc — confirming with zero amount paid is allowed (the state exposes an `isPaid` getter, but it does not gate confirmation). The confirm button in `CashDrawerAssistant` is gated on `total > 0`, not `subtotal > 0`.
* **Cart Mutation Side-Effects:** `UpdateQuantity` with quantity ≤ 0 removes the item; quantity changes and `RemoveFromCart` clear `amountPaidPiastres` (change must be recalculated). `SetDiscount` clamps to 0–100 and also clears the paid amount.
* **Payment Type Selection:** `PaymentType` enum (`cash`, `instapay`, `vodafoneCash`, `visa`) with stable string ids; unknown ids fall back to `cash`. `SetPaymentType(typeId)` on `CheckoutBloc` stores the choice (default `'cash'`) which is snapshotted onto the receipt. The payment-type selector in `CashDrawerAssistant` (and the table checkout dialog) is populated from the `shownPaymentTypeIds` setting — an empty list means all types are shown (see Module D, Payment Types Visibility).
* **Checkout Confirmation Dialog:** A custom `Dialog` wrapping `PopScope(canPop: false)` on success / `PopScope(canPop: true)` on failure (allows dismissal on error path). Shows a large 64px icon (check_circle for success, error for failure) with a title-large message. Success: auto-dismisses after 2 seconds via `Future.delayed`. Failure: auto-dismisses after 5 seconds; a dismiss button appears after 3 seconds. Triggered by the checkout workspace when `CheckoutStatus.confirmed` is emitted.
* **Tower Panel Restructure:** The receipt tower panel is split into two `SectionCard` sections: (1) Receipt section with centered store name in `heading2`, a `receiptDuotone` icon + localized title, numbered items with `quantity × price` breakdown, and a summary footer showing item count, subtotal, discount (if any), tax (if any), total, and a configurable receipt footnote; (2) Cash Drawer section below with `CashDrawerAssistant`. Separated by `SizedBox(height: Spacing.sm)`. The old "New Sale" button is removed — the auto-dismissing dialog replaces it.
* **Interactive Cash Drawer Assistant:** Quick-select monetary buttons for Egyptian currency notes (5, 10, 20, 50, 100, 200 EGP) to instantly calculate accurate customer change calculations. The confirm sale button is always enabled when the cart contains items (no cash amount entry required to enable it). Includes a discount percentage TextField with real-time bloc dispatch. On confirm, a success dialog is shown for 2 seconds, then auto-dismisses and clears the cart to start a new sale.

#### A10: In-Cart Key Navigation & Selection
* **Selection State:** Cart item selection is managed by a local `ValueNotifier<int>` (`_selectedIndex`) inside `CartTableWidget` — it does NOT live in `CheckoutState`. Selection wraps around (0 → n-1 → 0). Intents handle keyboard-driven navigation: `SelectNextCartItemIntent` (Down), `SelectPrevCartItemIntent` (Up), `RemoveSelectedCartItemIntent` (Delete), `EditCartItemQuantityIntent` (Enter to toggle inline edit mode on selected row).
* **Selection Highlight:** The matching row renders with a distinct highlight state (accented background / border) to indicate focus.
* **Modification Actions:** `RemoveSelectedCartItemIntent` dispatches `RemoveFromCart` for the selected barcode. `EditCartItemQuantityIntent` activates the inline quantity `TextField` edit mode on the selected row (same as tap-to-edit).

#### Module B: Product Management & Barcode Studio
* **Inventory Ingestion Interface:** Fast forms to input Item Name, Retail Price, Stock Count, Barcode, and Notes. New product form auto-fills barcode with a random 12-digit number (first digit non-zero). Fields: barcode, name, price, stock, notes, quick-tile toggle, and tile color picker.
* **Inventory Layout:** Two-column split — Normal Products (left column) and Quick Access (right column). Each column is a styled `Container` with `theme.cardColor` background (automatically adapts to light/dark mode), `dividerColor` border, and 12px rounded corners. Columns render side-by-side at all times; the right column hides if no quick-tile products exist. Search mode reverts to a single vertical list. The inventory workspace replaces the `AppBar` with a `SectionCard` wrapping the body; the inventory title and action buttons (search, add) are embedded in the SectionCard's notch title + actions slot.
* **Quick Grid Configuration Switch:** A switch allowing the user to flag any product as a "Quick-Tile" item, revealing a palette of 10 predefined colors (`#007ACC`, `#10B981`, `#F59E0B`, `#EF4444`, `#8B5CF6`, `#EC4899`, `#14B8A6`, `#F97316`, `#E11D48`, `#0284C7`). Color is stored as `tileColorHex` on `ProductEntity`. If `InventoryBloc.quickTileList.length >= 10`, the quick-tile toggle switch is hidden from the product form dialog. Existing products that are already quick-tiles preserve the toggle so their status can still be edited.
* **Live Barcode Generator Preview:** A rendering container using the `barcode_widget` package (code128) that displays in real-time once the barcode string is 6+ characters. Positioned above the barcode text field in the product form dialog.
* **Barcode Label Export:** A "Save Barcode" button below the live barcode preview renders the barcode as a styled label template (store name, barcode image, barcode text, product name + notes, price in locale-aware currency) and exports it as a PNG via `RenderRepaintBoundary.toImage()`. The export uses `BarcodeLabelTemplate` widget → captures as PNG → saves to user-selected download path with filename `barcode_<sanitized_barcode>_<timestamp>.png`. Uses `BarcodeExportCubit` (idle/exporting/success/failure states). Success shows snackbar with file path; failure shows error snackbar. Download path configured in Settings (Export Directory section); if unset, the save button shows a prompt to configure first.
* **Currency Display:** All prices formatted in Egyptian Pounds — Arabic locale shows `9.99 ج.م` (amount + space + symbol), English locale shows `EGP 9.99` (symbol + space + amount).
* **Stock Calculation Logic:** Total Stock Before Selling = Current Stock + Total Volume Sold. This formula is used in the Admin Sales view to provide historical context of inventory levels.

#### Module D: Store Settings & Localization Profile
* **Dynamic RTL Localization Toggle:** A master system switch changing the user interface between Arabic (العربية) and English instantly, triggering full structural layout direction flipping (`TextDirection.rtl`). Implemented as a `SegmentedButton` with per-tab auto-save.
* **Store Identity Configurator:** Configurable textual parameters `storeName` (String) and `receiptFootnote` (String) stored as fields on `AppSettingsEntity` with `copyWith()` immutability. Values feed directly into the digital checkout layout and physical transaction receipts.
* **Theme Preference Selector:** Toggle state between Light Mode (warm beige palette: `#F5F0EB`/`#FFFDF5`) and High-Contrast Dark Mode (charcoal: `#0F172A`/`#1E293B`) to alleviate eye-strain during extended retail night shifts. Implemented as a `Switch` with real-time status indicator.
* **Persistence Model:** Settings use plain `Bloc` state with explicit Hive repository reads/writes; `HydratedBloc` is not used. No explicit "Save" or "Apply" button is required — each interaction commits immediately. Persistence failures surface the localized error state from `DESIGN.md` Section 6.4.
* **AppBar Removal:** The `SettingsWorkspace` (and `InventoryWorkspace`) no longer use `Scaffold.appBar`. The section title and actions are embedded in a `SectionCard` notch title wrapping the body content. The `SectionCard` uses `mainAxisSize: MainAxisSize.max` so the child fills available space.
* **Localization Engine:** Dedicated `LocalizationService` class with O(1) `Map<String, Map<String, String>>` translation dictionary supporting Arabic and English. Accessed via `translate(key)` method. No `intl` package dependency.
* **Tax Configuration:** A dedicated settings section with an enable/disable `SwitchListTile` ("Enable Tax") and a percentage `TextField` ("Tax Rate (0-100)") shown conditionally when tax is enabled. Rate input is debounced (300ms) and clamped to 0-100. Dispatches `TaxToggled(bool)` and `TaxPercentChanged(int)` to `SettingsBloc`. Tax is synced to `CheckoutBloc` via `SetTaxPercent(int)` on app startup (via `app.dart`) and reactively on settings change (via a `BlocListener` in `AppShell`). Tax calculation is subtotal-based: `taxAmount = subtotal * taxPercent / 100` (not after-discount).
* **Auto-Print Toggle:** A `SwitchListTile` in a "Printing" settings section. Stores `autoPrintEnabled` (bool, default false) on `AppSettingsEntity`. Dispatches `AutoPrintToggled(bool)`. When enabled, receipt is automatically sent to the selected thermal printer after sale confirmation via `ReceiptPrintHelper` → .NET PrintServer sidecar.
* **Barcode Action Preference:** Stores `barcodeActionPreference` (String, default `'printDirect'`) on `AppSettingsEntity`. Presets the product form dialog's barcode-label export action: `'printDirect'` uses `BarcodeAction.printDirect`, `'savePng'` uses `BarcodeAction.savePng` (read only at `product_form_dialog.dart:255-260`). Scanner behavior is unaffected — scanned barcodes always add directly to the cart. Dispatches `BarcodeActionPreferenceChanged(String)`.
* **Save-Receipt-as-Image Toggle:** A `SwitchListTile` in the Printing section. Stores `saveReceiptAsImage` (bool, default false). When enabled, a PNG image of the receipt is automatically saved to the export directory after each sale.
* **Save-Receipt-as-PDF Toggle:** A `SwitchListTile` in the Printing section. Stores `saveReceiptAsPdf` (bool, default false, Hive field index 34). When enabled, an A4 PDF invoice of the receipt is rendered by the PrintServer (`POST /api/printing/save-pdf`, `InvoiceService.cs`) and saved to the export directory after each sale. `ReceiptPrintHelper.printReceipt()` calls `saveReceiptPdf()` after the thermal print whenever this flag is set (`receipt_print_helper.dart:90-92`).
* **Receipt/Barcode Printer Dropdowns:** Two `DropdownButton` widgets in the Printing section populated from the PrintServer's `GET /api/printing/local-printers` endpoint. Selections stored as `receiptPrinterName` and `barcodePrinterName` (empty = system default). A refresh button re-queries installed printers.
* **Export Directory Path:** A `_SettingsSection` with a validated Windows absolute path input + "Choose Folder" `FilledButton.tonalIcon`. Opens a directory picker via `file_picker`. Replaces the previous `barcodeDownloadPath` with a unified `exportDirectoryPath`. Path validated against Windows drive-letter regex before dispatch. Invalid paths show inline error and are not saved. Dispatches `SetExportDirectoryPath(String)`.
* **Payment Types Visibility:** A `_SettingsSection` (`payment_types_section.dart`) with one toggle per `PaymentType` (cash / instapay / vodafoneCash / visa). Selection persists to `shownPaymentTypeIds` on `AppSettingsEntity` via `PaymentTypeVisibilityChanged(List<String>)`. An empty list means "all types shown" (`PaymentType.fromIds` fallback). Consumed by the `CashDrawerAssistant` payment selector and the table checkout dialog's payment picker.
* **Prep Categories Visibility:** A `_SettingsSection` (`prep_categories_section.dart`) with one toggle per `PrepCategory` (`food`, `beverage`, `shisha`, `general`, `dessert`, `special`). Selection persists to `shownPrepCategoryIds` on `AppSettingsEntity` via `PrepCategoryVisibilityChanged(List<String>)`; empty = all shown (`PrepCategory.fromIds` fallback). Drives the prep-category picker shown in grid-mode product forms and table session dialogs.
* **Reset All Data:** A settings section with a destructive `ElevatedButton` (red). On confirmation dialog, clears the `settings`, `inventory`, `auth_users`, `shifts`, `active_shifts`, `receipts`, `refunds`, `audit_log`, `expenses`, `stations`, `session_records`, `floor_zones`, `tables`, `table_rounds`, and `product_categories` Hive boxes (`reset_section.dart`; each clear is failure-tolerant via `safeClear`), then dispatches `LoadSettings()`, `LoadInventory()`, and `LogoutRequested()` to reset the application to factory defaults and return to the login/setup flow.
* **Admin General Section (Store Identity):** An admin-only `_SettingsSection` with fields for store address, phone number, and SVG logo path. See DESIGN.md Component P.
* **New Localization Keys Added:** `checkout.cashDrawer`, `checkout.saleConfirmed`, `checkout.saleFailed`, `checkout.table.no`, `checkout.table.name`, `checkout.table.qty`, `checkout.table.price`, `checkout.table.total` — for the redesigned cart table and checkout confirmation flow. `tax`, `taxToggle`, `taxPercent`, `printing`, `autoPrint`, `resetAllData`, `resetAllDataConfirm`, `reset`, `discount`, `checkout.total` — for new settings sections. 40+ shortcut-related keys under `shortcuts.*` and `shortcuts.action.*`. `inventory.product.notes`, `inventory.product.notes.hint`, `inventory.product.saveBarcode` — for product notes field and barcode save button.

#### D6: Keyboard Mapping Configurator
* **Data Extension:** `AppSettingsEntity` gains `final Map<String, List<String>> customBindings` (action token → list of key combo strings, e.g., `"search.toggle" → ["f5", "/", "ctrl+f"]`), defaulting to an empty map. `AppSettingsModel` extends `customBindings` serialization in `fromJson`/`toJson` and `TypeAdapter` (field key `4`).
* **Bloc Events:** Three event types for customization: `AddCustomBinding(String actionToken, String keyCombo)` — merges new combo into the action's list and resolves conflicts (same key combo removed from other actions); `RemoveCustomBinding(String actionToken, String keyCombo)` — removes one combo from the action's list; `ResetCustomBinding(String actionToken)` — removes the action token entirely from `customBindings`, reverting to defaults.
* **Conflict Resolution:** Adding a combo that is already a **default** of another action writes an explicit **empty-list steal-marker** for the victim token in `customBindings` (suppressing its default at gate-merge time) while keeping the victim's other custom combos. Adding a combo held by another action's **custom** bindings removes that entry from the other action (last-assignment-wins). Removing a combo or resetting an action runs `_restoreDefaultsIfFree`: an empty-list marker is dropped (and its defaults restored) once no other action's custom bindings hold that default combo. Known accepted limitation: explicitly unbinding every custom combo on an action is indistinguishable from a steal-marker, so its defaults also return.
* **Keyboard Mapping Hub:** A dedicated `_SettingsSection` block rendered inside `SettingsWorkspace` (6 groups: Navigation, Search, Cash Drawer, Cart, Quick Tiles, Inventory). Lists every system action with a localized label + combo chips + add/remove/reset controls. Tapping the add button opens `KeyCaptureDialog`; result dispatches `AddCustomBinding`. Custom bindings display with a primary-colored border; default bindings have a plain outline.
* **Persistence Model:** Same per-tab auto-save pattern as existing settings — no explicit save button. Changes flow through `SettingsBloc` → Hive-backed repository; no HydratedBloc layer is used.
* **New Localization Keys Added:** `shortcuts.title`, shortcuts.group keys, `shortcuts.action.*` for every action token, `shortcuts.keyCapture.*`, `shortcuts.tapToRebind`, `shortcuts.resetToDefault` — for the Keyboard Mapping Hub.

### 4. Module E: Keyboard Shortcuts & Navigation System

#### E1: Global Search & Scanner Overlay
* **QuickSearchOverlay:** A modal `OverlayEntry` rendered at the `GlobalShortcutGate` level (above all workspaces). Triggered by default key `F5` (or `/` / `Ctrl+F`). On open, a `TextField` auto-focuses for manual search input. The overlay is a centered 500px-wide Material card on a semi-transparent scrim.
* **Scanner Integration:** While the overlay is open, the `BarcodeScannerGate` interceptor continues processing hardware scans. When a barcode is captured (`isSearchOpenNotifier.value == true`), the barcode is injected into the overlay via `_barcodeInjectionNotifier`. The overlay reads the injected barcode, populates the search text, and performs an O(1) lookup in `InventoryBloc.inventoryMap`. Results are shown as a `ListView` of product info rows. Tapping a result dispatches `AddToCart`.
* **Dismissal:** Pressing `Escape` or tapping the barrier outside the dialog closes the overlay and clears the search state.

#### E2: Guarded Checkout Actions
* **Triggers:** `F12` invokes checkout finalization (`ConfirmSale`).
* **Invariant Guard:** The shortcut controller checks `CartEntity.items.isNotEmpty` before dispatching. A business-level guard (`_confirmInProgress` flag) also exists in `CheckoutBloc._onConfirmSale` to prevent double-confirm race conditions.

#### E3: In-Cart Key Navigation & Manipulation Loop
* **Selection Focus:** Up/Down arrow keys shift local `_selectedIndex` (a `ValueNotifier<int>` in `CartTableWidget`). Selection wraps bidirectionally. `CartTableWidget` registers a global `HardwareKeyboard` handler (no cart `Focus` node — the cart never steals focus from the scanner). The handler is guarded: `KeyDownEvent` only, cart non-empty, context visible (`TickerMode` enabled — offstage `IndexedStack` tabs are skipped), no `TextField` focused, and no quantity edit in progress.
* **Delete:** `Delete` / `Del` key on a selected item dispatches `RemoveFromCart` for the selected barcode.
* **Edit Quantity:** `Enter` on a selected item activates the inline quantity `TextField` edit mode (same behaviour as tapping the quantity cell in `CartTableWidget`). A second `Enter` (or focus loss) commits the edit.

#### E4: Quick-Tiles Grid Hotkeys
* **Trigger Sequences:** `Alt + 1` through `Alt + 0` (where `Alt + 0` = index 9) map to `InventoryBloc.quickTileList[index]` (0-indexed: `N-1`). Up to 10 tile slots.
* **Execution:** On matching a tile index, dispatches `AddToCart` with the product's barcode, name, and price — identical to tapping the tile directly.

#### E5: Navigation & Utility Hotkeys
* **Navigation (positional):** `F1`..`F3` map to the user's nav-rail destinations in order — the gate **generates** these bindings dynamically from `allowedDestinations` (`F1` → `allowedDestinations[0]`, etc.) and intentionally ignores the static `nav.*` entries in `defaultBindings`. Cashier: `F1` → checkout, `F2` → sales. Admin: `F1` → sales, `F2` → inventory, `F3` → settings. There is NO effective `F4` binding (no role has 3+ destinations beyond F3; the static `nav.settings: ['f4']` default is never registered by the gate, though a custom binding for `nav.settings` would work). Each dispatches `NavigateToCheckoutIntent` / `NavigateToInventoryIntent` / `NavigateToSalesIntent` / `NavigateToSettingsIntent`, which set `selectedDestination` in `AppShell` (silently ignored if the destination is not allowed for the role).
* **Add Product:** `Ctrl + N` dispatches `AddProductIntent` (only active when on the inventory tab). Calls `AppShell.onAddProduct` callback to show `ProductFormDialog`.
* **Discount Focus (focus loan):** `Ctrl + D` dispatches `FocusDiscountIntent`, which increments `discountFocusTrigger`. `CashDrawerAssistant` listens and calls `FocusController.requestFocusLoan(FocusZone.discount, node)` — a temporary focus loan to the discount `TextField`, selecting all existing text. On submit, the field unfocuses and `returnToScanner()` hands focus back to the scanner node (no focus is ever left stranded).

#### E6: Cash Drawer Denomination Shortcuts
* **Trigger Sequences:** Actions `cart.amount.5eg` through `cart.amount.200eg` and `cart.amount.clear` are defined as intents (`SetAmountPaid5EGIntent` through `SetAmountPaid200EGIntent`, `ClearAmountPaidIntent`) but have **no default key bindings** (empty binding arrays). They exist solely as user-configurable slots.
* **Execution:** The shortcut gate reads the current `amountPaidPiastres` from `CheckoutBloc.state`, adds the denomination value (500 / 1000 / 2000 / 5000 / 10000 / 20000 piastres), and dispatches `SetAmountPaid(current + increment)`.

#### E7: Search Clear Shortcut
* **Trigger:** Action `search.clear` (`ClearSearchIntent`) has **no default binding** — user-configurable only. When bound, it clears the search text field in `GlobalSearchOverlay`.

#### E8: Shortcut Resolution Layer
* **Default Bindings:** A static `Map<String, List<String>>` of default action→key-combo-list mappings (e.g., `confirmSale → ["F12", "space"]`, `searchOverlay → ["f5", "/", "ctrl+f"]`, `quickTile1 → ["alt+1"]`, etc.).
* **User Override Merge:** At runtime, `GlobalShortcutGate._buildShortcutMap` computes `{...defaults, ...customBindings}`. User-defined entries replace defaults for the same action token (full rebinding, not additive). Each combo string is parsed via `parseKeyCombo` into a `ShortcutActivator` and mapped to the corresponding `Intent`.
* **Dispatcher:** `GlobalShortcutGate` uses Flutter's `Shortcuts` + `Actions` widgets. The `_buildActionsMap()` maps each `Intent` type to a `CallbackAction` that either sets a `ValueNotifier` (navigation, overlay toggle, focus triggers) or dispatches a `Bloc` event (confirm sale, amount paid, cart operations). The controller does not render UI — it only coordinates key→action routing.

---

#### Module C: Shift & Sales History Ledger
* **Shift Context:** Every transaction is recorded under an active shift (identified by `shiftId`). The cashier must be logged into an active shift to process sales. A shift is started on login (`StartShift`, dispatched from `AppShell`), but logout alone never closes it — the `AuthBloc` logout handler only logs the event and emits `unauthenticated`. The shift closes only via the End Shift button (`EndShift`, `app_shell.dart:141-148`). Logging out with an open shift leaves it orphaned (recovered and auto-closed on the next login).
* **Immutable Sales Log:** A secure local timeline capturing every successful transaction. Once recorded, the historical price, timestamp, and sold items remain unalterable, ensuring consistent accounting records if base product costs change in the future.

---

### Module F: Authentication & Shift Management

#### F1: Always-On Authentication
* **Login Screen:** The application boots directly to a login screen. No authenticated user = no access to any workspace. The login screen is a centered card (360px wide) containing store name/logo placeholder, username `ValidatedField`, password `ValidatedField` (obscured with eye toggle), and a Login `ElevatedButton`. Loading state shows a 2px hairline `LinearProgressIndicator` above the button + disabled state.
* **Seed Users:** On first boot (empty `auth_users` Hive box), the admin user is created lazily via a `__seeded__` marker key. It gets a 16-character cryptographically random password via `Random.secure()` (alphanumeric: `a-zA-Z0-9`):
  - `admin` / `<random>` → `UserRole.admin` (`mustChangePassword: true`)
* **Cashier Users:** Cashiers are NOT seeded. They are created manually by the admin via Settings → User Management (`Add User` dialog, role `cashier`).
* **Password Hashing:** PBKDF2-HMAC-SHA256 (100k iterations) with per-user 32-byte random salt. `passwordSalt` auto-generated if empty on save. Login hashes input with stored salt and compares against `passwordHash`.
* **Rate Limiting:** `_failedAttempts` counter tracks consecutive failures. At ≥3 failures, exponential backoff lockout = `min(30 * 2^(_failedAttempts - 3), 3600)` seconds (capped at 1 hour). Resets on successful login.
* **Username Validation:** `RegExp(r'^[a-zA-Z0-9_]{3,30}$')` enforced on user creation.
* **Roles** (`UserRole` enum: `admin`, `cashier` — no other roles exist):
  - `admin`: Access to Sales (default), Inventory, Settings. Nav-map source: `roleNavMap` in `lib/features/shortcuts/default_bindings.dart`.
  - `cashier`: Access to Checkout (default), Sales only. Cashiers do NOT get Inventory or Settings destinations in the nav rail.

#### F2: User Management (Admin Only)
* **Location:** First section in Settings workspace, above General section. Only visible to `admin` role.
* **User List:** Shows all users in a list. Each entry: username, role badge, change-password button.
* **Add User:** `+` button opens a dialog with username, password (min 8 characters), role `SegmentedButton` (admin/cashier). Username validated against `RegExp(r'^[a-zA-Z0-9_]{3,30}$')`. Duplicate username checked client-side. Cancel + Add buttons. Uses `BlocListener`: Navigator pops on success, shows inline error on failure.
* **Change Password:** Dialog with current password (admin re-auth verified against stored hash) + new password (min 8) + confirm. All fields required. Only admins can change other users' passwords. Uses `BlocListener`: success snackbar, error snackbar.
* **Persistence:** All changes save immediately to the `auth_users` Hive box via `AuthRepository`.

#### F3: Shift Lifecycle
* **ShiftEntity:** `id` (string UUID v4), `username` (string), `startedAt` (DateTime), `endedAt` (DateTime?), `openingFloat` (int piastres, default 0), `orderCount` (int, default 1 — per-shift receipt counter used for order number generation, see Module G2).
* **Storage:** Primary `shifts` Hive box (key = UUID) + companion `active_shifts` box (maps username→shiftId). Lookup goes through the companion first (O(1)), and falls back to scanning the `shifts` box for `username == currentUser && endedAt == null` when the companion entry is missing or stale (self-heals the companion on hit).
* **Auto-Create on Login:** After successful authentication, the system checks for an orphaned (active without endedAt) shift belonging to the logged-in user. If found, it is auto-closed (endedAt = now) silently, and a snackbar informs the user. A fresh shift is then created immediately.
* **Auto-Close on Logout:** When the user ends their shift, the shift is closed (endedAt = now), the `active_shifts` entry is removed, then the user is logged out (AuthBloc emits unauthenticated, login screen appears).
* **End Shift Button:** Fixed at the bottom of the nav rail, rendered with a `signOut` Phosphor icon. Always visible regardless of role. Tapping opens a confirmation dialog before executing. While `ShiftBloc` emits loading, the button shows a 2px `LinearProgressIndicator` and becomes non-interactive.
* **Entity Location:** `lib/features/auth/domain/entities/shift_entity.dart` — shift lives inside the auth feature (it is an auth concern: who was logged in when).

#### F4: Orphan Recovery (Crash Safety)
* **Crash Scenario:** Application crashes after login but before shift creation, or crashes during active shift leaving `endedAt == null`.
* **Recovery:** On next login, `ShiftsRepository.getActiveShift(username)` finds any shift where `username == currentUser && endedAt == null` — companion lookup first, scan fallback on miss/stale entry (stale companion entries are deleted; orphaned open shifts are re-indexed). If found, `endedAt` is set to current timestamp, `active_shifts` entry removed. User sees a snackbar: "Previous shift was closed automatically due to unexpected exit." A fresh shift is then started.
* **No Data Loss:** Receipts recorded during the orphaned shift remain intact (they carry `shiftId`). The auto-close merely terminates the shift window.

#### F5: Role-Based Navigation
* **NavItem Resolution:** Nav rail items are rendered from a `Map<UserRole, List<NavDestination>>` mapping (`roleNavMap`, `default_bindings.dart`). Admin: [Sales, Inventory, Settings]. Cashier: [Checkout, Sales]. The first destination in the list is selected by default on login. The nav rail also shows the user's username at the top.
* **Expenses Button:** A wallet-icon "Add Expense" nav-rail button (accent-colored, key `navExpenseButton`) rendered between the nav destinations and the End Shift button — **only while the checkout destination is selected** (i.e., cashiers). Opens the fullscreen `ExpensePanel` dialog (see Module N).
* **F1-F3 Shortcuts:** Each shortcut checks if the target `NavDestination` is in the user's allowed list. If not, the key press is a silent no-op. All navigation intents are also suppressed while a `TextField` has focus (`_isTyping` guard).
* **End Shift:** Not a nav destination — always rendered at nav rail bottom (red, `signOut` icon).
* **IndexedStack:** All 4 workspace slots exist in `IndexedStack` regardless of role. Unreachable destinations simply never get selected. The checkout slot is replaced per business type: `StationWorkspace` (playstation, wrapped in `AutoConversionHost`), `TableWorkspace` (cafe/restaurant), or `CheckoutWorkspace` (all other types). The receipt tower panel renders only for the non-playstation, non-table-billing checkout.

#### F6: First-Time Admin Setup
* **Problem:** On fresh install, seed passwords are cryptographically random (unreachable by a human). The admin must set a real password before first use.
* **Marker Mechanism:** A `__setup_completed__` marker key in the `auth_users` Hive box tracks whether admin initialization has occurred.
* **Flag name choice:** `__setup_completed__` (inverted semantics from `isFirstTimeLogin` — "login" is per-user, this is app-level).
* **Onboarding Flow:** 9 steps in `lib/features/onboarding/` — Welcome (skippable), Features highlights (skippable), Business Type (required selection — skip is blocked), Store Info (skippable), Branding (skippable), Export Path (skippable), Printing (skippable), Preferences (skippable), Admin Setup (required, last). Skippable steps jump forward via `SkipToSetup` (Welcome/Features → Business Type; Store Info through Preferences → Admin Setup); only completing Admin Setup exits the flow. Back navigation is available on every step except Welcome. Step state in `OnboardingBloc` (plain `Bloc`, not hydrated); `OnboardingStep` enum: `welcome → features → businessType → storeInfo → branding → exportPath → printing → preferences → adminSetup`. The Business Type screen dispatches `SettingsBloc.BusinessTypeChanged(type.name)` when the admin confirms a selection — this is the only place `businessType` is written outside a factory reset.
* **Flow:**
  1. App starts → `AuthBloc.CheckAuth` → seeds the admin user
  2. Checks `__setup_completed__` marker — absent on fresh install
  3. Emits `AuthStatus.setupRequired` → `OnboardingFlow` shown (Welcome → Features → Business Type → Store Info → Branding → Preferences → Admin Setup)
  4. Admin enters password (min 8 chars) + confirm
  5. `CompleteAdminSetup(password)` → PBKDF2 hash → save admin with `mustChangePassword: false` → write `__setup_completed__` → emit `authenticated`
* **Seed behavior:** Only the admin user is seeded (`mustChangePassword: true`). Cashiers are created later via User Management. Admin's `mustChangePassword` set to `false` after setup.
* **Existing installs:** Installs that already ran the old seed keep their seeded cashiers (seed is marker-idempotent; no migration, no auto-delete). If `__seeded__` exists but `__setup_completed__` is absent, `isSetupCompleted()` returns `false` → the install passes through onboarding once. Installs with the marker go straight to login.
* **Reset All Data:** Clears `auth_users` box → marker gone → setup re-triggered on next launch.

---

### Module G: Receipts & Persistence

#### G1: Receipt Model
* **Receipt = Transaction:** There is no separate "sale" concept — a receipt IS a completed transaction. One receipt per `ConfirmSale`.
* **ReceiptEntity:** `id` (string UUID), `shiftId` (string), `orderNumber` (string), `items` (List<ReceiptItem>), `subtotalPiastres` (int), `discountPiastres` (int), `taxPiastres` (int), `totalPiastres` (int), `taxPercent` (int, default 0), `discountPercent` (int, default 0), `createdAt` (DateTime), `username` (string), `stockUpdated` (bool, default false), `stockFailedBarcodes` (List<String>, default `[]`), `status` (ReceiptStatus, default active), `modificationCount` (int, default 0 — incremented on each successful modification), `amountPaidPiastres` (int?, default null), `paymentType` (String, default `'cash'`).
* **ReceiptItem:** `name` (string), `barcode` (string), `quantity` (int), `unitPricePiastres` (int).
* **Storage:** Hive box `receipts`. Simple key-value with receipt ID as key.

#### G2: Decoupled Creation Flow
* **CheckoutBloc stays pure:** On `ConfirmSale`, `CheckoutBloc` emits `status: confirmed` with order number and final cart. It does NOT persist receipts.
* **Order Number Generation:** Order numbers are generated as `'ORD-'` + the shift's `orderCount` zero-padded to 5 digits, then `IncrementShiftOrderCount` bumps the counter (`app.dart:155-164`). The settings `orderCounter`/`lastOrderDate` fields are persisted but unused.
* **BlocListener bridge:** `AppShell` contains a `BlocListener<CheckoutBloc>` that catches `confirmed` status and dispatches `ReceiptsBloc.CreateReceipt(...)` with shift ID, order number, cart snapshot, user info, `taxPercent`, and `discountPercent`.
* **ReceiptsBloc responsibilities (4-step atomic sequence):**
  1. Save `ReceiptEntity` to `ReceiptsRepository` with `stockUpdated: false`, `taxPercent`, `discountPercent`, `amountPaidPiastres`, and `paymentType` snapshots.
  2. Iterate items and call `IInventoryRepository.updateStock(barcode, -quantity)` for each (best-effort — failure does not roll back receipt). Failed barcodes are tracked in `stockFailedBarcodes` on the entity. Items with an empty barcode are skipped entirely — no stock update is attempted (`expenses_bloc.dart:139`, `receipts_bloc.dart`).
  3. Save entity with `stockUpdated: !stockFailedBarcodes.isEmpty` and `stockFailedBarcodes` list persisted.
  4. Second `ReceiptsRepository.save(receiptEntity)` to persist the `stockUpdated`/`stockFailedBarcodes` flags, then emit `ready`.
* **Failure Handling:** If step 1 fails, emit `ReceiptPersistenceFailure` immediately (no receipt, no stock change). If steps 2-4 fail after step 1 succeeded, the receipt still exists with `stockUpdated: false` and `stockFailedBarcodes` populated (incomplete — auto-retry possible). UI transitions to error variant in either case.
* **Financial Cross-Validation:** All creation and modification handlers run `_validateReceiptFinances` before proceeding: (1) every item must have `quantity >= 1` and `unitPricePiastres >= 0` (`ValidationFailure` reason `negative_quantity_or_price`); (2) the computed items sum must equal `subtotalPiastres` (reason `computed_value_does_not_match`); (3) `totalPiastres == subtotalPiastres - discountPiastres + taxPiastres` (reason `total_does_not_match_subtotal_discount_tax`).
* **Admin Verification Details:** `AuthorizedModifyReceipt` verifies the supplied admin username exists and has `UserRole.admin`, then compares `hashPassword(input, salt)` against the stored hash. If the stored hash only matches the legacy hashing scheme, the credentials are accepted and transparently **migrated**: a fresh salt is generated and the PBKDF2 hash re-persisted (`hashPasswordLegacy` path in `receipts_bloc.dart`).
* **Startup Stock Retry:** `ReceiptsBloc` exposes `retryPendingStockUpdates()` — on app startup, `AppShell` calls `unawaited(bloc.retryPendingStockUpdates())` to re-attempt stock decrements for receipts where `stockUpdated == false`. The retry scope narrows to only `stockFailedBarcodes` on partial success, preventing double deduction on already-resolved items. First failed items guarded via `firstWhere(orElse: ...)` with zero-quantity fallback.

#### G3: Stock Integrity
* Stock cannot go negative — `InventoryRepository.updateStock(barcode, deltaQuantity)` pre-computes `newStock = currentStock + deltaQuantity` and returns `Left(DatabaseFailure('Insufficient stock'))` if `newStock < 0` without mutating the database.
* **Stock Restoration:** Processing a Return or Invoice Modification must automatically increment (restore) the respective product quantities back to the inventory stock balance.
* **Double-Refund Security Lock:** Any receipt whose state is already marked 'returned' or 'modified' must be completely locked in the UI, disabling any further Return or Edit actions to prevent duplicate cash restoration.

---

### Module H: Sales Analytics Workspace — Implemented

#### H1: Admin Sales View
* **Today's Summary Bar (Fixed):** At top of Sales workspace, a non-scrollable summary bar showing three metrics: **Receipts Count** (number of receipts today), **Total Sales** (sum of `totalPiastres` for today's receipts, formatted in EGP), **Items Sold** (sum of all item quantities across today's receipts).
* **SummaryBar (Daily + Monthly, One Row):** A single non-scrollable `Row` at the top of the Sales workspace with a `VerticalDivider` between halves (`summary_bar.dart:34,109`). Left half: today's metrics — **Receipts Count**, **Total Sales** (sum of `totalPiastres` for today's receipts, formatted in EGP), **Items Sold** (sum of all item quantities). Right half: the current month's metrics via `MonthGroupedData` (receipt count, items sold, total sales). Loaded via `SalesBloc.LoadTodaySummary` / `LoadMonth` / `LoadShiftReceipts` events (`sales_event.dart:5,14,27`); the MonthBrowser issues six individual `LoadMonth(year, month)` calls. No `LoadMonths` event exists.
* **Month Browser (Scrollable Below):** Below the summary bar, a scrollable list of months. Each month card shows: month/year label, receipt count for that month, total sales for that month. Tapping a month expands into a detailed view showing each receipt for that month (order# · time · items count · total). Month data is computed at query time by filtering `receipts` box on `createdAt`.
* **Query Pattern:** `ReceiptsRepository.getByMonth(year, month)` filters in-memory (acceptable for local POS volumes).
* **Expense Integration:** The sales ledger merges **expenses** (Module N) as pseudo-receipts with `status: ReceiptStatus.expense` (order number = expense name or `EXP-<id5>`; `stockUpdated: true`). Today's summary additionally tracks **today's expense total + count** (`SalesBloc` via `IExpensesRepository.getByDate`); `MonthGroupedData` carries a per-day `expensesPiastres` breakdown plus a monthly expense count; the cashier's shift view appends the shift's expenses with `shiftExpensesPiastres`. Expense pseudo-receipts are excluded from sales totals/count metrics (those are computed from repository receipts only, filtered to `status != returned`).
* **Session Records (Playstation):** `LoadSessionRecords` loads `SessionRecordEntity` records (via `ISessionRecordRepository`) sorted newest-first and rendered as `SessionRecordCard`s in a dedicated SectionCard, shown only in playstation business mode.

#### H1a: Sales Exports (CSV / PDF)
* **Export Events:** `ExportByDay`, `ExportByMonth`, `ExportByYear`, `ExportAllMonths`, `ExportMonthToMonth`, and `ExportDayToDay` — each takes a `format` (`'csv'` or `'pdf'`) and `exportDirectoryPath`. Range exports iterate the months/days in the inclusive range (with safety guards of 1200 months / 37000 days) and aggregate receipts + expenses.
* **Aggregation:** Every export includes expenses (converted to `ReceiptStatus.expense` pseudo-receipts) alongside sales, sorted by `createdAt` ascending.
* **CSV:** Per-item rows with a `Type` column (`Sale`/`Expense`), date, order #, item name, quantity, price and total in EGP (written via `core/exports/csv_writer.dart`).
* **PDF:** A4 landscape report rendered by the PrintServer (`SalesPdfExporter.saveAsPdf` → `POST /api/printing/sales-export`) with type badges (green pill for receipts, red pill for expenses); falls back to a local `pdf` package table renderer when the PrintServer exporter is unavailable.
* **Guard:** Exporting with an empty export directory setting fails fast with the sentinel error `NO_EXPORT_DIRECTORY` (surfaced as a prompt to configure the path, not a crash).

#### H2: Cashier Sales View
* Cashiers see all receipts from the current active shift. Displayed as a scrollable list: order number, total, timestamp. No month browsing, no cross-shift data, no summary bar.
* Data source: `ReceiptsRepository.getByShift(shiftId)` sorted by `createdAt` descending.

---

### Module I: Refunds & Modifications (Double-Lock System)

#### I1: Receipt Status Machine
* **ReceiptStatus enum:** `active`, `returned`, `modified`, `expense`. All receipts created as `active`. The `expense` value marks system-generated expense pseudo-receipts shown in Sales views/exports (not refundable, not modifiable, excluded from sales totals).
* **Double-Lock Rule:** Any receipt with `status != active` rejects all mutating operations (return or modify) via `RefundLockFailure`.

#### I2: Refund Flow (Full/Partial)
* **Stock Restoration:** Full refund restores original quantities for all items via `IInventoryRepository.updateStock(barcode, +originalQuantity)`. Note: although `RefundType` supports `partial` and the UI collects a per-item quantity selection, the bloc's `ProcessRefund` currently restores the **full** quantity of every item on the receipt regardless of type.
* **Cross-Shift Refund Lock:** A refund is rejected with `RefundLockFailure` ("receipt belongs to a different shift") when `receipt.shiftId != getCurrentShiftId()` — refunds are only possible within the shift that created the receipt.
* **RefundEntity:** `id` (UUID), `originalReceiptId` (UUID), `refundDate` (DateTime), `amountRestored` (int piastres), `type` (RefundType: full/partial).
* **Status Transition:** Receipt marked `status = returned`. Receipt saved with updated status. `RefundEntity` persisted to Hive `refunds` box.
* **Admin-Verify Lockout:** Refund and modify actions require admin password re-verification. After ≥3 failed attempts the dialog locks with a cooldown (`remaining = attempts × 2` seconds), reset on successful verification (`receipt_detail_dialog.dart:303-422`).

#### I3: Modification Flow (Quantity Change)
* **Delta Calculation:** `deltaQuantity = originalQty - newQty`. Positive → restore stock. Negative → decrement.
* **Status:** Receipt set to `status = modified` and `modificationCount` incremented. **Correction vs. earlier drafts:** the cashier-facing `ModifyReceipt` handler requires `status == active`, so a once-modified receipt is locked for further normal modification. The admin-authorized `AuthorizedModifyReceipt` blocks only `status == returned` — a `modified` receipt can be edited again via admin re-authentication (new delta calculated against current quantities). Return is permanently blocked once `status == returned`.

#### I4: RefundLockFailure
* **Type:** New `Failure` subclass in `lib/core/error/failure.dart`.
* **Fields:** `receiptId` (String), `currentStatus` (ReceiptStatus), `message` (String).
* **Trigger:** Any refund/modify action on a receipt where `status != active`.

---

### Module J: Print Server & Receipt Reprint

#### J1: .NET PrintServer Sidecar
* **Architecture:** A platform-selected .NET 8 Minimal API sidecar runs on `127.0.0.1:5150`. Windows uses `PrintServer/PrintServer.csproj` and `PrintServerManager`; Linux uses the self-contained `PrintServer.Linux/PrintServer.Linux.csproj`, `PrintServerManagerLinux`, and CUPS. `PrintServerFactory` selects the manager, and `main.dart` publishes the missing platform binary on first launch before starting it.
* **Endpoints:**
  * `GET /api/printing/health` — Lightweight liveness probe (no printer enumeration). Used by the cashier app to decide between adopting a running instance and killing a stale one (`Program.cs:56`).
  * `GET /api/printing/local-printers` — Returns list of installed Windows printer names.
  * `POST /api/printing/receipt` — Prints a thermal receipt via GDI+ (`PrinterService.cs`). Accepts receipt payload (items, subtotal/tax/discount/total in piastres, store identity, RTL flag, payment type). Also writes a PNG version via SkiaSharp (`ImageExportService.cs`) if requested. Supports silent print-to-file via GDI+ `PrintToFile` (`PrintToFile`/`PrintFileName` request fields) — bypasses the printer dialog (`PrinterService.PrintReceiptToFile`, `PrinterService.cs:34-47`).
  * `POST /api/printing/save-png` — Saves a receipt PNG via `ImageExportService` (SkiaSharp) without printing. Used by the "Save as PNG" action in `ReceiptDetailDialog`.
  * `POST /api/printing/save-pdf` — Renders an A4 portrait invoice PDF via `InvoiceService.cs` (Skia PDF backend, `invoice_receipt_template.html` layout: logo + company header, doc title, meta, itemized table, totals, centered footer note) without printing. Used by the "Save PDF" action in `ReceiptDetailDialog` and the auto-save-on-print setting.
  * `POST /api/printing/sales-export` — Renders the sales report as an A4 landscape PDF via `SalesExportService.cs` (10-column table; column 0 shows a type badge — green pill for receipts, red pill for expenses). Used by the Sales workspace export action (PDF format).
  * `POST /api/printing/validate-svg` — Validates a base64-encoded SVG logo; returns error codes on rejection (`SvgValidator.cs`).
  * `POST /api/printing/barcode` — Prints a Code128 barcode label via `BarcodeLib`.
  * `POST /api/printing/ticket` — Prints a kitchen/bar/shisha production ticket (`TicketRequest.cs`, `PrinterService.PrintTicketAsync`). Distinct from financial receipts; no prices/totals/tax.
* **Image Export:** `SaveReceiptAsPngAsync()` renders with SkiaSharp (white background, black text, gray meta/dividers). RTL-aware since the print-server wave: `IsRtl` is read and drives Arabic font selection (`NotoNaskhArabic.ttf`, bundled under `Assets/`, SIL OFL), text direction, and mirrored label positions (`ImageExportService.cs:145-162`). Arabic text is reordered to visual order with **BidiReshapeSharp 1.2.0** (MIT, `BidiReshape.ProcessString`) and joined with SkiaSharp.HarfBuzz `SKShaper` (`ImageExportService.cs:480-508`).
* **PDF Arabic Support:** `InvoiceService.cs` and `SalesExportService.cs` bundle **Noto Sans Arabic** Regular/Bold faces (SIL OFL, `Assets/NotoSansArabic-*.ttf`) and use the same BidiReshape + HarfBuzz pipeline for Arabic. A provided-but-broken logo is never silently dropped — `DrawLogo` throws `LogoRenderException` when the SVG fails validation, so the app can surface the reason to the user (`InvoiceService.cs:150-156, 685-686`).
* **Silent Printing & Default Printer:** `PrinterService.cs` resolves the Windows default printer via winspool `GetDefaultPrinterW` P/Invoke (`PrinterService.cs:579-584`) and uses it as a fallback so silent printing never lands on a random device (`:562-568`).
* **Financial Row Logic:**
  * `showSubtotal = taxPiastres > 0 || discountPiastres > 0`
  * `showTax = taxPiastres > 0`
  * `showDiscount = discountPiastres > 0`
  * Label is always "Total" — "Grand Total" appears nowhere in PrintServer or lib (PrinterService.cs:149, ImageExportService.cs:353)
* **Barcode:** Uses `BarcodeLib` (NuGet) with CODE128 encoding. Rendered as `System.Drawing.Image` onto the `PrintDocument` page.
* **Platform runtime:** Windows uses `System.Drawing.Printing` through the `PrintServer.exe` sidecar. Linux uses the implemented `PrintServer.Linux` self-contained `linux-x64` sidecar, `PrintServerManagerLinux`, and CUPS. `PrintServerFactory` and `main.dart` select and build/check the platform-specific implementation at boot. Both expose the same loopback HTTP contract on `127.0.0.1:5150`.
* **Rate Limiting:** Kestrel configured with 30 requests/second rate limiter.

#### J2: Flutter PrintService Client
* **File:** `lib/core/printing/print_service.dart`
* **Methods:** `getLocalPrinters()` → `List<String>`, `printReceipt(ReceiptRequest)` → `bool`, `printBarcode(BarcodeRequest)` → `bool`, `printTicket(payload)`, `saveReceiptPng(payload)` → `String` (pngPath), `saveReceiptPdf(payload)` → `String` (pdfPath), `saveSalesPdf(payload)` → `String` (pdfPath), `validateSvg(base64Data)` → `List<String>` (error codes).
* **Communication:** HTTP via `dart:io` HttpClient to `http://127.0.0.1:5150`.

#### J3: PrintServerManager (Sidecar Lifecycle)
* **File:** `lib/core/printing/print_server_manager.dart`
* **Windows lifecycle:** `start()` → `Process.start('PrintServer.exe')` with stdout/stderr piped to `print()`. `stop()` → `Process.kill()`. `dispose()` → call `stop()`.
* **Linux lifecycle:** `PrintServerManagerLinux` starts `PrintServer.Linux` with `--parent-pid`, adopts a healthy existing instance, validates API version, and cleans stale port-5150 processes using `ss`, `ps`, and `kill`.
* **Factory:** `PrintServerFactory.create()` chooses the platform manager or a no-op implementation.
* **Auto-Build Fallback:** On first launch, `main.dart` publishes the missing platform sidecar. Windows publishes `PrintServer/PrintServer.csproj`; Linux publishes `PrintServer.Linux/PrintServer.Linux.csproj` as self-contained `linux-x64` output. Startup is skipped with a log when publishing or executable discovery fails.

#### J3a: Linux CUPS Sidecar

* **Project:** `PrintServer.Linux/PrintServer.Linux.csproj`.
* **Printer backend:** `CupsPrinterService` discovers installed printers and sends receipt, barcode, and production-ticket jobs through CUPS.
* **Endpoints:** The Linux sidecar implements `/health`, `/local-printers`, `/receipt`, `/save-png`, `/save-pdf`, `/sales-export`, `/validate-svg`, `/barcode`, and `/ticket` under `/api/printing/`.
* **Hardening:** It binds to loopback, allows only `127.0.0.1` and `localhost` hosts, caps request bodies at 8 MiB, rejects oversized receipt/ticket/report payloads, and applies a 30-request-per-second global limit.
* **Process safety:** `ParentProcessWatcher` receives the Flutter parent PID and exits when the parent disappears, including crash/forced-exit scenarios.
* **Rendering:** Linux receipt/image/PDF output uses bundled Noto Arabic fonts, BidiReshapeSharp, and HarfBuzz for RTL text. PDF and image export are available even when a physical CUPS printer is not configured.
* **Registration:** Created in `main.dart`, passed as constructor argument to `App`. Disposed in `App.dispose()`.

#### J4: Settings Integration (Expanded)
* **New AppSettingsEntity fields:** `exportDirectoryPath`, `saveReceiptAsImage`, `saveReceiptAsPdf`, `storeAddress`, `storePhoneNumber`, `logoSvgData`, `receiptPrinterName`, `barcodePrinterName`, `barcodeActionPreference`.
* **New SettingsBloc events:** `AutoPrintToggled`, `SaveReceiptAsImageToggled`, `SaveReceiptAsPdfToggled`, `SetExportDirectoryPath`, `StoreAddressChanged`, `StorePhoneNumberChanged`, `LogoSvgChanged`, `ReceiptPrinterNameChanged`, `BarcodePrinterNameChanged`.
* **Receipt output on Sale Confirm:** After successful receipt creation, `AppShell`'s `BlocListener<ReceiptsBloc>` triggers `ReceiptPrintHelper.printReceipt()` when `autoPrintEnabled`, `saveReceiptAsImage`, or `saveReceiptAsPdf` is enabled. The helper builds the receipt JSON payload (including store identity, logo SVG data, RTL flag, taxPercent/discountPercent) and dispatches to the platform-neutral `PrintService` contract.
* **Auto-save Receipt as Image:** When `saveReceiptAsImage == true`, after sale confirm, `ReceiptPrintHelper.printReceipt()` sets `saveAsPng: true` in the payload. The PrintServer's `ImageExportService` saves a PNG to `exportDirectoryPath`.
* **Auto-save Receipt as PDF:** When `saveReceiptAsPdf == true`, `ReceiptPrintHelper.printReceipt()` additionally calls `PrintService.saveReceiptPdf(payload)` after the print call (`receipt_print_helper.dart:90-92`). The PrintServer's `InvoiceService` saves an A4 PDF to `exportDirectoryPath`.
* **skipPrint flag:** When `saveReceiptAsImage == true && autoPrintEnabled == false`, the helper sets `skipPrint: true` — only PNG save, no thermal print. When both are true, both operations run. When both false, no print action occurs.

#### J5: Receipt Reprint, Save PNG & Save PDF (in ReceiptDetailDialog)
* **Print Trigger:** A "Print" button (Phosphor `printer` icon) in `ReceiptDetailDialog` footer. Visible when the platform sidecar is available; Windows sends a native print job and Linux sends a CUPS print job.
* **Save PNG Trigger:** A "Save as PNG" button (Phosphor `floppyDisk` icon) in `ReceiptDetailDialog` footer. Calls `PrintService.saveReceiptPng(payload)` via `ReceiptPrintHelper.saveAsPng()`.
* **Save PDF Trigger:** A "Save PDF" button in `ReceiptDetailDialog` footer (`receipt_detail_actions.dart:61-67`, wired at `receipt_detail_dialog.dart:150`). Calls `PrintService.saveReceiptPdf(payload)` via `ReceiptPrintHelper.saveAsPdf()`.
* **Payload:** Builds `ReceiptRequest` JSON from receipt entity + current settings state (store name, address, phone, logo, footnote, RTL flag).
* **Execution:** Calls `PrintService.printReceipt(payload)`, `PrintService.saveReceiptPng(payload)`, or `PrintService.saveReceiptPdf(payload)`.
* **Guard:** Buttons disabled if `PrintService` is unavailable or the required printer/export configuration is unavailable. Linux export operations do not require a physical printer.

---

### Module K: DRM Licensing (Offline Ed25519)

#### K1: LicenseEngine Architecture
* **Location:** `lib/core/licensing/`
* **Purpose:** Offline, machine-bound license verification using Ed25519 asymmetric signatures. No phone-home server required.
* **Components:** `LicenseEngine` (orchestrator), `Ed25519Verifier` (crypto), `HwidProvider` (HWID extraction), `SecureStorageAdapter` + `FileBackupAdapter` (dual storage).

#### K2: Hardware Binding
* **Windows:** Reads `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` via `reg query`. Last 8 hex characters formatted as `CS-XXXX-XXXX`.
* **No admin required** — reads standard registry key accessible to all users.
* **Linux:** A `LinuxHwidProvider` exists and is selected automatically by `LicenseEngine._defaultHwidProvider()` when `Platform.isLinux` (`WindowsHwidProvider` otherwise); devices yielding no ID fall back to the `UNKNOWN-MACHINE` sentinel, which cannot be activated.

#### K2a: Ed25519 Public Key Injection
* The Ed25519 public key is injected at build time via `--dart-define=ED25519_PUBKEY_HEX=<hex_string>`.
* `key_store.dart` reads it via `String.fromEnvironment('ED25519_PUBKEY_HEX', defaultValue: '')`.
* The private key is held offline (not in the repository). Each deployment can use a distinct key pair.
* An empty key (no `--dart-define`) throws `StateError` at verification time — builds fail fast on missing key.
* Development `.vscode/launch.json` supplies the dev public key via `toolArgs`.

#### K3: Activation Flow
* **Startup:** `App.initState()` → `LicenseEngine.verifyLicense()` → if not `valid`, shows `ActivationScreen`.
* **ActivationScreen:** Full-screen centered card with: shield icon, QR code of device ID, selectable device ID text, activation key input (base64url filtered), "Activate System" button.
* **Key Verification:** `LicenseEngine.activate(key)` → gets device ID → verifies key is valid Ed25519 signature of device ID → writes `LicenseEntity` to both primary and backup storage → re-checks → app unlocks.
* **Runtime Re-Verification:** `LicenseEngine._validateEntity()` is now async and calls `Ed25519Verifier.verifySignature()` on every license check (not just activation). If the stored signature no longer verifies against current device ID, status becomes `tampered`. This catches key rotation or storage corruption.
* **QR Code:** Rendered via `qr_flutter` package. User scans with phone to generate a signature off-device using the developer's Ed25519 private key.

#### K4: Dual Storage with Self-Healing
* **Primary:** `flutter_secure_storage` (encrypted, OS-level protection).
* **Backup:** XOR-obfuscated file at `<supportDir>/CashierSystem/license.lic`.
* **Self-Heal:** If primary is corrupted/tampered but backup is intact, primary is restored from backup automatically.

#### K5: Operational Gating
* **ShiftBloc.StartShift:** `verifyLicense()` — blocks shift start if license invalid (emits `ShiftStatus.error` with a license failure).
* **CheckoutBloc.ConfirmSale:** `verifyLicense()` — blocks sale if license invalid. Additionally, an active-shift guard (`canConfirmSale` callback) rejects confirming a sale with no active shift (see Module A, Guarded Confirmation).
* **Startup:** Silent async `verifyLicense()` (`silentLicenseCheck` in `main.dart`, fire-and-forget) — logs warning on tampered status; the UI-level check in `App` gates rendering on the license status notifier (`checking` → splash spinner, non-`valid` → `ActivationScreen`).

#### K6: License Status Machine
| Status | Meaning | UI Behavior |
|---|---|---|
| `checking` | Initial verification in progress | Splash spinner |
| `valid` | License verified, device ID matches | App renders normally |
| `invalid` | No license stored | ActivationScreen |
| `tampered` | Device ID mismatch or backup mismatch | ActivationScreen + red tamper warning |

#### K7: Dependencies
* `cryptography: ^2.7.0` — Ed25519 implementation
* `qr_flutter: ^4.1.0` — QR code generation
* `flutter_secure_storage: ^9.2.4` — Encrypted primary storage

---

### Module L: Audit Logging System

#### L1: Architecture
* **Purpose:** Immutable event log for security-relevant operations (auth events, receipt lifecycle). 90-day rolling retention. No user-facing UI — backend-only.
* **Components:** `AuditService` wrapping a Hive `Box<String>('audit_log')`, `AuditEntry` data class, `AuditEventType` enum.
* **Hive Box:** Encrypted `audit_log` box (same AES cipher as other boxes). Entries stored as JSON strings (not Hive TypeAdapter).

#### L2: AuditEntry Model
* **Fields:** `timestamp` (DateTime), `type` (AuditEventType), `username` (String?, nullable for system-triggered events), `details` (String, human-readable description), `success` (bool, default true).
* **Serialization:** Custom `toJson()`/`fromJson()` JSON serialization. No Hive TypeAdapter.

#### L3: AuditEventType Enum

| Value | Context |
|---|---|
| `login` | Auth — successful login |
| `loginFailed` | Auth — failed login attempt |
| `logout` | Auth — user logout / end shift |
| `userCreated` | Auth — admin creates new user |
| `userDeleted` | Auth — admin deletes user |
| `passwordChanged` | Auth — password change (self or admin-reset) |
| `receiptCreated` | Receipts — receipt persisted |
| `stockUpdateFailed` | Receipts — stock decrement failed for one or more items |
| `stockRetryResolved` | Receipts — startup retry successfully resolved pending stock |
| `expenseCreated` | Expenses — an expense was persisted (details include line count and piastre total) |

#### L4: AuditService API

| Method | Signature | Behavior |
|---|---|---|
| `log` | `Future<void> log(AuditEventType, {String? username, required String details, bool success = true})` | Creates `AuditEntry` with `DateTime.now()`, serializes to JSON, inserts into Hive box, then calls `_pruneOld()` |
| `getRecent` | `Future<List<AuditEntry>> getRecent({int limit = 100})` | Iterates box in reverse (newest first), returns up to `limit` entries |
| `_pruneOld` | (private) | Computes cutoff = `now - 90 days`. Scans entries newest-first, deleting those where `timestamp.isBefore(cutoff)`; stops at the first non-stale entry (assumes chronological append order). **Throttled to at most once per minute** via a `_lastPrune` timestamp — intermediate `log()` calls skip the scan. |

#### L5: Integration Points
* **AuthBloc:** Logs login success/failure, logout, user creation/deletion, password changes. `AuditService` injected as nullable `AuditService?` — all calls use `?.` null-safe operator.
* **ReceiptsBloc:** Logs receipt creation, stock update failures (per-receipt, with failure count), and resolved stock retries.
* **Wiring:** `main.dart` opens `Hive.box<String>('audit_log')` with encryption, creates `AuditService`, passes to `App` constructor. `app.dart` wraps widget tree in `RepositoryProvider<AuditService>.value(...)`.

#### L6: Retention Policy
* **Duration:** 90-day rolling window.
* **Trigger:** `_pruneOld()` is invoked at the end of every `log()` call, but internally throttled to run the scan at most once per minute (see L4).
* **Mechanism:** Iterates box entries newest-first, compares `entry.timestamp` against cutoff, deletes stale keys; early-exits at the first fresh entry (chronological append assumption). O(n) per run (acceptable for local POS volumes — low event frequency).
* **No archival:** Stale entries are permanently deleted.


---

## Module F: PlayStation Mode (Stations & Sessions) — Implemented

### F1. Scope
PlayStation business type gets a live station grid checkout: stations with hourly pricing tiers, timed sessions, auto-conversion, and persistent session records.

### F2. Station
- Fields: `id`, `name`, `parentCategory`, `stationType` (playstation/table), `normalHourlyRate`, `multiHourlyRate`, `minimumGameCostNormal`, `minimumGameCostMulti`, `iconAsset`, plus session state: `status` (available/active/overtime), `sessionStartTime`, `isFixedDuration`, `fixedDurationMinutes`, `overtimeStartMinutes`, `sessionTier` (normal/multi), and F&B hybrid state: `addonLines` (List<TableOrderLine> — see F3).
- CRUD from Inventory workspace (`StationFormDialog`); delete blocked while a session is active.
- Minimum game cost is **per station and per tier** (`minimumGameCostNormal` / `minimumGameCostMulti`); the global `minimumGameCost` setting (Module I3) acts as the default/editor, not a per-session floor override.

### F3. Session lifecycle
- **Start:** tap available station → dialog: tier + optional fixed duration (default 120 min) → `StartSession`.
- **End:** tap active/overtime station → end dialog showing elapsed time, tier, live total → `EndSession` composes a billing `SessionRecordEntity` (record id `'SES-<millisecondsSinceEpoch>-<stationId>'`, `shiftId` empty at composition and filled by the auto-persist listener; billed minutes = max(booked fixed, elapsed), minimum 1 minute; subtotal = max(hourly rate × billed minutes, per-tier minimum game cost) **+ addon lines total**; discount/tax 0 at creation) and auto-persists via app-shell listener.
- **F&B Addons (hybrid café + PlayStation):** while a session is active or overtime, `AddStationAddon` / `SetStationAddons` append/replace `TableOrderLine`s on the station (quantity ≥ 1, price ≥ 0 validation; adding to a non-active station fails). Addons are priced lines without time billing (`addonTotalPiastres`); the card shows the combined total (`combinedTotalPiastres`). Addons are cleared and snapshotted into the session record on `EndSession`.
- **Auto-conversion:** fixed sessions convert to open once the booked duration elapses **plus a 5-minute grace period** (`AutoConversionService` default `gracePeriod: Duration(minutes: 5)`, 30s check interval, hosted by `AutoConversionHost`); `ConvertToOpenSession` clears the fixed-duration flags and records `overtimeStartMinutes`.
- **Live card total** is tier-aware (`currentTotalPiastres` uses the active tier's hourly rate).

### F4. Session records
- Persisted via `SessionRecordBloc` (default cap 100); Sales workspace shows the latest 20; new records refresh the list listener-driven. Record carries station identity, tier, start/end times, duration, hourly rate, minimum game cost, addon lines, subtotal/discount/tax/total, username, payment type, and a `completed` status.

### F5. Failure behavior
- Unknown station id or no active session on convert/end → bloc emits `failure` (no crash, no state mutation).

---

## Module G: Grid-Mode Checkout (Cafe/Restaurant) — Implemented

### G1. Scope
Cafe/restaurant/piastary business types replace the scanner-driven checkout surface with a category product grid beside the cart; scanner gate disabled; favorites strip + Alt+digit shortcuts; playstation mode keeps its station workspace (grid checkout never renders for playstation).

### G2. Product category grid
- `ProductCategoryGrid` (`checkout/presentation/widgets/product_category_grid.dart`): search field (name contains, case-insensitive), category chips (All + each) as left rail (wide ≥800px) or horizontal strip (narrow), `GridView` cards (name + `PriceHelper.format(price)`), filtered by category + search.
- Favorites strip above the grid only when `BusinessType.favoritesEnabled && settings.favoritesStripEnabled` (quick-tile products); exposing 10 slots addressed by Alt+1..9, Alt+0 (index `digit == 0 ? 9 : digit - 1`), inert when favorites disabled.
- Tap semantics: cafe/restaurant card tap → `AddToCart` (reused event: not in cart → 1, in cart → +1). No playstation path in this widget.

### G3. Workspace layout (grid mode)
- `CheckoutWorkspace` stateful: cart `SectionCard` (flex 2) + grid `SectionCard` (flex 5) in a Row; scanner layout (empty state AppEmpty + QuickTilesGrid) preserved byte-for-byte for retail/supermarket.
- Grid focus auto-request gated to grid modes only (retail keyboard/barcode flow untouched).
- Favorites strip rebuild subscribes to `favoritesStripEnabled` (via `context.select`).

### G4. Scanner gating
- `BarcodeScannerGate` gains `enabled` (default true); `app_shell` sets `enabled: !BusinessType.isGridMode` — no buffer attachment in grid modes; enabled path identical to retail.
- Playstation never reaches this checkout (station workspace replaces it in shell); cart no longer supports timed items (AddTimedItem/TimeBillingDialog dropped — session billing covers playstation).

---

## Module H: Business-Adaptive Inventory (F&B + Playstation) — Implemented

### H1. Scope
Inventory workspace and product form adapt to business type: retail 2-column (unchanged; clothes/pharmacy share this layout), cafe/restaurant/piastary 3-column categorized layout, playstation stations section + flat product list; barcode/stock fields hidden in grid modes with auto-generated barcodes; hourly price labeling.

### H2. Auto barcode generation
- `inventory/domain/helpers/barcode_generator.dart`: `generateAutoBarcode()` = `'auto-<microsecondsSinceEpoch>'`; `isAutoBarcode(String)` prefix check.
- Grid-mode new products get an auto-barcode (unique, never collides with scanner imports); editing keeps the existing barcode.

### H3. Product form adapters
- barcode field + stock field hidden in ALL grid modes (cafe/restaurant/piastary); category dropdown only for cafe/restaurant/piastary; price label reads "price per hour" for playstation; quick-tile toggle relabeled Favorite for cafe/restaurant/piastary and hidden for playstation; name + price required in every mode.
- Barcode label preview/export UI only when `barcodesEnabled` (retail).

### H4. Workspace layouts
Branches on `BusinessType`: retail = today's 2 columns; cafe/restaurant = 3 columns Categorized (grouped under category headers in CategoryBloc order) / Uncategorized / Favorites (only when `settings.favoritesStripEnabled`; products without category but favorite appear in both); playstation = stations management section (add/edit/delete, delete blocked for active sessions) above a flat product list priced "/hr".

### H5. CategoryBloc instance sharing
- Dialogs reuse the app-shell global `CategoryBloc` (`.value` provider) so FnB category grouping stays fresh after category management; `_buildCategoryBloc` helper removed from workspace.

---

## Module I: Business-Adaptive Settings — Implemented

### I1. Scope
Settings surface adapts per business type: read-only business-type card, favorites-strip toggle (cafe/restaurant/piastary), minimum game cost editor (playstation), printer + shortcuts section visibility per mode table. `businessType` stays read-only (factory reset only).
- **BusinessType enum (8 modes):** `retail`, `supermarket`, `cafe`, `restaurant`, `playstation`, `clothes`, `pharmacy`, `piastary`. `clothes` and `pharmacy` are retail-parity modes (barcode scanning, stock, 2-column inventory, shortcuts + both printers — same as retail/supermarket). `piastary` is a grid mode with categories (`hasCategories` true, like cafe/restaurant): grid checkout, 3-column categorized inventory, favorites strip; `barcodesEnabled`/`stockEnabled` false. Only `playstation` is time-billing; only `cafe`/`restaurant` are table-billing.

### I2. Business-type card
- Top of settings page (all modes): `BusinessTypeRegistry.metadata` icon + localized type name + caption `settings.businessType.locked` ("Only changeable via factory reset"). No edit affordance.

### I3. Mode-gated settings
- Favorites strip switch (`FavoritesStripChanged`) — cafe/restaurant only; drives checkout favorites strip + shortcuts visibility.
- Minimum game cost editor (`MinimumGameCostChanged`) — playstation only; EGP input (2 decimals max), persisted as piastres, floor 100 pt (1 EGP).
- Workspace `buildWhen` includes businessType/favoritesStripEnabled/minimumGameCost so edits reflect without status change.

### I4. Section visibility
| Section | retail/super/clothes/pharmacy | cafe/rest/piastary | playstation |
|---|---|---|---|
| Shortcuts | always | only when favorites strip on | hidden |
| Barcode printer | always | hidden | hidden |
| Receipt printer | always | always | hidden |

---

### Module M: Café & Restaurant Table Mode

* **Business Context:** For venues operating as cafés, restaurants, or shisha lounges (BusinessType.cafe / BusinessType.restaurant). Replaces the single-shot grid/cart checkout with a **Floor Management** paradigm: zones, tables, open tabs, multi-round ordering, and kitchen routing.

#### M1: Floor Plan & Table Workspace
* **Zone/Section Seeding:** On first run (empty `floor_zones` box), the system seeds default zones per `BusinessTypeRegistry.defaultZones` — for cafe **and** restaurant: **Main Dining**, **Terrace**, **VIP**, and **Takeaway Queue** (kind `takeaway`; the other three `dineIn`). There is no "Bar/Counter" preset. Zones are managed afterwards via the Zone Management dialog (create/edit/delete); the box is only seeded while empty. Product **categories** are similarly seeded first-run for cafe/restaurant/piastary from `BusinessTypeRegistry.defaultCategories` (e.g., cafe: hot drinks, cold drinks, soda, juices, desserts). Tables are created by the admin via the Inventory workspace; no default tables are seeded.
* **Table Entity:** Each table has `id`, `name` (e.g., "T04"), `zoneId`, `capacity` (e.g., 4), `isRoom` flag, `hourlyRatePiastres` (for rooms). Status machine: `available → occupied → orderPending → served → paymentPending → available`. Status colors: available (green), occupied (blue), orderPending (yellow), served (gray), paymentPending (red).
* **Room Billing (Toggle):** `roomsEnabled` setting (default OFF). When ON, tables with `isRoom=true` bill by elapsed time: **ceil-to-hour** — 10 min = 1h, 1.5h = 2h, 90-120 min = 2h. `roomCharge = chargedHours × hourlyRatePiastres`. Live occupancy timer + room charge shown on table card (mirrors PlayStation station timer pattern).
* **Takeaway Exemption:** Tables in takeaway-kind zones are exempt from service charge and minimum charge.

#### M2: Multi-Round Ordering & Running Tabs
* **Tab Opening:** Cashier taps an available table → StartTab overlay opens a new tab (records `tabOpenedAt`, `activeRoundNumber = 0`, draft lines map).
* **Draft State:** Items added via the table's session dialog (product picker = `ProductCategoryGrid` reuse) accumulate in a draft list — not persisted, survives only in Bloc state.
* **Send Order / Fire Round:** Tapping "Send Order" commits draft items into a new `TableRoundEntity` (id `'RND-<now>-<tableId>'`, roundNumber = `activeRoundNumber + 1`, firedAt, lines with `PrepCategory`, status `pendingKitchen`). Round is persisted to Hive (`table_rounds` box) — survives app restart. Table status → `orderPending`, `activeRoundNumber` updated. Drafts cleared. **Guards:** firing on an available or paymentPending table fails ("no open tab"); firing an empty draft list fails. After persistence, tickets are printed (`_printTickets`) — print failures never fail the round.
* **Repeat Rounds:** Subsequent orders follow the same pattern; `activeRoundNumber` increments; each round is a separate `TableRoundEntity`.
* **Mark Served:** `MarkServed` sets the round to `served`. The table flips to `served` **only when ALL of its rounds are served**; otherwise it keeps its current status.
* **Clear Tab (`ClearTab`):** Deletes all of the table's rounds and resets the table to `available` (clears `tabOpenedAt`/`activeRoundNumber`/drafts). Blocked on an available table. This is the discard path (no receipts, no charge).
* **Checkout Lifecycle:** `StartCheckout` moves an occupied/served table to `paymentPending`; `CompleteCheckout` first **archives** every round of the table (`RoundStatus.archived`, persisted — aborts the checkout if archiving fails), then resets the table to `available` and drops the rounds/drafts from state.

#### M3: Kitchen & Bar Routing (Ticket Printing)
* **PrepCategory on Products:** `PrepCategory` enum (`food` / `beverage` / `shisha` / `general` / `dessert` / `special`) added to `ProductEntity`. Grid-mode product form shows a dropdown; defaults to `food`. Category visibility in pickers is governed by the `shownPrepCategoryIds` setting (Module D).
* **Automatic Split on Fire:** When a round is fired, lines are grouped by `PrepCategory`. For each category with ≥1 line:
  - If the category's ticket printer is enabled AND a printer is configured → prints a **production ticket** (distinct from financial receipts).
  - **Ticket Layout:** Venue name header, station label (KITCHEN / BAR / SHISHA), table + zone + round #, order number, lines (`qty × item name`), fired timestamp. **NO prices, totals, or tax.**
  - Ticket printing uses new `ticket` payload in `PrintService` + dedicated C# handler in `PrintServer/` (receipt/barcode handlers untouched).
  - If disabled or no printer → silently skips; round status still `pendingKitchen`.
* **Mark Served:** Cashier taps "Mark Served" on a round → round status → `prepared` → `served`. Table status → `served`.

#### M4: Advanced Table Operations
* **Transfer Table:** Move an entire active tab (fired rounds + drafts) from one table to another available table. Source table cleared to `available`. Target table receives tab + rounds; status → `occupied`.
* **Merge Tables:** Combine two or more occupied tables into a single target table. Lines summed; source tables cleared (no charge). Only available from table session dialog.
* **Split Billing (v1 = Equal-N):** At checkout, cashier selects "Split equally by N". The total (room + items + fees) is divided into N receipts; remainder piastres lands on the last receipt. N sequential payment dialogs (payment type from `shownPaymentTypeIds`, amount paid). N cashier receipts printed via `CreateReceipt` (full retail parity: order number, auto-print, save-as-image, shift audit, refunds). Table cleared to `available`, rounds archived (`RoundStatus.archived`).

#### M5: Hybrid Integration — PlayStation + F&B (Followup Branch)
* **Scope:** Owned by `feature/playstation-mode` (after café branch merges). Not in this branch.
* **Behavior:** Cashier orders F&B directly into an active PlayStation station session. On session end, time billing + F&B addons consolidate into a unified session receipt.

#### M6: Financials, Fees & Minimum Charge
* **Service Charge:** `serviceChargeEnabled` (toggle, default OFF) + `serviceChargePercent` (default 12). Applied dine-in only: `service = round(base × pct/100)`. Takeaway-kind zones exempt.
* **Minimum Charge:** `minChargeEnabled` (toggle, default OFF) + `minChargePerTablePiastres`. Floor applied to base (items + room charge) dine-in only: `base = max(base, minCharge)`. Takeaway-kind zones exempt.
* **Tax:** Reuses existing `taxEnabled` + `taxPercent` (settings). Applied after discount (retail-parity): `tax = round(discounted × taxPercent/100)`.
* **Discount:** Discount % input at checkout (mirrors retail `CheckoutConfirmationDialog` math).
* **Billing Order:** `base = items + roomCharge` → min-charge floor (dine-in) → service charge (dine-in) → discount % → tax % → total.

#### M7: Immutable Closed Tabs
* **Receipt Pipeline:** Table checkout → N `CreateReceipt` events → `ReceiptsBloc` → `ReceiptEntity` (immutable, itemized, shift-audit, refund-capable). Same pipeline as retail. Sales workspace shows café receipts alongside retail.
* **No New Record Type:** Closed tabs do NOT create a separate "table record" — the receipt IS the audit record.

#### M8: Settings Additions (Keys 22-32, all admin-gated)
| Key | Field | Default |
|-----|-------|---------|
| 22 | `roomsEnabled` | false |
| 23 | `serviceChargeEnabled` | false |
| 24 | `serviceChargePercent` | 12 |
| 25 | `minChargeEnabled` | false |
| 26 | `minChargePerTablePiastres` | 0 |
| 27 | `kitchenTicketsEnabled` | true |
| 28 | `kitchenPrinterName` | null |
| 29 | `barTicketsEnabled` | true |
| 30 | `barPrinterName` | null |
| 31 | `shishaTicketsEnabled` | true |
| 32 | `shishaPrinterName` | null |

* All new sections (Floor, Tickets) rendered under `if (isAdmin)` in `SettingsWorkspace`. **Guard fix:** Previously added `_BusinessTypeCard` (favorites strip, minimum game cost) was outside `isAdmin` — now gated.

#### M9: Deferred (Followups)
* Itemized split billing (per-guest line ownership model).
* KDS (Kitchen Display System) — digital screens for kitchen/bar/shisha prep.
* Table occupancy analytics in Sales workspace.
* Draft lines not persisted on app restart (accepted v1 limitation).

---
