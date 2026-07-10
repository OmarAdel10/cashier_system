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
│  [📊]  │ (Switches between Checkout,  │                      │
│        │   Inventory, or Settings)    ├──────────────────────┤
│        │                              │  Interactive Cash    │
│  [⚙️]  │                              │  Drawer Assistant    │
│Settings│                              │  [10] [20] [50] [200]│
└────────┴──────────────────────────────┴──────────────────────┘
```

#### Split Pane Spatial Ratios
* **Left Sidebar Rail (Right-Aligned in RTL mode):** Fixed Width `72px`. Houses core navigation icons (Checkout, Ingestion, Logs, Settings).
* **Center Workspace (100% Remaining Width on Settings, Inventory, and Sales History; 70% Remaining Width on Checkout):** Renders the active layout depending on navigation choice (Checkout Hub Grid, Stock Ingestion Interface, or the Store Configuration View). The Expanded flex token is 1 across every view; the 70/30 split on Checkout is achieved by the workspace sharing the Row with the fixed-width Tower Panel.
* **Side Tower Panel (30% Remaining Width, min-width 360px, Checkout-only):** Renders exclusively while the Checkout Hub is the active view. The panel and its preceding divider are removed from the Row entirely on every other view, leaving the Center Workspace to consume the full post-rail width.
* The AppShell wraps the Row in a `ValueListenableBuilder<int>` bound to the navigation index, so toggling views re-evaluates the full Row layout — including which children are inserted into the children list — without stale Expanded flex weights from the prior frame.

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
* **Action buttons:** Cancel (`TextButton`) / Add or Update (`FilledButton`). On submit, returns a `ProductEntity` via `Navigator.pop`.

#### Component C: The Dynamic Quick-Tiles
* **Layout:** Grid system using a `Wrap` widget inside a `SectionCard` titled "Quick Items". Spacing: `Spacing.sm` for both spacing and runSpacing, `WrapAlignment.start`.
* **Tile Dimensions:** 100×100 logical pixels (increased from 72×72), with `BorderRadius.circular(Spacing.md)`.
* **Visual Rules:** Container cards use `tileColorHex` background with `withValues(alpha: 0.6)` semi-transparency. Text rendered in `TextStyles.heading2` with `FontWeight.w500` (increased from `caption`). Max 2 lines with ellipsis overflow.
* **Animation:** Tiles animate in using `TweenAnimationBuilder<double>` from `0.0` to `1.0` with `Opacity` + `Transform.scale` (fade + scale, 300ms, `Curves.easeOut`).
* **Interaction:** Tapping a tile invokes a `Material` ripple flash effect that triggers instantly, bypassing multi-frame bounce easing configurations.

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
* **Usage:** Quantity cells, price cells, total footer in cart table; item total and subtotal in tower panel.

#### Component F: Cart Table Widget
* **File:** `lib/features/checkout/presentation/widgets/cart_table_widget.dart`
* **Layout:** A `Table` widget with 4 columns defined by `_cartColumnWidths` constant (`FlexColumnWidth` ratios: 1, 4, 1.5, 2, 2 — 5th column reserved for total but unused). Headers: No., Name, Qty, Price (via localized keys `checkout.table.*`). Each header cell rendered in `TextStyles.title` bold, with `onSurfaceVariant` color.
* **Rows:** Each row is rendered inside `AnimatedList` with `SizeTransition` + `FadeTransition` (300ms). Insert: `insertItem` at new index. Remove: `removeItem` with the removed item's data for animation. `didUpdateWidget` detects changes by comparing lengths and barcode sets.
* **Quantity editing:** `ValueNotifier<bool>` tracks edit mode. Tap-to-edit opens an inline `TextField` with `FilteringTextInputFormatter.digitsOnly`, borderless decoration, and `IntrinsicWidth` wrapping. On submit or focus loss, edits only apply if `_hasTyped` flag is true (prevents spurious empty updates). Setting qty to 0 removes the item.
* **Footer:** A total row below the `Divider` using `Table` with the same column widths. Shows "Total" label (localized), total quantity via `AnimatedCounter`, and total amount via `AnimatedCounter`. The 5th column is commented out.

#### Component G: Cash Drawer Assistant (Redesigned)
* **File:** `lib/features/checkout/presentation/widgets/cash_drawer_assistant.dart`
* **Layout:** Two rows of cash buttons inside the cash drawer section. First row: 10, 20, 50, 100 EGP. Second row: 200 EGP + Clear "C" button (red error color). Each button is an `Expanded` child in a `Row` with `Padding(Spacing.xs)` between items.
* **Confirm button:** `ElevatedButton` with `clipBehavior: Clip.antiAlias`, vertical padding `Spacing.lg`, `RoundedRectangleBorder` with `Spacing.md` radius and primary border side. Enabled when `subtotal > 0` and status is NOT `confirmed`.
* **Display:** Shows the localized section title ("Cash Drawer"), subtotal in `heading1`, paid amount + change when applicable. All amounts formatted with locale-aware `PriceHelper.format(value, languageCode: langCode)`.

#### Component H: Checkout Confirmation Dialog
* **File:** `lib/features/checkout/presentation/widgets/checkout_confirmation_dialog.dart`
* **Behavior:** A `StatefulWidget` that auto-dismisses after 2 seconds. Wraps content in `PopScope(canPop: false)` to prevent accidental dismissal.
* **Visual:** Transparent background `Dialog` with a styled `Container` (surface color, 16px radius, 32px padding). Shows a large 64px icon (`Icons.check_circle` for success, `Icons.error` for failure) with primary/error color, and a title-large message below.
* **Trigger:** The `CheckoutWorkspace` listens for `CheckoutStatus.confirmed` and shows this dialog. After dialog pop, `ClearCart` is dispatched.

#### Component I: Tower Panel Restructure
* **File:** `lib/features/checkout/presentation/widgets/checkout_tower_panel.dart`
* **Layout:** Two `SectionCard` sections stacked vertically:
  1. **Receipt Section** (`mainAxisSize: MainAxisSize.max`): Centered header with optional store name (`heading2`), `receiptDuotone` icon + localized title. Item list shows numbered entries (`1.`, `2.`, etc.) with `quantity × price` breakdown. Footer shows item count (`Items: N`) and subtotal via `AnimatedCounter`. Receipt footnote at bottom.
  2. **Cash Drawer Section** (below, separated by `SizedBox(height: Spacing.sm)`): Title "Cash Drawer" with `CashDrawerAssistant` child.
* **Removed:** The old `New Sale` button and standalone `CashDrawerAssistant` placement. The "New Sale" reset is now handled by the auto-dismissing `CheckoutConfirmationDialog`.

#### Component B: Store Settings Workspace Components
* **Layout Blocks:** Sectioned card layout using `Card` widgets with `_SettingsSection` wrapper, wrapped in a `SectionCard` notch title container (replacing previously used `AppBar`). Three distinct sections stacked vertically in a `SingleChildScrollView`:
  * **General Section:** `storeName` and `receiptFootnote` text input fields with character counters and localized hints.
  * **Appearance Section:** Dark mode toggle `Switch` with live status indicator showing active/inactive state text.
  * **Localization Section:** `SegmentedButton` for AR/EN language selection with directionality info banner showing `RTL` or `LTR` indicator.
* **Save Mechanism:** Per-tab auto-save — each user interaction immediately fires a `SettingsBloc` event. No explicit "Apply Changes" button. Changes persist to Hive via HydratedBloc automatically.
* **Text Inputs:** `TextField` widgets with `TextEditingController`, `onChanged` dispatches `StoreNameChanged` or `ReceiptFootnoteChanged` events to the bloc.
* **Design Token Integration:** All components consume `Spacing` constants (xs/sm/md/lg/xl/xxl) and `TextStyles` (heading1/heading2/title/body/bodySmall/caption) from `core/theme/`. Strings are fully localized via `LocalizationService.translate()`.

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