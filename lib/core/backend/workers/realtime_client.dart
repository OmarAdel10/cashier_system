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
    required this.ticketProvider,
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
  StreamController<bool>? _connectedController;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  int _attempts = 0;
  bool _connected = false;
  bool _closed = false;

  /// The event stream (broadcast). With [incomingForTest] injected, events
  /// come from there and no socket is opened.
  Stream<Map<String, dynamic>> get events {
    if (_injected != null) return _injected;
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  /// Connectivity as the socket sees it (broadcast): `true` once the
  /// WebSocket opens, `false` when it drops and again when the reconnect
  /// ladder gives up. The dashboard's live indicator subscribes here.
  Stream<bool> get connected {
    _connectedController ??= StreamController<bool>.broadcast();
    return _connectedController!.stream;
  }

  /// The latest [connected] value.
  bool get isConnected => _connected;

  bool get isClosed => _closed;

  Future<void> connect() async {
    if (_closed) return;
    final token = await tokenProvider();
    if (token == null || _closed) return;
    try {
      final uri = Uri.parse(wsUrl).replace(queryParameters: {'ticket': ticket});
      _channel = _channelFactory != null
          ? _channelFactory(uri)
          : WebSocketChannel.connect(uri);
      // A successful open — not only a live message — resets the backoff
      // ladder (T26): a transient drop after a healthy connect retries on
      // the 2s rung, never the escalated one the old attempt count implied.
      _attempts = 0;
      _setConnected(true);
      _sub = _channel!.stream.listen(
        (data) {
          _attempts = 0; // a live message resets the backoff ladder too
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _controller?.add(json);
          } catch (_) {
            // A malformed frame is dropped: the socket is healthy (a parse
            // failure must not escape to the zone or kill the connection),
            // and a worker-side bug surfaces in the worker's own logs.
          }
        },
        onError: (_) {
          _setConnected(false);
          _scheduleReconnect();
        },
        onDone: () {
          _setConnected(false);
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    if (_attempts >= 5) {
      // The ladder is exhausted: surface "offline" rather than silently
      // giving up (the caller has no other signal).
      _setConnected(false);
      return;
    }
    final delay = Duration(seconds: const [2, 4, 8, 16, 32][_attempts]);
    _attempts++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  void _setConnected(bool value) {
    _connected = value;
    final controller = _connectedController;
    if (controller != null && !controller.isClosed) controller.add(value);
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _setConnected(false);
    await _controller?.close();
    await _connectedController?.close();
  }
}
