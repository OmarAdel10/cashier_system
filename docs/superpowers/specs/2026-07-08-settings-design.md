# Settings Feature — Design Document

> **Project:** Premium Stationery POS System (المكتبة) — MVP
> **Module:** D — Store Settings & Localization Profile
> **Date:** 2026-07-08

## Overview

The Settings feature provides a configuration workspace for store operators to manage:
- **Store Identity** (Store Name, Receipt Footnote)
- **Appearance** (Dark Mode / Light Mode)
- **Localization** (Arabic / English RTL switching)

All settings persist automatically to local disk via HydratedBloc + Hive with per-tab auto-save.

## Architecture

Feature-First Clean Architecture within `lib/features/settings/`:

```
lib/features/settings/
├── data/
│   ├── models/
│   │   └── app_settings_model.dart         # JSON/Hive serializable DTO
│   ├── repositories/
│   │   └── settings_repository.dart         # ISettingsRepository impl
│   └── services/
│       └── localization_service.dart        # O(1) Map-based translations
├── domain/
│   ├── entities/
│   │   └── app_settings_entity.dart         # Pure Dart immutable entity
│   └── repositories/
│       └── i_settings_repository.dart       # Abstract persistence contract
└── presentation/
    ├── bloc/
    │   ├── settings_event.dart              # Event union sealed class
    │   ├── settings_state.dart              # State wrapper with status enum
    │   └── settings_bloc.dart               # HydratedBloc orchestrator
    └── views/
        └── settings_workspace.dart          # Tabbed configuration UI
```

### Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Entity fields | languageCode, isDarkMode, storeName, receiptFootnote | Covers all PRD Module D requirements |
| State management | HydratedBloc + Hive 2.2 | Full offline-first with automatic JSON disk serialization |
| Save mechanism | Per-tab auto-save | Settings persist immediately on change — no Apply button needed |
| UI layout | 3-tabbed layout: General / Appearance / Localization | Scalable for future sections |
| Localization | Separate LocalizationService class | Clean separation from bloc logic, follows spec's O(1) Map pattern |
| Localization engine | `Map<String, Map<String, String>>` | No intl dependency — lightweight, O(1) lookup, enables client-side overrides |

## Domain Layer (Pure Dart)

### AppSettingsEntity

```dart
class AppSettingsEntity {
  final String languageCode;    // 'ar' | 'en'
  final bool isDarkMode;
  final String storeName;
  final String receiptFootnote;

  bool get isRtl => languageCode == 'ar';
  // == and hashCode overrides for deep equality
}
```

### ISettingsRepository

```dart
abstract class ISettingsRepository {
  Future<AppSettingsEntity> getSettings();
  Future<void> saveSettings(AppSettingsEntity settings);
}
```

## Data Layer

### AppSettingsModel

Extends `AppSettingsEntity` with `toJson()` / `factory fromJson()` and Hive `@HiveType`/`@HiveField` annotations for automatic adapter generation.

### SettingsRepository

Injects a Hive `Box<AppSettingsModel>`, implements `getSettings()` (reads from box, falls back to defaults) and `saveSettings()` (writes to box).

### LocalizationService

```dart
class LocalizationService {
  static const Map<String, Map<String, String>> _translations = {
    'ar': { 'appTitle': 'المكتبة - نظام نقاط البيع', ... },
    'en': { 'appTitle': 'Al-Maktaba - POS System', ... },
  };

  String translate(String key, {String? languageCode});
  List<String> get supportedLanguages; // ['ar', 'en']
}
```

## Presentation Layer

### SettingsEvent (sealed class)

- `LoadSettings`
- `LanguageToggled(String languageCode)`
- `ThemeToggled(bool isDarkMode)`
- `StoreNameChanged(String storeName)`
- `ReceiptFootnoteChanged(String footnote)`

### SettingsState

```dart
enum SettingsStatus { initial, loading, ready, error }

class SettingsState {
  final SettingsStatus status;
  final AppSettingsEntity settings;
  final String? errorMessage;
}
```

### SettingsBloc

`HydratedBloc<SettingsEvent, SettingsState>`:
- **Initial state:** `SettingsState(status: initial, settings: AppSettingsEntity())`
- **Event handling:** Each event creates a new `AppSettingsEntity` with the modified field and emits `SettingsState(status: ready, settings: updated)`
- **HydratedBloc hooks:** `fromJson`/`toJson` serializes via `AppSettingsModel`
- **Auto-save:** Every state emission triggers HydratedBloc's automatic disk persistence

### SettingsWorkspace (UI)

3-tab layout using `DefaultTabController`:

| Tab | Content | Widgets |
|---|---|---|
| **General** | Store Name, Receipt Footnote | `TextField`, `TextFormField` |
| **Appearance** | Dark Mode toggle | `Switch` + theme preview |
| **Localization** | Language selector | `SegmentedButton<String>` (EN / AR) |

Each change fires the corresponding bloc event immediately (per-tab auto-save).

## App Integration

### main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HydratedBloc.storage = await HydratedStorage.build();
  runApp(const App());
}
```

### App (app.dart)

- `BlocProvider<SettingsBloc>(create: ...)`
- `BlocBuilder<SettingsBloc, SettingsState>` → `MaterialApp`
- `theme`: Light mode using design tokens (#007ACC, #F8FAFC bg)
- `darkTheme`: Dark mode (#0F172A bg)
- `locale`: from `state.settings.languageCode`
- `textDirection`: from `state.settings.isRtl`

## Design Tokens Used

| Token | Light | Dark |
|---|---|---|
| Background | `#F8FAFC` | `#0F172A` |
| Card background | `#FFFFFF` | `#1E293B` |
| Primary | `#007ACC` | `#007ACC` |
| Success | `#10B981` | `#10B981` |
| Borders | `#E2E8F0` | `#334155` |
| Font | Cairo (Google Fonts) | Cairo |

## Data Flow

```
User switches language → SettingsBloc.add(LanguageToggled('en'))
  → SettingsBloc maps to new AppSettingsEntity(languageCode: 'en')
  → Emits SettingsState(status: ready, settings: updated)
  → HydratedBloc serializes to Hive (disk) automatically
  → BlocBuilder rebuilds MaterialApp with new locale/textDirection
  → LocalizationService.translate('appTitle', languageCode: 'en') returns English
```

## Testing Strategy

| Layer | Test focus |
|---|---|
| Entity | Default values, equality, isRtl logic |
| Model | toJson/fromJson round-trip, null handling |
| Repository | Hive box read/write, defaults fallback |
| Service | Translation lookups, missing key fallback |
| Bloc | Event → state mapping, HydratedBloc serialization |
| UI | Tab rendering, widget event firing, state changes |
