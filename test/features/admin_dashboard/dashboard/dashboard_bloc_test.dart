// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/config/env_config.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/admin_dashboard/admin_shell.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/dashboard_bloc.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/models.dart';
import 'package:cashier_system/features/admin_dashboard/overview/overview_view.dart';
import 'package:cashier_system/features/admin_dashboard/sales/sales_chart_view.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;

  setUpAll(() {
    // The shell's Sales destination constructs SalesChartView → its own
    // ApiClient() — EnvConfig's baseUrl is a late final (once per process).
    EnvConfig.initializeFromEnv();
    registerFallbackValue(const DashboardError(messageAr: 'fallback'));
  });

  setUp(() {
    api = MockApiClient();
  });

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

    test('a throwing api → DashboardError (on Exception)', () async {
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenThrow(Exception('boom'));
      final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
      final states = <DashboardState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const OverviewRequested());
      await bloc.stream.firstWhere((s) => s is DashboardError);
      expect(states.last, isA<DashboardError>());
      await sub.cancel();
      await bloc.close();
    });

    test('a 403 overview response shows an error, not zeros', () async {
      // T25: a non-ok body is a FAILURE — the old code ignored `ok` and
      // rendered the 403 as an all-zeros dashboard.
      when(() => api.get('/admin/overview', idToken: 'tok')).thenAnswer(
        (_) async =>
            const Right(<String, dynamic>{'ok': false, 'error': 'FORBIDDEN'}),
      );
      when(() => api.get('/admin/devices', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'devices': <dynamic>[]},
        }),
      );
      when(() => api.get('/admin/activity', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'events': <dynamic>[]},
        }),
      );
      when(() => api.get('/sessions/active', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'sessions': <dynamic>[]},
        }),
      );

      final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
      bloc.add(const OverviewRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        bloc.state,
        isA<DashboardError>(),
        reason: 'a 403 must not render as an empty/zeros dashboard',
      );
      await bloc.close();
    });

    test(
      'a malformed device payload yields DashboardError, not a hang',
      () async {
        when(() => api.get('/admin/overview', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {
              'stats': {'saleCount': 1, 'totalPiastres': 100},
              'active_sessions': 0,
            },
          }),
        );
        // A device row without the required `device_hwid` — the mapper must
        // classify it as bad data, not leak a TypeError (forever loading).
        when(() => api.get('/admin/devices', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {
              'devices': [
                {'device_name': 'broken'},
              ],
            },
          }),
        );
        when(() => api.get('/admin/activity', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {'events': <dynamic>[]},
          }),
        );
        when(() => api.get('/sessions/active', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {'sessions': <dynamic>[]},
          }),
        );

        final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
        bloc.add(const OverviewRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<DashboardError>());
        await bloc.close();
      },
    );

    test('a non-Map list ELEMENT yields DashboardError, not a hang', () async {
      // cast is LAZY: a non-object element throws a TypeError (an Error,
      // not an Exception) only when iterated, so the old code hung on
      // DashboardLoading forever. This is the regression for it.
      when(() => api.get('/admin/overview', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {
            'stats': {'saleCount': 1, 'totalPiastres': 100},
            'active_sessions': 0,
          },
        }),
      );
      when(() => api.get('/admin/devices', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {
            'devices': <dynamic>[42],
          },
        }),
      );
      when(() => api.get('/admin/activity', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'events': <dynamic>[]},
        }),
      );
      when(() => api.get('/sessions/active', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'sessions': <dynamic>[]},
        }),
      );

      final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
      bloc.add(const OverviewRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<DashboardError>());
      expect(bloc.state, isNot(isA<DashboardLoading>()));
      await bloc.close();
    });

    test(
      'a non-ok activity response yields DashboardError, not an empty panel',
      () async {
        // All four sources are validated: a failing /admin/activity must not
        // render as a silently empty panel.
        when(() => api.get('/admin/overview', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {
              'stats': {'saleCount': 1, 'totalPiastres': 100},
              'active_sessions': 0,
            },
          }),
        );
        when(() => api.get('/admin/devices', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {'devices': <dynamic>[]},
          }),
        );
        when(() => api.get('/admin/activity', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': false,
            'error': 'DASHBOARD_ERROR',
          }),
        );
        when(() => api.get('/sessions/active', idToken: 'tok')).thenAnswer(
          (_) async => const Right(<String, dynamic>{
            'ok': true,
            'data': {'sessions': <dynamic>[]},
          }),
        );

        final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
        bloc.add(const OverviewRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.state, isA<DashboardError>());
        await bloc.close();
      },
    );

    test(
      'a null local token routes to session expiry, not a dead pane',
      () async {
        // The shell only reacts to isSessionExpired, so an expired local token
        // must carry the structured code — a bare error left a pane whose retry
        // could never succeed.
        final bloc = DashboardBloc(api: api, tokenProvider: () async => null);
        bloc.add(const OverviewRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final state = bloc.state;
        expect(state, isA<DashboardError>());
        expect((state as DashboardError).code, 'SESSION_EXPIRED');
        expect(state.isSessionExpired, isTrue);
        await bloc.close();
      },
    );

    test('a stale overview response cannot overwrite a newer one', () async {
      // T26: the older request finishes LAST; only the newest may win.
      var overviewCalls = 0;
      when(() => api.get('/admin/overview', idToken: 'tok')).thenAnswer((
        _,
      ) async {
        overviewCalls++;
        if (overviewCalls == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return const Right(<String, dynamic>{
            'ok': true,
            'data': {
              'stats': {'saleCount': 1, 'totalPiastres': 0},
              'active_sessions': 0,
            },
          });
        }
        return const Right(<String, dynamic>{
          'ok': true,
          'data': {
            'stats': {'saleCount': 2, 'totalPiastres': 0},
            'active_sessions': 0,
          },
        });
      });
      when(() => api.get('/admin/devices', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'devices': <dynamic>[]},
        }),
      );
      when(() => api.get('/admin/activity', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'events': <dynamic>[]},
        }),
      );
      when(() => api.get('/sessions/active', idToken: 'tok')).thenAnswer(
        (_) async => const Right(<String, dynamic>{
          'ok': true,
          'data': {'sessions': <dynamic>[]},
        }),
      );

      final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
      bloc.add(const OverviewRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const OverviewRequested()); // the newer request
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect((bloc.state as DashboardLoaded).stats.saleCount, 2);
      await bloc.close();
    });

    test(
      'a burst of realtime events results in one overview load emission',
      () async {
        // T26: every refresh is restartable — a burst collapses to one load.
        when(
          () => api.get(
            any(),
            idToken: any(named: 'idToken'),
            query: any(named: 'query'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return const Right(<String, dynamic>{
            'ok': true,
            'data': {
              'stats': {'saleCount': 7, 'totalPiastres': 0},
              'active_sessions': 0,
              'devices': <dynamic>[],
              'events': <dynamic>[],
              'sessions': <dynamic>[],
            },
          });
        });

        final bloc = DashboardBloc(api: api, tokenProvider: () async => 'tok');
        final loads = <DashboardState>[];
        final sub = bloc.stream.listen((s) {
          if (s is DashboardLoaded) loads.add(s);
        });
        bloc.add(const OverviewRequested());
        for (var i = 0; i < 4; i++) {
          bloc.add(const RealtimeEventReceived({'type': 'sale'}));
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(loads, hasLength(1));
        await sub.cancel();
        await bloc.close();
      },
    );

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

  group('Dashboard models (isOnline branches)', () {
    test('session / fresh heartbeat → online; stale → offline', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      const withSession = DeviceCardModel(
        deviceHwid: 'hw1',
        lastSeenAt: 0,
        activeUsername: 'admin',
      );
      final freshHeartbeat = DeviceCardModel(
        deviceHwid: 'hw2',
        lastSeenAt: now - 60000,
      );
      final stale = DeviceCardModel(
        deviceHwid: 'hw3',
        lastSeenAt: now - 600000,
      );
      expect(withSession.isOnline(now), isTrue); // activeUsername != null
      expect(freshHeartbeat.isOnline(now), isTrue); // fresh heartbeat (< 5 min)
      expect(stale.isOnline(now), isFalse); // stale heartbeat
    });
  });

  group('AdminShell (responsive)', () {
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

    testWidgets('tablet width shows the collapsed 72px rail (768–1200)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(
        tester
            .widget<SizedBox>(
              find
                  .ancestor(
                    of: find.byType(NavigationRail),
                    matching: find.byType(SizedBox),
                  )
                  .first,
            )
            .width,
        72,
      );
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('tapping the Users rail destination renders the placeholder', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      // onDestinationSelected → _selected → the content switch: the Users
      // placeholder replaces the overview (the shell's core interaction).
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      // T14: the Users destination renders the real UsersView (its header).
      expect(find.textContaining('المستخدمون'), findsWidgets);
      expect(find.text('المستخدمون'), findsNWidgets(2)); // AppBar + rail label
      expect(find.byType(OverviewView), findsNothing);
    });

    testWidgets('tapping the Sales rail destination renders the sales chart', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      stubApi();
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      // _content switch: the Sales destination swaps the overview for the
      // SalesChartView (T13) — this harness passes the shell no token, so
      // the chart's own empty state renders (no /sales fetch, no network).
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SalesChartView), findsOneWidget);
      expect(find.text('لا توجد مبيعات في آخر 7 أيام'), findsOneWidget);
      expect(find.text('المبيعات'), findsNWidgets(2)); // AppBar + rail label
      expect(find.byType(OverviewView), findsNothing);
    });

    testWidgets('the AppBar refresh dispatches OverviewRequested', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(calls, 4, reason: 'initial load: 4 sources');
      // The AppBar refresh (tooltip) dispatches OverviewRequested — pump
      // until the fresh round lands (each pump flushes the handler's async
      // gaps; pumpAndSettle alone can return before the handler resumes).
      await tester.tap(find.byTooltip('تحديث'));
      for (var i = 0; i < 20 && calls < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(calls, 8, reason: 'refresh dispatches a fresh OverviewRequested');
    });

    testWidgets('the error pane shows the message + retry recovers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => const Left(DatabaseFailure('down')));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('ar'), Locale('en')],
          home: BlocProvider<DashboardBloc>(
            create: (_) =>
                DashboardBloc(api: api, tokenProvider: () async => 'tok')
                  ..add(const OverviewRequested()),
            child: const AdminShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('فشل تحميل لوحة التحكم. حاول مجددًا.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      stubApi(); // the retry hits the working stub
      await tester.tap(find.text('إعادة المحاولة'));
      for (
        var i = 0;
        i < 20 && tester.widgetList(find.text('المبيعات')).isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.text('المبيعات'), findsWidgets); // back to the overview
      expect(find.byType(OverviewView), findsOneWidget);
    });

    testWidgets('empty devices, shifts, and activity render empty cards', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((inv) {
        final path = inv.positionalArguments[0] as String;
        return switch (path) {
          '/admin/overview' => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {
                'stats': {'saleCount': 0, 'totalPiastres': 0},
                'active_sessions': 0,
              },
            }),
          ),
          '/admin/devices' => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {'devices': []},
            }),
          ),
          '/admin/activity' => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {'events': []},
            }),
          ),
          _ => Future.value(
            const Right(<String, dynamic>{
              'ok': true,
              'data': {'sessions': []},
            }),
          ),
        };
      });
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(
        find.text('لا توجد أجهزة بعد. اربط جهازًا من تطبيق الكاشير.'),
        findsOneWidget,
      );
      expect(find.text('لا توجد ورديات نشطة'), findsOneWidget);
      expect(find.text('لا توجد تنبيهات'), findsOneWidget);
      expect(find.text('لا يوجد نشاط'), findsOneWidget);
    });

    testWidgets('DashboardLoading renders the spinner', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Hold the api responses open so the loading state persists.
      final gate = Completer<void>();
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer(
        (_) =>
            gate.future.then((_) => const Right(<String, dynamic>{'ok': true})),
      );
      await tester.pumpWidget(shell());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('OverviewView (panels layout)', () {
    Widget overview() {
      // Physical size must be set before pumpWidget (the 900px breakpoint
      // reads the content width — no rail here, so the full window width).
      stubApi();
      return MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: BlocProvider<DashboardBloc>(
          create: (_) =>
              DashboardBloc(api: api, tokenProvider: () async => 'tok')
                ..add(const OverviewRequested()),
          // The Scaffold provides the Material ancestor the ListTiles need
          // (production renders the view inside the shell's Scaffold).
          child: const Scaffold(body: OverviewView()),
        ),
      );
    }

    testWidgets('panels lay out side-by-side at ≥900 (feed on the wide side)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(overview());
      await tester.pumpAndSettle();
      // side-by-side: the feed sits in the layout's Row — one Row ancestor.
      // (The breakpoint reads the content width: 960 - 2×24 padding = 912 ≥ 900.)
      expect(
        find.ancestor(
          of: find.byType(RecentActivityFeed),
          matching: find.byType(Row),
        ),
        findsOneWidget,
      );
      expect(find.text('120.00 EGP'), findsOneWidget); // feed summary
      expect(find.text('admin'), findsOneWidget); // active shift ListTile
    });

    testWidgets('panels stack below 900 (shifts → warnings → feed)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(880, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(overview());
      await tester.pumpAndSettle();
      // stacked: the feed lives in the layout's Column — no Row ancestor.
      expect(
        find.ancestor(
          of: find.byType(RecentActivityFeed),
          matching: find.byType(Row),
        ),
        findsNothing,
      );
      expect(find.text('120.00 EGP'), findsOneWidget);
    });
  });
}
