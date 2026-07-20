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
	  * First row: **[5]** **[10]** **[20]** **[50]** ج.م
	  * Second row: **[100]** **[200]** ج.م + **[C]** (clear, red color)
	* The `CheckoutBloc` captures the event value (`20000` Piastres) and instantly emits a computational state alteration.
	* The visual screen panel immediately updates to display paid amount and change in high-contrast text: `135.00 EGP` (`13500` Piastres). All amounts use locale-aware `PriceHelper.format()` with `languageCode` parameter.

3. **Transaction Finalization & Order Numbering:**
	* Cashier triggers the "Confirm Sale" `ElevatedButton` (styled with `RoundedRectangleBorder`, `Spacing.lg` vertical padding, always enabled when cart has items, no cash amount entry required).
	* **State Action 1:** The `generateOrderNumber` callback is invoked: it reads `SettingsBloc` state, compares `lastOrderDate` to today, increments `orderCounter` (or resets to 1 if date changed), dispatches `UpdateOrderCounter`, and returns `ORD-XXXXX`.
	* **State Action 2:** The `CheckoutBloc` emits `status: CheckoutStatus.confirmed` and `orderNumber: "ORD-00001"`.
	* **State Action 3:** A `CheckoutConfirmationDialog` appears (wrapped in `PopScope(canPop: false)`) showing a large success checkmark icon with the message "Sale Confirmed!".
	* **State Action 4:** After 2 seconds, the dialog auto-dismisses and the `ClearCart` event is dispatched, resetting the cart to empty with a fresh `CartEntity.create()`.
	* No manual "New Sale" button is required — the flow is fully automatic.

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
       [ User fills: barcode, name, price, stock, notes (optional) ]
                       │
                       ▼
      [ Optionally toggles isQuickTile (hidden if count >= 10) ]
                       │
                       ▼
      [ 8-color palette appears when toggled ]
                       │
                       ▼
       [ Live BarcodeWidget preview (≥6 chars) ]
                        │
                        ▼
       [ "Save Barcode" button (below preview) ]
                        │
               ┌────────┴────────┐
               ▼                 ▼
       [ Path set ]        [ Path empty ]
               │                 │
               ▼                 ▼
   [ Pick download dir    [ Show prompt:
     via file_picker ]      "Set path in
               │            Settings first" ]
               ▼                 │
   [ BarcodeLabelTemplate        │
     → RepaintBoundary.toImage() │
     → save as PNG ]             │
               │                 │
               ▼                 │
   [ Snackbar: success      ┌────┘
     (file path) or
     failure (error msg) ]
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

* **Note:** Clicking a tile fires the exact same operational business logic as scanning a physical barcode. Tiles now appear inside a `SectionCard` titled "Quick Items" with a `Wrap` layout, positioned below the cart section (or as the sole content when the cart is empty, alongside an `AppEmpty` state above). Maximum 10 quick-tile items.

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
   * The SettingsWorkspace renders ten stacked card sections: General, Appearance, Localization, Tax, Printing, Barcode Download Path, Keyboard Shortcuts (6 groups), and Reset All Data.
   * **General Section:** The user modifies `Store Name` or `Receipt Footnote` text input values using the keyboard. Each keystroke fires a `StoreNameChanged` or `ReceiptFootnoteChanged` event to the `SettingsBloc`.
   * **Appearance Section:** The user toggles the Dark Mode `Switch`. The switch immediately fires a `ThemeToggled` event. A status label updates in real-time ("Dark Mode Active" / "Light Mode Active").
   * **Localization Section:** The user selects a language via `SegmentedButton` (`EN` / `AR`). The selection immediately fires a `LanguageToggled` event. A directionality info banner updates to show `RTL` or `LTR` accordingly.
   * **Tax Section:** The user toggles tax on/off via `SwitchListTile`. The tax rate `TextField` appears conditionally when tax is enabled. Input is digits-only with 300ms debounce, clamped to 0-100. Dispatches `TaxToggled` and `TaxPercentChanged`.
   * **Printing Section:** The user toggles "Auto-print" via `SwitchListTile`. Dispatches `AutoPrintToggled`. The setting is stored but print execution is not yet wired.
   * **Barcode Download Path Section:** The user taps "Choose Folder" `FilledButton.tonalIcon`. A native directory picker opens via `file_picker`. The selected path dispatches `SetBarcodeDownloadPath(path)` to `SettingsBloc`. The path displays immediately; if unset, shows localized "Not set" in grey.
   * **Keyboard Shortcuts Section:** See Section 8 below.
   * **Reset All Data Section:** See Section 11 below.

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

---

### 6. In-Cart Key Navigation & Manipulation Loop
This flow describes keyboard-driven cart item selection and manipulation in the checkout workspace.

```
[ Up / Down Arrow pressed (cart.items.isNotEmpty) ]
                        │
                        ▼
       [ Local _selectedIndex shifts +/- 1 ]
          (ValueNotifier<int> in CartTableWidget,
           NOT in CheckoutState)
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
                        (Enter again commits edit)
```

---

### 7. Quick-Tiles Grid Hotkeys
This flow describes the keyboard activation of quick-tile items from the checkout screen.

```
[ Alt + N pressed (1 ≤ N ≤ 10) ]
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

---

### 8. Customizable Shortcut Settings Flow
This flow describes how a cashier customizes keyboard shortcuts in the settings workspace.

1. **Navigation Trigger:**
   * The cashier opens the Settings workspace and scrolls to the "Keyboard Shortcuts" section card, rendered below the Printing section.

2. **Parameter Interaction:**
   * The Keyboard Shortcuts section lists 6 groups of actions (Navigation, Search, Cash Drawer, Cart, Quick Tiles, Inventory). Each action appears as a row with a localized label, combo chips showing current key bindings, and add/remove/reset controls.
   * Custom (user-overridden) bindings display with a primary-colored border; default bindings have a plain outline.
   * The cashier taps the "+" icon on an action row. A `KeyCaptureDialog` opens with focus capture. The cashier presses a physical key or key combination (e.g., `Ctrl+Shift+S`). The dialog displays the captured combo and the cashier taps "Confirm".
   * The dialog pops with a key combo string (e.g., `"ctrl+shift+s"`). The settings workspace immediately dispatches `AddCustomBinding(actionToken, combo)` to `SettingsBloc`.

3. **Conflict Resolution & State Mutation:**
   * Upon `AddCustomBinding`, the `SettingsBloc` scans all other actions: if any other action already uses the same key combo, that combo is removed from the other action (the new binding wins). This is a last-assignment-wins model.
   * The bloc stores ONLY the custom overrides (not the full map) in `customBindings: Map<String, List<String>>`. The `GlobalShortcutGate` merges `{...defaults, ...customBindings}` at runtime.
   * `HydratedBloc.fromJson`/`toJson` automatically persists the updated map to the local Hive disk layer.

4. **Reactive Resolution Update:**
   * The `GlobalShortcutGate` rebuilds its `ShortcutActivator`→`Intent` map when the `SettingsBloc` state changes.
   * If the user rebound a default action, the user's key sequence fully replaces the default (no fallback, no additive).
   * The new binding takes effect immediately — no restart or workspace reload required.

5. **Revert to Default:**
   * The cashier taps the reset (recycle) icon on a custom binding row. `ResetCustomBinding(actionToken)` is dispatched, removing the action entirely from `customBindings`. The action reverts to its default bindings.

---

### 9. Discount Entry Flow
This flow describes how a cashier applies a percentage discount to the entire cart.

```
[ Ctrl+D pressed (or tap on discount TextField) ]
                        │
                        ▼
   [ FocusDiscountIntent increments discountFocusTrigger ]
                        │
                        ▼
   [ CashDrawerAssistant._onDiscountFocusTrigger() ]
   [ _discountFocusNode.requestFocus() + select all text ]
                        │
                        ▼
   [ Cashier types discount percent (digits only) ]
                        │
                        ▼
   [ onChanged: parses percent, clamps to 0-100 ]
                        │
                        ▼
   [ Dispatch SetDiscount(clampedPercent) to CheckoutBloc ]
                        │
                        ▼
   [ CheckoutState recomputes: ]
   [ discountAmount = subtotal * percent / 100 ]
   [ afterDiscount = subtotal - discountAmount ]
   [ taxAmount = afterDiscount * taxPercent / 100 ]
   [ total = afterDiscount + taxAmount ]
                        │
                        ▼
   [ Tower panel updates: shows "(X%) -EGP Y.YY" in red ]
   [ + updated total. Cash Drawer clears amountPaid. ]
                        │
                        ▼
   [ Cashier presses Enter or taps away ]
   [ → discount field unfocuses ]
   [ → cartFocusTrigger incremented → cart refocused ]
```

---

### 10. Order Number Generation Flow
This flow describes the auto-generation of sequential order numbers on sale confirmation.

```
[ Cashier taps Confirm Sale (F12 / Space) ]
                        │
                        ▼
   [ CheckoutBloc._onConfirmSale ]
   [ Guard: cart not null, not empty, _confirmInProgress false ]
                        │
                        ▼
   [ generateOrderNumber!() callback called ]
                        │
                        ▼
   [ Read SettingsBloc state: lastOrderDate, orderCounter ]
                        │
           ┌────────────┴────────────┐
           ▼                         ▼
   [ lastOrderDate == today ]  [ lastOrderDate != today ]
           │                         │
           ▼                         ▼
   counter = orderCounter + 1  counter = 1
           │                         │
           └──────────┬──────────────┘
                      ▼
   [ Dispatch UpdateOrderCounter(counter, today) to SettingsBloc ]
                      ▼
   [ Return "ORD-${counter.padLeft(5, '0')}" ]
                      ▼
   [ Emit CheckoutStatus.confirmed, orderNumber: "ORD-00001" ]
                      ▼
   [ Tower panel displays "#ORD-00001" above store name ]
                      ▼
   [ Confirmation dialog → auto-dismiss → ClearCart ]
```

---

### 11. Reset All Data Flow
This flow describes the destructive reset of all application data.

```
[ User taps "Reset All Data" button in settings ]
                        │
                        ▼
   [ Confirmation AlertDialog appears ]
   [ Title: "Are you sure?" ]
   [ Body: "This will delete all data. This action cannot be undone." ]
                        │
           ┌────────────┴────────────┐
           ▼                         ▼
   [ Cancel ]                  [ Reset (red) ]
           │                         │
        (close)                      ▼
           │            [ Hive.box('settings').clear() ]
           │            [ Hive.box('inventory').clear() ]
           │            [ HydratedBloc.storage.clear() ]
           │                         │
           │                         ▼
           │            [ Dispatch LoadSettings() ]
           │            [ Dispatch LoadInventory() ]
           │                         │
           │                         ▼
           │            [ App resets to factory defaults ]
           │            [ settings: defaults, inventory: empty ]
           │                         │
           └─────────────────────────┘
```

---

### 12. Cash Drawer Amount Keyboard Shortcuts Flow
This flow describes the optional user-configured keyboard shortcuts for cash denomination selection.

```
[ User-configured key combo pressed (e.g., user-bound Alt+5 for 5EG) ]
                        │
                        ▼
   [ SetAmountPaid5EGIntent → GlobalShortcutGate CallbackAction ]
                        │
                        ▼
   [ Read CheckoutBloc.state.amountPaidPiastres (nullable) ]
                        │
                        ▼
   [ Compute newAmount = (current ?? 0) + 500 (piastres) ]
                        │
                        ▼
   [ Dispatch SetAmountPaid(newAmount) to CheckoutBloc ]
                        │
                        ▼
   [ Cash Drawer Assistant rebuilds ]
   [ Shows "Paid: X.XX EGP", updates change display ]

[ Clear shortcut: dispatches ClearAmountPaid → sets amountPaid to null ]
```

---

### 13. Authentication & Login Flow

```
[ App starts → AuthBloc.CheckAuth dispatched ]
                        │
                        ▼
          [ AuthBloc emits AuthLoading ]
                        │
                        ▼
       [ AuthRepository.getAll() called ]
                        │
                        ▼
  [ Check __seeded__ marker key in Hive box ]
              ┌────────┴────────┐
              ▼                 ▼
        [ Key absent ]      [ Key present ]
              │                 │
              ▼                 ▼
   [ Seed 3 users created ]  [ Return existing ]
   [ admin/admin (admin)   ] [ users from Hive ]
   [ cashier1/cashier1     ]   │
   [ cashier2/cashier2     ]   │
   [ All with mustChange=│  │
   [   Password: true    ]  │
   [ Set __seeded__ key  ]  │
              │                 │
              └────────┬────────┘
                       ▼
           [ AuthBloc emits AuthUnauthenticated ]
                       │
                       ▼
              [ LoginScreen renders ]
                       │
                       ▼
           [ User enters credentials ]
                       │
                       ▼
        [ LoginRequested(username, password) ]
                       │
                       ▼
   [ Rate limiting check: _failedAttempts ]
        ┌────────────┴────────────┐
        ▼                         ▼
   [ < 3 failures ]          [ ≥ 3 failures ]
        │                     [ lockout = failed * 2s ]
        │                     [ Emit AuthUnauthenticated ]
        │                     [ error: invalidCredentials ]
        │                         │
        ▼                         ▼
   [ passwordHash = PBKDF2(      [ Return to login ]
   [   password, storedSalt,     │
   [   100k iterations) ]        │
        │                        │
        ▼                        │
   [ Lookup user in AuthRepository by username ]
        ┌────────┴────────┐        │
        ▼                 ▼        │
   [ Found ]          [ Not found ]│
        │                 │        │
        ▼                 ▼        │
   [ Compare hash ]     [ _failed+1] │
   ┌────┴────┐          [ error ]    │
   ▼         ▼              │        │
[ Match ] [ No match ]──────┘────────┘
   │         │
   ▼         ▼
[ Reset    [ _failedAttempts++ ]
[ _failed  [ Emit AuthUnauthenticated ]
[ = 0 ]   [ error: invalidCredentials ]
   │
   ▼
[ Check mustChangePassword ]
   ┌────┴────┐
   ▼         ▼
[ true ]  [ false ]
   │         │
   ▼         ▼
[ Show      [ Emit AuthAuthenticated(user) ]
[ Change    [ BlocBuilder swaps → AppShell ]
[ Password    │
[ dialog ]    │
   │          │
   ▼          ▼
[ AuthBloc emits AuthAuthenticated(user) after
  password changed ]
        │
        ▼
[ BlocBuilder swaps LoginScreen → AppShell ]
```

### 14. Shift Lifecycle Flow

#### 14a. Auto-Create on Login

```
[ AuthAuthenticated(user) emitted ]
                        │
                        ▼
  [ ShiftBloc created with username: user.username ]
                        │
                        ▼
  [ StartShift dispatched in ShiftBloc constructor ]
                        │
                        ▼
  [ ShiftBloc emits ShiftLoading ]
                        │
                        ▼
  [ ShiftsRepository.getActiveShift(username) ]
  [ O(1) via companion active_shifts box ]
               ┌────────────┴────────────┐
               ▼                         ▼
        [ Orphan found ]          [ No orphan ]
        (endedAt == null)               │
               │                        │
               ▼                        ▼
  [ Auto-close: copyWith(endedAt: now) ]  │
  [ repository.save(orphan) ]             │
  [ active_shifts.delete(username) ]      │
  [ ShiftBloc emits ShiftRecovered(old)] │
  [ Show snackbar: "Previous shift was   ]│
  [  closed automatically due to         ]│
  [  unexpected exit." ]                  │
               │                        │
               └───────────┬────────────┘
                           ▼
          [ Create new ShiftEntity ]
          [ id: UUID v4 ]
          [ username: user.username ]
          [ startedAt: now ]
          [ openingFloat: 0 ]
                           │
                           ▼
          [ repository.save(shift) ]
          [ active_shifts.put(username, shiftId) ]
                           │
                           ▼
          [ ShiftBloc emits ShiftActive(shift) ]
                           │
                           ▼
          [ AppShell renders with shift context ]
```

#### 14b. End Shift Flow

```
[ User taps End Shift in nav rail ]
                        │
                        ▼
           [ Confirmation dialog opens ]
           [ "End Shift?" ]
           [ "Ending your shift will close this session ]
           [  and log you out." ]
           [ [Cancel]  [End Shift] ]
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
        [ Cancel ]            [ End Shift ]
            │                       │
            ▼                       ▼
    [ Dialog closes ]    [ Dispatch ShiftBloc.EndShift ]
            │                       │
                                    ▼
                          [ ShiftBloc emits ShiftLoading ]
                                    │
                                    ▼
                    [ shiftEntity.copyWith(endedAt: now) ]
                                    │
                                    ▼
                    [ ShiftsRepository.save(shift) ]
                    [ active_shifts.delete(username) ]
                                    │
                                    ▼
                    [ ShiftBloc emits ShiftEnded(shift) ]
                                    │
                                    ▼
                    [ BlocListener<ShiftBloc> catches ShiftEnded ]
                                    │
                                    ▼
                    [ Dispatch AuthBloc.LogoutRequested ]
                                    │
                                    ▼
                    [ AuthBloc emits AuthUnauthenticated ]
                                    │
                                    ▼
                    [ BlocBuilder<AuthBloc> swaps to LoginScreen ]
                    [ ShiftBloc and ReceiptsBloc disposed ]
```

### 15. User Management Flow (Admin Only)

```
[ Admin taps Settings → User Management section ]
                        │
                        ▼
        [ Dispatch AuthBloc.LoadUsers ]
                        │
                        ▼
          [ AuthRepository.getAll() returns user list ]
                        │
                        ▼
          [ User list renders as cards with ⋮ popup ]
              │               │               │
              ▼               ▼               ▼
     [ Tap + Add User ]  [ ⋮ Change Pwd ]  [ ⋮ Delete User ]
              │               │               │
              ▼               ▼               ▼
  [ AddUserDialog ]   [ ChangePassword ]  [ RBAC guard:
  ┌────────────────┐  [   Dialog       ]  [ cannot delete
  │ Username: [ ]  │  ┌───────────────┐  [ self ]
  │ Password: [ ]  │  │ Current: [ ]  │  [ Confirmation ]
  │ Role: [A|C]    │  │ New: [____]   │       │
  │ [Cancel][Add]  │  │ Confirm:[____]│       ▼
  └────────────────┘  │ [Cancel][Chg] │  [ Dispatch
       │              └───────────────┘  DeleteUser
       ▼                    │            to AuthBloc ]
  [ Validation:        [ Re-auth: verify  │
  username regex,      admin's current    ▼
  password min 8,      password against ] [ AuthBloc emits
  duplicate check ]    PBKDF2 hash    ]    UsersLoaded ]
  ┌───┴───┐            ┌────┴────┐        │
  ▼       ▼            ▼         ▼        ▼
[Pass]  [Fail]      [Valid]  [Invalid] [ UI rebuilds:
  │       │           │         │       user removed ]
  ▼       ▼           ▼         ▼
[CreateUser   [Inline  [Set new  [Inline
 to AuthBloc]  error]  password  error]
  │                    (min 8), │
  ▼                    reset     │
[BlocListener:         mustChange│
 pop on success,       Pass=false│
 inline error on fail]  save()   │
  │                    │         │
  ▼                    ▼         ▼
[AuthBloc emits    [AuthBloc emits
 UsersLoaded]       UsersLoaded]
  │                  │
  ▼                  ▼
[UI rebuilds:     [UI rebuilds:
 user added]     password updated]
```

### 16. Receipt Creation Flow (Checkout → ReceiptsBloc)

```
[ Cashier taps Confirm Sale (or F12/Space) ]
                        │
                        ▼
  [ CheckoutBloc._onConfirmSale ]
  [ Guard: cart not empty, _confirmInProgress false ]
                        │
                        ▼
  [ generateOrderNumber callback invoked ]
  [ Reads SettingsBloc: lastOrderDate, orderCounter ]
  [ Compares lastOrderDate to today ]
  [ Generates new order number ]
  [ Dispatches UpdateOrderCounter to SettingsBloc ]
                        │
                        ▼
  [ CheckoutBloc emits confirmed status ]
  [ Builder: CheckoutConfirmationDialog shows (2s) ]
                        │
                        ▼
  [ AppShell.BlocListener<CheckoutBloc> catches confirmed ]
                        │
                        ▼
  [ Reads current shift from ShiftBloc state ]
  [ Reads final cart from CheckoutBloc state ]
                        │
                        ▼
  [ ReceiptsBloc.CreateReceipt(
      shiftId: shift.id,
      orderNumber: state.orderNumber!,
      items: cart.items.map → ReceiptItem,
      totals: Totals(subtotal, discount, tax, total),
      username: currentUser.username,
    ) ]
                        │
                        ▼
  [ ReceiptsBloc emits ReceiptLoading ]
                        │
                        ▼
  [ 1. ReceiptsRepository.save(receiptEntity) ]
  [   → Mark stockUpdated: false ]
  [   → Hive box 'receipts' ]
  [   → SURE FAIL: If save fails, emit ReceiptPersistenceFailure and STOP. UI must not show "Confirmed". ]
                        │
                        ▼
[ 2. IInventoryRepository.updateStock(barcode, -qty) for each item ]
[   → Best-effort: fail does not roll back receipt ]
                        │
                        ▼
[ 3. After all stock updates attempted: ]
[   → receiptEntity.stockUpdated = true ]
[   → Second ReceiptsRepository.save(receiptEntity) ]
[   → Marks receipt as stock-integrity-verified ]
                        │
                        ▼
[ 4. ReceiptsBloc atomic result ]
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
[ ReceiptCreated(receipt) ]    [ ReceiptPersistenceFailure ]
          │                           │
          ▼                           ▼
[ Dialog transitions to       [ Dialog transitions to error ]
[ success variant             [ Icon: error (red, 64px)       ]
[ Icon: check_circle          [ Message: failure reason       ]
[ (green, 64px)               [ Manual dismiss or 5s timeout  ]
[ Auto-dismiss: 2s ]          [ No ClearCart                  ]
          │                           │
          ▼                           ▼
[ 2s timer →               [ User dismisses dialog →    ]
[ CheckoutBloc.ClearCart ]  [ CheckoutBloc.ClearCart ]  
          │                           │
          └──────────┬────────────────┘
                     ▼
  [ Cart resets, tower panel clears ]
  [ Cashier Sales view (full shift) updates ]
  [ Admin TodaySummaryBar updates (if visible) ]
```

### 17. Admin Month Browsing Flow

```
[ Admin navigates to Sales workspace ]
                        │
                        ▼
  [ SalesBloc.LoadTodaySummary dispatched ]
                        │
                        ▼
  [ ReceiptsRepository.getByDate(today) ]
  [ Computes: receiptCount, totalPiastres, itemsSold ]
                        │
                        ▼
  [ TodaySummaryBar renders with AnimatedCounter values ]
                        │
                        ▼
  [ SalesBloc.LoadMonth(currentYear, currentMonth) ]
                        │
                        ▼
  [ ReceiptsRepository.getByMonth(year, month) ]
  [ Filters all receipts by createdAt.year == year ]
  [  && createdAt.month == month ]
                        │
                        ▼
  [ MonthBrowser shows month list, current month expanded ]
                        │
                        ▼
  [ Admin scrolls through months, tapping to expand/collapse ]
                        │
                        ▼
  [ Tapping a receipt row opens ReceiptDetailDialog ]
  [ Read-only: order number, items, totals, cashier ]
```

### 18. Cashier Sales View Flow

```
[ Cashier navigates to Sales workspace ]
                        │
                        ▼
  [ SalesBloc dispatches LoadShiftReceipts(shiftId) ]
                        │
                        ▼
  [ ReceiptsRepository.getByShift(shiftId) ]
  [ Sorts by createdAt descending ]
                        │
                        ▼
  [ UI renders static header + receipt cards ]
  [ Each card: orderNumber, total, timestamp ]
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
        [ Has receipts ]    [ No receipts ]
              │                   │
              ▼                   ▼
  [ Show receipt list ]       [ AppEmpty state ]
                              [ icon: receipt ]
                              [ "No sales yet this shift" ]
```

### 19. Orphan Shift Auto-Recovery Flow

```
[ App crashes mid-shift (endedAt still null) ]
         ...
[ User relaunches app and logs in ]
                        │
                        ▼
  [ AuthAuthenticated(user) → ShiftBloc.StartShift ]
                        │
                        ▼
  [ ShiftsRepository.getActiveShift(username) ]
                        │
                        ▼
  [ Finds shift where endedAt == null && username == match ]
  [ O(1) via companion active_shifts box lookup ]
                        │
                        ▼
  [ Auto-close: shift.copyWith(endedAt: now) ]
  [ repository.save(closedShift) ]
  [ active_shifts.delete(username) ]
                        │
                        ▼
  [ ShiftBloc then creates a fresh shift as normal ]
                        │
                        ▼
  [ AppShell shows snackbar:
    "Previous shift was closed automatically
     due to unexpected exit." ]
                        │
                        ▼
  [ All receipts from orphaned shift preserved in 'receipts' box ]
  [ shiftId on each receipt still matches the now-closed shift ID ]
```

---

### 20. Refund & Modification Flow (Double-Lock System)

This flow describes the double-lock system for refunds and modifications, ensuring stock integrity and preventing duplicate refunds.

#### 20a. Receipt Status State Machine

Every receipt starts with `status: active`. The `ReceiptStatus` enum governs transitions:

```
[ active ] ──→ [ returned ]  (Full/partial refund — locked)
[ active ] ──→ [ modified ]  (Quantity change — locked for modification, refund allowed)
[ returned ] ──→ (fully locked — RefundLockFailure on any mutating action)
[ modified ] ──→ (modification locked, return allowed — further modification blocked, refund permitted)
```

**ReceiptStatus enum:** `enum ReceiptStatus { active, returned, modified }` stored on `ReceiptEntity.status`.

#### 20b. Full Refund (Void/Return) Flow

```
[ User opens Sales Workspace → selects receipt → taps "Return/Refund" ]
                        │
                        ▼
[ Check receipt.status ]
                        │
          ┌─────────────┴─────────────┐
          ▼                           ▼
[ status == returned ]         [ status != returned ]
          │                           │
          ▼                           ▼
[ Throw RefundLockFailure ]    [ Set receipt.status = returned ]
[ UI: "This receipt has        [ receipt = receipt.copyWith(
  already been returned." ]      status: ReceiptStatus.returned ) ]
          │                            │
          │                            ▼
          └───┐            [ For each item in receipt.items: ]
              │                        │
              │                        ▼
              │            [ IInventoryRepository.updateStock(
              │              barcode, +originalQuantity) ]
              │                        │
              │                        ▼
              │            [ Create RefundEntity:
              │              id: UUID v4,
              │              originalReceiptId: receipt.id,
              │              refundDate: DateTime.now(),
              │              amountRestored: receipt.totalPiastres,
              │              type: RefundType.full ]
              │                        │
              │                        ▼
              │            [ ReceiptsRepository.save(receipt) ]
              │            [ RefundsRepository.save(refundEntity) ]
              │                        │
              │                        ▼
              │            [ UI shows refund confirmation ]
              │                        │
              └────────────────────────┘
```

#### 20c. Modification Flow (Quantity Change)

```
[ User opens receipt → taps "Modify" → changes item X qty from 5 to 3 ]
                        │
                        ▼
[ Check receipt.status ]
              │
     ┌────────┴────────┐
     ▼                  ▼
[ returned | modified ]  [ active ]
     │                  │
     ▼                  ▼
[ RefundLockFailure ]   [ Calculate deltaQuantity = originalQty - newQty ]
                        [ (positive = items removed → restore stock) ]
                        [ (negative = items added → decrement stock) ]
                                  │
                                  ▼
                        [ IInventoryRepository.updateStock(
                          item.barcode, deltaQuantity) ]
                                  │
                                  ▼
                        [ Recalculate financial totals: ]
                        [ subtotalPiastres = Σ(newQty × unitPrice) ]
                        [ discountAmount = subtotal × discountPercent / 100 ]
                        [ taxAmount = (subtotal - discount) × taxPercent / 100 ]
                        [ totalPiastres = subtotal - discount + tax ]
                                  │
                                  ▼
                        [ Update ReceiptEntity: ]
                        [ receipt = receipt.copyWith(
                            items: updatedItems,
                            subtotalPiastres: newSubtotal,
                            totalPiastres: newTotal,
                            status: ReceiptStatus.modified,
                          ) ]
                                  │
                                  ▼
                        [ ReceiptsRepository.save(receipt) ]
                                  │
                                  ▼
                        [ UI shows modification confirmed ]
```

#### 20d. RefundEntity Model

```dart
enum RefundType { full, partial }

class RefundEntity {
  final String id;                 // UUID v4
  final String originalReceiptId;  // References the original receipt
  final DateTime refundDate;
  final int amountRestored;        // Piastres
  final RefundType type;           // Full or Partial
}
```

Stored in Hive box `refunds` (key = UUID). Created in `lib/features/receipts/domain/entities/refund_entity.dart`.

#### 20e. Double-Refund Security Lock Summary

| Condition | Behavior |
|---|---|
| `status == active` | Return and Modify allowed |
| `status == returned` | All mutation locked. `RefundLockFailure` thrown |
| `status == modified` | Return locked. Further modification allowed (new delta calculated against current quantities) |

`RefundLockFailure` extends `Failure` in `lib/core/error/failure.dart`:
- Fields: `receiptId` (String), `currentStatus` (ReceiptStatus), `message` (String)

---

### 21. First-Time Admin Setup Flow

```
[ App starts → AuthBloc.CheckAuth dispatched ]
                    │
                    ▼
        [ AuthBloc emits AuthLoading ]
                    │
                    ▼
      [ AuthRepository.getAll() called ]
                    │
                    ▼
          [ __setup_completed__ check ]
              ┌────────┴────────┐
              ▼                 ▼
        [ Absent ]         [ Present ]
              │                 │
              ▼                 ▼
   [ Emit AuthStatus.      [ Normal login
     setupRequired ]         flow follows ]
              │                 │
              ▼                 │
   [ FirstTimeSetupScreen ]     │
              │                 │
              ▼                 │
   [ Admin enters password      │
     + confirm ]                │
              │                 │
              ▼                 │
   [ CompleteAdminSetup         │
     (password) dispatched ]    │
              │                 │
              ▼                 │
   [ AuthBloc validates         │
     password (min 8) ]         │
              │                 │
              ▼                 │
   [ Hash password (PBKDF2),    │
     update admin user,         │
     salt, mustChangePassword   │
     = false ]                  │
              │                 │
              ▼                 │
   [ AuthRepository.complete    │
     Setup(admin) → saves user  │
     + writes __setup_completed │
     __ marker ]                │
              │                 │
              ▼                 │
   [ Emit AuthStatus.           │
     authenticated(user) ]      │
              │                 │
              ▼                 │
    [ AppShell renders,          │
      ShiftBloc starts shift ]───┘
```

---

### 22. Print Server Lifecycle Flow

```
[ App starts → main.dart ]
              │
              ▼
[ PrintServerManager.start() ]
              │
              ▼
[ Process.start('PrintServer.exe') ]
              │
              ▼
[ .NET Kestrel host listening on 127.0.0.1:5150 ]
              │
              ▼
[ App closes → PrintServerManager.dispose() ]
              │
              ▼
[ Process.kill() → sidecar terminates ]
```

---

### 23. Auto-Print on Sale Confirmation Flow

```
[ Cashier taps Confirm Sale ]
              │
              ▼
[ CheckoutBloc emits confirmed → ReceiptsBloc.CreateReceipt ]
              │
              ▼
[ ReceiptsBloc emits ReceiptCreated(success) ]
              │
              ▼
[ AppShell catches ReceiptCreated ]
              │
              ▼
[ Check autoPrintEnabled ]
    ┌───────┴───────┐
    ▼               ▼
[ Enabled ]    [ Disabled ]
    │               │
    ▼               │
[ Read SettingsBloc state: ]
[ storeName, storeAddress,   ]
[ storePhoneNumber,          ]
[ logoSvgPath,               ]
[ receiptFootnote, langCode  ]
    │                        │
    ▼                        │
[ Build ReceiptRequest       │
  from receipt entity +      │
  settings state             │
    │                        │
    ▼                        │
[ PrintService.printReceipt  │
  (payload) → HTTP POST      │
  to :5150/api/printing/     │
  receipt ]                  │
    │                        │
    ▼                        │
[ .NET PrinterService.cs     │
  → GDI+ receipt layout      │
  → send to receiptPrinter   │
  or default printer ]       │
    │                        │
    ▼                        │
[ Check saveReceiptAsImage ]─┘
    │
    ▼
[ If enabled: same payload
  → ImageExportService
  → SkiaSharp PNG render
  → save to exportDirectoryPath
  → filename: receipt_<orderNumber>_<timestamp>.png ]
```

#### 23b. Receipt Reprint Flow

```
[ User opens ReceiptDetailDialog ]
              │
              ▼
[ "Print" button visible (Windows + PrintServer available) ]
              │
              ▼
[ User taps Print ]
              │
              ▼
[ Build ReceiptRequest from receipt + current settings ]
              │
              ▼
[ PrintService.printReceipt(payload) ]
              │
              ▼
[ .NET PrinterService prints receipt ]
              │
              ▼
[ Snackbar: "Receipt sent to printer" / error message ]
```

---

### 24. DRM Activation Flow

#### 24a. License Check on Startup

```
[ App starts → _AppState.initState() ]
              │
              ▼
[ LicenseEngine.verifyLicense() ]
              │
              ▼
[ Check primary storage (FlutterSecureStorage) ]
    ┌───────────────┴───────────────┐
    ▼                               ▼
[ Key exists ]                 [ No key ]
    │                               │
    ▼                               ▼
[ Compare stored device ID    [ Check backup storage ]
  against current HWID ]           │
    ┌───────┴───────┐        ┌─────┴─────┐
    ▼               ▼        ▼           ▼
[ Match ]    [ Mismatch ]  [ Valid ]  [ Empty ]
    │               │        │           │
    ▼               ▼        ▼           ▼
[ valid ]    [ Check backup ]  [ Restore   [ invalid ]
              │               primary     │
        ┌─────┴─────┐        from         ▼
        ▼           ▼        backup ]  [ Activation
    [ Match ]  [ Mismatch ]  → valid     Screen ]
        │           │
        ▼           ▼
    [ valid ]  [ tampered ]
                  │
                  ▼
           [ Activation Screen
             + tamper warning ]
```

#### 24b. Activation Key Entry

```
[ ActivationScreen shown (invalid or tampered) ]
              │
              ▼
[ QR code displays device ID ]
[ Device ID text: CS-XXXX-XXXX (selectable) ]
              │
              ▼
[ User obtains activation key
  (developer signs device ID with Ed25519 private key) ]
              │
              ▼
[ User types/pastes key into input field ]
              │
              ▼
[ Input filters: base64url chars only (A-Za-z0-9-_) ]
              │
              ▼
[ User taps "Activate System" ]
              │
              ▼
[ ActivationCubit.submitActivationKey(key) ]
              │
              ▼
[ LicenseEngine.activate(key) ]
              │
              ▼
[ Ed25519Verifier.verify(deviceId, key) ]
    ┌───────────────┴───────────────┐
    ▼                               ▼
[ Signature valid ]            [ Invalid ]
    │                               │
    ▼                               ▼
[ Write LicenseEntity to:      [ Show error:
  • FlutterSecureStorage          "Invalid activation key"
  • FileBackupAdapter           [ Return to form ]
  (XOR-obfuscated file) ]
    │
    ▼
[ Emit ActivationSuccess ]
    │
    ▼
[ onActivated callback → re-check license ]
    │
    ▼
[ LicenseEngine.verifyLicense() → valid ]
    │
    ▼
[ AppShell renders (normal app) ]
```

#### 24c. Operational Gating (Runtime Checks)

```
[ ShiftBloc.StartShift or CheckoutBloc.ConfirmSale ]
              │
              ▼
[ LicenseEngine.quickVerify() ]
              │
              ▼
[ Read primary storage only ]
    ┌───────┴───────┐
    ▼               ▼
[ Valid ]      [ Invalid / Missing ]
    │               │
    ▼               ▼
[ Proceed ]    [ Block operation ]
    │           [ Emit Failure:
    │             "License verification
    │              failed. Contact support." ]
    │               │
    └───────┬───────┘
            ▼
    [ Normal flow continues / error handled by UI ]
```

