// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// The dashboard's realtime WebSocket client (T15) — connects to the
/// realtime worker's /ws with the session JWT (the worker verifies it on
/// the upgrade) and re-broadcasts JSON events to listeners.
///
/// Reconnect backoff per spec §6.4: 2s/4s/8s/16s/32s, max 5 attempts.
class RealtimeClient {
  RealtimeClient({
    required this.wsUrl,
    required this.tokenProvider,
    Stream<Map<String, dynamic>>? incomingForTest,
    WebSocketChannel Function(Uri uri)? channelFactory,
  }) : _injected = incomingForTest,
       _channelFactory = channelFactory;

  final String wsUrl;
  final Future<String?> Function() tokenProvider;
  final Stream<Map<String, dynamic>>? _injected; // test seam
  final WebSocketChannel Function(Uri uri)? _channelFactory; // test seam

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  int _attempts = 0;
  bool _closed = false;

  /// The event stream (broadcast). With [incomingForTest] injected, events
  /// come from there and no socket is opened.
  Stream<Map<String, dynamic>> get events {
    if (_injected != null) return _injected;
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  bool get isClosed => _closed;

  Future<void> connect() async {
    if (_closed) return;
    final token = await tokenProvider();
    if (token == null || _closed) return;
    try {
      final uri = Uri.parse(wsUrl).replace(queryParameters: {'token': token});
      _channel = _channelFactory != null
          ? _channelFactory(uri)
          : WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (data) {
          _attempts = 0; // a live message resets the backoff ladder
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _controller?.add(json);
          } catch (_) {
            // A malformed frame is dropped: the socket is healthy (a parse
            // failure must not escape to the zone or kill the connection),
            // and a worker-side bug surfaces in the worker's own logs.
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed || _attempts >= 5) return;
    final delay = Duration(seconds: const [2, 4, 8, 16, 32][_attempts]);
    _attempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    await _controller?.close();
  }
}
