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

### 2b. Typography Extension
* **`heading3`:** Added to `TextStyles` — Cairo SemiBold, 20pt. Used for `SectionCard` notch titles and mid-level section headings.

### 3. Core Feature Scope (MVP)

#### Module A: Cashier Checkout Hub (Home Screen)
* **Headless Barcode Scanning Interceptor:** A global keyboard event listener must process input from a hardware barcode scanner automatically, regardless of which UI element currently holds focus.
* **Unknown Barcode Feedback:** When the scanner interceptor produces a barcode that does not exist in the `inventoryMap`, the system must surface a localized, dismissible error affordance (see `DESIGN.md` Section 6.4) — the cashier must never see a silent no-op on a missed scan, and the focus must remain on the scanner input so the next scan is captured immediately.
* **Empty Cart First-Launch State:** A new install with no inventory must present a localized empty state (see `DESIGN.md` Section 6.3) directing the cashier to the Product Management module rather than a blank canvas.
* **Unified SKU Registry Tracking:** Identical items share the same barcode. Modifying the item quantity increments or decrements that unified record. Distinct packaging levels (e.g., a single pen vs. an entire box of pens) are treated as separate products with distinct barcodes.
* **Dynamic Quick Actions Grid:** A dedicated panel housing large, color-coded interactive tiles for barcode-less sales (e.g., photocopying services, custom gift wrapping, loose colored paper sheets).
* **Cart Table Widget:** Cart items render in a structured `Table` widget with 4 columns (No., Name, Qty, Price) using fixed `FlexColumnWidth` ratios (1:4:1.5:2:2, with the 5th total column hidden). The table uses `AnimatedList` with `SizeTransition` + `FadeTransition` (300ms) for insert/remove animations. Column widths are extracted as a top-level `_cartColumnWidths` constant. Quantity cells use `ValueNotifier<bool>` for edit mode tracking and `FilteringTextInputFormatter.digitsOnly`. The widget also includes a total footer row with `AnimatedCounter` values. Individual `CartItemTile` (removed) is no longer used — all cart interactions go through `CartTableWidget`.
* **Quick Tiles:** Enlarged from 72x72 to 100x100. Font size increased from `caption` (11pt) to `heading2` with `FontWeight.w500`. Background uses `withValues(alpha: 0.6)` for subtle transparency. Tiles animate in with `TweenAnimationBuilder` (fade + scale, 300ms, `Curves.easeOut`). Tile grid wrapped in `SectionCard` with "Quick Items" title.
* **Cash Drawer Assistant (Redesigned):** Quick-select monetary buttons in a 2-row grid layout (first row: 10, 20, 50, 100 EGP; second row: 200 EGP + Clear "C" button). Amounts display with locale-aware currency formatting. Confirm button uses styled `ElevatedButton` with `clipBehavior: Clip.antiAlias`, vertical padding `Spacing.lg`, `RoundedRectangleBorder` with `Spacing.md` radius and primary border side.
* **Checkout Lifecycle:** The `CheckoutBloc` initializes in `CheckoutStatus.ready` (not `initial`) with an empty `CartEntity`. On confirm, status transitions to `confirmed`. A `CheckoutConfirmationDialog` (see Module D) shows for 2 seconds, then `ClearCart` resets to a fresh cart.
* **Checkout Confirmation Dialog:** A custom `Dialog` wrapping `PopScope(canPop: false)` to prevent dismissal. Shows a large icon (check_circle for success, error for failure) with a message string. Auto-dismisses after 2 seconds via `Future.delayed`. Triggered by the checkout workspace when `CheckoutStatus.confirmed` is emitted.
* **Tower Panel Restructure:** The receipt tower panel is split into two `SectionCard` sections: (1) Receipt section with centered store name in `heading2`, a `receiptDuotone` icon + localized title, numbered items with `quantity × price` breakdown, and a summary footer showing item count + subtotal in `AnimatedCounter`; (2) Cash Drawer section below with `CashDrawerAssistant`. Separated by `SizedBox(height: Spacing.sm)`. The old "New Sale" button is removed — the auto-dismissing dialog replaces it.
* **Interactive Cash Drawer Assistant:** Quick-select monetary buttons for Egyptian currency notes (10, 20, 50, 100, 200 EGP) to instantly calculate accurate customer change calculations. The confirm sale button is always enabled when the cart contains items (no cash amount entry required to enable it). On confirm, a success/error dialog is shown for 2 seconds, then auto-dismisses and clears the cart to start a new sale.

#### A10: In-Cart Key Navigation & Selection
* **Selection State:** `CheckoutState` gains `int? selectedItemIndex`. New `CheckoutEvent` types: `SelectNextItem`, `SelectPreviousItem`, `DeleteSelectedItem`, `EditSelectedItemQuantity`.
* **Selection Highlight:** `CartTableWidget` accepts `selectedIndex` prop; the matching row renders with a distinct highlight state (accented background / border) to indicate focus. Selection wraps around (0 → n-1 → 0).
* **Modification Actions:** `DeleteSelectedItem` dispatches `RemoveFromCart` for the selected barcode. `EditSelectedItemQuantity` activates the inline quantity `TextField` edit mode on the selected row (same as tap-to-edit).

#### Module B: Product Management & Barcode Studio
* **Inventory Ingestion Interface:** Fast forms to input Item Name, Retail Price, Stock Count, and Barcode. New product form auto-fills barcode with a random 12-digit number (first digit non-zero). Fields: barcode, name, price, stock, quick-tile toggle, and tile color picker.
* **Inventory Layout:** Two-column split — Normal Products (left column) and Quick Access (right column). Each column is a styled `Container` with `theme.cardColor` background (automatically adapts to light/dark mode), `dividerColor` border, and 12px rounded corners. Columns render side-by-side at all times; the right column hides if no quick-tile products exist. Search mode reverts to a single vertical list. The inventory workspace replaces the `AppBar` with a `SectionCard` wrapping the body; the inventory title and action buttons (search, add) are embedded in the SectionCard's notch title + actions slot.
* **Quick Grid Configuration Switch:** A switch allowing the user to flag any product as a "Quick-Tile" item, revealing a palette of 8 predefined colors (`#007ACC`, `#10B981`, `#F59E0B`, `#EF4444`, `#8B5CF6`, `#EC4899`, `#14B8A6`, `#F97316`). Color is stored as `tileColorHex` on `ProductEntity`. If `InventoryBloc.quickTileList.length >= 8`, the quick-tile toggle switch is hidden from the product form dialog. Existing products that are already quick-tiles preserve the toggle so their status can still be edited.
* **Live Barcode Generator Preview:** A rendering container using the `barcode_widget` package (code128) that displays in real-time once the barcode string is 6+ characters. Positioned above the barcode text field in the product form dialog.
* **Currency Display:** All prices formatted in Egyptian Pounds — Arabic locale shows `9.99 ج.م` (amount + space + symbol), English locale shows `EGP 9.99` (symbol + space + amount).
* **Full Localization:** Inventory workspace and product form dialog use `LocalizationService` with ~25 inventory-specific keys (ar + en). Language follows the setting from `SettingsBloc.languageCode`.

#### Module C: Shift & Sales History Ledger
* **Immutable Sales Log:** A secure local timeline capturing every successful transaction. Once recorded, the historical price, timestamp, and sold items remain unalterable, ensuring consistent accounting records if base product costs change in the future.

#### Module D: Store Settings & Localization Profile
* **Dynamic RTL Localization Toggle:** A master system switch changing the user interface between Arabic (العربية) and English instantly, triggering full structural layout direction flipping (`TextDirection.rtl`). Implemented as a `SegmentedButton` with per-tab auto-save.
* **Store Identity Configurator:** Configurable textual parameters `storeName` (String) and `receiptFootnote` (String) stored as fields on `AppSettingsEntity` with `copyWith()` immutability. Values feed directly into the digital checkout layout and physical transaction receipts.
* **Theme Preference Selector:** Toggle state between Light Mode (warm beige palette: `#F5F0EB`/`#FFFDF5`) and High-Contrast Dark Mode (charcoal: `#0F172A`/`#1E293B`) to alleviate eye-strain during extended retail night shifts. Implemented as a `Switch` with real-time status indicator.
* **Persistence Model:** All settings persisted automatically via `HydratedBloc` + Hive local key-value storage. No explicit "Save" or "Apply" button required — each interaction commits immediately. A failure to persist (disk full, corrupted box) must surface the localized error state from `DESIGN.md` Section 6.4, with a retry action that re-issues the original bloc event against the same payload.
* **AppBar Removal:** The `SettingsWorkspace` (and `InventoryWorkspace`) no longer use `Scaffold.appBar`. The section title and actions are embedded in a `SectionCard` notch title wrapping the body content. The `SectionCard` uses `mainAxisSize: MainAxisSize.max` so the child fills available space.
* **Localization Engine:** Dedicated `LocalizationService` class with O(1) `Map<String, Map<String, String>>` translation dictionary supporting Arabic and English. Accessed via `translate(key)` method. No `intl` package dependency.
* **New Localization Keys Added:** `checkout.cashDrawer`, `checkout.saleConfirmed`, `checkout.saleFailed`, `checkout.table.no`, `checkout.table.name`, `checkout.table.qty`, `checkout.table.price`, `checkout.table.total` — for the redesigned cart table and checkout confirmation flow.

#### D6: Keyboard Mapping Configurator
* **Data Extension:** `AppSettingsEntity` gains `final Map<String, String> shortcutMap` (action key → key combo string, e.g., `"confirmSale" → "F12"`), defaulting to an empty map. `AppSettingsModel` extends `shortcutMap` serialization in `fromJson`/`toJson` and `TypeAdapter` (field key `4`).
* **Bloc Event:** New `SettingsEvent.ShortcutChanged(String action, String keySequence)` handled in `SettingsBloc._onShortcutChanged` which merges the new mapping via `{...state.settings.shortcutMap, action: keySequence}` and persists via the repository.
* **Keyboard Mapping Hub:** A dedicated `_SettingsSection` block rendered last inside `SettingsWorkspace`, below the Localization card. Lists every system action with a label + recorder field. Tapping a recorder field captures the next physical key press (or key combo) and displays it; the change commits immediately via `ShortcutChanged`.
* **Persistence Model:** Same per-tab auto-save pattern as existing settings — no explicit save button. Changes flow through `SettingsBloc` → repository → HydratedBloc Hive layer.
* **New Localization Keys Added:** `shortcuts.title`, `shortcuts.confirmSale`, `shortcuts.searchOverlay`, `shortcuts.cartNavUp`, `shortcuts.cartNavDown`, `shortcuts.cartDelete`, `shortcuts.cartEditQty`, `shortcuts.quickTile1` through `shortcuts.quickTile8`, `shortcuts.recorderHint` — for the Keyboard Mapping Hub.

### 4. Module E: Keyboard Shortcuts & Navigation System

#### E1: Global Search & Scanner Overlay
* **QuickSearchOverlay:** A modal overlay rendered at the `AppShell` level (above all workspaces, within `BarcodeScannerGate` scope), initially offstage. Triggered by default key `F5` (or `/` / `Ctrl+F`). On open, a `TextField` auto-focuses for manual search input.
* **Scanner Integration:** While the overlay is open, the `BarcodeScannerGate` interceptor continues processing hardware scans. When a barcode is captured, the overlay field populates with the scanned value and runs an O(1) lookup in `InventoryBloc.inventoryMap`. If the product exists, a detail card is rendered inline within the overlay; if not, a "not found" message is shown.
* **Dismissal:** Pressing `Escape` or tapping the barrier outside the dialog closes the overlay and clears the search state.

#### E2: Guarded Checkout Actions
* **Triggers:** `F12` or `Spacebar` invokes checkout finalization (`ConfirmSale`).
* **Invariant Guard:** The shortcut controller checks `CartEntity.items.isNotEmpty` before dispatching. A business-level guard already exists in `CheckoutBloc._onConfirmSale`; the shortcut layer adds a UX-level guard to avoid dispatching with an empty cart.

#### E3: In-Cart Key Navigation & Manipulation Loop
* **Selection Focus:** Up/Down arrow keys shift `selectedItemIndex` in the checkout workspace. Selection wraps bidirectionally.
* **Delete:** `Delete` / `Del` key on a selected item dispatches `RemoveFromCart` for the selected barcode.
* **Edit Quantity:** `Enter` on a selected item activates the inline quantity `TextField` edit mode (same behaviour as tapping the quantity cell in `CartTableWidget`).

#### E4: Quick-Tiles Grid Hotkeys
* **Trigger Sequences:** `Alt + 1` through `Alt + 8` map to `InventoryBloc.quickTileList[index]` (0-indexed: `N-1`).
* **Execution:** On matching a tile index, dispatches `AddToCart` with the product's barcode, name, and price — identical to tapping the tile directly.

#### E5: Shortcut Resolution Layer
* **Default Bindings:** A static `Map<String, String>` of default action→key mappings (e.g., `confirmSale → "F12"`, `searchOverlay → "F5"`, `quickTile1 → "Alt+1"`, etc.).
* **User Override Merge:** At runtime, the controller computes `{...defaults, ...settings.shortcutMap}`. User-defined sequences completely replace the default for that action (full rebinding, not additive).
* **Dispatcher:** A centralized `ShortcutController` listens for raw key events at the root level, matches them against the resolved map, and dispatches the corresponding `Bloc` event (or overlay toggle). The controller does not render UI — it only coordinates key→action routing.

---