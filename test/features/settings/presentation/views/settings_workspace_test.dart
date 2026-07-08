import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/views/settings_workspace.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

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

void main() {
  late SettingsBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    bloc = SettingsBloc();
  });

  tearDown(() {
    bloc.close();
  });

  group('SettingsWorkspace', () {
    testWidgets('should render 3 tabs', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Localization'), findsOneWidget);
    });

    testWidgets('should show General tab content by default', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pump();

      expect(find.text('Store Name'), findsOneWidget);
      expect(find.text('Receipt Footnote'), findsOneWidget);
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

    testWidgets('should switch to Appearance tab', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('should toggle dark mode', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.isDarkMode, true);
    });

    testWidgets('should switch to Localization tab', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Localization'));
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('should switch language to English', (tester) async {
      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Localization'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.languageCode, 'en');
    });

    testWidgets('should switch language to Arabic', (tester) async {
      bloc.add(const LanguageToggled('en'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_buildTestWidget(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Localization'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Arabic'));
      await tester.pumpAndSettle();

      expect(bloc.state.settings.languageCode, 'ar');
    });
  });
}
