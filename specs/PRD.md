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
* **Transaction ID Generation:** `CartEntity` generates a 15-character tx ID using `DateTime.now().millisecondsSinceEpoch` concatenated with `Random.secure().nextInt(100000)`, truncated/padded to 15 chars. `Random.secure()` provides cryptographically strong randomness from platform CSPRNG — prevents tx ID enumeration.
* **Dynamic Quick Actions Grid:** A dedicated panel housing large, color-coded interactive tiles for barcode-less sales (e.g., photocopying services, custom gift wrapping, loose colored paper sheets).
* **Cart Table Widget:** Cart items render in a structured `Table` widget with 4 columns (No., Name, Qty, Price) using fixed `FlexColumnWidth` ratios (1:4:1.5:2:2, with the 5th total column hidden). The table uses `AnimatedList` with `SizeTransition` + `FadeTransition` (300ms) for insert/remove animations. Column widths are extracted as a top-level `_cartColumnWidths` constant. Quantity cells use `ValueNotifier<bool>` for edit mode tracking and `FilteringTextInputFormatter.digitsOnly`. The widget also includes a total footer row with `AnimatedCounter` values. Individual `CartItemTile` (removed) is no longer used — all cart interactions go through `CartTableWidget`.
* **Quick Tiles:** Enlarged from 72x72 to 100x100. Font size increased from `caption` (11pt) to `heading2` with `FontWeight.w500`. Background uses `withValues(alpha: 0.6)` for subtle transparency. Tiles animate in with `TweenAnimationBuilder` (fade + scale, 300ms, `Curves.easeOut`). Tile grid wrapped in `SectionCard` with "Quick Items" title. Maximum 10 quick-tile items; at limit, the quick-tile toggle switch is hidden in the product form dialog.
* **Cash Drawer Assistant (Redesigned):** Quick-select monetary buttons in 2-row grid layout (first row: 5, 10, 20, 50 EGP; second row: 100, 200 EGP + Clear "C" button). Amounts display with locale-aware currency formatting. Confirm button uses styled `ElevatedButton` with `clipBehavior: Clip.antiAlias`, vertical padding `Spacing.lg`, `RoundedRectangleBorder` with `Spacing.md` radius and primary border side.
* **Checkout Lifecycle:** The `CheckoutBloc` initializes in `CheckoutStatus.ready` (not `initial`) with an empty `CartEntity`. On confirm, status transitions to `confirmed`. A `CheckoutConfirmationDialog` shows optimistically (neutral loading state: `CircularProgressIndicator` + "Processing sale...", no icon). On `ReceiptsBloc` success, dialog transitions to success state (check_circle, auto-dismiss 2s); on `ReceiptsBloc` failure (`ReceiptPersistenceFailure`), dialog transitions to error variant (error icon, failure reason, auto-dismiss 5s). Either case: after 2 seconds (or on failure, after the 5s auto-dismiss or manual dismissal), `ClearCart` resets to a fresh cart.
* **Guarded Confirmation:** `CheckoutBloc._onConfirmSale` guards against double-confirm race via a `_confirmInProgress` field-level bool (set true before emit, reset false on `ClearCart` or license failure). There is no `isPaid` guard in the bloc — confirming with zero amount paid is allowed. The confirm button in `CashDrawerAssistant` is gated on `total > 0`, not `subtotal > 0`.
* **Checkout Confirmation Dialog:** A custom `Dialog` wrapping `PopScope(canPop: false)` on success / `PopScope(canPop: true)` on failure (allows dismissal on error path). Shows a large 64px icon (check_circle for success, error for failure) with a title-large message. Success: auto-dismisses after 2 seconds via `Future.delayed`. Failure: auto-dismisses after 5 seconds; a dismiss button appears after 3 seconds. Triggered by the checkout workspace when `CheckoutStatus.confirmed` is emitted.
* **Tower Panel Restructure:** The receipt tower panel is split into two `SectionCard` sections: (1) Receipt section with centered store name in `heading2`, a `receiptDuotone` icon + localized title, numbered items with `quantity × price` breakdown, and a summary footer showing item count, subtotal, discount (if any), tax (if any), total, and a configurable receipt footnote; (2) Cash Drawer section below with `CashDrawerAssistant`. Separated by `SizedBox(height: Spacing.sm)`. The old "New Sale" button is removed — the auto-dismissing dialog replaces it.
* **Interactive Cash Drawer Assistant:** Quick-select monetary buttons for Egyptian currency notes (5, 10, 20, 50, 100, 200 EGP) to instantly calculate accurate customer change calculations. The confirm sale button is always enabled when the cart contains items (no cash amount entry required to enable it). Includes a discount percentage TextField with real-time bloc dispatch. On confirm, a success dialog is shown for 2 seconds, then auto-dismisses and clears the cart to start a new sale.

#### A10: In-Cart Key Navigation & Selection
* **Selection State:** Cart item selection is managed by a local `ValueNotifier<int>` (`_selectedIndex`) inside `CartTableWidget` — it does NOT live in `CheckoutState`. Selection wraps around (0 → n-1 → 0). Intents handle keyboard-driven navigation: `SelectNextCartItemIntent` (Down), `SelectPrevCartItemIntent` (Up), `RemoveSelectedCartItemIntent` (Delete), `EditCartItemQuantityIntent` (Enter to toggle inline edit mode on selected row).
* **Selection Highlight:** The matching row renders with a distinct highlight state (accented background / border) to indicate focus.
* **Modification Actions:** `RemoveSelectedCartItemIntent` dispatches `RemoveFromCart` for the selected barcode. `EditCartItemQuantityIntent` activates the inline quantity `TextField` edit mode on the selected row (same as tap-to-edit).

#### Module B: Product Management & Barcode Studio
* **Inventory Ingestion Interface:** Fast forms to input Item Name, Retail Price, Stock Count, Barcode, and Notes. New product form auto-fills barcode with a random 12-digit number (first digit non-zero). Fields: barcode, name, price, stock, notes, quick-tile toggle, and tile color picker.
* **Purchase Price Field:** `purchasePrice` (double, default 0.0) on `ProductEntity` (`product_entity.dart:5`), persisted through `InventoryRepository` (`inventory_repository.dart:31-40`) and edited in the product form. Saving a product whose purchase price exceeds the selling price surfaces a warning dialog.
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
* **Persistence Model:** All settings persisted automatically via `HydratedBloc` + Hive local key-value storage. No explicit "Save" or "Apply" button required — each interaction commits immediately. A failure to persist (disk full, corrupted box) must surface the localized error state from `DESIGN.md` Section 6.4, with a retry action that re-issues the original bloc event against the same payload.
* **AppBar Removal:** The `SettingsWorkspace` (and `InventoryWorkspace`) no longer use `Scaffold.appBar`. The section title and actions are embedded in a `SectionCard` notch title wrapping the body content. The `SectionCard` uses `mainAxisSize: MainAxisSize.max` so the child fills available space.
* **Localization Engine:** Dedicated `LocalizationService` class with O(1) `Map<String, Map<String, String>>` translation dictionary supporting Arabic and English. Accessed via `translate(key)` method. No `intl` package dependency.
* **Tax Configuration:** A dedicated settings section with an enable/disable `SwitchListTile` ("Enable Tax") and a percentage `TextField` ("Tax Rate (0-100)") shown conditionally when tax is enabled. Rate input is debounced (300ms) and clamped to 0-100. Dispatches `TaxToggled(bool)` and `TaxPercentChanged(int)` to `SettingsBloc`. Tax is synced to `CheckoutBloc` via `SetTaxPercent(int)` on app startup (via `app.dart`) and reactively on settings change (via a `BlocListener` in `AppShell`). Tax calculation is subtotal-based: `taxAmount = subtotal * taxPercent / 100` (not after-discount).
* **Auto-Print Toggle:** A `SwitchListTile` in a "Printing" settings section. Stores `autoPrintEnabled` (bool, default false) on `AppSettingsEntity`. Dispatches `AutoPrintToggled(bool)`. When enabled, receipt is automatically sent to the selected thermal printer after sale confirmation via `ReceiptPrintHelper` → .NET PrintServer sidecar.
* **Barcode Action Preference:** Stores `barcodeActionPreference` (String, default `'printDirect'`) on `AppSettingsEntity`. Presets the product form dialog's barcode-label export action: `'printDirect'` uses `BarcodeAction.printDirect`, `'savePng'` uses `BarcodeAction.savePng` (read only at `product_form_dialog.dart:255-260`). Scanner behavior is unaffected — scanned barcodes always add directly to the cart. Dispatches `BarcodeActionPreferenceChanged(String)`.
* **Save-Receipt-as-Image Toggle:** A `SwitchListTile` in the Printing section. Stores `saveReceiptAsImage` (bool, default false). When enabled, a PNG image of the receipt is automatically saved to the export directory after each sale.
* **Receipt/Barcode Printer Dropdowns:** Two `DropdownButton` widgets in the Printing section populated from the PrintServer's `GET /api/printing/local-printers` endpoint. Selections stored as `receiptPrinterName` and `barcodePrinterName` (empty = system default). A refresh button re-queries installed printers.
* **Export Directory Path:** A `_SettingsSection` with a validated Windows absolute path input + "Choose Folder" `FilledButton.tonalIcon`. Opens a directory picker via `file_picker`. Replaces the previous `barcodeDownloadPath` with a unified `exportDirectoryPath`. Path validated against Windows drive-letter regex before dispatch. Invalid paths show inline error and are not saved. Dispatches `SetExportDirectoryPath(String)`.
* **Reset All Data:** A settings section with a destructive `ElevatedButton` (red). On confirmation dialog, clears the `settings`, `inventory`, `auth_users`, `shifts`, `active_shifts`, `receipts`, `refunds`, and `audit_log` Hive boxes plus `HydratedBloc.storage` (`reset_section.dart`), then dispatches `LoadSettings()`, `LoadInventory()`, and `LogoutRequested()` to reset the application to factory defaults and return to the login/setup flow.
* **Admin General Section (Store Identity):** An admin-only `_SettingsSection` with fields for store address, phone number, and SVG logo path. See DESIGN.md Component P.
* **New Localization Keys Added:** `checkout.cashDrawer`, `checkout.saleConfirmed`, `checkout.saleFailed`, `checkout.table.no`, `checkout.table.name`, `checkout.table.qty`, `checkout.table.price`, `checkout.table.total` — for the redesigned cart table and checkout confirmation flow. `tax`, `taxToggle`, `taxPercent`, `printing`, `autoPrint`, `resetAllData`, `resetAllDataConfirm`, `reset`, `discount`, `checkout.total` — for new settings sections. 40+ shortcut-related keys under `shortcuts.*` and `shortcuts.action.*`. `inventory.product.notes`, `inventory.product.notes.hint`, `inventory.product.saveBarcode` — for product notes field and barcode save button.

#### D6: Keyboard Mapping Configurator
* **Data Extension:** `AppSettingsEntity` gains `final Map<String, List<String>> customBindings` (action token → list of key combo strings, e.g., `"search.toggle" → ["f5", "/", "ctrl+f"]`), defaulting to an empty map. `AppSettingsModel` extends `customBindings` serialization in `fromJson`/`toJson` and `TypeAdapter` (field key `4`).
* **Bloc Events:** Three event types for customization: `AddCustomBinding(String actionToken, String keyCombo)` — merges new combo into the action's list and resolves conflicts (same key combo removed from other actions); `RemoveCustomBinding(String actionToken, String keyCombo)` — removes one combo from the action's list; `ResetCustomBinding(String actionToken)` — removes the action token entirely from `customBindings`, reverting to defaults.
* **Conflict Resolution:** When adding a combo, all other action tokens' bindings are scanned. If any other action already uses the same combo, that entry is removed (the new binding wins). This is a last-assignment-wins, many-to-one conflict model.
* **Keyboard Mapping Hub:** A dedicated `_SettingsSection` block rendered inside `SettingsWorkspace` (6 groups: Navigation, Search, Cash Drawer, Cart, Quick Tiles, Inventory). Lists every system action with a localized label + combo chips + add/remove/reset controls. Tapping the add button opens `KeyCaptureDialog`; result dispatches `AddCustomBinding`. Custom bindings display with a primary-colored border; default bindings have a plain outline.
* **Persistence Model:** Same per-tab auto-save pattern as existing settings — no explicit save button. Changes flow through `SettingsBloc` → repository → HydratedBloc Hive layer.
* **New Localization Keys Added:** `shortcuts.title`, shortcuts.group keys, `shortcuts.action.*` for every action token, `shortcuts.keyCapture.*`, `shortcuts.tapToRebind`, `shortcuts.resetToDefault` — for the Keyboard Mapping Hub.

### 4. Module E: Keyboard Shortcuts & Navigation System

#### E1: Global Search & Scanner Overlay
* **QuickSearchOverlay:** A modal `OverlayEntry` rendered at the `GlobalShortcutGate` level (above all workspaces). Triggered by default key `F5` (or `/` / `Ctrl+F`). On open, a `TextField` auto-focuses for manual search input. The overlay is a centered 500px-wide Material card on a semi-transparent scrim.
* **Scanner Integration:** While the overlay is open, the `BarcodeScannerGate` interceptor continues processing hardware scans. When a barcode is captured (`isSearchOpenNotifier.value == true`), the barcode is injected into the overlay via `_barcodeInjectionNotifier`. The overlay reads the injected barcode, populates the search text, and performs an O(1) lookup in `InventoryBloc.inventoryMap`. Results are shown as a `ListView` of product info rows. Tapping a result dispatches `AddToCart`.
* **Dismissal:** Pressing `Escape` or tapping the barrier outside the dialog closes the overlay and clears the search state.

#### E2: Guarded Checkout Actions
* **Triggers:** `F12` or `Spacebar` invokes checkout finalization (`ConfirmSale`).
* **Invariant Guard:** The shortcut controller checks `CartEntity.items.isNotEmpty` before dispatching. A business-level guard (`_confirmInProgress` flag) also exists in `CheckoutBloc._onConfirmSale` to prevent double-confirm race conditions.

#### E3: In-Cart Key Navigation & Manipulation Loop
* **Selection Focus:** Up/Down arrow keys shift local `_selectedIndex` (a `ValueNotifier<int>` in `CartTableWidget`). Selection wraps bidirectionally. The arrow key bindings exist both as global `ShortcutActivator` entries in `GlobalShortcutGate` AND as local `Shortcuts` in `CartTableWidget` (the scoped version takes priority when the cart's `Focus` node is active).
* **Delete:** `Delete` / `Del` key on a selected item dispatches `RemoveFromCart` for the selected barcode.
* **Edit Quantity:** `Enter` on a selected item activates the inline quantity `TextField` edit mode (same behaviour as tapping the quantity cell in `CartTableWidget`). A second `Enter` (or focus loss) commits the edit.

#### E4: Quick-Tiles Grid Hotkeys
* **Trigger Sequences:** `Alt + 1` through `Alt + 0` (where `Alt + 0` = index 9) map to `InventoryBloc.quickTileList[index]` (0-indexed: `N-1`). Up to 10 tile slots.
* **Execution:** On matching a tile index, dispatches `AddToCart` with the product's barcode, name, and price — identical to tapping the tile directly.

#### E5: Navigation & Utility Hotkeys
* **Navigation:** `F1` → checkout tab, `F2` → inventory tab, `F3` → sales history tab, `F4` → settings tab. Each dispatches `NavigateToCheckoutIntent` / `NavigateToInventoryIntent` / `NavigateToSalesIntent` / `NavigateToSettingsIntent`, which set `selectedIndexNotifier` in `AppShell`.
* **Add Product:** `Ctrl + N` dispatches `AddProductIntent` (only active when on the inventory tab). Calls `AppShell.onAddProduct` callback to show `ProductFormDialog`.
* **Discount Focus:** `Ctrl + D` dispatches `FocusDiscountIntent`, which increments `_discountFocusTrigger` notifier. `CashDrawerAssistant` listens and requests focus on the discount `TextField`, selecting all existing text.

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
* **Roles:**
  - `admin`: Access to Sales (default), Settings.
  - `cashier`: Access to Checkout (default), Inventory, Sales (limited view), Settings (limited sections).

#### F2: User Management (Admin Only)
* **Location:** First section in Settings workspace, above General section. Only visible to `admin` role.
* **User List:** Shows all users in a list. Each entry: username, role badge, change-password button.
* **Add User:** `+` button opens a dialog with username, password (min 8 characters), role `SegmentedButton` (admin/cashier). Username validated against `RegExp(r'^[a-zA-Z0-9_]{3,30}$')`. Duplicate username checked client-side. Cancel + Add buttons. Uses `BlocListener`: Navigator pops on success, shows inline error on failure.
* **Change Password:** Dialog with current password (admin re-auth verified against stored hash) + new password (min 8) + confirm. All fields required. Only admins can change other users' passwords. Uses `BlocListener`: success snackbar, error snackbar.
* **Persistence:** All changes save immediately to the `auth_users` Hive box via `AuthRepository`.

#### F3: Shift Lifecycle
* **ShiftEntity:** `id` (string UUID v4), `username` (string), `startedAt` (DateTime), `endedAt` (DateTime?), `openingFloat` (int piastres, default 0).
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
* **NavItem Resolution:** Nav rail items are rendered from a `Map<UserRole, List<NavDestination>>` mapping. Admin: [Sales, Settings]. Cashier: [Checkout, Inventory, Sales, Settings].
* **F1-F4 Shortcuts:** Each shortcut checks if the target `NavDestination` is in the user's allowed list. If not, the key press is a silent no-op.
* **End Shift:** Not a nav destination — always rendered at nav rail bottom.
* **IndexedStack:** All 4 workspace slots exist in `IndexedStack` regardless of role. Unreachable destinations simply never get selected.

#### F6: First-Time Admin Setup
* **Problem:** On fresh install, seed passwords are cryptographically random (unreachable by a human). The admin must set a real password before first use.
* **Marker Mechanism:** A `__setup_completed__` marker key in the `auth_users` Hive box tracks whether admin initialization has occurred.
* **Flag name choice:** `__setup_completed__` (inverted semantics from `isFirstTimeLogin` — "login" is per-user, this is app-level).
* **Onboarding Flow:** 3 screens in `lib/features/onboarding/` — Welcome (skippable), Features highlights (skippable), Admin Setup (required, last). Step state in `OnboardingBloc` (plain `Bloc`, not hydrated). Only completing Admin Setup exits the flow; skip/next are blocked on the final screen.
* **Flow:**
  1. App starts → `AuthBloc.CheckAuth` → seeds the admin user
  2. Checks `__setup_completed__` marker — absent on fresh install
  3. Emits `AuthStatus.setupRequired` → `OnboardingFlow` shown (Welcome → Features → Admin Setup)
  4. Admin enters password (min 8 chars) + confirm
  5. `CompleteAdminSetup(password)` → PBKDF2 hash → save admin with `mustChangePassword: false` → write `__setup_completed__` → emit `authenticated`
* **Seed behavior:** Only the admin user is seeded (`mustChangePassword: true`). Cashiers are created later via User Management. Admin's `mustChangePassword` set to `false` after setup.
* **Existing installs:** Installs that already ran the old seed keep their seeded cashiers (seed is marker-idempotent; no migration, no auto-delete). If `__seeded__` exists but `__setup_completed__` is absent, `isSetupCompleted()` returns `false` → the install passes through onboarding once. Installs with the marker go straight to login.
* **Reset All Data:** Clears `auth_users` box → marker gone → setup re-triggered on next launch.

---

### Module G: Receipts & Persistence

#### G1: Receipt Model
* **Receipt = Transaction:** There is no separate "sale" concept — a receipt IS a completed transaction. One receipt per `ConfirmSale`.
* **ReceiptEntity:** `id` (string UUID), `shiftId` (string), `orderNumber` (string), `items` (List<ReceiptItem>), `subtotalPiastres` (int), `discountPiastres` (int), `taxPiastres` (int), `totalPiastres` (int), `taxPercent` (int, default 0), `discountPercent` (int, default 0), `createdAt` (DateTime), `username` (string), `stockUpdated` (bool, default false), `stockFailedBarcodes` (List<String>, default `[]`), `status` (ReceiptStatus, default active).
* **ReceiptItem:** `name` (string), `barcode` (string), `quantity` (int), `unitPricePiastres` (int).
* **Storage:** Hive box `receipts`. Simple key-value with receipt ID as key.

#### G2: Decoupled Creation Flow
* **CheckoutBloc stays pure:** On `ConfirmSale`, `CheckoutBloc` emits `status: confirmed` with order number and final cart. It does NOT persist receipts.
* **Order Number Generation:** Order numbers are generated as `'ORD-'` + the shift's `orderCount` zero-padded to 5 digits, then `IncrementShiftOrderCount` bumps the counter (`app.dart:155-164`). The settings `orderCounter`/`lastOrderDate` fields are persisted but unused.
* **BlocListener bridge:** `AppShell` contains a `BlocListener<CheckoutBloc>` that catches `confirmed` status and dispatches `ReceiptsBloc.CreateReceipt(...)` with shift ID, order number, cart snapshot, user info, `taxPercent`, and `discountPercent`.
* **ReceiptsBloc responsibilities (4-step atomic sequence):**
  1. Save `ReceiptEntity` to `ReceiptsRepository` with `stockUpdated: false`, `taxPercent`, and `discountPercent` snapshots.
  2. Iterate items and call `IInventoryRepository.updateStock(barcode, -quantity)` for each (best-effort — failure does not roll back receipt). Failed barcodes are tracked in `stockFailedBarcodes` on the entity.
  3. Save entity with `stockUpdated: !stockFailedBarcodes.isEmpty` and `stockFailedBarcodes` list persisted.
  4. Second `ReceiptsRepository.save(receiptEntity)` to persist the `stockUpdated`/`stockFailedBarcodes` flags, then emit `ready`.
* **Failure Handling:** If step 1 fails, emit `ReceiptPersistenceFailure` immediately (no receipt, no stock change). If steps 2-4 fail after step 1 succeeded, the receipt still exists with `stockUpdated: false` and `stockFailedBarcodes` populated (incomplete — auto-retry possible). UI transitions to error variant in either case.
* **Total Cross-Validation:** All creation and modification handlers validate `totalPiastres == subtotalPiastres - discountPiastres + taxPiastres` before proceeding. Mismatch emits `ValidationFailure` with reason `total_does_not_match_subtotal_discount_tax`.
* **Admin Password Verification:** `AuthorizedModifyReceipt` uses constant-time `hashPassword(event.adminPassword, adminUser.passwordSalt)` comparison against stored hash (not plain-text compare).
* **Startup Stock Retry:** `ReceiptsBloc` exposes `retryPendingStockUpdates()` — on app startup, `AppShell` calls `unawaited(bloc.retryPendingStockUpdates())` to re-attempt stock decrements for receipts where `stockUpdated == false`. The retry scope narrows to only `stockFailedBarcodes` on partial success, preventing double deduction on already-resolved items. First failed items guarded via `firstWhere(orElse: ...)` with zero-quantity fallback.

#### G3: Stock Integrity
* Stock cannot go negative — `InventoryRepository.updateStock(barcode, deltaQuantity)` pre-computes `newStock = currentStock + deltaQuantity` and returns `Left(DatabaseFailure('Insufficient stock'))` if `newStock < 0` without mutating the database.
* **Stock Restoration:** Processing a Return or Invoice Modification must automatically increment (restore) the respective product quantities back to the inventory stock balance.
* **Double-Refund Security Lock:** Any receipt whose state is already marked 'returned' or 'modified' must be completely locked in the UI, disabling any further Return or Edit actions to prevent duplicate cash restoration.

---

### Module H (Phase 6 — Future): Sales Analytics Workspace

#### H1: Admin Sales View
* **Today's Summary Bar (Fixed):** At top of Sales workspace, a non-scrollable summary bar showing three metrics: **Receipts Count** (number of receipts today), **Total Sales** (sum of `totalPiastres` for today's receipts, formatted in EGP), **Items Sold** (sum of all item quantities across today's receipts).
* **SummaryBar (Daily + Monthly, One Row):** A single non-scrollable `Row` at the top of the Sales workspace with a `VerticalDivider` between halves (`summary_bar.dart:34,109`). Left half: today's metrics — **Receipts Count**, **Total Sales** (sum of `totalPiastres` for today's receipts, formatted in EGP), **Items Sold** (sum of all item quantities). Right half: the current month's metrics via `MonthGroupedData` (receipt count, items sold, total sales). Loaded via `SalesBloc.LoadTodaySummary` / `LoadMonth` / `LoadShiftReceipts` events (`sales_event.dart:5,14,27`); the MonthBrowser issues six individual `LoadMonth(year, month)` calls. No `LoadMonths` event exists.
* **Month Browser (Scrollable Below):** Below the summary bar, a scrollable list of months. Each month card shows: month/year label, receipt count for that month, total sales for that month. Tapping a month expands into a detailed view showing each receipt for that month (order# · time · items count · total). Month data is computed at query time by filtering `receipts` box on `createdAt`.
* **Query Pattern:** `ReceiptsRepository.getByMonth(year, month)` filters in-memory (acceptable for local POS volumes).

#### H2: Cashier Sales View
* Cashiers see all receipts from the current active shift. Displayed as a scrollable list: order number, total, timestamp. No month browsing, no cross-shift data, no summary bar.
* Data source: `ReceiptsRepository.getByShift(shiftId)` sorted by `createdAt` descending.

---

### Module I: Refunds & Modifications (Double-Lock System)

#### I1: Receipt Status Machine
* **ReceiptStatus enum:** `active`, `returned`, `modified`. All receipts created as `active`.
* **Double-Lock Rule:** Any receipt with `status != active` rejects all mutating operations (return or modify) via `RefundLockFailure`.

#### I2: Refund Flow (Full/Partial)
* **Stock Restoration:** Full refund restores original quantities for all items via `IInventoryRepository.updateStock(barcode, +originalQuantity)`.
* **RefundEntity:** `id` (UUID), `originalReceiptId` (UUID), `refundDate` (DateTime), `amountRestored` (int piastres), `type` (RefundType: full/partial).
* **Status Transition:** Receipt marked `status = returned`. Receipt saved with updated status. `RefundEntity` persisted to Hive `refunds` box.
* **Admin-Verify Lockout:** Refund and modify actions require admin password re-verification. After ≥3 failed attempts the dialog locks with a cooldown (`remaining = attempts × 2` seconds), reset on successful verification (`receipt_detail_dialog.dart:303-422`).

#### I3: Modification Flow (Quantity Change)
* **Delta Calculation:** `deltaQuantity = originalQty - newQty`. Positive → restore stock. Negative → decrement.
* **Status:** Receipt set to `status = modified`. Further modifications allowed (new delta calculated against current quantities). Return blocked.

#### I4: RefundLockFailure
* **Type:** New `Failure` subclass in `lib/core/error/failure.dart`.
* **Fields:** `receiptId` (String), `currentStatus` (ReceiptStatus), `message` (String).
* **Trigger:** Any refund/modify action on a receipt where `status != active`.

---

### Module J: Print Server & Receipt Reprint

#### J1: .NET PrintServer Sidecar
* **Architecture:** A .NET 8 Minimal API (`PrintServer/`) running as a child process on `127.0.0.1:5150`. The Flutter app spawns it via `PrintServerManager` on startup and kills it on dispose. The manager resolves `PrintServer.exe` across six candidate paths (side-by-side, Inno Setup install layout, `build/windows` Debug/Release, and `PrintServer/bin` Debug/Release — `print_server_manager.dart:17-61`); if no candidate exists, `main.dart` runs `dotnet publish` on the `PrintServer.csproj` automatically on first launch before starting the process.
* **Endpoints:**
  * `GET /api/printing/local-printers` — Returns list of installed Windows printer names.
  * `POST /api/printing/receipt` — Prints a thermal receipt via GDI+ (`PrinterService.cs`). Accepts receipt payload (items, subtotal/tax/discount/total in piastres, store identity, RTL flag). Also writes a PNG version via SkiaSharp (`ImageExportService.cs`) if requested.
  * `POST /api/printing/save-png` — Saves a receipt PNG via `ImageExportService` (SkiaSharp, `Program.cs:69`) without printing. Used by the "Save as PNG" action in `ReceiptDetailDialog`.
  * `POST /api/printing/barcode` — Prints a Code128 barcode label via `BarcodeLib`.
* **Image Export:** `SaveReceiptAsPngAsync()` renders with SkiaSharp (white background, black text, gray meta/dividers). `IsRtl` is serialized in the request but never read — layout renders LTR unconditionally (ImageExportService.cs). `SkiaSharp.HarfBuzz` is imported but no shaping API is used.
* **Financial Row Logic:**
  * `showSubtotal = taxPiastres > 0 || discountPiastres > 0`
  * `showTax = taxPiastres > 0`
  * `showDiscount = discountPiastres > 0`
  * Label is always "Total" — "Grand Total" appears nowhere in PrintServer or lib (PrinterService.cs:149, ImageExportService.cs:353)
* **Barcode:** Uses `BarcodeLib` (NuGet) with CODE128 encoding. Rendered as `System.Drawing.Image` onto the `PrintDocument` page.
* **Windows-only:** `System.Drawing.Printing` + `PrintServer.exe` sidecar require Windows host.
* **Rate Limiting:** Kestrel configured with 30 requests/second rate limiter.

#### J2: Flutter PrintService Client
* **File:** `lib/core/printing/print_service.dart`
* **Methods:** `getLocalPrinters()` → `List<String>`, `printReceipt(ReceiptRequest)` → `bool`, `printBarcode(BarcodeRequest)` → `bool`.
* **Communication:** HTTP via `dart:io` HttpClient to `http://127.0.0.1:5150`.

#### J3: PrintServerManager (Sidecar Lifecycle)
* **File:** `lib/core/printing/print_server_manager.dart`
* **Lifecycle:** `start()` → `Process.start('PrintServer.exe')` with stdout/stderr piped to `print()`. `stop()` → `Process.kill()`. `dispose()` → call `stop()`.
* **Auto-Build Fallback:** On first launch, `main.dart` calls `ensurePrintServerBuilt()` — runs `dotnet publish` on `PrintServer.csproj` when `PrintServer.exe` is missing — before handing off to `PrintServerManager.start()`.
* **Registration:** Created in `main.dart`, passed as constructor argument to `App`. Disposed in `App.dispose()`.

#### J4: Settings Integration (Expanded)
* **New AppSettingsEntity fields:** `exportDirectoryPath`, `saveReceiptAsImage`, `storeAddress`, `storePhoneNumber`, `logoSvgData`, `receiptPrinterName`, `barcodePrinterName`, `barcodeActionPreference`.
* **New SettingsBloc events:** `AutoPrintToggled`, `SaveReceiptAsImageToggled`, `SetExportDirectoryPath`, `StoreAddressChanged`, `StorePhoneNumberChanged`, `LogoSvgChanged`, `ReceiptPrinterNameChanged`, `BarcodePrinterNameChanged`.
* **Auto-print on Sale Confirm:** After successful receipt creation, `AppShell`'s `BlocListener<ReceiptsBloc>` triggers `ReceiptPrintHelper.printReceipt()`. The helper builds the receipt JSON payload (including store identity, logo SVG data, RTL flag, taxPercent/discountPercent) and dispatches to `PrintService.printReceipt()`. Enabled only when `autoPrintEnabled == true`.
* **Auto-save Receipt as Image:** When `saveReceiptAsImage == true`, after sale confirm, `ReceiptPrintHelper.printReceipt()` sets `saveAsPng: true` in the payload. The PrintServer's `ImageExportService` saves a PNG to `exportDirectoryPath`.
* **skipPrint flag:** When `saveReceiptAsImage == true && autoPrintEnabled == false`, the helper sets `skipPrint: true` — only PNG save, no thermal print. When both are true, both operations run. When both false, no print action occurs.

#### J5: Receipt Reprint & Save PNG (in ReceiptDetailDialog)
* **Print Trigger:** A "Print" button (Phosphor `printer` icon) in `ReceiptDetailDialog` footer. Visible when app is running on Windows and PrintServer is available.
* **Save PNG Trigger:** A "Save as PNG" button (Phosphor `floppyDisk` icon) in `ReceiptDetailDialog` footer. Calls `PrintService.saveReceiptPng(payload)` via `ReceiptPrintHelper.saveAsPng()`.
* **Payload:** Builds `ReceiptRequest` JSON from receipt entity + current settings state (store name, address, phone, logo, footnote, RTL flag).
* **Execution:** Calls `PrintService.printReceipt(payload)` or `PrintService.saveReceiptPng(payload)`.
* **Guard:** Buttons disabled if `PrintService` is unavailable or no printer configured.

---

### Module K: DRM Licensing (Offline Ed25519)

#### K1: LicenseEngine Architecture
* **Location:** `lib/core/licensing/`
* **Purpose:** Offline, machine-bound license verification using Ed25519 asymmetric signatures. No phone-home server required.
* **Components:** `LicenseEngine` (orchestrator), `Ed25519Verifier` (crypto), `HwidProvider` (HWID extraction), `SecureStorageAdapter` + `FileBackupAdapter` (dual storage).

#### K2: Hardware Binding
* **Windows:** Reads `HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid` via `reg query`. Last 8 hex characters formatted as `CS-XXXX-XXXX`.
* **No admin required** — reads standard registry key accessible to all users.

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
* **ShiftBloc.StartShift:** `verifyLicense()` — blocks shift start if license invalid.
* **CheckoutBloc.ConfirmSale:** `verifyLicense()` — blocks sale if license invalid.
* **Startup:** Silent async `verifyLicense()` — logs warning on tampered status.

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

#### L4: AuditService API

| Method | Signature | Behavior |
|---|---|---|
| `log` | `Future<void> log(AuditEventType, {String? username, required String details, bool success = true})` | Creates `AuditEntry` with `DateTime.now()`, serializes to JSON, inserts into Hive box, then calls `_pruneOld()` |
| `getRecent` | `Future<List<AuditEntry>> getRecent({int limit = 100})` | Iterates box in reverse (newest first), returns up to `limit` entries |
| `_pruneOld` | (private) | Computes cutoff = `now - 90 days`. Iterates all entries, deletes those where `timestamp.isBefore(cutoff)`. Runs after every `log()` call. |

#### L5: Integration Points
* **AuthBloc:** Logs login success/failure, logout, user creation/deletion, password changes. `AuditService` injected as nullable `AuditService?` — all calls use `?.` null-safe operator.
* **ReceiptsBloc:** Logs receipt creation, stock update failures (per-receipt, with failure count), and resolved stock retries.
* **Wiring:** `main.dart` opens `Hive.box<String>('audit_log')` with encryption, creates `AuditService`, passes to `App` constructor. `app.dart` wraps widget tree in `RepositoryProvider<AuditService>.value(...)`.

#### L6: Retention Policy
* **Duration:** 90-day rolling window.
* **Trigger:** `_pruneOld()` runs at the end of every `log()` call.
* **Mechanism:** Iterates all box entries, compares `entry.timestamp` against cutoff, deletes stale keys. O(n) per write (acceptable for local POS volumes — low event frequency).
* **No archival:** Stale entries are permanently deleted.

