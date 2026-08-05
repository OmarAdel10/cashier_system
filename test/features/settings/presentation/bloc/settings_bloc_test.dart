import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/settings/data/models/app_settings_model.dart';
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
          predicate<SettingsState>(
            (state) =>
                state.settings.languageCode == 'en' &&
                state.status == SettingsStatus.ready,
          ),
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
          predicate<SettingsState>(
            (state) =>
                state.settings.isDarkMode == true &&
                state.status == SettingsStatus.ready,
          ),
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
          predicate<SettingsState>(
            (state) =>
                state.settings.storeName == 'My Store' &&
                state.status == SettingsStatus.ready,
          ),
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
          predicate<SettingsState>(
            (state) =>
                state.settings.receiptFootnote == 'Thank you!' &&
                state.status == SettingsStatus.ready,
          ),
        ]),
      );
    });
  });

  group('persistence', () {
    test(
      'should persist changes to repository and restore via LoadSettings',
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
      },
    );
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

      expect(bloc.state.settings.customBindings['cart.confirm'], [
        'f12',
        'ctrl+k',
      ]);
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

    test('AddCustomBinding keeps other custom combos of the victim action '
        '(no wipe)', () async {
      bloc.add(const AddCustomBinding('nav.sales', 'f7'));
      await bloc.stream.first;

      bloc.add(const AddCustomBinding('cart.confirm', 'f3'));
      await bloc.stream.first;

      final bindings = bloc.state.settings.customBindings;
      expect(bindings['nav.sales'], ['f7']);
      expect(bindings['cart.confirm'], ['f3']);
    });

    test('RemoveCustomBinding restores defaults of steal-marker victims '
        '(key dropped)', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f3'));
      await bloc.stream.first;
      expect(bloc.state.settings.customBindings['nav.sales'], isEmpty);

      bloc.add(const RemoveCustomBinding('cart.confirm', 'f3'));
      await bloc.stream.first;

      final bindings = bloc.state.settings.customBindings;
      expect(bindings.containsKey('nav.sales'), isFalse);
      expect(bindings.containsKey('cart.confirm'), isFalse);
    });

    test('RemoveCustomBinding keeps steal marker while another action still '
        'holds the stolen default', () async {
      bloc.add(const AddCustomBinding('nav.inventory', 'f1'));
      await bloc.stream.first;
      bloc.add(const AddCustomBinding('nav.sales', 'f1'));
      await bloc.stream.first;

      bloc.add(const RemoveCustomBinding('nav.inventory', 'f1'));
      await bloc.stream.first;

      final bindings = bloc.state.settings.customBindings;
      expect(
        bindings['nav.checkout'],
        isEmpty,
        reason: 'nav.checkout default f1 still held by nav.sales',
      );
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

    test('RemoveCustomBinding restores defaults when no custom combos remain '
        '(key dropped)', () async {
      bloc.add(const AddCustomBinding('search.toggle', 'f5'));
      await bloc.stream.first;

      bloc.add(const RemoveCustomBinding('search.toggle', 'f5'));
      await bloc.stream.first;

      expect(
        bloc.state.settings.customBindings.containsKey('search.toggle'),
        isFalse,
        reason:
            'no steal in play - removing the last custom combo must '
            'restore defaults, not keep an unbind marker',
      );
    });

    test('ResetCustomBinding removes the key entirely', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;

      bloc.add(const ResetCustomBinding('cart.confirm'));
      await bloc.stream.first;

      expect(
        bloc.state.settings.customBindings.containsKey('cart.confirm'),
        isFalse,
      );
    });

    test('customBindings survive fromJson/toJson round-trip', () async {
      bloc.add(const AddCustomBinding('cart.confirm', 'f12'));
      await bloc.stream.first;
      bloc.add(const AddCustomBinding('search.toggle', 'f5'));
      await bloc.stream.first;

      final model = AppSettingsModel(
        languageCode: bloc.state.settings.languageCode,
        isDarkMode: bloc.state.settings.isDarkMode,
        storeName: bloc.state.settings.storeName,
        receiptFootnote: bloc.state.settings.receiptFootnote,
        customBindings: bloc.state.settings.customBindings,
        taxEnabled: bloc.state.settings.taxEnabled,
        taxPercent: bloc.state.settings.taxPercent,
        autoPrintEnabled: bloc.state.settings.autoPrintEnabled,
        orderCounter: bloc.state.settings.orderCounter,
        lastOrderDate: bloc.state.settings.lastOrderDate,
        exportDirectoryPath: bloc.state.settings.exportDirectoryPath,
        saveReceiptAsImage: bloc.state.settings.saveReceiptAsImage,
        storeAddress: bloc.state.settings.storeAddress,
        storePhoneNumber: bloc.state.settings.storePhoneNumber,
        logoSvgData: bloc.state.settings.logoSvgData,
        receiptPrinterName: bloc.state.settings.receiptPrinterName,
        barcodePrinterName: bloc.state.settings.barcodePrinterName,
        barcodeActionPreference: bloc.state.settings.barcodeActionPreference,
        shownPaymentTypeIds: bloc.state.settings.shownPaymentTypeIds,
      );
      final json = model.toJson();
      expect(json['customBindings']['cart.confirm'], ['f12']);

      final restored = AppSettingsModel.fromJson(json).toEntity();
      expect(restored.customBindings['cart.confirm'], ['f12']);
      expect(restored.customBindings['search.toggle'], ['f5']);
    });
  });
}
