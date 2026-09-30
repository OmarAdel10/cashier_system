// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:cashier_system/core/backend/workers/realtime_client.dart';
import 'package:cashier_system/features/admin_dashboard/dashboard/dashboard_bloc.dart';
import 'package:cashier_system/core/backend/workers/api_client.dart';
import 'package:cashier_system/core/error/either.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockWebSocketChannel extends Mock implements WebSocketChannel {}

class MockWebSocketSink extends Mock implements WebSocketSink {}

final _channelLedger = <MockWebSocketChannel>[];
final _controllerLedger = <StreamController<dynamic>>[];

MockWebSocketChannel makeChannel(Uri uri) {
  final c = MockWebSocketChannel();
  final controller = StreamController<dynamic>();
  when(() => c.stream).thenAnswer((_) => controller.stream);
  final sink = MockWebSocketSink();
  when(() => sink.close()).thenAnswer((_) async {});
  when(() => c.sink).thenReturn(sink);
  _channelLedger.add(c);
  _controllerLedger.add(controller);
  return c;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('RealtimeClient', () {
    setUp(() {
      // Each test starts with an empty ledger: the absolute indices below
      // stay valid regardless of test order.
      _channelLedger.clear();
      _controllerLedger.clear();
    });

    test('injected events flow through to listeners', () async {
      final controller = StreamController<Map<String, dynamic>>();
      final client = RealtimeClient(
        wsUrl: 'wss://x/ws',
        tokenProvider: () async => 'tok',
        incomingForTest: controller.stream,
      );
      final events = <Map<String, dynamic>>[];
      final sub = client.events.listen(events.add);
      controller.add({'type': 'sale', 'count': 1});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(events, [
        {'type': 'sale', 'count': 1},
      ]);
      await sub.cancel();
      await client.close();
      expect(client.isClosed, isTrue);
    });

    test('reconnects with the backoff ladder on done (fake async)', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: makeChannel,
        );
        client.connect();
        async.elapse(const Duration(milliseconds: 10));
        expect(_channelLedger, hasLength(1)); // connected

        // The socket dies → the 2s backoff → reconnect.
        _controllerLedger[0].close();
        async.elapse(const Duration(seconds: 3));
        expect(_channelLedger, hasLength(2));

        // Die again → the 4s backoff → reconnect.
        _controllerLedger[1].close();
        async.elapse(const Duration(seconds: 5));
        expect(_channelLedger, hasLength(3));

        // After close: no more reconnects (the ladder stops).
        client.close();
        _controllerLedger[2].close();
        async.elapse(const Duration(seconds: 40));
        expect(_channelLedger, hasLength(3));
      });
    });

    test('a live message resets the backoff ladder (fake async)', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: makeChannel,
        );
        final events = <Map<String, dynamic>>[];
        final sub = client.events.listen(events.add);
        client.connect();
        async.elapse(const Duration(milliseconds: 10));
        expect(_channelLedger, hasLength(1)); // connected

        // Die twice → the ladder records 2 attempts.
        _controllerLedger[0].close();
        async.elapse(const Duration(seconds: 3)); // the 2s backoff → reconnect
        _controllerLedger[1].close();
        async.elapse(const Duration(seconds: 5)); // the 4s backoff → reconnect
        expect(_channelLedger, hasLength(3));

        // A live message on the new channel resets the ladder and broadcasts.
        _controllerLedger[2].add(jsonEncode({'type': 'sale', 'count': 2}));
        async.elapse(const Duration(milliseconds: 10));
        expect(events, [
          {'type': 'sale', 'count': 2},
        ]);

        // Die again → the next backoff is 2s (reset), not 8s.
        _controllerLedger[2].close();
        async.elapse(const Duration(seconds: 3)); // an 8s ladder would not fire
        expect(_channelLedger, hasLength(4));
        sub.cancel();
        client.close();
      });
    });

    test('the backoff ladder resets after a successful open (fake async)', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: makeChannel,
        );
        client.connect();
        async.elapse(const Duration(milliseconds: 10));
        expect(_channelLedger, hasLength(1)); // connected

        // Die twice → the ladder reaches 2 attempts.
        _controllerLedger[0].close();
        async.elapse(const Duration(seconds: 3)); // 2s → reconnect
        _controllerLedger[1].close();
        async.elapse(const Duration(seconds: 5)); // 4s → reconnect
        expect(_channelLedger, hasLength(3)); // a successful OPEN

        // T26: opening the socket resets the ladder — the next drop waits
        // 2s, not the 8s the old message-only reset would have used.
        _controllerLedger[2].close();
        async.elapse(const Duration(seconds: 3));
        expect(_channelLedger, hasLength(4));
        client.close();
      });
    });

    test('connected emits true once a socket opens (fake async)', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: makeChannel,
        );
        final connectivity = <bool>[];
        final sub = client.connected.listen(connectivity.add);
        client.connect();
        async.elapse(const Duration(milliseconds: 10));
        expect(connectivity, [true]);
        expect(client.isConnected, isTrue);
        sub.cancel();
        client.close();
      });
    });

    test('connected emits false after the 5th failure (fake async)', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: (uri) => throw StateError('down'),
        );
        final connectivity = <bool>[];
        final sub = client.connected.listen(connectivity.add);
        client.connect();
        async.elapse(const Duration(seconds: 70));
        expect(connectivity, isNotEmpty);
        expect(connectivity.last, isFalse);
        expect(client.isConnected, isFalse);
        sub.cancel();
        client.close();
      });
    });

    test('a throwing channel factory schedules a reconnect (fake async)', () {
      fakeAsync((async) {
        var calls = 0;
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: (uri) {
            calls++;
            if (calls == 1) throw StateError('boom');
            return makeChannel(uri);
          },
        );
        // The factory throws → connect() catches → the 2s backoff.
        client.connect();
        async.elapse(const Duration(milliseconds: 10));
        expect(_channelLedger, isEmpty); // the throw left no channel behind

        async.elapse(const Duration(seconds: 3)); // the 2s timer → a retry
        expect(_channelLedger, hasLength(1)); // the retry succeeded
        expect(calls, 2);
        expect(client.isClosed, isFalse);
        client.close();
      });
    });

    test(
      'the ladder stops after 5 failed attempts without close (fake async)',
      () {
        fakeAsync((async) {
          var calls = 0;
          final client = RealtimeClient(
            wsUrl: 'wss://x/ws',
            tokenProvider: () async => 'tok',
            channelFactory: (uri) {
              calls++;
              throw StateError('down');
            },
          );
          client.connect(); // every connect fails: the ladder runs 2+4+8+16+32
          async.elapse(const Duration(seconds: 70));
          expect(calls, 6); // the initial connect plus the 5 backoff retries
          expect(client.isClosed, isFalse); // no close(): the cap stopped it

          // The 6th failure schedules nothing — the ladder is capped at 5.
          async.elapse(const Duration(seconds: 40));
          expect(calls, 6);
        });
      },
    );

    test('an error event also schedules a reconnect (fake async)', () {
      fakeAsync((async) {
        final client = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          channelFactory: makeChannel,
        );
        client.connect();
        async.elapse(const Duration(milliseconds: 10));
        expect(_channelLedger, hasLength(1)); // connected

        // A socket error routes to onError → the 2s backoff → reconnect.
        _controllerLedger[0].addError(StateError('boom'));
        async.elapse(const Duration(seconds: 3));
        expect(_channelLedger, hasLength(2));
        client.close();
      });
    });

    test('close cancels the reconnect timer and stops connecting', () async {
      final client = RealtimeClient(
        wsUrl: 'wss://x/ws',
        tokenProvider: () async => 'tok',
      );
      await client.close();
      // connect() after close is a no-op (no crash).
      await client.connect();
      expect(client.isClosed, isTrue);
    });

    test('a null token does not open a connection', () async {
      final client = RealtimeClient(
        wsUrl: 'wss://x/ws',
        tokenProvider: () async => null,
      );
      await client.connect(); // no crash, no socket
      expect(client.isClosed, isFalse);
      await client.close();
    });

    test('a malformed frame is dropped without crashing', () async {
      final controllers = <StreamController<dynamic>>[];
      final client = RealtimeClient(
        wsUrl: 'wss://x/ws',
        tokenProvider: () async => 'tok',
        channelFactory: (uri) {
          final c = MockWebSocketChannel();
          final controller = StreamController<dynamic>();
          when(() => c.stream).thenAnswer((_) => controller.stream);
          final sink = MockWebSocketSink();
          when(() => sink.close()).thenAnswer((_) async {});
          when(() => c.sink).thenReturn(sink);
          controllers.add(controller);
          return c;
        },
      );
      final events = <Map<String, dynamic>>[];
      final sub = client.events.listen(events.add);
      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // A non-JSON text frame and a binary frame must not escape to the zone
      // (an exception in a data handler is not routed to onError).
      controllers.last.add('not json');
      controllers.last.add([1, 2]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, isEmpty);
      await sub.cancel();
      await client.close();
    });
  });

  group('DashboardBloc realtime wiring', () {
    test('a realtime sale event triggers a refresh', () async {
      final api = MockApiClient();
      final controller = StreamController<Map<String, dynamic>>();
      when(
        () => api.get(
          any(),
          idToken: any(named: 'idToken'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
      final realtime = RealtimeClient(
        wsUrl: 'wss://x/ws',
        tokenProvider: () async => 'tok',
        incomingForTest: controller.stream,
        channelFactory: (uri) => makeChannel(uri),
      );
      final bloc = DashboardBloc(
        api: api,
        tokenProvider: () async => 'tok',
        realtime: realtime,
      );
      final states = <DashboardState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(const OverviewRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final loadsAfterFirst = states.where((s) => s is DashboardLoaded).length;
      controller.add(
        jsonDecode('{"type": "sale", "count": 1}') as Map<String, dynamic>,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final loadsAfterEvent = states.where((s) => s is DashboardLoaded).length;
      expect(loadsAfterEvent, greaterThan(loadsAfterFirst));
      await sub.cancel();
      await bloc.close(); // also closes the realtime client
      expect(realtime.isClosed, isTrue);
    });

    test(
      'surfaces the realtime connectivity flag in the loaded state',
      () async {
        final api = MockApiClient();
        final controller = StreamController<Map<String, dynamic>>();
        when(
          () => api.get(
            any(),
            idToken: any(named: 'idToken'),
            query: any(named: 'query'),
          ),
        ).thenAnswer((_) async => const Right(<String, dynamic>{'ok': true}));
        final realtime = RealtimeClient(
          wsUrl: 'wss://x/ws',
          tokenProvider: () async => 'tok',
          incomingForTest: controller.stream,
          channelFactory: (uri) => makeChannel(uri),
        );
        final bloc = DashboardBloc(
          api: api,
          tokenProvider: () async => 'tok',
          realtime: realtime,
        );
        final states = <DashboardState>[];
        final sub = bloc.stream.listen(states.add);
        bloc.add(const OverviewRequested());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(bloc.realtimeConnected, isTrue);
        expect((states.last as DashboardLoaded).realtimeConnected, isTrue);
        await sub.cancel();
        await bloc.close();
      },
    );
  });
}
