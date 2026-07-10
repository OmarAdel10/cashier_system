# User Flows & State Transitions
## Project: Premium Stationery POS System (المكتبة) - MVP

### 1. Global Keyboard Scanner Interceptor Flow
This flow ensures that hardware barcode scanner events are reliably captured anywhere in the window without requiring the cashier to manually click or focus on an input box.

```
[ Hardware Scan Event Triggered ]
               │
               ▼
   [ Root Keyboard Interceptor ]
               │
     Is typing speed < 20ms?
               ├──► NO  ──► Pass characters to currently focused input field
               │
               └──► YES ──► Buffer characters until [Enter] key is hit
                                       │
                                       ▼
                         [ Fire ScanBarcodeUseCase ]
                                       │
                                       ▼
                       Look up barcode in Inventory Map
                                       │
                ┌──────────────────────┴──────────────────────┐
                ▼                                             ▼
          [ Found Entry ]                              [ Entry Not Found ]
                │                                             │
                ▼                                             ▼
   Add/Increment item in Cart                     Trigger visual error toast
   
   
```

### 2. Cart Processing & Cash Drawer Assistant Flow
This flow details the sequence of a standard checkout transaction from item calculations down to currency change extraction.
1. **Cart Calculation State:**
	* Each time an item is added or its quantity is modified via the inline table cells (tap-to-edit, `ValueNotifier<bool>` edit mode, `FilteringTextInputFormatter.digitsOnly`), the `CheckoutBloc` recalculates the subtotal and total purely in Piastres.
	* Cart items render in a 4-column `Table` (No., Name, Qty, Price) inside a `SectionCard` with `AnimatedList` for insert/remove animations (300ms `SizeTransition` + `FadeTransition`).
	* The UI updates fluidly with `AnimatedCounter` transitions on quantity and price cells, and a total footer row showing item count + subtotal.

2. **Change Calculation Interaction Loop:**
	* Total calculated equals `6500` Piastres (65.00 EGP). 
	* Cashier taps a cash button from the 2-row grid layout placed in the lower `SectionCard` of the tower panel:
	  * First row: **[10]** **[20]** **[50]** **[100]** ج.م
	  * Second row: **[200]** ج.م + **[C]** (clear, red color)
	* The `CheckoutBloc` captures the event value (`20000` Piastres) and instantly emits a computational state alteration.
	* The visual screen panel immediately updates to display paid amount and change in high-contrast text: `135.00 EGP` (`13500` Piastres). All amounts use locale-aware `PriceHelper.format()` with `languageCode` parameter.

3. **Transaction Finalization:**
	* Cashier triggers the "Confirm Sale" `ElevatedButton` (styled with `RoundedRectangleBorder`, `Spacing.lg` vertical padding, always enabled when cart has items, no cash amount entry required).
	* **State Action 1:** The `CheckoutBloc` emits `status: CheckoutStatus.confirmed`.
	* **State Action 2:** A `CheckoutConfirmationDialog` appears (wrapped in `PopScope(canPop: false)`) showing a large success checkmark icon with the message "Sale Confirmed!".
	* **State Action 3:** After 2 seconds, the dialog auto-dismisses and the `ClearCart` event is dispatched, resetting the cart to empty with a fresh `CartEntity.create()`.
	* No manual "New Sale" button is required — the flow is fully automatic.
	* 

### 3. Inventory Management & Barcode Creation Flow
This dictates the full product lifecycle from creation through display in the two-column inventory workspace.

```
[ App starts → InventoryBloc dispatches LoadInventory ]
                       │
                       ▼
     [ InventoryWorkspace renders based on status ]
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
   [ Loading state ]          [ Ready state ]
    (LinearProgressIndicator)      │
                                   ├── products.isEmpty → Empty state (package icon + text)
                                   │
                                   └── products exist → Two-column layout
                                        ├── Left: "Normal Products" (isQuickTile == false)
                                        └── Right: "Quick Access" (isQuickTile == true)
                                             └── Each column: bordered surface container
                                                  └── ListView of _ProductCard widgets
                                                        ├── Leading: PhosphorIcons.package
                                                        ├── Title: product name
                                                        ├── Subtitle: barcode • EGP price • stock
                                                        └── Trailing: edit + delete buttons
```

#### 3a. Add / Edit Product Flow
```
[ Tap "+" in AppBar → ProductFormDialog ]
                       │
                       ▼
     [ Auto-generated 12-digit barcode ]
                       │
                       ▼
     [ User fills: barcode, name, price, stock ]
                       │
                       ▼
     [ Optionally toggles isQuickTile ]
                       │
                       ▼
     [ 8-color palette appears when toggled ]
                       │
                       ▼
     [ Live BarcodeWidget preview (≥6 chars) ]
                       │
                       ▼
     [ Tap "Add" → InventoryBloc.AddProduct → saved to Hive ]
                       │
                       ▼
     [ UI rebuilds: product appears in correct column ]
```

#### 3b. Quick-Tile Display on Checkout Screen
```
[ Inventory screen: Admin toggles isQuickTile + picks color ]
                        │
                        ▼
    [ HydratedBLoC serializes update to local disk ]
                        │
                        ▼
   [ System broadcasts reactive state modification ]
                        │
                        ▼
   [ QuickTilesGrid (wrapped in SectionCard "Quick Items") rebuilds ]
                        │
                        ▼
   [ Each tile animates in with fade + scale (TweenAnimationBuilder, 300ms) ]
                        │
                        ▼
   [ 100×100 tiles render with semi-transparent color (alpha 0.6), heading2 font ]
```

* **Note:** Clicking a tile fires the exact same operational business logic as scanning a physical barcode. Tiles now appear inside a `SectionCard` titled "Quick Items" with a `Wrap` layout, positioned below the cart section (or as the sole content when the cart is empty, alongside an `AppEmpty` state above).

#### 3c. Product Deletion Flow
```
[ Tap trash icon on a product card ]
                       │
                       ▼
   [ Confirmation dialog: "Delete [product name]?" ]
                       │
                       ▼
   [ Confirm → InventoryBloc.DeleteProduct(barcode) ]
                       │
                       ▼
   [ Product removed from Hive box → UI rebuilds ]
```

### 4. Settings Modification & Structural Localization Flipping

1. **Navigation Trigger:**
   * The cashier or store owner clicks the `[⚙️]` configuration icon located on the root navigation bar rail.
   * The application interceptor replaces the active center workspace content view with the `SettingsWorkspace` interface module, while leaving the right-side receipt tower anchored.

2. **Parameter Interaction (Per-Tab Auto-Save):**
   * The SettingsWorkspace renders three stacked card sections: General, Appearance, and Localization.
   * **General Section:** The user modifies `Store Name` or `Receipt Footnote` text input values using the keyboard. Each keystroke fires a `StoreNameChanged` or `ReceiptFootnoteChanged` event to the `SettingsBloc`.
   * **Appearance Section:** The user toggles the Dark Mode `Switch`. The switch immediately fires a `ThemeToggled` event. A status label updates in real-time ("Dark Mode Active" / "Light Mode Active").
   * **Localization Section:** The user selects a language via `SegmentedButton` (`EN` / `AR`). The selection immediately fires a `LanguageToggled` event. A directionality info banner updates to show `RTL` or `LTR` accordingly.

3. **State Mutation Dispatch (Per-Tab Auto-Save):**
   * No explicit **"Apply Changes"** action button exists. Each user interaction instantly fires a configuration update event directly into the system's `SettingsBloc`.
   * The `SettingsBloc` processes the event, produces a new `SettingsState` with the updated `AppSettingsEntity`, and the UI rebuilds immediately via `BlocBuilder`.
   * The `HydratedBloc.fromJson`/`toJson` serialization automatically persists the new state to the local Hive disk layer.

4. **Reactive State Broadcast Updates:**
   * **Structural Inversion:** The root application framework immediately re-evaluates layout boundaries, transforming `Directionality.of(context)` references from `TextDirection.ltr` into native `TextDirection.rtl`.
   * **Visual Flipping:** The navigation rail dynamically mirrors to the right margin, text alignment scales shift rightward, and row items layout vectors invert completely.
   * **Dictionary Re-mapping:** The application's `LocalizationService` O(1) localization dictionary swaps its internal string reference matrices to evaluate against the newly activated Arabic key strings instantly.
   * **Asynchronous Persistence:** The `HydratedBLoC` state layer automatically triggers, flushing the serialized layout adjustments and new store name strings down to the local Hive disk block layer asynchronously.

---

### 5. Global Search & Scanner Overlay Flow
This flow describes the global search dialog that can be summoned from anywhere in the application.

```
[ F5 / '/' / Ctrl+F triggered (from anywhere) ]
                        │
                        ▼
            [ QuickSearchOverlay opens ]
                        │
                        ▼
            [ TextField auto-focuses ]
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
  [ Cashier types manually ]   [ Scanner captures barcode ]
          │                           │
          ▼                           ▼
          └──────────┬────────────────┘
                     ▼
    O(1) lookup in InventoryBloc.inventoryMap
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
   [ Product found ]      [ Not found ]
          │                     │
          ▼                     ▼
  Show product detail     Show "not found"
  card inside overlay     inline message
          │                     │
          └──────────┬──────────┘
                     ▼
     [ Escape or tap-barrier closes overlay ]
```

### 6. In-Cart Key Navigation & Manipulation Loop
This flow describes keyboard-driven cart item selection and manipulation in the checkout workspace.

```
[ Up / Down Arrow pressed (cart.items.isNotEmpty) ]
                        │
                        ▼
          [ selectedItemIndex shifts +/- 1 ]
                        │
                        ▼
         [ Selection wraps (0 → n-1 → 0) ]
                        │
                        ▼
   [ CartTableWidget highlights row at selectedIndex ]
                        │
          ┌─────────────┴──────────────┐
          │                            │
          ▼                            ▼
   [ Delete/Del pressed ]      [ Enter pressed ]
          │                            │
          ▼                            │
   RemoveFromCart                      │
   (selected barcode)                  │
                                       ▼
                        Activate inline quantity
                        TextField edit mode on
                        selected row (same as tap)
```

### 7. Quick-Tiles Grid Hotkeys
This flow describes the keyboard activation of quick-tile items from the checkout screen.

```
[ Alt + N pressed (1 ≤ N ≤ 8) ]
                        │
                        ▼
              index = N - 1
                        │
                        ▼
    product = InventoryBloc.quickTileList[index]
                        │
              ┌─────────┴──────────┐
              ▼                    ▼
         [ exists ]          [ null / OOB ]
              │                    │
              ▼                    ▼
         AddToCart              (no-op)
         (product barcode,
          name, price)
```

### 8. Customizable Shortcut Settings Flow
This flow describes how a cashier customizes keyboard shortcuts in the settings workspace.

1. **Navigation Trigger:**
   * The cashier opens the Settings workspace and scrolls to the "Keyboard Mapping Hub" section card, rendered below the Localization card.

2. **Parameter Interaction:**
   * The Keyboard Mapping Hub lists each system action as a row with an action label (localized) and a recorder input field.
   * The cashier taps a recorder field. The field enters recording mode (visual indicator changes, e.g., border highlight or placeholder text "Press a key...").
   * The cashier presses a physical key or key combination (e.g., `F5`, `Ctrl+Shift+S`). The recorder captures the combo and displays it in the field.

3. **State Mutation Dispatch:**
   * Immediately upon capturing the key, a `ShortcutChanged(action, keySequence)` event fires into `SettingsBloc`.
   * The bloc merges the mapping into `AppSettingsEntity.shortcutMap` and emits a new state.
   * `HydratedBloc.fromJson`/`toJson` automatically persists the updated map to the local Hive disk layer.

4. **Reactive Resolution Update:**
   * The `ShortcutController` recomputes its resolved map: `{...defaults, ...settings.shortcutMap}`.
   * If the user rebound a default action, the user's key sequence fully replaces the default (no fallback).
   * The new binding takes effect immediately — no restart or workspace reload required.

---


