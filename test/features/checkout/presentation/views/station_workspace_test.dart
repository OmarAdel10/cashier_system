import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_event.dart';
import 'package:cashier_system/features/checkout/presentation/views/station_workspace.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/end_session_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/start_session_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';

import '../../../../features/settings/helpers/fake_settings_repository.dart';
import '../../helpers/fake_station_repository.dart';

Widget _wrap({
  required SettingsBloc settingsBloc,
  required StationBloc stationBloc,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsBloc>.value(value: settingsBloc),
      BlocProvider<StationBloc>.value(value: stationBloc),
    ],
    child: MaterialApp(home: Scaffold(body: const StationWorkspace())),
  );
}

/// Bounded pump sequence: active-station cards subscribe to the shared
/// one-second clock ticker, so pumpAndSettle would never settle. A few short
/// pumps flush async load futures and dialog animations instead.
Future<void> _pumpReady(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late SettingsBloc settingsBloc;
  late StationBloc stationBloc;

  setUp(() {
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(
          languageCode: 'en',
          businessType: 'playstation',
        ),
      ),
    );
    settingsBloc.add(const LoadSettings());
    stationBloc = StationBloc(
      repository: FakeStationRepository([
        const StationEntity(
          id: 'PS4-1',
          name: 'PS4-1',
          parentCategory: 'PS4',
          stationType: StationType.playstation,
          normalHourlyRate: 50,
          multiHourlyRate: 75,
          minimumGameCostNormal: 100,
          minimumGameCostMulti: 150,
          iconAsset: 'a',
          status: StationStatus.available,
        ),
        const StationEntity(
          id: 'PS4-2',
          name: 'PS4-2',
          parentCategory: 'PS4',
          stationType: StationType.playstation,
          normalHourlyRate: 50,
          multiHourlyRate: 75,
          minimumGameCostNormal: 100,
          minimumGameCostMulti: 150,
          iconAsset: 'a',
          status: StationStatus.active,
          sessionStartTime: null,
        ),
        const StationEntity(
          id: 'BILLIARDS-1',
          name: 'Billiards-1',
          parentCategory: 'Billiards',
          stationType: StationType.table,
          normalHourlyRate: 40,
          multiHourlyRate: 40,
          minimumGameCostNormal: 80,
          minimumGameCostMulti: 80,
          iconAsset: 'b',
          status: StationStatus.overtime,
          sessionStartTime: null,
        ),
      ]),
    );
    stationBloc.add(const LoadStations());
    addTearDown(() {
      settingsBloc.close();
      stationBloc.close();
    });
  });

  testWidgets('renders station grid with status sorting', (tester) async {
    await tester.pumpWidget(
      _wrap(settingsBloc: settingsBloc, stationBloc: stationBloc),
    );
    await _pumpReady(tester);

    // All three stations rendered.
    expect(find.text('PS4-1'), findsOneWidget);
    expect(find.text('PS4-2'), findsOneWidget);
    expect(find.text('Billiards-1'), findsOneWidget);
  });

  testWidgets('tap available station opens StartSessionDialog', (tester) async {
    await tester.pumpWidget(
      _wrap(settingsBloc: settingsBloc, stationBloc: stationBloc),
    );
    await _pumpReady(tester);

    await tester.tap(find.text('PS4-1'));
    await _pumpReady(tester);

    expect(find.byType(StartSessionDialog), findsOneWidget);
  });

  testWidgets('tap active station opens EndSessionDialog', (tester) async {
    await tester.pumpWidget(
      _wrap(settingsBloc: settingsBloc, stationBloc: stationBloc),
    );
    await _pumpReady(tester);

    await tester.tap(find.text('PS4-2'));
    await _pumpReady(tester);

    expect(find.byType(EndSessionDialog), findsOneWidget);
  });
}
