import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/station_form_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';

const _addButton = 'Add';
const _cancelButton = 'Cancel';
const _newStationTitle = 'New Station';

void main() {
  late List<StationEntity?> results;

  setUp(() {
    results = [];
  });

  Widget buildTestWidget({
    StationEntity? station,
    AppSettingsEntity settings = const AppSettingsEntity(languageCode: 'en'),
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
                    showDialog<StationEntity>(
                      context: context,
                      builder: (_) => MultiBlocProvider(
                        providers: [
                          BlocProvider<SettingsBloc>.value(
                            value: context.read<SettingsBloc>(),
                          ),
                        ],
                        child: StationFormDialog(station: station),
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

  testWidgets('adds a new station via form', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(_newStationTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'PS4-1');
    await tester.enterText(find.byType(TextField).at(1), 'PS4');
    await tester.enterText(find.byType(TextField).at(2), '50');
    await tester.enterText(find.byType(TextField).at(3), '75');
    await tester.enterText(find.byType(TextField).at(4), '100');
    await tester.enterText(find.byType(TextField).at(5), '150');
    await tester.tap(find.text(_addButton));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    final station = results.single!;
    expect(station.id, 'PS4-1');
    expect(station.name, 'PS4-1');
    expect(station.parentCategory, 'PS4');
    expect(station.stationType, StationType.playstation);
    expect(station.normalHourlyRate, 50);
    expect(station.multiHourlyRate, 75);
    expect(station.minimumGameCostNormal, 100);
    expect(station.minimumGameCostMulti, 150);
  });

  testWidgets('edits existing station preserving id and status', (
    tester,
  ) async {
    const existing = StationEntity(
      id: 'PS4-1',
      name: 'PS4-1',
      parentCategory: 'PS4',
      stationType: StationType.playstation,
      normalHourlyRate: 50,
      multiHourlyRate: 75,
      minimumGameCostNormal: 100,
      minimumGameCostMulti: 150,
      iconAsset: 'assets/icons/ps4.svg',
      status: StationStatus.active,
    );

    await tester.pumpWidget(buildTestWidget(station: existing));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Station'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'PS4-2');
    await tester.enterText(find.byType(TextField).at(2), '55');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    final station = results.single!;
    expect(station.id, 'PS4-1');
    expect(station.name, 'PS4-2');
    expect(station.normalHourlyRate, 55);
    expect(station.status, StationStatus.active);
  });
}
