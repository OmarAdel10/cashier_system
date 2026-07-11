import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/views/settings_workspace.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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
}

Widget _buildTestWidget(SettingsBloc bloc) {
  return MaterialApp(
    home: BlocProvider<SettingsBloc>.value(
      value: bloc,
      child: const SettingsWorkspace(),
    ),
  );
}

extension _Scroll on WidgetTester {
  Future<void> scrollToLocalization() async {
    await drag(find.byType(SettingsWorkspace), const Offset(0, -500));
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

  tearDown(() {
    bloc.close();
  });

  group('SettingsWorkspace', () {
    testWidgets('should render title and 6 sections', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Settings'), findsAtLeastNWidgets(1));
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Localization'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('Printing'), findsOneWidget);
      expect(find.text('Keyboard Shortcuts'), findsOneWidget);
    });

    testWidgets('should render sections as cards', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(7));
    });

    testWidgets('should show all fields in General section', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Store Name'), findsOneWidget);
      expect(find.text('Receipt Footnote'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('should update store name on text change', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'My Store');
      await tester.pump();

      expect(bloc.state.settings.storeName, 'My Store');
    });

    testWidgets('should update receipt footnote on text change', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.last, 'Thank you!');
      await tester.pump();

      expect(bloc.state.settings.receiptFootnote, 'Thank you!');
    });

    testWidgets('should show appearance section with dark mode toggle', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Light theme active'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('should toggle dark mode', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(bloc.state.settings.isDarkMode, true);
    });

    testWidgets('should show localization section with language options', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();
      await tester.scrollToLocalization();

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Arabic'), findsOneWidget);
    });

    testWidgets('should switch language to Arabic', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToLocalization();

      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.languageCode, 'ar');
    });

    testWidgets('should switch language to English', (tester) async {
      bloc.add(const LanguageToggled('ar'));
      await tester.pump();
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();
      await tester.scrollToLocalization();

      await tester.tap(find.text('الإنجليزية'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.languageCode, 'en');
    });

    testWidgets('should show directionality info banner', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();
      await tester.scrollToLocalization();

      expect(find.textContaining('English mode:'), findsOneWidget);
    });

    testWidgets('should scroll through all sections', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(7));
    });
  });
}
