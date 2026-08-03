import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/presentation/widgets/status_badge.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<SettingsBloc>.value(
        value: _settingsBloc,
        child: child,
      ),
    ),
  );
}

late SettingsBloc _settingsBloc;

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
    _settingsBloc = SettingsBloc(repository: FakeSettingsRepository());
    _settingsBloc.add(const LanguageToggled('en'));
  });

  tearDown(() {
    _settingsBloc.close();
  });

  group('StatusBadge', () {
    testWidgets('shows active status with green check icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(ReceiptStatus.active)));

      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.checkCircle), findsOneWidget);
    });

    testWidgets('shows returned status with red arrow icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(ReceiptStatus.returned)));

      expect(find.text('Returned'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.arrowArcLeft), findsOneWidget);
    });

    testWidgets('shows modified status with amber pencil icon', (tester) async {
      await tester.pumpWidget(_wrap(const StatusBadge(ReceiptStatus.modified)));

      expect(find.text('Modified'), findsOneWidget);
      expect(find.byIcon(PhosphorIcons.pencilSimple), findsOneWidget);
    });

    testWidgets('uses localized labels', (tester) async {
      _settingsBloc.add(const LanguageToggled('ar'));
      await tester.pump();

      await tester.pumpWidget(_wrap(const StatusBadge(ReceiptStatus.active)));

      expect(find.text('نشط'), findsOneWidget);
    });
  });
}
