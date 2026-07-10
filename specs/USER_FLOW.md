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
	* Each time an item is added or its quantity is modified via the UI controls, the `CheckoutBloc` recalculates the subtotal, tax weights, and absolute total purely in Piastres. 
	* The UI updates fluidly with subtle micro-animations on total shifts.
	
2. **Change Calculation Interaction Loop:**
	* Total calculated equals `6500` Piastres (65.00 EGP). 
	* Cashier taps the quick-action cash card **[ 200 ج.م ]**.
	* The `CheckoutBloc` captures the event value (`20000` Piastres) and instantly emits a computational state alteration.
	* The visual screen panel immediately updates to display change in high-contrast text: `135.00 EGP` (`13500` Piastres). 
3. **Transaction Finalization:**
	* Cashier triggers the "Confirm Sale" action button (always enabled when cart has items, no cash amount entry required).
	* **State Action 1:** The `CheckoutBloc` emits `status: CheckoutStatus.confirmed`.
	* **State Action 2:** A confirmation dialog appears showing a success checkmark icon with the message "Sale Confirmed!".
	* **State Action 3:** After 2 seconds, the dialog auto-dismisses and the `ClearCart` event is dispatched, resetting the cart to empty with a new `transactionId`.
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
  [ Home Screen GridView dynamically re-draws tile ]
```

* ***Note:** Clicking the dynamically generated tile inside the checkout screen grid fires the exact same operational business logic as scanning a physical barcode, minimizing duplicate code configurations. 

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
