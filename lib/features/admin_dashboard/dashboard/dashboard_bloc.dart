// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/backend/workers/api_client.dart';
import '../../../core/backend/workers/realtime_client.dart';
import '../../../core/error/either.dart';
import '../../../core/error/failure.dart';
import 'models.dart';

// ---- events ----

sealed class DashboardEvent {
  const DashboardEvent();
}

class OverviewRequested extends DashboardEvent {
  const OverviewRequested();
}

/// A realtime push (sale / session_revoked) — refresh the affected views.
class RealtimeEventReceived extends DashboardEvent {
  final Map<String, dynamic> event;
  const RealtimeEventReceived(this.event);
}

/// The realtime socket's connectivity changed — update the live badge.
class _RealtimeConnectivityChanged extends DashboardEvent {
  final bool connected;
  const _RealtimeConnectivityChanged(this.connected);
}

// ---- state ----

sealed class DashboardState {
  const DashboardState();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardError extends DashboardState {
  final String messageAr;

  /// The structured server/transport code behind the failure when there is
  /// one (`SESSION_EXPIRED`, `SESSION_REVOKED`, `FORBIDDEN`, …). Never parsed
  /// out of a message string.
  final String? code;

  const DashboardError({required this.messageAr, this.code});

  /// True when the failure means the session can no longer be used, so the
  /// shell must route the admin back to re-authentication.
  bool get isSessionExpired => const {
    'SESSION_EXPIRED',
    'SESSION_REVOKED',
    'SESSION_STALE',
    'OWNER_REAUTH_REQUIRED',
  }.contains(code);
}

class DashboardLoaded extends DashboardState {
  final OverviewStats stats;
  final List<DeviceCardModel> devices;
  final List<SessionCardModel> activeSessions;
  final List<ActivityEventModel> activity;

  /// True while the realtime socket is connected (the shell's live badge).
  final bool realtimeConnected;

  const DashboardLoaded({
    required this.stats,
    required this.devices,
    required this.activeSessions,
    required this.activity,
    this.realtimeConnected = false,
  });
}

/// The dashboard's data bloc (T12): loads the four admin sources in
/// parallel and refreshes on realtime pushes (T15 wires the socket).
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ApiClient _api;
  final Future<String?> Function() _tokenProvider;
  final RealtimeClient? _realtime;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;
  StreamSubscription<bool>? _connectedSub;
  bool _realtimeConnected = false;

  DashboardBloc({
    required ApiClient api,
    required Future<String?> Function() tokenProvider,
    RealtimeClient? realtime,
  }) : _api = api,
       _tokenProvider = tokenProvider,
       _realtime = realtime,
       super(const DashboardLoading()) {
    // Restartable (T26): a newer refresh cancels the in-flight one, so an
    // older response can never land after — and overwrite — a newer one.
    on<OverviewRequested>(
      _onOverview,
      transformer: _restartable<OverviewRequested>(),
    );
    on<RealtimeEventReceived>(_onRealtime);
    on<_RealtimeConnectivityChanged>(_onConnectivityChanged);
    // The realtime push → refresh (T15 wiring; the bloc owns the client's
    // lifecycle — close() disposes the socket).
    if (realtime != null) {
      _realtimeSub = realtime.events.listen(
        (event) => add(RealtimeEventReceived(event)),
      );
      // Reflect the socket's real connectivity in the loaded state.
      _connectedSub = realtime.connected.listen((connected) {
        _realtimeConnected = connected;
        add(_RealtimeConnectivityChanged(connected));
      });
      realtime.connect();
    }
  }

  /// True while the realtime socket is connected.
  bool get realtimeConnected => _realtimeConnected;

  @override
  Future<void> close() async {
    await _connectedSub?.cancel();
    await _realtimeSub?.cancel();
    await _realtime?.close();
    return super.close();
  }

  Future<void> _onOverview(
    OverviewRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      // The token fetch is INSIDE the try: a throwing provider must surface
      // as an error state, never escape to the zone (T25).
      final token = await _tokenProvider();
      if (token == null) {
        emit(
          const DashboardError(messageAr: 'انتهت الجلسة. سجل الدخول من جديد.'),
        );
        return;
      }
      final results = await Future.wait([
        _api.get('/admin/overview', idToken: token),
        _api.get('/admin/devices', idToken: token),
        _api.get('/admin/activity', idToken: token),
        _api.get('/sessions/active', idToken: token),
      ]);
      final overviewBody = _bodyOf(results[0]);
      final devicesBody = _bodyOf(results[1]);
      final activityBody = _bodyOf(results[2]);
      final sessionsBody = _bodyOf(results[3]);
      // A non-ok body (401/403/500) or a transport Left is a FAILURE, never
      // an empty dashboard — and its structured code is preserved so the
      // shell can react to an expired session (T25 / T28).
      if (overviewBody?['ok'] != true || devicesBody?['ok'] != true) {
        final code = _codeOf(results[0]) ?? _codeOf(results[1]);
        emit(
          DashboardError(
            messageAr: 'فشل تحميل لوحة التحكم. حاول مجددًا.',
            code: code,
          ),
        );
        return;
      }
      final deviceList = _listAt(devicesBody, 'devices');
      emit(
        DashboardLoaded(
          stats: mapOverview(
            overviewBody!,
            deviceList.cast<Map<String, dynamic>>(),
            DateTime.now().millisecondsSinceEpoch,
          ),
          devices: deviceList
              .cast<Map<String, dynamic>>()
              .map(DeviceCardModel.fromJson)
              .toList(),
          activity: _listAt(activityBody, 'events')
              .cast<Map<String, dynamic>>()
              .map(ActivityEventModel.fromJson)
              .toList(),
          activeSessions: _listAt(sessionsBody, 'sessions')
              .cast<Map<String, dynamic>>()
              .map(SessionCardModel.fromJson)
              .toList(),
          realtimeConnected: _realtimeConnected,
        ),
      );
    } on Exception {
      // Only classified failures (transport/format) are handled. A
      // programming Error (TypeError, StateError, …) is not caught here:
      // it must surface, not masquerade as a network failure (T25).
      emit(
        const DashboardError(messageAr: 'فشل تحميل لوحة التحكم. حاول مجددًا.'),
      );
    }
  }

  Future<void> _onRealtime(
    RealtimeEventReceived event,
    Emitter<DashboardState> emit,
  ) async {
    // Refresh on sale / session_revoked pushes.
    add(const OverviewRequested());
  }

  void _onConnectivityChanged(
    _RealtimeConnectivityChanged event,
    Emitter<DashboardState> emit,
  ) {
    final current = state;
    if (current is! DashboardLoaded) return;
    emit(
      DashboardLoaded(
        stats: current.stats,
        devices: current.devices,
        activeSessions: current.activeSessions,
        activity: current.activity,
        realtimeConnected: event.connected,
      ),
    );
  }

  Map<String, dynamic>? _bodyOf(Either<Failure, Map<String, dynamic>> res) =>
      res.fold((_) => null, (b) => b);

  /// `body.data[key]` when it is a List, else an empty list — a wrong shape
  /// is empty data, never a `NoSuchMethodError`/`TypeError` escape.
  List<dynamic> _listAt(Map<String, dynamic>? body, String key) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) return const [];
    final value = data[key];
    return value is List ? value : const [];
  }

  /// The structured code for a failure: a non-ok body's `error`, an
  /// [AdminAuthFailure.code], a `DatabaseFailure.detail`, or a bare 401 —
  /// keyed structurally, never parsed from a message.
  String? _codeOf(Either<Failure, Map<String, dynamic>> res) {
    final body = _bodyOf(res);
    if (body != null) {
      return body['ok'] == true
          ? null
          : (body['error'] as String? ?? 'UNKNOWN');
    }
    final failure = res.fold((f) => f, (_) => null);
    if (failure is AdminAuthFailure) return failure.code;
    if (failure is HttpFailure && failure.statusCode == 401) {
      return 'SESSION_EXPIRED';
    }
    if (failure is DatabaseFailure) return failure.detail;
    return null;
  }
}

/// A `restartable`-style event transformer: when a new event arrives the
/// in-flight handler's emitter is cancelled, so its late response can no
/// longer emit a stale state.
///
/// `bloc_concurrency`'s `restartable()` is not a declared dependency of this
/// package (only `bloc`/`flutter_bloc` are), so the one transformer this
/// client needs is implemented directly on `dart:async`.
EventTransformer<E> _restartable<E>() {
  return (events, mapper) {
    final controller = StreamController<E>();
    StreamSubscription<E>? outer;
    StreamSubscription<E>? inner;
    var outerDone = false;
    var pending = 0;

    void closeIfDone() {
      if (outerDone && pending == 0 && !controller.isClosed) {
        controller.close();
      }
    }

    controller.onListen = () {
      outer = events.listen(
        (event) {
          inner?.cancel(); // cancel the in-flight handler's emitter
          pending++;
          inner = mapper(event).listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              pending--;
              closeIfDone();
            },
          );
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          closeIfDone();
        },
      );
    };
    controller.onCancel = () async {
      await inner?.cancel();
      await outer?.cancel();
    };
    return controller.stream;
  };
}
