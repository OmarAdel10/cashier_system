# Flutter Performance & Architecture Guidelines
## Project: Cashier System

### 1. Bloc State Selection: `context.select` over `context.watch`

**Rule:** Always use `context.select` with a field-level selector instead of `context.watch` on the entire Bloc state.

```dart
// BAD — rebuilds on any SettingsState change
final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

// GOOD — rebuilds only when languageCode changes
final langCode = context.select(
  (SettingsBloc b) => b.state.settings.languageCode,
);
```

**Rationale:** `context.watch` rebuilds the entire widget subtree on every Bloc state emission. `context.select` only rebuilds when the specific selected value changes — critical for widgets that only read one field (e.g., language code, tax percent) while other fields change frequently.

### 2. Local UI State: `ValueNotifier` over `setState`

**Rule:** Use `ValueNotifier<T>` + `ValueListenableBuilder` for local UI state instead of `setState` in `StatefulWidget`.

```dart
// BAD — rebuilds entire StatefulWidget
bool _submitting = false;
setState(() => _submitting = true);

// GOOD — only rebuilds the specific subtree
final _submittingNotifier = ValueNotifier(false);
_submittingNotifier.value = true;
ValueListenableBuilder<bool>(
  valueListenable: _submittingNotifier,
  builder: (_, submitting, __) => submitting ? LinearProgressIndicator() : SizedBox(),
);
```

**Rationale:** `setState` triggers a full rebuild of the widget and all its children. `ValueNotifier` + `ValueListenableBuilder` scopes rebuilds to only the widgets that depend on that value.

**Grouping Rule:** Group related boolean/numeric UI state fields into immutable `copyWith` classes:

```dart
class CaptureState {
  final bool shiftDown;
  final bool altDown;
  final LogicalKeyboardKey? capturedKey;
  
  const CaptureState({this.shiftDown = false, this.altDown = false, this.capturedKey});
  
  CaptureState copyWith({bool? shiftDown, bool? altDown, LogicalKeyboardKey? capturedKey}) => CaptureState(
    shiftDown: shiftDown ?? this.shiftDown,
    altDown: altDown ?? this.altDown,
    capturedKey: capturedKey ?? this.capturedKey,
  );
}

// Single notifier instead of 3
final _state = ValueNotifier(CaptureState());
```

### 3. Widget Extraction: No Private Inline Widgets Beyond ~20 Lines

**Rule:** Extract any private widget exceeding ~20 lines to a standalone public file in `widgets/` subdirectory.

```dart
// BAD — inline _FooWidget bloating parent file
class _MyWidget extends StatelessWidget { /* 25 lines */ }

// GOOD — extracted file
// lib/features/checkout/presentation/widgets/my_widget.dart
class MyWidget extends StatelessWidget {
  final String langCode;
  final VoidCallback onTap;
  // ...
}
```

**Explicit Dependencies:** Extracted widgets receive dependencies as explicit constructor parameters — they do NOT call `context.watch` or `context.read` for their inputs. This makes them testable and decouples them from ancestor widget structure.

### 4. `BlocBuilder` + `buildWhen`: Narrow Rebuild Scope

**Rule:** Add a `buildWhen` predicate to every `BlocBuilder` that does not need to rebuild on every state change.

```dart
BlocBuilder<SalesBloc, SalesState>(
  buildWhen: (prev, curr) =>
    prev.status != curr.status ||
    prev.todaySummary != curr.todaySummary ||
    prev.shiftReceipts != curr.shiftReceipts ||
    !listEquals(prev.months, curr.months),
  builder: (context, state) { /* ... */ },
);
```

**Rationale:** Without `buildWhen`, `BlocBuilder` rebuilds on every emission including background events (e.g., `LoadTodaySummary` triggering while `LoadShiftReceipts` is already displayed).

### 5. Hive API: `encryptionCipher` over `encryptionKey`

**Rule:** Use `HiveAesCipher(key)` instead of the deprecated raw `encryptionKey:` parameter.

```dart
// DEPRECATED
Box('settings', encryptionKey: key);

// CURRENT
Box('settings', encryptionCipher: HiveAesCipher(key));
```

### 6. State Widgets: Prefer `AppEmpty` / `AppLoading` / `AppError`

**Rule:** Use the canonical shared state widgets from `lib/core/widgets/` instead of ad-hoc inline state rendering.

| Widget | File | Use Case |
|---|---|---|
| `AppLoading` | `lib/core/widgets/app_loading.dart` | Medium-to-long operations — 2px hairline `LinearProgressIndicator` |
| `AppEmpty` | `lib/core/widgets/app_empty.dart` | Empty state — Duotone icon + headline + body + optional action |
| `AppError` | `lib/core/widgets/app_error.dart` | Error state — warning/xCircle icon + headline + retry `ElevatedButton` |

**Banned:** `CircularProgressIndicator` for loading states (continuous spin loop causes frame drops on integrated graphics). Use the typographic-only or hairline bar pattern instead (see `DESIGN.md` §6.2).
