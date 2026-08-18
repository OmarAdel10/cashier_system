import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/zone_management_dialog.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../checkout/helpers/fake_zone_repository.dart';
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
  late FakeZoneRepository repo;
  late ZoneBloc bloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    repo = FakeZoneRepository(const [
      ZoneEntity(id: 'hall', name: 'Hall'),
      ZoneEntity(id: 'street', name: 'Street', kind: ZoneKind.takeaway),
    ]);
    bloc = ZoneBloc(repository: repo)..add(const LoadZones());
  });

  tearDown(() {
    bloc.close();
  });

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<SettingsBloc>(
              create: (_) {
                final sBloc = SettingsBloc(
                  repository: FakeSettingsRepository(),
                );
                sBloc.add(const LoadSettings());
                return sBloc;
              },
            ),
            BlocProvider<ZoneBloc>.value(value: bloc),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => MultiBlocProvider(
                      providers: [
                        BlocProvider<SettingsBloc>.value(
                          value: context.read<SettingsBloc>(),
                        ),
                        BlocProvider<ZoneBloc>.value(value: bloc),
                      ],
                      child: const ZoneManagementDialog(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists zones with kind labels', (tester) async {
    await pumpDialog(tester);

    expect(find.text('إدارة المناطق'), findsOneWidget);
    expect(find.text('Hall'), findsOneWidget);
    expect(find.text('Street'), findsOneWidget);
    expect(find.text('داخلية'), findsOneWidget);
    expect(find.text('خارجية (استلام)'), findsOneWidget);
  });

  testWidgets('adds a zone through the form', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key('zoneAddButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المنطقة'),
      'Garden',
    );
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Garden'), findsOneWidget);
    expect(repo.all.any((z) => z.name == 'Garden'), isTrue);
  });

  testWidgets('edits a zone name', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key('zoneEdit_hall')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المنطقة'),
      'Main Hall',
    );
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Main Hall'), findsOneWidget);
    expect(
      repo.all.any((z) => z.id == 'hall' && z.name == 'Main Hall'),
      isTrue,
    );
  });

  testWidgets('deletes a zone after confirmation', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byKey(const Key('zoneDelete_hall')));
    await tester.pumpAndSettle();
    expect(find.text('حذف المنطقة'), findsOneWidget);
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Hall'), findsNothing);
    expect(repo.all.any((z) => z.id == 'hall'), isFalse);
  });
}
