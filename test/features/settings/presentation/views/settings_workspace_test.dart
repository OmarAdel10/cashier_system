import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/views/settings_workspace.dart';
import 'package:cashier_system/features/settings/presentation/widgets/printing_section.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../../auth/helpers/fake_auth_repository.dart';
import '../../helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}

  List<String> getKeys() => _store.keys.toList();
}

Widget _buildTestWidget(SettingsBloc bloc, {UserRole role = UserRole.admin}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<SettingsBloc>.value(value: bloc),
        BlocProvider<AuthBloc>(
          create: (_) =>
              AuthBloc(repository: FakeAuthRepository())
                ..add(const CheckAuth()),
        ),
      ],
      child: SettingsWorkspace(
        currentUser: UserEntity(
          username: role == UserRole.admin ? 'admin' : 'cashier1',
          passwordHash: '',
          role: role,
          createdAt: DateTime.now(),
        ),
      ),
    ),
  );
}

extension _Scroll on WidgetTester {
  Future<void> scrollToLocalization() async {
    await drag(find.byType(SettingsWorkspace), const Offset(0, -500));
    await pumpAndSettle();
  }

  Future<void> scrollToPrinting() async {
    await drag(find.byType(SettingsWorkspace), const Offset(0, -1200));
    await pumpAndSettle();
  }
}

void main() {
  late SettingsBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = SettingsBloc(repository: FakeSettingsRepository());
    bloc.add(const LanguageToggled('en'));
  });

  Future<void> pumpWithSize(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(widget);
  }

  tearDown(() {
    bloc.close();
  });

  group('SettingsWorkspace', () {
    testWidgets('should render title and 7 sections', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Settings'), findsAtLeastNWidgets(1));
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Localization'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Printing'), findsOneWidget);
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
      expect(find.text('Reset All Data'), findsAtLeastNWidgets(1));
    });

    testWidgets('should render sections as cards', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(12));
    });

    testWidgets('should hide Keyboard Shortcuts for non-admin users', (
      tester,
    ) async {
      await pumpWithSize(
        tester,
        _buildTestWidget(bloc, role: UserRole.cashier),
      );
      await tester.pump();

      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });

    testWidgets('should show all fields in General section', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Store Name'), findsOneWidget);
      expect(find.text('Receipt Footnote'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Store Name'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Receipt Footnote'),
        findsOneWidget,
      );
    });

    testWidgets('should update store name on text change', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Store Name'),
        'My Store',
      );
      await tester.pump();

      expect(bloc.state.settings.storeName, 'My Store');
    });

    testWidgets('should update receipt footnote on text change', (
      tester,
    ) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Receipt Footnote'),
        'Thank you!',
      );
      await tester.pump();

      expect(bloc.state.settings.receiptFootnote, 'Thank you!');
    });

    testWidgets('should show appearance section with dark mode toggle', (
      tester,
    ) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Light theme active'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(5));
    });

    testWidgets('should toggle dark mode', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      await tester.ensureVisible(find.byType(Switch).first);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(bloc.state.settings.isDarkMode, true);
    });

    testWidgets('should show localization section with language options', (
      tester,
    ) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();
      await tester.scrollToLocalization();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Arabic'), findsOneWidget);
    });

    testWidgets('should switch language to Arabic', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToLocalization();

      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.languageCode, 'ar');
    });

    testWidgets('should switch language to English', (tester) async {
      bloc.add(const LanguageToggled('ar'));
      await tester.pump();
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToLocalization();

      await tester.tap(find.text('الإنجليزية'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.languageCode, 'en');
    });

    testWidgets('should show directionality info banner', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();
      await tester.scrollToLocalization();

      expect(find.textContaining('English mode:'), findsOneWidget);
    });

    testWidgets('should scroll through all sections', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(12));
    });

    testWidgets('tax toggle should enable tax and show percent field', (
      tester,
    ) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToLocalization();
      await tester.drag(find.byType(SettingsWorkspace), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Enable Tax'), findsOneWidget);

      await tester.tap(find.text('Enable Tax'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.taxEnabled, true);
    });

    testWidgets('should autoPrint toggle should exist and toggle', (
      tester,
    ) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToPrinting();

      expect(find.text('Auto Print'), findsOneWidget);

      await tester.ensureVisible(find.text('Auto Print'));
      await tester.tap(find.text('Auto Print'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.autoPrintEnabled, true);
    });

    testWidgets('should show business type card with translated name', (
      tester,
    ) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();

      expect(find.text('Cafe'), findsAtLeastNWidgets(1));
      expect(find.text('Only changeable via factory reset'), findsOneWidget);
    });

    testWidgets('should show business type card for retail', (tester) async {
      final retailBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'retail'),
        ),
      );
      retailBloc.add(const LoadSettings());
      retailBloc.add(const LanguageToggled('en'));
      addTearDown(retailBloc.close);
      await pumpWithSize(tester, _buildTestWidget(retailBloc));
      await tester.pumpAndSettle();

      expect(find.text('Retail Store'), findsAtLeastNWidgets(1));
      expect(find.text('Only changeable via factory reset'), findsOneWidget);
    });

    testWidgets('should show business type card in Arabic', (tester) async {
      final arBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(
            businessType: 'playstation',
            languageCode: 'ar',
          ),
        ),
      );
      arBloc.add(const LoadSettings());
      addTearDown(arBloc.close);
      await pumpWithSize(tester, _buildTestWidget(arBloc));
      await tester.pumpAndSettle();

      expect(find.text('بلايستيشن'), findsAtLeastNWidgets(1));
      expect(find.text('يمكن تغييره فقط بإعادة ضبط المصنع'), findsOneWidget);
    });

    testWidgets('should hide business type card for non-admin cashier', (
      tester,
    ) async {
      await pumpWithSize(
        tester,
        _buildTestWidget(bloc, role: UserRole.cashier),
      );
      await tester.pump();

      expect(find.text('Retail Store'), findsNothing);
      expect(find.text('Only changeable via factory reset'), findsNothing);
    });

    testWidgets('business type card should not be tappable', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();

      final card = find
          .ancestor(of: find.text('Retail Store'), matching: find.byType(Card))
          .first;
      expect(
        find.descendant(of: card, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.byType(IconButton)),
        findsNothing,
      );
    });

    testWidgets('cafe should show favorites strip toggle and toggle it', (
      tester,
    ) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();

      final toggle = find.widgetWithText(
        SwitchListTile,
        'Favorites strip in checkout',
      );
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, false);
      expect(find.text('Minimum game cost (EGP)'), findsNothing);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(cafeBloc.state.settings.favoritesStripEnabled, true);
      expect(tester.widget<SwitchListTile>(toggle).value, true);
    });

    testWidgets('should hide favorites toggle for retail', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();

      expect(find.text('Favorites strip in checkout'), findsNothing);
    });

    testWidgets('should hide favorites toggle for playstation', (tester) async {
      final psBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'playstation'),
        ),
      );
      psBloc.add(const LoadSettings());
      psBloc.add(const LanguageToggled('en'));
      addTearDown(psBloc.close);
      await pumpWithSize(tester, _buildTestWidget(psBloc));
      await tester.pumpAndSettle();

      expect(find.text('Favorites strip in checkout'), findsNothing);
    });

    testWidgets('should hide minimum game cost for cafe', (tester) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();

      expect(find.text('Minimum game cost (EGP)'), findsNothing);
    });

    testWidgets('playstation should edit minimum game cost in EGP', (
      tester,
    ) async {
      final psBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(
            businessType: 'playstation',
            minimumGameCost: 500,
          ),
        ),
      );
      psBloc.add(const LoadSettings());
      psBloc.add(const LanguageToggled('en'));
      addTearDown(psBloc.close);
      await pumpWithSize(tester, _buildTestWidget(psBloc));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, 'Minimum game cost (EGP)');
      expect(field, findsOneWidget);
      expect(find.widgetWithText(TextField, '5.00'), findsOneWidget);

      await tester.enterText(field, '3.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(psBloc.state.settings.minimumGameCost, 350);
    });

    testWidgets('playstation minimum game cost clamps below 1 EGP', (
      tester,
    ) async {
      final psBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'playstation'),
        ),
      );
      psBloc.add(const LoadSettings());
      psBloc.add(const LanguageToggled('en'));
      addTearDown(psBloc.close);
      await pumpWithSize(tester, _buildTestWidget(psBloc));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, 'Minimum game cost (EGP)');
      await tester.enterText(field, '0.9');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(psBloc.state.settings.minimumGameCost, 100);
    });

    testWidgets('cafe hides shortcuts when favorites strip off', (
      tester,
    ) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(
            businessType: 'cafe',
            favoritesStripEnabled: false,
          ),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });

    testWidgets('cafe shows shortcuts when favorites strip on', (tester) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(
            businessType: 'cafe',
            favoritesStripEnabled: true,
          ),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    });

    testWidgets('playstation hides shortcuts section', (tester) async {
      final psBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'playstation'),
        ),
      );
      psBloc.add(const LoadSettings());
      psBloc.add(const LanguageToggled('en'));
      addTearDown(psBloc.close);
      await pumpWithSize(tester, _buildTestWidget(psBloc));
      await tester.pumpAndSettle();

      expect(find.text('Keyboard Shortcuts'), findsNothing);
    });

    testWidgets('retail shows both printer dropdowns', (tester) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToPrinting();

      expect(
        find.descendant(
          of: find.byType(PrintingSection),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('cafe hides barcode printer dropdown', (tester) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();
      await tester.scrollToPrinting();

      expect(
        find.descendant(
          of: find.byType(PrintingSection),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNWidgets(1),
      );
    });

    testWidgets('playstation hides both printer dropdowns', (tester) async {
      final psBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'playstation'),
        ),
      );
      psBloc.add(const LoadSettings());
      psBloc.add(const LanguageToggled('en'));
      addTearDown(psBloc.close);
      await pumpWithSize(tester, _buildTestWidget(psBloc));
      await tester.pumpAndSettle();
      await tester.scrollToPrinting();

      expect(
        find.descendant(
          of: find.byType(PrintingSection),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNothing,
      );
    });

    testWidgets('cafe admin shows floor and tickets sections', (tester) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SettingsWorkspace), const Offset(0, -2400));
      await tester.pumpAndSettle();

      expect(find.text('Floor'), findsOneWidget);
      expect(find.text('Kitchen tickets'), findsNWidgets(2));
    });

    testWidgets('cafe cashier hides floor and tickets sections', (
      tester,
    ) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(
        tester,
        _buildTestWidget(cafeBloc, role: UserRole.cashier),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SettingsWorkspace), const Offset(0, -2400));
      await tester.pumpAndSettle();

      expect(find.text('Floor'), findsNothing);
      expect(find.text('Kitchen tickets'), findsNothing);
    });

    testWidgets('retail admin hides floor and tickets sections', (
      tester,
    ) async {
      await pumpWithSize(tester, _buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SettingsWorkspace), const Offset(0, -2400));
      await tester.pumpAndSettle();

      expect(find.text('Floor'), findsNothing);
      expect(find.text('Kitchen tickets'), findsNothing);
    });

    testWidgets('cafe floor toggles update settings and show fields', (
      tester,
    ) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SettingsWorkspace), const Offset(0, -2400));
      await tester.pumpAndSettle();

      expect(cafeBloc.state.settings.roomsEnabled, false);
      await tester.tap(find.text('Rooms'));
      await tester.pumpAndSettle();
      expect(cafeBloc.state.settings.roomsEnabled, true);

      await tester.tap(find.text('Service charge'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Service charge %'),
        '15',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(cafeBloc.state.settings.serviceChargeEnabled, true);
      expect(cafeBloc.state.settings.serviceChargePercent, 15);

      await tester.tap(find.text('Minimum charge per table'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount (EGP)'),
        '25',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(cafeBloc.state.settings.minChargeEnabled, true);
      expect(cafeBloc.state.settings.minChargePerTablePiastres, 2500);
    });

    testWidgets('cafe tickets toggle updates settings', (tester) async {
      final cafeBloc = SettingsBloc(
        repository: FakeSettingsRepository(
          const AppSettingsEntity(businessType: 'cafe'),
        ),
      );
      cafeBloc.add(const LoadSettings());
      cafeBloc.add(const LanguageToggled('en'));
      addTearDown(cafeBloc.close);
      await pumpWithSize(tester, _buildTestWidget(cafeBloc));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SettingsWorkspace), const Offset(0, -2400));
      await tester.pumpAndSettle();

      expect(cafeBloc.state.settings.kitchenTicketsEnabled, true);
      expect(cafeBloc.state.settings.barTicketsEnabled, true);
      await tester.tap(find.text('Kitchen tickets').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bar tickets').last);
      await tester.pumpAndSettle();
      expect(cafeBloc.state.settings.kitchenTicketsEnabled, false);
      expect(cafeBloc.state.settings.barTicketsEnabled, false);
    });
  });
}
