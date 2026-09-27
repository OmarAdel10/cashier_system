// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/admin_shell.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/dashboard_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/models.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;

  setUpAll(() {
    registerFallbackValue(const DashboardError(messageAr: 'fallback'));
  });

  setUp(() {
    api = MockApiClient();
  });

  group('DashboardBloc', () {
    test(
      'OverviewRequested loads the four sources → DashboardLoaded',
      () async {
        when(() => api.get('/admin/overview', idToken: 'tok')).thenAnswer(
          (_) async => const Right({
            'ok': true,
            'data': {
              'stats': {'saleCount': 12, 'totalPiastres': 450000},
              'active_sessions': 2,
            },
          }),
        );
        when(() => api.get('/admin/devices', idToken: 'tok')).thenAnswer(
          (_) async => const Right({
            'ok': true,
            'data': {
              'devices': [
                {
                  'device_hwid': 'hw1',
                  'device_name': 'Main Counter',
                  'platform': 'linux',
                  'last_seen_at': 1,
                  'active_session': {
                    'id': 's1',
                    'username': 'admin',
                    'started_at': 5,
                  },
                },
              ],
            },
          }),
        );
        when(() => api.get('/admin/activity', idToken: 'tok')).thenAnswer(
          (_) async => const Right({
            'ok': true,
            'data': {
              'events': [
                {'type': 'sale', 'at': 9, 'summary': '50.00 EGP'},
              ],
            },
          }),
        );
        when(() => api.get('/sessions/active', idToken: 'tok')).thenAnswer(
          (_) async => const Right({
            'ok': true,
            'data': {
              'sessions': [
                {
                  'id': 's1',
                  'username': 'admin',
                  'device_hwid': 'hw1',
                  'started_at': 5,
                  'heartbeat_at': 9,
                },
              ],
            },
          }),
        );

        final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
        final states = <DashboardState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const OverviewRequested());
        await bloc.stream.firstWhere((s) => s is DashboardLoaded);
        final loaded = states.last as DashboardLoaded;
        expect(loaded.stats.saleCount, 12);
        expect(loaded.stats.totalPiastres, 450000);
        expect(loaded.stats.activeSessions, 2);
        expect(loaded.stats.devicesOnline, 1);
        expect(loaded.stats.alerts, 0);
        expect(loaded.devices, hasLength(1));
        expect(loaded.devices.first.activeUsername, 'admin');
        expect(loaded.activity, hasLength(1));
        expect(loaded.activeSessions, hasLength(1));
        await sub.cancel();
        await bloc.close();
      },
    );

    test('missing token → DashboardError', () async {
      final bloc = DashboardBloc(api: api, tokenProvider: () async => null);
      final states = <DashboardState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const OverviewRequested());
      await bloc.stream.firstWhere((s) => s is DashboardError);
      expect(states.last, isA<DashboardError>());
      await sub.cancel();
      await bloc.close();
    });

    test('failed overview fetch → DashboardError', () async {
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => const Left(DatabaseFailure('down')));
      final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
      final states = <DashboardState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const OverviewRequested());
      await bloc.stream.firstWhere((s) => s is DashboardError);
      expect(states.last, isA<DashboardError>());
      await sub.cancel();
      await bloc.close();
    });

    test('RealtimeEventReceived triggers a refresh', () async {
      var calls = 0;
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async {
        calls++;
        return const Right(<String, dynamic>{'ok': true});
      });
      final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
      bloc.add(const OverviewRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const RealtimeEventReceived({'type': 'sale'}));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, greaterThanOrEqualTo(8)); // 4 sources x 2 rounds
      await bloc.close();
    });
  });

  group('AdminShell (responsive)', () {
    void stubApi() {
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((inv) {
        final path = inv.positionalArguments[0] as String;
        final now = DateTime.now().millisecondsSinceEpoch;
        return switch (path) {
          '/admin/overview' => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {
                'stats': {'saleCount': 12, 'totalPiastres': 450000},
                'active_sessions': 1,
              },
            }),
          ),
          '/admin/devices' => Future.value(
            Right(<String, dynamic>{
              'ok': true,
              'data': {
                'devices': [
                  {
                    'device_hwid': 'hw1',
                    'device_name': 'Main Counter',
                    'platform': 'linux',
                    'last_seen_at': now,
                    'active_session': {
                      'id': 's1',
                      'username': 'admin',
                      'started_at': 5,
                    },
                  },
                  {
                    'device_hwid': 'hw2',
                    'device_name': 'Back Office',
                    'platform': 'windows',
                    'last_seen_at': now - 600000,
                  },
                ],
              },
            }),
          ),
          '/admin/activity' => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {
                'events': [
                  {'type': 'sale', 'at': 9, 'summary': '120.00 EGP'},
                ],
              },
            }),
          ),
          _ => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {
                'sessions': [
                  {
                    'id': 's1',
                    'username': 'admin',
                    'device_hwid': 'hw1',
                    'started_at': 5,
                    'heartbeat_at': 9,
                  },
                ],
              },
            }),
          ),
        };
      });
    }

    Widget shell({Locale locale = const Locale('ar')}) {
      // Default ar exercises the shell's RTL branch (direction derives from
      // the locale); the delegates provide the MaterialLocalizations the
      // rail/AppBar need (production gets them from AdminApp's MaterialApp).
      return MaterialApp(
        locale: locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: BlocProvider<DashboardBloc>(
          create: (_) =>
              DashboardBloc(api: api, tokenProvider: () async => 'tok')
                ..add(const OverviewRequested()),
          child: const AdminShell(),
        ),
      );
    }

    testWidgets('desktop width shows the extended 240px rail', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(rail.minExtendedWidth, 240);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('mobile width hides the rail and shows the bottom nav', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('overview renders the stat cards + device cards (RTL)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(find.text('المبيعات'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('Main Counter'), findsOneWidget);
      expect(
        find.text('Back Office'),
        findsNWidgets(2),
      ); // device card + warnings panel
      expect(find.text('الكاشير: admin'), findsOneWidget);
      expect(find.text('غير متصل'), findsOneWidget); // hw2 offline warning
      final directionality = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('نظرة عامة'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
    });

    testWidgets('english locale lays out LTR (direction follows the locale)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell(locale: const Locale('en')));
      await tester.pumpAndSettle();
      // Scaffold is unique (the AppBar title + extended rail label share text).
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr,
      );
    });
  });
}
