import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/table_form_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async => _store[key];
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
  late List<TableEntity?> results;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    results = [];
  });

  Widget buildTestWidget({
    TableEntity? table,
    AppSettingsEntity settings = const AppSettingsEntity(),
    List<ZoneEntity> zones = const [
      ZoneEntity(id: 'hall', name: 'Hall'),
      ZoneEntity(id: 'terrace', name: 'Terrace'),
    ],
  }) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>(
            create: (_) {
              final sBloc = SettingsBloc(
                repository: FakeSettingsRepository(settings),
              );
              sBloc.add(const LoadSettings());
              return sBloc;
            },
          ),
        ],
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    showDialog<TableEntity>(
                      context: context,
                      builder: (_) => BlocProvider<SettingsBloc>.value(
                        value: context.read<SettingsBloc>(),
                        child: TableFormDialog(table: table, zones: zones),
                      ),
                    ).then(results.add),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('TableFormDialog', () {
    testWidgets('pops a table with name, zone, capacity on submit', (
      tester,
    ) async {
      await openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'اسم الطاولة'),
        'T1',
      );
      await tester.enterText(find.widgetWithText(TextField, 'السعة'), '4');
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      final table = results.single;
      expect(table, isNotNull);
      expect(table!.id, 'T1');
      expect(table.name, 'T1');
      expect(table.zoneId, 'hall');
      expect(table.capacity, 4);
      expect(table.isRoom, isFalse);
      expect(table.status, TableStatus.available);
    });

    testWidgets('rejects empty name and zero capacity', (tester) async {
      await openDialog(tester);

      await tester.enterText(find.widgetWithText(TextField, 'السعة'), '0');
      await tester.enterText(
        find.widgetWithText(TextField, 'اسم الطاولة'),
        '   ',
      );
      await tester.tap(find.text('إضافة'));
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('selects a different zone from the dropdown', (tester) async {
      await openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'اسم الطاولة'),
        'T2',
      );
      await tester.tap(find.byKey(const Key('tableZoneDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terrace').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      expect(results.single!.zoneId, 'terrace');
    });

    testWidgets('shows room controls only when rooms enabled', (tester) async {
      await openDialog(tester);

      expect(find.byKey(const Key('tableIsRoomSwitch')), findsNothing);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(results.single, isNull);
    });

    testWidgets('room switch converts EGP hourly rate to piastres', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(settings: const AppSettingsEntity(roomsEnabled: true)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'اسم الطاولة'),
        'R1',
      );
      await tester.tap(find.byKey(const Key('tableIsRoomSwitch')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'سعر الساعة (ج.م)'),
        '12.5',
      );
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      final table = results.single!;
      expect(table.isRoom, isTrue);
      expect(table.hourlyRatePiastres, 1250);
    });

    testWidgets('prefills values when editing an existing table', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          table: const TableEntity(
            id: 't3',
            name: 'VIP',
            zoneId: 'terrace',
            capacity: 6,
            isRoom: true,
            hourlyRatePiastres: 2000,
          ),
          settings: const AppSettingsEntity(roomsEnabled: true),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('تعديل الطاولة'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'اسم الطاولة'))
            .controller!
            .text,
        'VIP',
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'السعة'))
            .controller!
            .text,
        '6',
      );
      // Rate prefill in EGP: 2000 piastres -> 20
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'سعر الساعة (ج.م)'),
            )
            .controller!
            .text,
        '20',
      );

      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final saved = results.single!;
      expect(saved.id, 't3');
      expect(saved.name, 'VIP');
      expect(saved.zoneId, 'terrace');
      expect(saved.capacity, 6);
      expect(saved.hourlyRatePiastres, 2000);
    });
  });
}
