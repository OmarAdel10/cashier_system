import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_state.dart';
import '../../helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async {
    return _store[key];
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }

  @override
  Future<void> close() async {}
}

void main() {
  late SettingsBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = SettingsBloc(repository: FakeSettingsRepository());
  });

  tearDown(() {
    bloc.close();
  });

  group('initial state', () {
    test('should have initial status with default settings', () {
      expect(bloc.state.status, SettingsStatus.initial);
      expect(bloc.state.settings.languageCode, 'ar');
      expect(bloc.state.settings.isDarkMode, false);
      expect(bloc.state.settings.storeName, '');
      expect(bloc.state.settings.receiptFootnote, 'Thanks');
    });
  });

  group('LanguageToggled', () {
    test('should update languageCode and set ready status', () async {
      bloc.add(const LanguageToggled('en'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SettingsState>((state) =>
              state.settings.languageCode == 'en' &&
              state.status == SettingsStatus.ready),
        ]),
      );
    });
  });

  group('ThemeToggled', () {
    test('should update isDarkMode and set ready status', () async {
      bloc.add(const ThemeToggled(true));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SettingsState>((state) =>
              state.settings.isDarkMode == true &&
              state.status == SettingsStatus.ready),
        ]),
      );
    });
  });

  group('StoreNameChanged', () {
    test('should update storeName and set ready status', () async {
      bloc.add(const StoreNameChanged('My Store'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SettingsState>((state) =>
              state.settings.storeName == 'My Store' &&
              state.status == SettingsStatus.ready),
        ]),
      );
    });
  });

  group('ReceiptFootnoteChanged', () {
    test('should update receiptFootnote and set ready status', () async {
      bloc.add(const ReceiptFootnoteChanged('Thank you!'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SettingsState>((state) =>
              state.settings.receiptFootnote == 'Thank you!' &&
              state.status == SettingsStatus.ready),
        ]),
      );
    });
  });

  group('serialization', () {
    test('should persist and restore state via HydratedBloc', () async {
      bloc.add(const LanguageToggled('en'));
      await bloc.stream.first;

      final stored = await HydratedBloc.storage.read('SettingsBloc');
      expect(stored, isNotNull);
      expect((stored as Map)['languageCode'], 'en');
    });

    test('should serialize and deserialize correctly via fromJson/toJson', () {
      final toJsonResult = bloc.toJson(bloc.state);
      expect(toJsonResult, isA<Map<String, dynamic>>());
      expect(toJsonResult!['languageCode'], 'ar');
      expect(toJsonResult['isDarkMode'], false);

      final fromJsonResult = bloc.fromJson(toJsonResult);
      expect(fromJsonResult, isNotNull);
      expect(fromJsonResult!.settings.languageCode, 'ar');
      expect(fromJsonResult.settings.isDarkMode, false);
    });

    test('fromJson should handle malformed JSON gracefully', () {
      final result = bloc.fromJson(<String, dynamic>{});
      expect(result, isNotNull);
      expect(result!.status, SettingsStatus.ready);
    });
  });

  group('multiple events', () {
    test('should chain multiple changes correctly', () async {
      bloc.add(const LanguageToggled('en'));
      await bloc.stream.first;

      bloc.add(const ThemeToggled(true));
      await bloc.stream.first;

      bloc.add(const StoreNameChanged('Multi Store'));
      await bloc.stream.first;

      expect(bloc.state.settings.languageCode, 'en');
      expect(bloc.state.settings.isDarkMode, true);
      expect(bloc.state.settings.storeName, 'Multi Store');
    });
  });

  group('custom bindings', () {
    test('AddCustomBinding stores the combo', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;

      expect(bloc.state.settings.customBindings['cart.confirm'], ['f12']);
    });

    test('AddCustomBinding appends to existing combos', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;
      bloc.add(const AddCustomBinding('cart.confirm', 'ctrl+k'));
      await bloc.stream.first;

      expect(bloc.state.settings.customBindings['cart.confirm'], ['f12', 'ctrl+k']);
    });

    test('AddCustomBinding dedupes identical combos', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;

      expect(bloc.state.settings.customBindings['cart.confirm'], ['f12']);
    });

    test('AddCustomBinding steals combo from other actions', () async {
      bloc.add(const AddCustomBinding('nav.inventory', 'f1'));
      await bloc.stream.first;

      final bindings = bloc.state.settings.customBindings;
      expect(bindings['nav.inventory'], ['f1']);
      expect(bindings['nav.checkout'], []);
    });

    test('RemoveCustomBinding removes only the given combo', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;
      bloc.add(const AddCustomBinding('cart.confirm', 'ctrl+k'));
      await bloc.stream.first;

      bloc.add(const RemoveCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;

      expect(bloc.state.settings.customBindings['cart.confirm'], ['ctrl+k']);
    });

    test('RemoveCustomBinding keeps empty list as explicit unbind marker',
        () async {
      bloc.add(const AddCustomBinding('search.toggle', 'f5'));
      await bloc.stream.first;

      bloc.add(const RemoveCustomBinding('search.toggle', 'f5'));
      await bloc.stream.first;

      expect(bloc.state.settings.customBindings.containsKey('search.toggle'), isTrue);
      expect(bloc.state.settings.customBindings['search.toggle'], isEmpty);
    });

    test('ResetCustomBinding removes the key entirely', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;

      bloc.add(const ResetCustomBinding('cart.confirm'));
      await bloc.stream.first;

      expect(bloc.state.settings.customBindings.containsKey('cart.confirm'), isFalse);
    });

    test('customBindings survive fromJson/toJson round-trip', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;
      bloc.add(const AddCustomBinding('search.toggle', 'f5'));
      await bloc.stream.first;

      final json = bloc.toJson(bloc.state);
      expect(json!['customBindings']['cart.confirm'], ['f12']);

      final restored = bloc.fromJson(json)!;
      expect(restored.settings.customBindings['cart.confirm'], ['f12']);
      expect(restored.settings.customBindings['search.toggle'], ['f5']);
    });
  });
}
