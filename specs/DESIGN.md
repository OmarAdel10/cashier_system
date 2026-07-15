# Design System & UI/UX Specification
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Visual Philosophy & Performance Constraints
To achieve a "premium" feel on potato desktop hardware (low-end CPUs, integrated graphics, 4GB RAM), the interface must abandon heavy GPU-intensive operations.
* **Banned Layout Properties:** Deep Gaussian blurs (`BackdropFilter`), nested overlapping opacity layers, heavy blurred drop shadows, and continuous loop decorative animations.
* **Design Aesthetic:** Flat, high-contrast, structural minimalism. Premium quality is achieved through **immaculate typography hierarchies, crisp sharp borders, perfect padding symmetry, and fast, snappy micro-interactions**.

### 2. Design Tokens (The Theme Matrix)

#### Color Palette
Designed for high legibility inside retail stores under harsh fluorescent lighting conditions:
* **Primary / Accent:** Deep Modern Blue (`#007ACC`) — for core action buttons and focus states.
* **Success / Cash:** Teal Green (`#10B981`) — exclusively for total amounts, payment triggers, and sales completions.
* **Background (Light Mode):** Warm Beige (`#F5F0EB`) with card containers set to (`#FFFDF5`).
* **Background (Dark Mode):** Charcoal/Slate (`#0F172A`) with card containers set to (`#1E293B`).
* **Borders / Dividers:** Warm Beige Grey (`#E8E0D8` for Light, `#334155` for Dark).

#### Typography & Localization Engine Rules (Dual Language RTL)
The system must render flawless Arabic (for store operations/items) and English text concurrently.
* **Directionality Rule:** When the active state sets language to Arabic, the root application wrapper executes a full layout inversion (`TextDirection.rtl`). The Side Nav Rail shifts cleanly to the right-hand window edge, and layout vectors mirror perfectly.
* **Primary Font Family:** `Cairo` (Local Font Asset under `fonts/Cairo/Cairo[slnt,wght].ttf`, SIL OFL v1.1) — chosen for its geometric design rendering cleanly across both English labels and complex Arabic script. Downloaded from Google Fonts and bundled as a local asset (no runtime Google Fonts dependency).
* **Heading Hierarchy:**
	* `HeadlineLarge` (Totals/Change): Bold, 32pt.
	* `heading2` (Section headers, totals): Bold, 24pt.
	* `heading3` (SectionCard notch titles, mid-level headings): SemiBold, 20pt.
	* `TitleMedium` (Product Names/Grid Tiles): SemiBold, 16pt.
	* `BodySmall` (Receipt details/Skus): Regular, 12pt.

### 3. Desktop Layout Geometry & Layout Grids

The application layout locks into a fixed, multi-pane structural layout to prevent excessive window resizing calculations.

```
┌─────────────────────────────────────────────────────────────┐
│  Side  │ Search Bar & Scanner Status Interceptor Indicator  │
│  Nav   ├──────────────────────────────┬──────────────────────┤
│  Rail  │                              │                      │
│        │                              │                      │
│  [🏠]  │                              │   Digital Receipt    │
│  [📦]  │    Dynamic Workspace View    │    Tower Panel       │
│  [📊]  │ (Switches between Checkout,  │    ────────────     │
│        │   Inventory, or Settings)    │  Items: 3  EGP 65.00│
│  [⚙️]  │                              │  (15%) -EGP 9.75    │
│Settings│                              │  +EGP 7.73 (14%)    │
│        │                              │  Total: EGP 62.98   │
│        │                              ├──────────────────────┤
│        │                              │  Cash Drawer        │
│        │                              │  [5][10][20][50]    │
│        │                              │  [100][200]  [C]    │
│        │                              │  Discount: [__]%    │
│        │                              │  [Confirm Sale]     │
└────────┴──────────────────────────────┴──────────────────────┘
```

#### Split Pane Spatial Ratios
* **Left Sidebar Rail (Right-Aligned in RTL mode):** Fixed Width `72px`. Houses core navigation icons (Checkout, Ingestion, Logs, Settings).
* **Center Workspace (100% Remaining Width on Settings, Inventory, and Sales History; 70% Remaining Width on Checkout):** Renders the active layout depending on navigation choice (Checkout Hub Grid, Stock Ingestion Interface, or the Store Configuration View). The Expanded flex token is 1 across every view; the 70/30 split on Checkout is achieved by the workspace sharing the Row with the fixed-width Tower Panel.
* **Side Tower Panel (30% Remaining Width, min-width 360px, Checkout-only):** Renders exclusively while the Checkout Hub is the active view. The panel and its preceding divider are removed from the Row entirely on every other view, leaving the Center Workspace to consume the full post-rail width.
* The AppShell wraps the Row in a `ValueListenableBuilder<int>` bound to the navigation index, so toggling views re-evaluates the full Row layout — including which children are inserted into the children list — without stale Expanded flex weights from the prior frame.
* **GlobalSearchOverlay:** Rendered as an `OverlayEntry` at the `GlobalShortcutGate` level, above all workspaces. It is mounted/removed via overlay entry lifecycle — not part of the Row layout. This ensures it appears above all panes including the side nav rail.

### 4. Interactive Component Specifications

#### Component A: The Inventory Workspace (Two-Column Layout)
* **Layout:** The `InventoryWorkspace` body is a `Row` with two `Expanded` children when no search is active. Left column displays non-quick-tile products ("Normal Products"), right column displays quick-tile products ("Quick Access"). Each column is a `_ProductColumn` wrapping cards in a `Container` with `theme.cardColor` background (automatically adapts to light/dark mode), `dividerColor` border, and `BorderRadius.circular(12)`.
* **Column inner layout:** Section title (`Text`, 16pt bold) → `Expanded` → `ListView.builder` of `_ProductCard` widgets. When a column has no items, a centered `"No items"` message is shown. When both columns are empty, the full `AppEmpty` state is displayed with the `package` icon.
* **Empty state:** `PhosphorIcons.package` Duotone (48px, grey.shade400) → headline → body copy → no action (the `+` FAB in the AppBar is the primary CTA).
* **Search mode:** When the search delegate is active, the workspace switches to a single full-width vertical `ListView` of matching products.
* **Product cards:** Each `_ProductCard` uses `Card` → `ListTile` layout. Leading: `PhosphorIcons.package` icon (within colored container for quick-tile items). Title: product name. Subtitle: formatted barcode + EGP price + stock via `product.card.subtitle` translation key with `{0}`/`{1}`/`{2}` param interpolation. Trailing: edit (`PhosphorIcons.pencil`) and delete (`PhosphorIcons.trash`) icon buttons.

#### Component B: Product Form Dialog
* **Trigger:** Tapping `+` (new product) or edit icon on a card (edit existing product).
* **Dialog type:** `AlertDialog` with `SingleChildScrollView` content, fixed width 360px.
* **Auto-generated barcode:** On new product, `_genBarcode()` produces a random 12-digit number (`Random().nextInt(9) + 1` for the first digit, 11 random 0-9 for the rest).
* **Live barcode preview:** `BarcodeWidget(barcode: Barcode.code128(), data: _barcodeCtrl.text)` rendered inside a white container with rounded border. Only visible when barcode input length ≥ 6 characters.
* **Fields:** Barcode (`TextInputType.number`, maxLength 12), Product Name, Price (`TextInputType.numberWithOptions(decimal: true)`), Stock (`TextInputType.number`). Each field has a Phosphor icon prefix.
* **Quick-tile switch:** `SwitchListTile` — toggling reveals an 8-color palette (`Wrap` of 36px circle `GestureDetector` widgets with white checkmark on selection). Colors: `['#007ACC', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6', '#EC4899', '#14B8A6', '#F97316']`.
* **Quick-tile guard:** The switch is hidden if `_currentQuickTileCount >= 10` (for new products or products not already quick-tiles). Existing quick-tile products always preserve the toggle.
* **Action buttons:** Cancel (`TextButton`) / Add or Update (`FilledButton`). On submit, returns a `ProductEntity` via `Navigator.pop`.

#### Component C: The Dynamic Quick-Tiles
* **Layout:** Grid system using a `Wrap` widget inside a `SectionCard` titled "Quick Items". Spacing: `Spacing.sm` for both spacing and runSpacing, `WrapAlignment.start`.
* **Tile Dimensions:** 100×100 logical pixels (increased from 72×72), with `BorderRadius.circular(Spacing.md)`.
* **Visual Rules:** Container cards use `tileColorHex` background with `withValues(alpha: 0.6)` semi-transparency. Text rendered in `TextStyles.heading2` with `FontWeight.w500` (increased from `caption`). Max 2 lines with ellipsis overflow.
* **Animation:** Tiles animate in using `TweenAnimationBuilder<double>` from `0.0` to `1.0` with `Opacity` + `Transform.scale` (fade + scale, 300ms, `Curves.easeOut`).
* **Interaction:** Tapping a tile invokes a `Material` ripple flash effect that triggers instantly, bypassing multi-frame bounce easing configurations. Maximum 10 quick-tile items.

#### Component D: SectionCard (Universal Card Container)
* **File:** `lib/core/widgets/section_card.dart`
* **Purpose:** The single canonical card wrapper for every workspace, replacing ad-hoc `AppBar` + `Container` combinations.
* **Parameters:** `title` (optional String), `actions` (optional List<Widget>), `child` (required Widget), `padding` (optional EdgeInsetsGeometry, defaults to `EdgeInsets.all(Spacing.md)`), `mainAxisSize` (defaults to `MainAxisSize.min`), `childFit` (defaults to `FlexFit.tight`).
* **Visual:** `Card` widget with `elevation: 1`, `BorderRadius.circular(12)`, `outlineVariant` border, `surfaceContainerLow` background, `margin: EdgeInsets.all(Spacing.sm)`.
* **Notch Title:** When `title` is provided, the card wraps its padding in a `Stack` with `PositionedDirectional` notch badge overlapping the top border (`top: -10`). The badge is a `Container` with `surface` semi-transparent background (`alpha: 0.8`), `outlineVariant` border, `BorderRadius.circular(Spacing.sm)`, horizontal `Spacing.sm` padding, containing the title `Text` (style: `TextStyles.heading3`) and optional action widgets.
* **Layout behavior:** When `title` is provided AND `mainAxisSize` is `MainAxisSize.max`, the child is wrapped in a `Flexible(fit: childFit, child: child)` to prevent unbounded height errors.
* **Usage:** Nav rail, inventory workspace, settings workspace, checkout cart table, tower panel receipt, tower panel cash drawer.

#### Component E: AnimatedCounter (Value Transition)
* **File:** `lib/core/widgets/animated_counter.dart`
* **Purpose:** Smooth text value transitions without GPU animations.
* **Behavior:** Wraps a `Text` widget in `AnimatedSwitcher` with `FadeTransition` (200ms duration). Uses `ValueKey(value)` on the Text to trigger transitions on value change. Accepts `style` and `textAlign` parameters.
* **Usage:** Quantity cells, price cells, total footer in cart table; item total, subtotal, discount, tax, total in tower panel.

#### Component F: Cart Table Widget
* **File:** `lib/features/checkout/presentation/widgets/cart_table_widget.dart`
* **Layout:** A `Table` widget with 4 columns defined by `_cartColumnWidths` constant (`FlexColumnWidth` ratios: 1, 4, 1.5, 2, 2 — 5th column reserved for total but unused). Headers: No., Name, Qty, Price (via localized keys `checkout.table.*`). Each header cell rendered in `TextStyles.title` bold, with `onSurfaceVariant` color.
* **Rows:** Each row is rendered inside `AnimatedList` with `SizeTransition` + `FadeTransition` (300ms). Insert: `insertItem` at new index. Remove: `removeItem` with the removed item's data for animation. `didUpdateWidget` detects changes by comparing lengths and barcode sets.
* **Quantity editing:** `ValueNotifier<bool>` tracks edit mode. Tap-to-edit opens an inline `TextField` with `FilteringTextInputFormatter.digitsOnly`, borderless decoration, and `IntrinsicWidth` wrapping. On submit or focus loss, edits only apply if `_hasTyped` flag is true (prevents spurious empty updates). Setting qty to 0 removes the item.
* **Row Selection:** A local `ValueNotifier<int> _selectedIndex` tracks which row is focused for keyboard navigation. The selected row renders with a distinct highlight state (accented background or border, matching the primary color `#007ACC`). `_editingIndex` tracks which row is in edit mode (-1 = none). Internal `Shortcuts` widget handles `arrowDown`/`arrowUp`/`delete`/`enter` for scoped key dispatch. `SelectNextCartItemIntent` increments `_selectedIndex`; `SelectPrevCartItemIntent` decrements it. Both clamp to valid range and wrap.
* **Footer:** A total row below the `Divider` using `Table` with the same column widths. Shows "Total" label (localized), total quantity via `AnimatedCounter`, and total amount via `AnimatedCounter`. The 5th column is commented out.
* **Focus trigger:** Accepts an optional `ValueNotifier<int>? cartFocusTrigger`. When incremented, requests focus on the cart widget (used after discount entry submission to return focus to the cart).

#### Component G: Cash Drawer Assistant (Redesigned)
* **File:** `lib/features/checkout/presentation/widgets/cash_drawer_assistant.dart`
* **Layout:** Inside the cash drawer section, organized top to bottom: (1) Amount due display with `AnimatedCounter`; (2) Paid amount display (if set); (3) Cash denomination buttons in two rows (5, 10, 20, 50 / 100, 200, Clear). Each button is an `Expanded` child in a `Row` with `Padding(Spacing.xs)` between items. Buttons animate in with `ScaleTransition`; (4) Change display (if paid and change > 0); (5) Discount row with label + TextField + error icon + amount display; (6) Confirm Sale button.
* **Cash buttons:** Denominations in piastres: 500, 1000, 2000, 5000, 10000, 20000. First row: 5, 10, 20, 50 EGP. Second row: 100, 200 EGP + Clear "C" button (red error color).
* **Discount field:** A `TextField` with `FilteringTextInputFormatter.digitsOnly`, hint `"0%"`. On every keystroke, `onChanged` parses the percent, clamps to 0-100, and dispatches `SetDiscount(percent.clamp(0, 100))` to `CheckoutBloc` in real-time. On `onSubmitted`, the field unfocuses and `cartFocusTrigger` is incremented to shift focus to the cart table. A warning icon (`Icons.warning_amber`) appears if the entered value exceeds 100, though the clamped value is still dispatched.
* **Discount focus trigger:** Accepts `ValueNotifier<int>? discountFocusTrigger`. When incremented, `_discountFocusNode.requestFocus()` is called and all existing text is selected.
* **Confirm button:** `ElevatedButton` with `clipBehavior: Clip.antiAlias`, vertical padding `Spacing.lg`, `RoundedRectangleBorder` with `Spacing.md` radius and primary border side. Enabled when `subtotal > 0` and status is NOT `confirmed`.
* **Display:** Shows the localized section title ("Cash Drawer"), subtotal in `heading1`, paid amount + change when applicable. All amounts formatted with locale-aware `PriceHelper.format(value, languageCode: langCode)`.

#### Component H: Checkout Confirmation Dialog (Dual-Mode)
* **File:** `lib/features/checkout/presentation/widgets/checkout_confirmation_dialog.dart`
* **Behavior:** A `StatefulWidget` with three phases: (1) **Optimistic loading** — shows `CircularProgressIndicator` + "Processing sale..." with no icon, `PopScope(canPop: false)`. (2) **Success** — `Icons.check_circle` (64px, green), "Sale Confirmed!" message, `PopScope(canPop: false)`, auto-dismiss via `Future.delayed(2s)`. (3) **Failure** — `Icons.error` (64px, red), failure reason detail, `PopScope(canPop: true)`, manual dismiss (close button or 5s timeout). Transitions from phase 1 to phase 2 or 3 based on `ReceiptsBloc` state.
* **Visual:** Transparent background `Dialog` with a styled `Container` (surface color, 16px radius, 32px padding). Large 64px icon with corresponding color, title-large message text. On failure, error detail shown below the message in body-medium red text.
* **Trigger:** `CheckoutWorkspace` listens for `CheckoutStatus.confirmed` and shows this dialog. After dialog pop (either path), `ClearCart` is dispatched. Dialog listens to `BlocListener<ReceiptsBloc>` for receipt creation result.

#### Component I: Tower Panel Restructure
* **File:** `lib/features/checkout/presentation/widgets/checkout_tower_panel.dart`
* **Layout:** Two `SectionCard` sections stacked vertically:
  1. **Receipt Section** (`mainAxisSize: MainAxisSize.max`): Order number (if present, shown as `#ORD-XXXXX`), centered header with optional store name (`heading2`), `receiptDuotone` icon + localized title (with `checkCircle` icon overlay when `status == confirmed`). Item list shows numbered entries (`1.`, `2.`, etc.) with `quantity × price` breakdown and line total. Footer shows item count (`Items: N`), subtotal via `AnimatedCounter`, discount line (if > 0, red text: `(X%) -EGP Y.YY`), tax line (if tax enabled and > 0, green text: `+EGP Y.YY (X%)`), and total via `AnimatedCounter` (bold). Receipt footnote at bottom.
  2. **Cash Drawer Section** (below, separated by `SizedBox(height: Spacing.sm)`): Title "Cash Drawer" with `CashDrawerAssistant` child.
* **Removed:** The old `New Sale` button and standalone `CashDrawerAssistant` placement. The "New Sale" reset is now handled by the auto-dismissing `CheckoutConfirmationDialog`.

#### Component J: Store Settings Workspace Components (9 Sections)
* **Layout Blocks:** Sectioned card layout using `Card` widgets with `_SettingsSection` wrapper, wrapped in a `SectionCard` notch title container (replacing previously used `AppBar`). Nine distinct sections stacked vertically in a `SingleChildScrollView`:
  1. **General Section:** `storeName` and `receiptFootnote` text input fields with character counters and localized hints.
  2. **Appearance Section:** Dark mode toggle `Switch` with live status indicator showing active/inactive state text.
  3. **Localization Section:** `SegmentedButton` for AR/EN language selection with directionality info banner showing `RTL` or `LTR` indicator.
  4. **Tax Section:** Enable/disable `SwitchListTile` ("Enable Tax"). Conditionally shown `_TaxPercentField` (digits-only, 300ms debounce, clamps 0-100, dispatches `TaxPercentChanged`).
  5. **Printing Section:** `SwitchListTile` for "Auto-print" with subtitle "Automatically print receipt after sale confirmation".
  6. **Keyboard Shortcuts Section:** Grouped action-to-key-binding mapping. See Component K below for full spec.
  7. **Reset All Data Section:** Subtitle text + red `ElevatedButton` triggering confirmation dialog, then clearing all Hive/HydratedBloc data.
* **Save Mechanism:** Per-tab auto-save — each user interaction immediately fires a `SettingsBloc` event. No explicit "Apply Changes" button. Changes persist to Hive via HydratedBloc automatically.
* **Text Inputs:** `TextField` widgets with `TextEditingController`, `onChanged` dispatches `StoreNameChanged` or `ReceiptFootnoteChanged` events to the bloc.
* **Design Token Integration:** All components consume `Spacing` constants (xs/sm/md/lg/xl/xxl) and `TextStyles` (heading1/heading2/title/body/bodySmall/caption) from `core/theme/`. Strings are fully localized via `LocalizationService.translate()`.

#### Component K: Keyboard Shortcuts Mapping Hub
* **Layout:** A `_SettingsSection` inside the settings workspace, below the Printing section. Contains 6 groups (Navigation, Search, Cash Drawer, Cart, Quick Tiles, Inventory), each with a group title.
* **`_ShortcutRow`:** Each action renders as a row with: (1) A localized label (e.g., "Open Search Overlay"); (2) Combo chips (`_ShortcutChip`) showing the display-friendly key combination (e.g., `Ctrl+D`, `F5`, `↑`); (3) An add button (`+` icon) that opens `KeyCaptureDialog`; (4) A reset button (recycle icon, shown only for custom/overridden bindings).
* **Visual distinction:** Custom (overridden) bindings render with a primary-colored border (`#007ACC`). Default bindings render with a plain outline (`outlineVariant`).
* **KeyCaptureDialog:** An `AlertDialog` with a `Focus` node that captures raw keyboard events. Shows a prompt "Press a key..." or the captured combo in a styled display box. Tracks modifier keys (Ctrl, Alt, Shift, Meta) via KeyDown/KeyUp and a non-modifier key. Bare Esc cancels. On confirm, pops with a combo string (e.g., `"ctrl+alt+f5"`). Cancel + Confirm (`FilledButton`) actions.

#### Component L: GlobalSearchOverlay
* **File:** `lib/features/shortcuts/presentation/widgets/global_search_overlay.dart`
* **Trigger:** Dispatched via `ToggleSearchOverlayIntent` → `GlobalShortcutGate._toggleSearchOverlay()` creates an `OverlayEntry`.
* **Visual:** Semi-transparent scrim (0.5 alpha, `colorScheme.scrim`). Centered 500px-wide `Material` card (elevation 24, rounded corners) containing:
  * **Search TextField:** Auto-focused on open, with search icon prefix, clear button suffix, localized hint text.
  * **Results List:** `ListView` of `ListTile` widgets showing product icon, name, barcode, and price. Tapping a result dispatches `AddToCart` and closes the overlay.
  * **`onSubmitted`:** If exactly one result matches, auto-selects it.
  * **Auto-close:** `Escape` key (via `Focus.onKeyEvent`) or tapping the scrim background calls `onClose`.
* **Scanner Integration:** Listens to `barcodeInjectionNotifier` for injected barcodes from `BarcodeScannerGate`. On injection, sets search text and performs lookup.

### 5. Iconography System Mandate — Phosphor Icons

The "premium" feel is achieved in part by rejecting the default Material and Cupertino icon sets in favor of **Phosphor Icons**, which carry a deliberate, structural weight that pairs with the Cairo typography.

#### 5.1 Forbidden Icon Sources
* **Material `Icons.*`** — banned in production UI. The filled and outlined glyphs are visually generic and clash with the high-contrast palette. The `material_icons` font asset that Flutter ships by default must not be referenced.
* **`cupertino_icons`** — banned. The package may remain in `pubspec.yaml` only as a transitive dependency, but no `CupertinoIcons.*` glyph may be instantiated in the codebase.
* **Phosphor `Thin` and `Light` variants** — banned. Sub-pixel rendering of these variants degrades on 4GB-RAM integrated-graphics Windows machines, producing shimmer on vector edges.

#### 5.2 Mandated Package and Variants
* **Package:** `phosphoricons_flutter: ^1.0.0` (the official Phosphor Icons Dart port). Adding the dependency to `pubspec.yaml` is tracked as a follow-up implementation task; the spec rule binds from the moment the dependency is added.
* **Primary variant — `Duotone`:** Used for the Side Nav Rail (`pointOfSale`, `package`, `chartBar`, `gear`), for Empty/Error state glyphs, and for any decorative or system-level icon. The two-tone treatment gives structural depth that approximates the visual richness of a `BackdropFilter` at zero GPU cost.
* **Secondary variant — `Bold`:** Reserved for dense grids and small control surfaces — Quick-Tiles, settings switches, segmented buttons, and any glyph rendered below 20 logical pixels — where the higher optical weight aids legibility on low-DPI Windows displays.
* **Reserved variants:** `Regular` is permitted as a neutral fallback for inline list icons where neither Duotone nor Bold is the right fit. `Fill` is permitted only for the active/selected state of a toggleable icon (the active Side Nav Rail item, for example).

#### 5.3 Directionality & Mirroring
* Phosphor's directional glyphs (chevrons, arrows, `caretLeft`/`caretRight`, `arrowLeft`/`arrowRight`) honor the ambient `Directionality` ancestor automatically. The codebase must rely on this built-in RTL behavior.
* **Manual `Transform.flip` on icons is forbidden.** Flipping an icon manually desynchronizes the icon's internal geometry from the typography baseline and breaks the premium alignment.
* Non-directional glyphs (objects, symbols, abstract marks) never mirror — they render identically in LTR and RTL.

### 6. Loading / Empty / Error State Contract

The three universal UI states — Loading, Empty, and Error — are first-class components with strict rules. Every screen in the app must use these components rather than ad-hoc inline states. The contract exists to keep render cost flat on low-end hardware and to keep the visual rhythm identical across features.

#### 6.1 General Rules (Apply to All Three States)
* **Spacing:** All padding and gaps use `Spacing` tokens from `core/theme/`. The allowed set is `xs` (4), `sm` (8), `md` (16), `lg` (24), `xl` (32), `xxl` (48). No hard-coded `EdgeInsets.all(16)`, no `SizedBox(height: 17)`. Tokens are the only source of truth.
* **Absolute Padding Symmetry:** All three state widgets use equal padding on all four sides — typically `EdgeInsets.symmetric(horizontal: Spacing.xl, vertical: Spacing.xl)`. Asymmetric padding (different top vs bottom, different left vs right) is forbidden; it breaks the centered rhythm in both LTR and RTL.
* **Directionality:** Each state widget relies on the root `MaterialApp`'s `locale` to set `Directionality`. The state's `Column` must use `MainAxisAlignment.center` and `CrossAxisAlignment.center` so the content mirrors correctly in RTL. Wrapping individual state widgets in a `Directionality` override is forbidden.
* **Typography Hierarchy (Cairo):**
	* State **icon** glyph size: 48 logical pixels (Duotone variant — Empty and Error states only; Loading state has no icon).
	* State **headline**: `TextStyles.heading2` — Cairo Bold, 24pt.
	* State **body message**: `TextStyles.body` — Cairo Regular, 14pt.
	* State **action label** (button text): `TextStyles.bodySmall` — Cairo SemiBold, 12pt. English labels render ALL CAPS; Arabic labels render in their natural case (the Cairo typeface's Arabic glyph set is already optimized for sentence-medial casing).
* **Localization:** All user-facing copy must come from the `LocalizationService` translation map under the `state.*` namespace — for example `state.loading.scanning`, `state.empty.cart`, `state.error.network`. Hard-coded English or Arabic strings inside a state widget are forbidden.
* **Container:** A state widget fills the available space of its parent and centers its content. It does not paint its own background — the parent surface (card, screen scaffold) is the background.

#### 6.2 Loading State
* **Banned:**
	* `CircularProgressIndicator` — a continuous spin loop is a perpetual GPU animation, and is the single largest source of frame drops on integrated-graphics Windows machines.
	* `LinearProgressIndicator` with a continuous `AnimationController` repaint, or any `ShaderMask`/gradient sweep effect.
	* Skeleton screens with `AnimationController` shimmer — banned for the same reason.
* **Mandated patterns (pick one based on duration):**
	* **Short operations (< ~400ms) — Typographic Only:** A single `TextStyles.body` line localized to the operation in progress, with no progress bar at all. Adding a flash of a bar that disappears within half a second is visual noise.
	* **Medium-to-long operations — Thin Hairline Bar:** A `LinearProgressIndicator` with `minHeight: 2` (a 2-pixel hairline), no associated `AnimationController` (Flutter's default indeterminate mode is acceptable), full width of the state container. The bar is the only affordance.
	* **Multi-step async flows (e.g., barcode generation, sale commit) — Step Indicator:** A discrete step indicator showing `1 / 3` → `2 / 3` → `3 / 3` as Cairo Bold `TextStyles.body` glyphs separated by a Phosphor `Bold` `dot` or `dash`. The step indicator is the preferred form whenever the operation has a known, finite set of stages.
* **No icon.** A Loading state never carries a Phosphor glyph — the typographic + bar combo is the entire composition.

#### 6.3 Empty State
* **Icon:** A single Phosphor **`Duotone`** glyph, 48 logical pixels, chosen semantically for the empty condition (`shoppingCart` for an empty cart, `package` for an empty inventory list, `funnel` for a filtered view that yielded no results). Glyph color: `Colors.grey.shade400` in light mode, `Colors.grey.shade600` in dark mode.
* **Composition:** Icon → headline → body copy → optional single primary action.
* **Vertical rhythm:** `Spacing.xl` (32) between icon and headline, `Spacing.sm` (8) between headline and body, `Spacing.lg` (24) between body and action button. The rhythm is identical in LTR and RTL because the underlying `Column` is centered.
* **Action button:** `TextButton` or `OutlinedButton` only — never `ElevatedButton` (visual weight belongs to the primary screen action, not the empty-state CTA). Label is localized under `state.empty.<feature>.action`.

#### 6.4 Error State
* **Icon:** A single Phosphor **`Duotone`** warning or alert glyph — `warningCircle` for recoverable errors (network blip, retry-able database failure), `xCircle` for terminal errors (corrupt settings file, unrecoverable parse error). Glyph size: 48 logical pixels.
* **Glyph color:** The Primary/Accent Deep Modern Blue `#007ACC` for recoverable errors (a calm, actionable tone that matches the existing focus state). The destructive token `#DC2626` (muted red) is permitted for terminal errors only. The codebase must not invent additional error colors.
* **Composition:** Icon → headline → body copy → single primary `ElevatedButton` action.
* **Action button:** `ElevatedButton` (not `TextButton`/`OutlinedButton`) — the error action is a primary screen-level recovery affordance. The label is localized under `state.error.<feature>.action` (for example `state.error.network.action = 'Try again'`). The button must dispatch a bloc retry event — a no-op label is forbidden.
* **Error message source rule:** The headline and body copy displayed to the user must originate from a `Failure` subclass surfaced by the repository (see `ARCHITECTURE.md` Section 6). The presentation layer must not display raw exception strings, raw `toString()` output, or any text that bypasses the `LocalizationService` lookup. A `DatabaseFailure` message becomes a localized "Could not save your changes" string; a `ValidationFailure` message becomes a localized field-specific hint; an `ItemNotFoundFailure` becomes a localized "Item not found" string with the barcode rendered from the `Failure` field, not from any captured exception.

---

### 7. Login Screen

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                                                             │
│                    ┌─────────────────────┐                  │
│                    │                     │                  │
│                    │    [Store Logo]      │                  │
│                    │    [Store Name]      │                  │
│                    │                     │                  │
│                    │  Username            │                  │
│                    │  [______________]    │                  │
│                    │                     │                  │
│                    │  Password            │                  │
│                    │  [______________]    │                  │
│                    │                     │                  │
│                    │  [ Login ]           │                  │
│                    │                     │                  │
│                    │  (error message)     │                  │
│                    └─────────────────────┘                  │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

* **Layout:** Full-screen centered `Column` with `MainAxisAlignment.center`. No nav rail, no header — only the login card.
* **Login Card:** `SectionCard` width 360px, no notch title. Contains store name/logo placeholder (icon + `heading2` text), two `ValidatedField` widgets (username, password), Login `ElevatedButton` (full-width, primary), and an optional error banner (`state.error != null` renders a red `Container` with localized error message + `xCircle` icon above the button).
* **Password Field:** `obscureText: true`, `suffixIcon: PhosphorIcons.eye` toggle for password visibility.
* **Loading State:** On `AuthLoading`, Login button shows a small `LinearProgressIndicator` (hairline 2px) above the button and the button becomes disabled.
* **Transition:** On success, `AuthBloc` emits `AuthAuthenticated` → `BlocBuilder` in `main.dart` swaps `LoginScreen` for `AppShell` with a cross-fade transition.

---

### 8. Nav Rail Updates (Role-Based + End Shift)

* **File:** `lib/presentation/app_shell.dart` (existing, rewritten nav logic)

```
NavRail (72px)
├── Column
│   ├── NavItem[0]   ← first destination from roleNavMap[user.role]
│   ├── NavItem[1]   ← second destination
│   ├── ...          ← (up to 4, depending on role)
│   ├── Spacer
│   └── NavItem(signOut)  ← End Shift (always present, bottom)
```

* **NavItem resolution:** The `_NavRail` receives a `List<NavDestination> allowedDestinations` and renders one `_NavRailItem` per destination. The active index is determined by `allowedDestinations.indexOf(_currentDestination)`.
* **End Shift Button:** `PhosphorIcons.signOut` Duotone icon + localized label `"End Shift"`. Tapping opens an `AlertDialog`: "Are you sure? Ending your shift will close this session and log you out." with Cancel / End Shift (`FilledButton` destructive/primary) actions.
* **End Shift State:** While `ShiftBloc` emits `ShiftLoading`, the End Shift button shows a small hairline indicator (2px `LinearProgressIndicator`) and becomes non-interactive.
* **Settings badge (admin):** For `admin` role, nav Settings item shows no badge (User Management is an internal Settings section, not a separate destination).

---

### 9. Settings: User Management Section

* **Location:** First `_SettingsSection` block inside `SettingsWorkspace`, rendered before General section. Only exists when `currentUser.role == admin`.
* **User List:** Each user renders as a `Card` inside the section with a popup menu (⋮) for actions:
  ```
  ┌──────────────────────────────────────────────┐
  │  [person icon]  admin              [admin] ⋮ │
  ├──────────────────────────────────────────────┤
  │  [person icon]  cashier1          [cashier] ⋮│
  ├──────────────────────────────────────────────┤
  │  [person icon]  cashier2          [cashier] ⋮│
  ├──────────────────────────────────────────────┤
  │                              [ + Add User ]   │
  └──────────────────────────────────────────────┘
  ```
* **Popup Menu Actions:** Change Password, Delete User (admin cannot delete self).
* **Add User Dialog:** `AlertDialog` with username (validated against `RegExp(r'^[a-zA-Z0-9_]{3,30}$')`), password (min 8 chars), role `SegmentedButton` (Admin / Cashier). Uses `BlocListener`: Navigator pops on success, inline error on failure. Cancel + Add buttons.
* **Change Password Dialog:** `AlertDialog` with current password (admin re-auth required — verified against stored PBKDF2 hash), new password (min 8), confirm new password. All fields required. Only admins can change other users' passwords. Uses `BlocListener`: success snackbar, error snackbar. Cancel + Change buttons.
* **Error States:** Inline error text below the relevant field on validation failure (duplicate username, short password, wrong current password). Inline snackbar on change-password failure.

---

### 10. Sales Workspace (Admin View)

* **File:** `lib/features/sales/presentation/views/sales_workspace.dart` (new)

```
SalesWorkspace
└── SectionCard(title: salesHistory, mainAxisSize: max)
    └── Column
        ├── TodaySummaryBar (non-scrollable, fixed top)
        │   └── Row of 3 summary cards
        │       ├── Receipts Count (icon + number)
        │       ├── Total Sales (EGP amount)
        │       └── Items Sold (count)
        ├── Divider
        └── Expanded → MonthBrowser
            └── ListView.builder of MonthCard
                ├── Month/year label + receipt count + total EGP
                └── onTap → expanded ReceiptListForMonth
                    └── ListView of ReceiptRow
                        ├── orderNumber · time · items count · total
                        └── onTap → ReceiptDetailDialog (read-only)
```

* **TodaySummaryBar:** Three `Card` widgets in a `Row`, each with a Phosphor icon (Duotone), title (`heading3`), and value (`heading1` with `AnimatedCounter`). Metrics computed by filtering `receipts` on `createdAt` where date == today. Updates in real-time when a new receipt is created.
* **MonthBrowser:** `ListView.builder` of `MonthCard` widgets. Each card shows month name + year, receipt count badge, total sales in EGP. Data from `ReceiptsRepository.getByMonth()`. Tapping expands the card (or navigates to a sub-view) showing individual receipt rows.
* **ReceiptRow:** Compact row: order number (`#ORD-00001`), time (HH:mm), items count (N items), total (EGP). Tapping opens a read-only `ReceiptDetailDialog` showing full receipt breakdown.
* **ReceiptDetailDialog:** `AlertDialog` with scrollable content showing: order number, store name, timestamp, itemized list (name × qty × unit price = line total), totals (subtotal, discount, tax, total), cashier username. No edit or delete actions.
* **Status Badge:** Each receipt row shows a colored badge (e.g., `Container` with rounded corners) indicating `ReceiptStatus`: green for `active`, amber for `modified`, red for `returned`. Badge text uses `labelSmall` with white text on colored background.
* **Refund Trigger Button:** In `ReceiptDetailDialog` footer, a "Return/Refund" button (red `TextButton` with `Icons.receipt_long`) visible only when `receipt.status == active`. Tapping opens the refund confirmation flow (Component L).
* **Modify Trigger Button:** A "Modify" `TextButton` with `Icons.edit` in `ReceiptDetailDialog` footer, visible when `receipt.status == active || receipt.status == modified`. Tapping opens the modification flow (Component L).

#### Component L: Refund & Modification Flow UI
* **File:** `lib/features/receipts/presentation/widgets/`
* **Refund Confirmation Dialog:** `AlertDialog` with scrollable content showing:
  - Receipt order number and date
  - Itemized list showing original quantities
  - Total amount to restore (formatted EGP)
  - "Confirm Refund" button (red `ElevatedButton`) and "Cancel"
  - On success: brief snackbar "Refund processed — EGP X.XX restored"
  - On `RefundLockFailure`: error dialog showing "This receipt has already been returned or modified." with the receipt ID and current status
* **Modification Dialog (Quantity Change):** Bottom sheet or dialog with:
  - Editable quantity fields per item (pre-filled with original quantities)
  - Delta preview showing quantity change (+/-) with color coding
  - Updated total preview (recalculated in real-time)
  - "Save Changes" `ElevatedButton` and "Cancel"
  - On success: snackbar "Receipt modified" + updated receipt reloads
  - On `RefundLockFailure`: same error dialog as refund
* **Status Machine Enforcement:** Both dialogs check `receipt.status` before showing. If `status != active`, the refund button is disabled/hidden. UI must never present refund/modify options on locked receipts.

---

### 11. Sales Workspace (Cashier View)

* Same file, different child based on `user.role`.
* **Content:** Static header "My Sales (This Shift)" in `heading2`. Below, a scrollable column of receipt cards showing all receipts from the current active shift. Each card: order number, total, timestamp (formatted). If no receipts yet, `AppEmpty` state with `receipt` icon and "No sales yet this shift" message.
* **Auto-refresh:** The cashier Sales workspace rebuilds when `ReceiptsBloc` emits a new receipt (the receipt list updates).
* **No month browsing, no summary bar.** Cashiers see only their current shift's receipts.

---

### 12. Active Shift Indicator

* **Location:** Bottom of the nav rail, above the End Shift button. Small label showing `Shift: #ORD-XXXXX` or `Active: username` (not a separate workspace element).
* **Visual:** `Text` in `bodySmall` style, `onSurfaceVariant` color, centered in the rail. Only visible when a shift is active.
* **No interactive function** — purely informational.

