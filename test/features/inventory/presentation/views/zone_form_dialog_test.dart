import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/zone_form_dialog.dart';
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
  late List<ZoneEntity?> results;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    results = [];
  });

  Widget buildTestWidget({ZoneEntity? zone}) {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsBloc>(
            create: (_) {
              final sBloc = SettingsBloc(repository: FakeSettingsRepository());
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
                    showDialog<ZoneEntity>(
                      context: context,
                      builder: (_) => BlocProvider<SettingsBloc>.value(
                        value: context.read<SettingsBloc>(),
                        child: ZoneFormDialog(zone: zone),
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

  group('ZoneFormDialog', () {
    testWidgets('pops a dine-in zone with name as id', (tester) async {
      await openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'اسم المنطقة'),
        'Hall',
      );
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      final zone = results.single!;
      expect(zone.id, 'Hall');
      expect(zone.name, 'Hall');
      expect(zone.kind, ZoneKind.dineIn);
    });

    testWidgets('pops a takeaway zone when tab selected', (tester) async {
      await openDialog(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'اسم المنطقة'),
        'Street',
      );
      await tester.tap(find.text('خارجية (استلام)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة'));
      await tester.pumpAndSettle();

      expect(results.single!.kind, ZoneKind.takeaway);
    });

    testWidgets('rejects empty name', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('إضافة'));
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('prefills when editing and keeps id', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          zone: const ZoneEntity(
            id: 'hall',
            name: 'Hall',
            kind: ZoneKind.takeaway,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('تعديل المنطقة'), findsOneWidget);
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      final zone = results.single!;
      expect(zone.id, 'hall');
      expect(zone.name, 'Hall');
      expect(zone.kind, ZoneKind.takeaway);
    });
  });
}
