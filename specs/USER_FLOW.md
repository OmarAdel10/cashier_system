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
	* Cashier triggers the "Confirm & Print Sale" action button.
	* **State Action 1:** The cart content maps to the `SalesHistoryBloc` as an immutable receipt snapshot ledger entry.
	* **State Action 2:** The `InventoryBloc` decrements stock values for all matching barcodes.
	* **State Action 3:** The active checkout cart clears entirely, and the global keyboard scanner listener resets focus for the next client.
	* 

### 3. Dynamic Quick-Tile Creation Flow
This dictates the synchronization loop between the back-office product management layer and the main checkout panel.

```
[ Inventory screen: Admin maps product details ]
                       │
                       ▼
    [ Toggle Switch: isQuickTile = True ]
                       │
                       ▼
           [ Select color theme hex ]
                       │
                       ▼
         [ Click Save Product button ]
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

### 4. Settings Modification & Structural Localization Flipping

1. **Navigation Trigger:**
   * The cashier or store owner clicks the `[⚙️]` configuration icon located on the root navigation bar rail.
   * The application interceptor replaces the active center workspace content view with the `SettingsWorkspace` interface module, while leaving the right-side receipt tower anchored.

2. **Parameter Interaction:**
   * The user toggles the primary language selection switch element from English (`EN`) to Arabic (`AR`).
   * The user modifies the `Store Name` text input value using the keyboard.

3. **State Mutation Dispatch:**
   * The user taps the high-contrast **"Apply Changes"** action button.
   * The UI layer instantly fires a configuration update event directly into the system's `SettingsBloc`.

4. **Reactive State Broadcast Updates:**
   * **Structural Inversion:** The root application framework immediately re-evaluates layout boundaries, transforming `Directionality.of(context)` references from `TextDirection.ltr` into native `TextDirection.rtl`.
   * **Visual Flipping:** The navigation rail dynamically mirrors to the right margin, text alignment scales shift rightward, and row items layout vectors invert completely.
   * **Dictionary Re-mapping:** The application's local $O(1)$ localization dictionary swaps its internal string reference matrices to evaluate against the newly activated Arabic key strings instantly.
   * **Asynchronous Persistence:** The `HydratedBLoC` state layer automatically triggers, flushing the serialized layout adjustments and new store name strings down to the local Hive disk block layer asynchronously.

---
