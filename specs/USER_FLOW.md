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
      [ User fills: barcode, name, price, stock ]
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
   * The SettingsWorkspace renders nine stacked card sections: General, Appearance, Localization, Tax, Printing, Keyboard Shortcuts (6 groups), and Reset All Data.
   * **General Section:** The user modifies `Store Name` or `Receipt Footnote` text input values using the keyboard. Each keystroke fires a `StoreNameChanged` or `ReceiptFootnoteChanged` event to the `SettingsBloc`.
   * **Appearance Section:** The user toggles the Dark Mode `Switch`. The switch immediately fires a `ThemeToggled` event. A status label updates in real-time ("Dark Mode Active" / "Light Mode Active").
   * **Localization Section:** The user selects a language via `SegmentedButton` (`EN` / `AR`). The selection immediately fires a `LanguageToggled` event. A directionality info banner updates to show `RTL` or `LTR` accordingly.
   * **Tax Section:** The user toggles tax on/off via `SwitchListTile`. The tax rate `TextField` appears conditionally when tax is enabled. Input is digits-only with 300ms debounce, clamped to 0-100. Dispatches `TaxToggled` and `TaxPercentChanged`.
   * **Printing Section:** The user toggles "Auto-print" via `SwitchListTile`. Dispatches `AutoPrintToggled`. The setting is stored but print execution is not yet wired.
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
         [ First boot? Box empty? ]
              ┌────────┴────────┐
              ▼                 ▼
          [ Yes ]           [ No ]
              │                 │
              ▼                 ▼
   [ Seed 3 users created ]  [ Return existing ]
   [ admin/admin (admin) ]   [ users from Hive ]
   [ cashier1/cashier1 ]     │
   [ cashier2/cashier2 ]     │
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
      [ passwordHash = sha256(utf8.encode(password)) ]
                       │
                       ▼
        [ Lookup user in AuthRepository by username ]
              ┌────────┴────────┐
              ▼                 ▼
         [ Found ]          [ Not found ]
              │                 │
              ▼                 ▼
   [ Compare hash ]     [ Emit AuthUnauthenticated ]
        ┌────┴────┐     [ error: invalidCredentials ]
        ▼         ▼
    [ Match ]  [ No match ]
        │         │
        ▼         ▼
  [ Emit      [ Emit AuthUnauthenticated ]
   AuthLoading  error: invalidCredentials ]
        │
        ▼
  [ Seed users check: if username/password ]
  [ matches seed credentials, the seed user ]
  [ is persisted to Hive at this point ]
        │
        ▼
  [ AuthBloc emits AuthAuthenticated(user) ]
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
               ┌────────────┴────────────┐
               ▼                         ▼
        [ Orphan found ]          [ No orphan ]
        (endedAt == null)               │
               │                        │
               ▼                        ▼
  [ Auto-close: copyWith(endedAt: now) ]  │
  [ repository.update() ]                 │
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
                    [ ShiftsRepository.update(shift) ]
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
          [ AuthRepository.getAll() returns user list ]
                        │
                        ▼
          [ User list renders as cards ]
              │                   │
              ▼                   ▼
     [ Tap + Add User ]    [ Tap Change Password ]
              │                   │
              ▼                   ▼
  [ AddUserDialog opens ]  [ ChangePasswordDialog opens ]
  ┌─────────────────────┐  ┌──────────────────────────┐
  │ Username: [____]    │  │ Current Password: [____] │
  │ Password: [____]    │  │ New Password: [____]     │
  │ Role: [Admin|Cashier]│  │ Confirm: [____]         │
  │ [Cancel] [Add]      │  │ [Cancel] [Change]       │
  └─────────────────────┘  └──────────────────────────┘
              │                      │
              ▼                      ▼
     [ Validation checks ]  [ Validate current password ]
     ┌───┴───┐               [ against admin's stored hash]
     ▼       ▼                        │
  [Pass]  [Fail]              ┌───────┴───────┐
     │       │                ▼               ▼
     ▼       ▼            [ Valid ]        [ Invalid ]
  [Dispatch   [Error]      │                  │
  CreateUser  inline       ▼                  ▼
  to AuthBloc]        [ Hash new password ]  [ Show inline
     │                [ AuthRepository      error: "Wrong
     ▼                 .save(user) ]        current password"]
  [AuthBloc emits       │
  UsersLoaded]          ▼
     │            [ AuthBloc emits UsersLoaded ]
     ▼
  [UI rebuilds: new user appears in list]
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
  [   → Hive box 'receipts' ]
                        │
                        ▼
  [ 2. IInventoryRepository.updateStock(barcode, -qty) ]
  [   → Best-effort: fail does not roll back receipt ]
                        │
                        ▼
  [ ReceiptsBloc emits ReceiptCreated(receipt) ]
                        │
                        ▼
  [ 2s timer expires → CheckoutBloc.ClearCart ]
  [ Cart resets, tower panel clears ]
  [ Cashier Sales view (last 3) updates ]
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

### 18. Cashier Limited Sales View Flow

```
[ Cashier navigates to Sales workspace ]
                        │
                        ▼
  [ SalesBloc dispatches LoadShiftReceipts(shiftId) ]
                        │
                        ▼
  [ ReceiptsRepository.getByShift(shiftId) ]
  [ Sorts by createdAt descending ]
  [ Takes first 3 (limit 3) ]
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
  [ Show 1-3 receipt cards ]  [ AppEmpty state ]
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
                        │
                        ▼
  [ Auto-close: shift.copyWith(endedAt: now) ]
  [ repository.update(closedShift) ]
                        │
                        ▼
  [ ShiftBloc emits ShiftRecovered(oldShift) ]
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

