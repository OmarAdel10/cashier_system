import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/end_session_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_station_repository.dart';

const _station = StationEntity(
  id: 'PS4-1',
  name: 'PS4-1',
  parentCategory: 'PS4',
  stationType: StationType.playstation,
  normalHourlyRate: 50,
  multiHourlyRate: 75,
  minimumGameCostNormal: 100,
  minimumGameCostMulti: 150,
  iconAsset: 'a',
  status: StationStatus.active,
  sessionStartTime: null,
);

Widget _wrap({
  required SettingsBloc settingsBloc,
  required StationBloc stationBloc,
  StationEntity? station,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: settingsBloc),
      BlocProvider<StationBloc>.value(value: stationBloc),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => EndSessionDialog(station: station ?? _station),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late SettingsBloc settingsBloc;
  late StationBloc stationBloc;

  setUp(() {
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(languageCode: 'en'),
      ),
    );
    settingsBloc.add(const LoadSettings());
    stationBloc = StationBloc(repository: FakeStationRepository([_station]));
    stationBloc.add(const LoadStations());
  });

  tearDown(() {
    settingsBloc.close();
    stationBloc.close();
  });

  testWidgets('renders title, tier, running total and confirm', (tester) async {
    await tester.pumpWidget(
      _wrap(settingsBloc: settingsBloc, stationBloc: stationBloc),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('End Session: PS4-1'), findsOneWidget);
    expect(find.text('Normal (1-2 controllers)'), findsOneWidget);
    expect(find.textContaining('Total:'), findsOneWidget);
    expect(find.text('End Session'), findsOneWidget);
  });

  testWidgets('confirm dispatches EndSession', (tester) async {
    await tester.pumpWidget(
      _wrap(settingsBloc: settingsBloc, stationBloc: stationBloc),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Session'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(stationBloc.state.stations.first.status, StationStatus.available);
  });

  testWidgets('shows booked duration for fixed duration session', (
    tester,
  ) async {
    final fixed = StationEntity(
      id: 'PS4-1',
      name: 'PS4-1',
      parentCategory: 'PS4',
      stationType: StationType.playstation,
      normalHourlyRate: 50,
      multiHourlyRate: 75,
      minimumGameCostNormal: 100,
      minimumGameCostMulti: 150,
      iconAsset: 'a',
      status: StationStatus.active,
      sessionStartTime: null,
      isFixedDuration: true,
      fixedDurationMinutes: 120,
    );

    await tester.pumpWidget(
      _wrap(
        settingsBloc: settingsBloc,
        stationBloc: stationBloc,
        station: fixed,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Booked duration: 120 min'), findsOneWidget);
  });
}
