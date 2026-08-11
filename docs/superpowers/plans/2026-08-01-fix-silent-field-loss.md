# Fix Silent Field Loss (notes + stockFailedBarcodes) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop two confirmed silent data-loss bugs: `ProductEntity.notes` wiped on every product save/stock/tile operation (plus never reaching persistence at all), and `ReceiptEntity.stockFailedBarcodes` dropped on receipt save causing double stock deduction on startup retry.

**Architecture:** Same threading pattern established by commit 116dea4 (purchasePrice): field exists on entity+model+adapter but is omitted at reconstruction sites. Fix = thread the field through every reconstruction boundary — event, bloc handler, dispatch callers, repository constructions, HydratedBloc toJson — and lock each boundary with a test. Both bugs are independent subsystems (inventory vs receipts) but share the same root-cause class; Tasks 1-3 fix notes, Task 4 fixes stockFailedBarcodes.

**Tech Stack:** Flutter, Dart, flutter_bloc + hydrated_bloc, hive (hand-written TypeAdapters, no codegen), flutter_test. No new dependencies.

## Global Constraints

- Commit format per `specs/DEVELOPMENT_ENVIRONMENT.md` section 3: `<emoji> <type>(<scope>): <summary>` — subject under 50 chars, imperative mood, single quotes ONLY (never double quotes). Use `🐞 fix(...)`. Legend: 🐣 feat, 🐞 fix, 📄 docs, 🎨 style, ✏️ refactor, ⚡ perf, 🏗️ chore.
- Never edit `lib/features/*/domain/entities/*.dart` or `lib/features/*/data/models/*.dart` in this plan — entity/model/adapter already carry both fields correctly (verified: ProductEntity.notes at product_entity.dart:9, model id 6; ReceiptEntity.stockFailedBarcodes at receipt_entity.dart:19 with copyWith + clear flags).
- Do not touch `product_form_dialog.dart` — it already returns `notes: nt` in its popped ProductEntity (product_form_dialog.dart:123-133).
- Follow existing code style: no added comments unless surrounding code has them.
- Every task ends with `flutter test <target>` green and a spec-formatted commit.

---

### Task 1: Thread `notes` through AddProduct event, dispatch callers, and bloc handler

**Files:**
- Modify: `lib/features/inventory/presentation/bloc/inventory_event.dart:9-27` (AddProduct)
- Modify: `lib/features/inventory/presentation/views/inventory_workspace.dart:122-130` (both dispatch sites)
- Modify: `lib/presentation/app_shell.dart:342-352` (shortcut-gate dispatch)
- Modify: `lib/features/inventory/presentation/bloc/inventory_bloc.dart:49-57` (`_onAddProduct`)
- Test: `test/features/inventory/presentation/bloc/inventory_bloc_test.dart` (AddProduct test)

**Interfaces:**
- Consumes: `ProductEntity` already has `String notes` (default `''`); `ProductFormDialog` already returns it.
- Produces: `AddProduct` gains `final String notes;` (ctor param `this.notes = ''`). `_onAddProduct` passes `notes: event.notes`.

- [ ] **Step 1: Write the failing bloc test**

In `test/features/inventory/presentation/bloc/inventory_bloc_test.dart`, find the existing AddProduct test (~L74-155). Add assertion that the emitted/state entity carries `notes`. Example:

```dart
test('AddProduct preserves notes', () async {
  final bloc = InventoryBloc(repository: repository, storage: fakeStorage);
  bloc.add(const AddProduct(
    barcode: 'x1', name: 'X', price: 10, purchasePrice: 5, stock: 3,
    isQuickTile: false, notes: 'shelf 2',
  ));
  // assert state.inventoryMap['x1'].notes == 'shelf 2'
});
```

Run: `flutter test test/features/inventory/presentation/bloc/inventory_bloc_test.dart`
Expected: FAIL — `notes` is not a named parameter of `AddProduct`.

- [ ] **Step 2: Add `notes` to `AddProduct` event**

`inventory_event.dart` — after `tileColorHex`:

```dart
  final String notes;

  const AddProduct({
    required this.barcode,
    required this.name,
    this.price = 0.0,
    this.purchasePrice = 0.0,
    this.stock = 0,
    this.isQuickTile = false,
    this.tileColorHex,
    this.notes = '',
  });
```

- [ ] **Step 3: Update the 3 dispatch callers**

`inventory_workspace.dart:123` and `:128` — append `notes: r.notes,` to each `AddProduct(...)`.
`app_shell.dart` shortcut-gate dispatch (`r` is the dialog result) — append `notes: r.notes,` before the closing paren (check the full call: `AddProduct(barcode: r.barcode, ..., tileColorHex: r.tileColorHex, notes: r.notes)`).

- [ ] **Step 4: Update `_onAddProduct`**

`inventory_bloc.dart:49-57` — add `notes: event.notes,` to the `ProductEntity(...)` construction.

- [ ] **Step 5: Run bloc test**

Run: `flutter test test/features/inventory/presentation/bloc/inventory_bloc_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/inventory/presentation/bloc/inventory_event.dart lib/features/inventory/presentation/bloc/inventory_bloc.dart lib/features/inventory/presentation/views/inventory_workspace.dart lib/presentation/app_shell.dart test/features/inventory/presentation/bloc/inventory_bloc_test.dart
git commit -m "🐞 fix(inventory): thread notes through AddProduct path"
```

---

### Task 2: Preserve `notes` at all 4 repository construction sites

**Files:**
- Modify: `lib/features/inventory/data/repositories/inventory_repository.dart:31-39, 80-88, 103-111, 132-140`
- Test: `test/features/inventory/data/repositories/inventory_repository_test.dart`

**Interfaces:**
- Consumes: `AppProductModel` carries `notes` (field id 6, adapter byte count already 8). `ProductEntity.notes` (default `''`).
- Produces: All 4 `AppProductModel(...)` constructions preserve `notes` from source.

- [ ] **Step 1: Write failing repository tests**

In `inventory_repository_test.dart`, follow the existing saveProduct round-trip pattern (~L60-80) and preservation-assert pattern (~L161-237). Add `notes: 'shelf 3'` to the saved product and assert round-trip; then assert preservation for toggleQuickTile, updateTileColor, updateStock (each test: create product with notes, run op, read back, expect `notes == 'shelf 3'`).

Run: `flutter test test/features/inventory/data/repositories/inventory_repository_test.dart`
Expected: FAIL — read-back `notes` is empty.

- [ ] **Step 2: Thread `notes` through 4 sites**

`inventory_repository.dart`:
- `saveProduct` (~L31): add `notes: product.notes,`
- `toggleQuickTile` (~L80): add `notes: model.notes,`
- `updateTileColor` (~L103): add `notes: model.notes,`
- `updateStock` (~L132): add `notes: model.notes,`

(Source names vary — read each site: saveProduct takes `product` param; the other three take/rebuild `model`.)

- [ ] **Step 3: Run repository tests**

Run: `flutter test test/features/inventory/data/repositories/inventory_repository_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/inventory/data/repositories/inventory_repository.dart test/features/inventory/data/repositories/inventory_repository_test.dart
git commit -m "🐞 fix(inventory): preserve notes on product writes"
```

---

### Task 3: Preserve `notes` in HydratedBloc toJson + regression helpers

**Files:**
- Modify: `lib/features/inventory/presentation/bloc/inventory_bloc.dart:173-181` (`toJson`)
- Modify: `test/helpers/default_product.dart` (add optional `String notes = ''` param)
- Test: `test/features/inventory/presentation/bloc/inventory_bloc_test.dart` (hydration round-trip test ~L154-180)

**Interfaces:**
- Consumes: `AppProductModel.toJson()` already emits `'notes'` key (model toJson verified complete in sweep).
- Produces: Hydrated cache JSON preserves `notes`.

- [ ] **Step 1: Write failing hydration assertion**

In the existing hydration test (asserts purchasePrice survives toJson/fromJson round-trip), seed state with a product carrying `notes: 'keep me'` and assert the restored state entity has `notes == 'keep me'`.

Run: `flutter test test/features/inventory/presentation/bloc/inventory_bloc_test.dart`
Expected: FAIL — toJson omits notes.

- [ ] **Step 2: Fix `toJson`**

`inventory_bloc.dart` toJson `AppProductModel(...)` construction — add `notes: p.notes,`.

- [ ] **Step 3: Update `default_product.dart`**

Add `String notes = ''` optional param, pass `notes: notes` to `ProductEntity(...)` (keeps all existing call sites compiling).

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/inventory/presentation/bloc/inventory_bloc_test.dart test/helpers/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/inventory/presentation/bloc/inventory_bloc.dart test/helpers/default_product.dart test/features/inventory/presentation/bloc/inventory_bloc_test.dart
git commit -m "🐞 fix(inventory): keep notes in hydrated cache"
```

---

### Task 4: Preserve `stockFailedBarcodes` on receipt save

**Files:**
- Modify: `lib/features/receipts/data/repositories/receipts_repository_impl.dart:15-31` (`save`)
- Test: `test/features/receipts/data/repositories/receipts_repository_impl_test.dart`

**Interfaces:**
- Consumes: `ReceiptEntity.stockFailedBarcodes` (`List<String>`, default `const []`, receipt_entity.dart:19/37). `AppReceiptModel` supports it (model field id 13, adapter byte 16 — verified balanced).
- Produces: `ReceiptsRepositoryImpl.save` persists `stockFailedBarcodes`. This fixes double stock deduction at `app_shell.dart:178` → `retryPendingStockUpdates()` (`receipts_bloc.dart:64-66` falls back to ALL item barcodes when the list is empty).

- [ ] **Step 1: Write failing repository test**

In `receipts_repository_impl_test.dart`, follow the existing save/read pattern. Save a `ReceiptEntity` with `stockUpdated: false, stockFailedBarcodes: ['b1', 'b2']`, read back, assert `stockFailedBarcodes` equals `['b1', 'b2']`.

Run: `flutter test test/features/receipts/data/repositories/receipts_repository_impl_test.dart`
Expected: FAIL — read-back list is empty.

- [ ] **Step 2: Fix `save()`**

`receipts_repository_impl.dart` `AppReceiptModel(...)` — add `stockFailedBarcodes: receipt.stockFailedBarcodes,` after `taxPercent:`.

- [ ] **Step 3: Run test**

Run: `flutter test test/features/receipts/data/repositories/receipts_repository_impl_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/receipts/data/repositories/receipts_repository_impl.dart test/features/receipts/data/repositories/receipts_repository_impl_test.dart
git commit -m "🐞 fix(receipts): persist stockFailedBarcodes on save"
```

---

### Task 5: Full verification

- [ ] **Step 1: Static analysis**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: All pass (previous baseline 553; expect 553+ new cases).

- [ ] **Step 3: Commit any residual changes (docs)**

```bash
git add docs/superpowers/plans/2026-08-01-fix-silent-field-loss.md
git commit -m "📄 docs: add silent field loss fix plan"
```

## Self-Review

- Spec coverage: notes threading (event → callers → bloc → 4 repo sites → toJson) = Tasks 1-3; stockFailedBarcodes = Task 4; analyze + full suite = Task 5. No gaps.
- Placeholder scan: every step has concrete code or an exact command; no TBD/TODO.
- Type consistency: `notes` is `String` (default `''`) everywhere — matches `product_entity.dart:9,19`; `stockFailedBarcodes` is `List<String>` matching `receipt_entity.dart:19,37` and `receipts_bloc.dart:64-66` usage.
- Boundary check: dialog already returns notes (product_form_dialog.dart:123-133) — no dialog change needed; verified during plan research.
