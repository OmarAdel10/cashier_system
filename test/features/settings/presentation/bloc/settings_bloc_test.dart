import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_state.dart';
import '../../helpers/fake_settings_repository.dart';

void main() {
  late SettingsBloc bloc;
  late FakeSettingsRepository repository;

  setUp(() {
    repository = FakeSettingsRepository();
    bloc = SettingsBloc(repository: repository);
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

  group('persistence', () {
    test('should persist changes to repository and restore via LoadSettings',
        () async {
      bloc.add(const LanguageToggled('en'));
      await bloc.stream.first;

      final stored = await repository.getSettings();
      expect(stored.fold((_) => null, (s) => s.languageCode), 'en');

      bloc.add(const LoadSettings());
      await bloc.stream.first;
      await bloc.stream.first;

      expect(bloc.state.settings.languageCode, 'en');
      expect(bloc.state.status, SettingsStatus.ready);
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
}
