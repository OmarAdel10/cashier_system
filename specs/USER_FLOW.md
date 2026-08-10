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
                          (BarcodeScannerGate widget)
                                        │
                                        ▼
                        Look up barcode in Inventory Map
                             (gate layer only — no
                              validation in CheckoutBloc)
                                        │
                 ┌──────────────────────┴──────────────────────┐
                 ▼                                             ▼
           [ Found Entry ]                              [ Entry Not Found ]
                 │                                             │
                 ▼                                             ▼
    AddToCart(barcode, name, price)                 Trigger visual error toast
    → CheckoutBloc._onAddToCart                     (gate only)
      adds ANY barcode
      unconditionally — the
      checkout add path has
      NO inventory validation
    
   
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
	* **State Action 1:** The `generateOrderNumber` callback is invoked: it reads the current shift's `orderCount` from `ShiftBloc` state, dispatches `IncrementShiftOrderCount`, and returns `ORD-` + the counter zero-padded to 5 digits (`app.dart:155-162`). The settings `orderCounter`/`lastOrderDate` fields are unused.
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

* **Note:** A "Print" action sends the label to the PrintServer via `POST /api/printing/barcode` (`print_service.dart:49`); `BarcodeRequest.cs` validates `[StringLength(80)]` + printable-ASCII-only regex; `BarcodeLabelTemplate` renders the label with RTL support.

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
   * The SettingsWorkspace renders nine stacked card sections: General, Appearance, Localization, Tax, Printing, Export Directory, Keyboard Shortcuts (6 groups), and Reset All Data.
   * **General Section:** The user modifies `Store Name` or `Receipt Footnote` text input values using the keyboard. Each keystroke fires a `StoreNameChanged` or `ReceiptFootnoteChanged` event to the `SettingsBloc`.
   * **Appearance Section:** The user toggles the Dark Mode `Switch`. The switch immediately fires a `ThemeToggled` event. A status label updates in real-time ("Dark Mode Active" / "Light Mode Active").
   * **Localization Section:** The user selects a language via `SegmentedButton` (`EN` / `AR`). The selection immediately fires a `LanguageToggled` event. A directionality info banner updates to show `RTL` or `LTR` accordingly.
   * **Tax Section:** The user toggles tax on/off via `SwitchListTile`. The tax rate `TextField` appears conditionally when tax is enabled. Input is digits-only with 300ms debounce, clamped to 0-100. Dispatches `TaxToggled` and `TaxPercentChanged`.
   * **Printing Section:** The user toggles "Auto-print" via `SwitchListTile`. Dispatches `AutoPrintToggled`. The setting is stored but print execution is not yet wired.
   * **Export Directory Section:** The user taps "Choose Folder" `FilledButton.tonalIcon`. A native directory picker opens via `file_picker`. The selected path dispatches `SetExportDirectoryPath(path)` to `SettingsBloc`. The path displays immediately; if unset, shows localized "Not set" in grey.
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
         [ Selection clamps to [0, n-1] via ]
         [ .clamp() — no wrap-around;       ]
         [ empty cart → index held at 0     ]
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
    [ taxAmount = subtotal * taxPercent / 100 ]
    [ total = subtotal - discountAmount + taxAmount ]
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
   [ Read ShiftBloc state: current shift's orderCount ]
                         │
                         ▼
   [ Dispatch IncrementShiftOrderCount(shift.id) ]
                         │
                         ▼
   [ Return "ORD-${counter.padLeft(5, '0')}" ]
                         │
                         ▼
   [ Emit CheckoutStatus.confirmed, orderNumber: "ORD-00001" ]
                         │
                         ▼
   [ Tower panel displays "#ORD-00001" above store name ]
                         │
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
This flow describes the optional user-configured keyboard shortcuts for cash denomination selection. Unlike navigation/search/cart actions, all amount actions (`cart.amount.5eg`–`cart.amount.200eg`, `cart.amount.clear`, `search.clear`) ship with EMPTY default bindings (`default_bindings.dart:24-31`) — they do nothing until the cashier binds a key combo in Settings.

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
    [ Seed admin user created  ]  [ Return existing ]
    [ admin (admin role)      ]  [ users from Hive ]
    [ Password: random        ]   │
    [ 16-char alphanumeric    ]   │
    [ (no known value)        ]   │
    [ With mustChange=        ]   │
    [   Password: true        ]   │
    [ Set __seeded__ key      ]   │
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
         │                     [ lockout = min(30 * (1 << ]
         │                     [   (failures - 3)), 3600) ]
         │                     [   seconds — exponential ]
         │                     [   backoff measured from ]
         │                     [   last failure          ]
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
[ Emit AuthStatus.      [ Emit AuthAuthenticated(user) ]
[ passwordChangeRequired ] [ BlocBuilder swaps → AppShell ]
[ LoginScreen shows     │
[ failure banner:       │
[ "Password change      │
[ required..." — no     │
[ change-password UI    │
[ on LoginScreen         │
   │                    │
   ▼                    ▼
[ Cashier accounts are NOT seeded; they are
  created by the admin via Settings → User
  Management with a known password. The
  passwordChangeRequired state is only
  reachable for the seeded admin before
  first-time setup completes ]
        │
        ▼
[ BlocBuilder stays on LoginScreen ]
```

* **Note:** The `failed × 2s` lockout formula exists only in the admin-password dialog (`receipt_detail_dialog.dart:411-428`) — the login path uses exponential backoff only.

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
   [ Validation:        [ Current pwd only  │
   username regex,      for own change      │
   password min 8,      (isSelf); admin     ▼
   duplicate check ]    resets others    ] [ AuthBloc emits
                                             UsersLoaded ]
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
[ Cashier taps Confirm Sale (F12/Space) ]
                         │
                         ▼
    [ CheckoutBloc._onConfirmSale ]
    [ Guard: cart not empty, _confirmInProgress false ]
    [ No isPaid guard — confirming with zero paid is allowed ]
                          │
                          ▼
    [ generateOrderNumber callback invoked ]
    [ Reads ShiftBloc state: shift.orderCount ]
    [ Dispatches IncrementShiftOrderCount(shift.id) ]
    [ Generates "ORD-${orderCount.padLeft(5, '0')}" ]
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
        taxPercent: settings.taxPercent,  (0 if tax disabled)
        discountPercent: state.discountPercent,
      ) ]
                          │
                          ▼
    [ Total cross-validation: total == subtotal - discount + tax ]
   [ → FAIL: emit ValidationFailure, dialog shows error ]
                         │ (pass)
                         ▼
   [ ReceiptsBloc emits ReceiptLoading ]
                         │
                         ▼
    [ 1. ReceiptsRepository.save(receiptEntity) ]
    [   → Mark stockUpdated: false, stockFailedBarcodes: [] ]
    [   → Persist taxPercent, discountPercent snapshots ]
    [   → Hive box 'receipts' ]
    [   → SURE FAIL: If save fails, emit ReceiptPersistenceFailure and STOP ]
                         │
                         ▼
   [ 2. For each item: IInventoryRepository.updateStock(barcode, -qty) ]
   [   → Track failed barcodes in local List<String> failedBarcodes ]
   [   → Best-effort: individual failures do not roll back receipt ]
                         │
                         ▼
   [ 3. After all updates attempted: ]
   [   → stockUpdated = failedBarcodes.isEmpty ]
   [   → stockFailedBarcodes = failedBarcodes (persisted) ]
   [   → Second ReceiptsRepository.save(receiptEntity) ]
                         │
                         ▼
   [ 4. AuditService?.log(receiptCreated) with item count + total ]
                         │
                         ▼
   [ 5. If stockFailedBarcodes not empty: ]
   [   → AuditService?.log(stockUpdateFailed, N items) ]
                         │
                         ▼
   [ 6. ReceiptsBloc atomic result ]
                         │
           ┌─────────────┴─────────────┐
           ▼                           ▼
   [ ReceiptCreated(receipt) ]    [ ReceiptPersistenceFailure ]
           │                           │
           ▼                           ▼
    [ Dialog transitions to       [ Dialog transitions to error ]
    [ success variant             [ Icon: error (red, 64px)       ]
    [ Icon: check_circle          [ Message: failure reason       ]
    [ (green, 64px)               [ Auto-dismiss: 5s              ]
     [ Auto-dismiss: 2s ]          [ Dismiss button appears at 3s ]
     [                             [ ClearCart on dialog dismiss — ]
     [                             [ cart cleared even on error    ]
            │                           │
            ▼                           ▼
    [ 2s timer →               [ 5s timer or manual dismiss → ]
    [ CheckoutBloc.ClearCart ]  [ CheckoutBloc.ClearCart ]  
           │                           │
           └──────────┬────────────────┘
                      ▼
    [ Cart resets, tower panel clears ]
    [ Cashier Sales view updates ]
     [ Admin SummaryBar updates ]
    [ InventoryBloc.RefreshInventory dispatched ]
    [ If autoPrintEnabled or saveReceiptAsImage: ]
    [   → ReceiptPrintHelper.printReceipt() ]
    [   → Builds payload with skipPrint/saveAsPng flags ]
    [   → Dispatches to PrintService (HTTP :5150) ]
    [   → Shows success/failure snackbar ]
```

### 16b. Startup Stock Retry Flow

```
[ App starts → AppShell creates ReceiptsBloc ]
                         │
                         ▼
   [ unawaited(bloc.retryPendingStockUpdates()) ]
                         │
                         ▼
   [ ReceiptsRepository.getByStockNotUpdated() ]
   [ → returns all receipts where stockUpdated == false ]
                         │
                         ▼
   [ For each receipt: ]
                         │
                         ▼
   [ Determine barcodesToRetry: ]
   [   if stockFailedBarcodes.isEmpty → all item barcodes ]
   [   else → only stockFailedBarcodes list (narrowed retry) ]
                         │
                         ▼
   [ For each barcode in barcodesToRetry: ]
   [   item = receipt.items.firstWhere(barcode, orElse: → qty=0) ]
   [   if item.quantity == 0 → skip, add to stillFailed ]
                         │
                         ▼
   [   IInventoryRepository.updateStock(barcode, -item.quantity) ]
                         │
               ┌─────────┴─────────┐
               ▼                   ▼
           [ Success ]        [ Failed ]
               │                   │
               ▼                   ▼
         [ Continue ]     [ Add to stillFailedBarcodes ]
               │                   │
               └─────────┬─────────┘
                         ▼
   [ After all barcodes processed: ]
                         │
            ┌────────────┴────────────┐
            ▼                         ▼
   [ all succeeded ]          [ partial failures ]
            │                         │
            ▼                         ▼
   [ Save receipt with        [ Save receipt with narrowed
     stockUpdated: true,        stockFailedBarcodes:
     clearStockFailedBarcodes ]  stillFailedBarcodes ]
            │                         │
            ▼                         ▼
   [ AuditService?.log(         [ AuditService?.log(
     stockRetryResolved) ]        stockUpdateFailed) ]
            │                         │
            └────────────┬────────────┘
                         ▼
                 [ Continue to next receipt ]
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
    [ SummaryBar renders with MetricCard values ]
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
   [ Sorted by createdAt descending (newest first) ]
   [ sales_bloc.dart:189 — r.sort((a,b) => b.createdAt.compareTo(a.createdAt)) ]
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
[ returned ]       [ active | modified ]
      │                  │
      ▼                  ▼
[ RefundLockFailure ]   [ If status == modified → admin authorization required ]
                        [   → _AdminPasswordDialog: constant-time hash compare ]
                        [   → hashPassword(enteredPwd, adminUser.passwordSalt) ]
                        [   → if mismatch: emit AuthenticationFailure ]
                                      │
                                      ▼
                        [ Total cross-validation: ]
                        [ newTotal == newSubtotal - discount + tax ]
                        [ → FAIL: emit ValidationFailure, abort ]
                                      │
                                      ▼
                        [ Calculate deltaQuantity = originalQty - newQty ]
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
                        [ taxAmount = subtotal × taxPercent / 100 ]
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
   [ OnboardingFlow:           │
     Welcome (skippable) →     │
     Features (skippable) →    │
     Admin Setup (required) ]  │
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

* **Note:** `PrintServerManager` probes 6 candidate `PrintServer.exe` paths (side-by-side with the app exe, `PrintServer/` subdir, `build/windows/x64/runner/{Debug,Release}`, `PrintServer/bin/{Debug,Release}/net8.0`); `main.dart` runs `dotnet publish` (ensure-build) and skips launch if no binary is found.

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
[ logoSvgData,               ]
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

* **Note:** PNG export rides `POST /api/printing/save-png` (`print_service.dart:66`); `ImageExportService.cs:22` names files `receipt_{yyyyMMdd_HHmmss}.png` (no order number); toggled via settings events `SaveReceiptAsImageToggled` / `SetExportDirectoryPath`.

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

* **Note:** `FileBackupAdapter` (`file_backup_adapter.dart`) writes `license.lic` under the `CashierSystem` subdir of the app-support directory, obfuscated with XOR mask `[0xAB,0xCD,0xEF,0x12,0x34,0x56,0x78,0x90]` then base64Url-encoded.

#### 24c. Operational Gating (Runtime Checks)

```
[ ShiftBloc.StartShift or CheckoutBloc.ConfirmSale ]
              │
              ▼
[ LicenseEngine.verifyLicense() ]
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

---

### 25. Audit Event Logging Flow

#### 25a. Audit Log Write on Auth Events

```
[ AuthBloc processes auth event ]
                         │
                         ▼
   [ AuditService?.log(AuditEventType.*) ]
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
   [ login: username,          [ loginFailed: username,
     'User logged in' ]          'User not found' | 'Invalid password'
         │                       success: false ]
         ▼                               │
   [ logout: username,           [ userCreated: adminUser,
     'User logged out' ]           'Created user: {username}' ]
         │                               │
   [ passwordChanged:            [ userDeleted: adminUser,
     username,                      'Deleted user: {username}' ]
     'Password changed' ]               │
         └───────────────┬───────────────┘
                         ▼
   [ AuditService.log(): ]
   [ 1. Create AuditEntry(timestamp: now, type, username, details, success) ]
   [ 2. toJson() → write JSON string to Hive Box<String>('audit_log') ]
   [ 3. _pruneOld(): delete entries where timestamp < now - 90 days ]
```

#### 25b. Audit Log Write on Receipt Events

```
[ ReceiptsBloc completes receipt creation ]
                         │
                         ▼
   [ AuditService?.log(receiptCreated,
       username: cashier,
       details: 'Receipt {id}: {N} items, {total}pt') ]
                         │
                         ▼
   [ If stockFailedBarcodes not empty: ]
   [   AuditService?.log(stockUpdateFailed,
         username: cashier,
         details: 'Receipt {id}: stock update failed for {N} item(s)',
         success: false) ]
                         │
                         ▼
   [ On startup retry success (retryPendingStockUpdates): ]
   [   AuditService?.log(stockRetryResolved,
         details: 'Receipt {id}: pending stock update resolved') ]
```

#### 25c. Audit Box Structure

```
Hive Box('audit_log') — encrypted, Box<String>
  Key:   auto-generated UUID (Hive default)
  Value: JSON string of AuditEntry
         {"timestamp":"2026-07-26T10:30:00.000","type":"login",
          "username":"sara","details":"User logged in","success":true}

Retention: 90-day rolling
  _pruneOld() runs on every log() write
  Deletes all entries where timestamp < DateTime.now() - 90 days
  Full box scan per write (acceptable for low-frequency POS events)
```

* **Note:** Subsystem lives in `lib/core/audit` — 9 `AuditEventType` values, stored in an encrypted `LazyBox<String>('audit_log')` (not a plain `Box`), read via `getRecent(limit: 100)` newest-first, prune throttled to ≥1 min between runs, no UI; wired at app.dart:126,176, main.dart:134,165, app_shell.dart:176, receipts_bloc.dart:89,207,224, auth_bloc (8 sites).


---

### 15. PlayStation Mode Flow (Stations & Sessions)

**Entry:** business type = PlayStation → checkout tab renders `StationWorkspace` grid instead of product checkout; sorted available → active → overtime.

**15a. Start Session**
1. Cashier taps an **available** station card.
2. `StartSessionDialog`: pick tier (normal/multi; hidden for table stations), optionally tick fixed duration and set minutes (default 120).
3. Confirm → `StartSession` → status becomes `active`, `sessionStartTime` stamped; card shows live timer (⏱ HH:MM, 30s refresh) and tier-aware running total.
4. Fixed-duration stations: when booked minutes elapse, `AutoConversionService` dispatches `ConvertToOpenSession` → `isFixedDuration = false`, `overtimeStartMinutes` set, status `overtime` (orange).

**15b. End Session**
1. Cashier taps an **active/overtime** station card.
2. `EndSessionDialog`: shows elapsed time, tier label, booked duration (if fixed), live total.
3. Confirm → `EndSession` → billing `SessionRecordEntity` composed (billed minutes = max(fixed booked, elapsed), overtime included; subtotal = max(rate×minutes, min game cost); tax/discount 0 at record time).
4. Station resets to `available`; all session fields cleared (incl. persisted `overtimeStartMinutes`/`fixedDurationMinutes`).
5. App-shell `BlocListener` auto-persists the record via `CreateSessionRecord` (shift id + username attached); Sales workspace reloads its session list.
6. End on a station with no active session: no record is minted (no phantom charges); unknown station id → failure state, no crash.

**15c. Manage Stations (Inventory)**
1. Add: `station.form.title` dialog → name, category, type, normal/multi hourly rates, min game costs, icon asset.
2. Edit: same dialog prefilled; session fields (start time, tier, fixed duration, overtime) are **preserved** when editing an active station.
3. Delete: confirm dialog; **blocked** for stations with a running session (snackbar explains the session must end first); confirmation for available stations only.

### 16. Grid-Mode Checkout Flow (Cafe/Restaurant)

**Entry:** business type = cafe/restaurant → checkout tab renders cart SectionCard (left) + `ProductCategoryGrid` (right, flex 2:5).

**16a. Browse & filter**
1. Grid shows all products; category chips (All + each category) filter the grid; narrow window (<800px) renders chips horizontally above the grid, wide renders a left rail.
2. Search field filters by name substring.

**16b. Add items**
1. Tap a product card → `AddToCart` (not in cart → qty 1, in cart → +1); cart table on the left updates live.
2. Quick-tile products appear in the favorites strip above the grid only when the favorites toggle is on; Alt+1..9 / Alt+0 focuses the corresponding favorites slot (inert when disabled).

**16c. Scanner & playstation boundaries**
1. Barcode scanner gate is disabled in grid modes (`enabled: !isGridMode`) — typing does not inject barcodes.
2. Playstation keeps its station workspace; timed cart items (AddTimedItem/TimeBillingDialog) were removed — session billing is the only playstation billing path.

---

### 17. Business-Adaptive Inventory Flow

**Entry:** Inventory tab. Layout adapts to business type.

**17a. Retail/supermarket**
1. Exactly today's surface: Normal Products + Quick Access columns, barcode export/label studio available in the product form.

**17b. Cafe/restaurant**
1. Three columns: Categorized (products grouped under category headers, CategoryBloc order), Uncategorized (no category), Favorites (quick-tile products, only when the favorites toggle is on).
2. Product form: no barcode/stock fields (auto barcode assigned on create); quick-tile toggle reads "Favorite".

**17c. Playstation**
1. Inventory shows the stations section (add station via top '+' or section; edit via pencil; delete blocked for running sessions with snackbar) over a flat product list priced per hour ("X EGP/hr").
2. Product form: no barcode/stock/category/favorite fields; price label reads "price per hour".

---

### 18. Business-Adaptive Settings Flow

**Entry:** Settings tab. Top card always shows the business type (icon, name, "changeable only via factory reset" caption).

**18a. Cafe/restaurant**
1. Favorites strip switch visible; toggling persists and shows/hides the shortcuts section.
2. Barcode printer row absent; receipt printer present.

**18b. Playstation**
1. Minimum game cost editor in EGP (floor 1 EGP); stored as piastres.
2. Shortcuts section, barcode printer, and receipt printer all hidden.

**18c. Retail/supermarket**
- Today's settings unchanged: shortcuts always visible, both printers configurable.

---

### 19. Café & Restaurant Table Mode Flow (Floor Management)

**Entry:** Business type = cafe/restaurant → checkout tab renders `TableWorkspace` (zone sections + table cards). The grid/cart checkout is replaced entirely for these modes.

#### 19a. Floor Map & Table States
```
[ Available (green) ] ── tap ──► [ StartTab Overlay ] ──► [ Occupied (blue) ]
                                                             │
                                                             ▼
[ PaymentPending (red) ] ◄── Checkout ◄── [ Served (gray) ] ◄── Mark Served ◄── [ OrderPending (yellow) ]
     ▲                                                                           │
     └────────────────────────── ClearTab (rounds archived) ────────────────────┘
```
* **Zone Sections:** Dine-in zones first (Main Dining, Terrace, VIP, Bar/Counter), Takeaway Queue last. Each zone renders as a section header + grid of table cards.
* **Table Card:** Shows table name, capacity badge, live occupancy timer (for rooms: ceil-hour charge). Status color per state machine.
* **Rooms:** When `roomsEnabled` setting is ON, tables with `isRoom=true` show hourly rate badge; room charge = `ceil(elapsedMinutes/60) × hourlyRatePiastres` (min 1h). Live on card + in session dialog.

#### 19b. Start Tab & Session Dialog
1. Tap available table → `StartTabDialog` overlay (confirms opening tab, optional fixed-duration for playstation-style sessions).
2. Tab opens → `TableSessionDialog` full-screen overlay:
   - **Bill area:** Fired rounds (each with item lines, Mark Served button) + draft items.
   - **Product picker:** Reuses `ProductCategoryGrid` (category chips, search, favorites strip when enabled). Tap product → adds to draft lines.
   - **Send Order:** Commits draft → creates `TableRoundEntity` (roundNumber++, firedAt, lines with `PrepCategory`), persists to Hive, drafts cleared, table status → `orderPending`.
   - **Ticket Routing:** On Send Order, lines grouped by `PrepCategory` (food/beverage/shisha/general). For each enabled category with configured printer → prints production ticket (venue name, station label KITCHEN/BAR/SHISHA, table+zone+round#, order#, `qty × item name`, fired time). **NO prices/totals.** Skip silently if disabled/no printer.
   - **Mark Served:** Cashier taps → round status `prepared` → `served`. Table status oscillates `orderPending` ↔ `served`.

#### 19c. Multi-Round Ordering
* Subsequent orders follow same pattern: draft items → Send Order → new round number → ticket routing. Rounds persist across app restart (fired rounds in `table_rounds` box; drafts only in Bloc state).

#### 19d. Checkout & Financials
1. Tap "Checkout" in session dialog → `CheckoutTableDialog`:
   - **Bill composition:** `base = sum(fired+draft lines) + roomCharge` (ceil-hour). `minCharge floor (dine-in, enabled)` → `serviceCharge % (dine-in, enabled)` → `discount % input` → `tax % (from settings)` → `total`. Mirrors retail `CheckoutBloc` discount/tax math exactly.
   - **Equal-N Split:** Stepper to split equally by N guests. Total divided into N receipts (remainder piastres on last). N sequential payment dialogs (payment type from `shownPaymentTypeIds`, amount paid). N `CreateReceipt` dispatches (full cashier parity: order#, auto-print, save-as-image, shift audit, refunds).
   - **Confirm Payment:** Each split part → payment dialog → receipt printed → table cleared when all parts paid.

#### 19e. Transfer & Merge (from Session Dialog)
* **Transfer:** "Transfer" button → `TransferTableDialog` (select available target table). Moves tab + all fired rounds to target; source cleared to `available`. Target status → `occupied`.
* **Merge:** "Merge" button → `MergeTablesDialog` (select occupied target table). Lines summed into target; source cleared (no charge). Target status unchanged.

#### 19f. Table Management (Inventory Workspace)
* Admin-only section in Inventory when business type = cafe/restaurant.
* **Zone Management:** `ZoneManagementDialog` (list, add, edit name+kind dineIn/takeaway, delete).
* **Table Management:** Grid of `_TableManagementTile` (room badge, capacity, status). Actions: add table (name, zone dropdown, capacity, isRoom + hourlyRate when roomsEnabled), edit (same dialog prefilled), delete (blocked for non-available tables with snackbar). Mirrors PlayStation station management pattern.

#### 19g. Settings (Admin-Gated Sections)
* **Floor Section:** `roomsEnabled` toggle, `serviceChargeEnabled` + `serviceChargePercent`, `minChargeEnabled` + `minChargePerTablePiastres`.
* **Tickets Section:** 3 rows — kitchen/bar/shisha: `*TicketsEnabled` toggle + printer dropdown (reuse PrintingSection dropdown pattern). All under `if (isAdmin)`.
* **Guard Fix:** Previously `_BusinessTypeCard` (favorites strip, minimum game cost) rendered outside `isAdmin` — now gated. All new sections admin-only.

#### 19h. Receipts & Sales
* Table checkout → N `CreateReceipt` events → `ReceiptsBloc` → `ReceiptEntity` (same pipeline as retail: order#, itemized, shift audit, refunds). Sales workspace shows café receipts alongside retail. No separate "table record" type.

#### 19i. Deferred (Followups)
* Itemized split billing (per-guest line ownership).
* KDS (digital kitchen display screens).
* Table occupancy analytics in Sales.
* Draft lines not persisted on app restart.

---
