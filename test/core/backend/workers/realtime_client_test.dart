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
  });
}
