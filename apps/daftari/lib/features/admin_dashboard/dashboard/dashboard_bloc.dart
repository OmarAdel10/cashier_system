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
        // The local token is gone (expired or cleared): there is no usable
        // session, so this MUST carry the structured session-expiry code —
        // the shell's listener only fires on isSessionExpired, and a bare
        // error here would leave a dead pane whose retry can never succeed.
        emit(
          const DashboardError(
            messageAr: 'انتهت الجلسة. سجل الدخول من جديد.',
            code: 'SESSION_EXPIRED',
          ),
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
      // shell can react to an expired session (T25 / T28). All four sources
      // are validated uniformly: a non-ok activity or sessions response is an
      // error panel, never silently empty data.
      if (overviewBody?['ok'] != true ||
          devicesBody?['ok'] != true ||
          activityBody?['ok'] != true ||
          sessionsBody?['ok'] != true) {
        emit(
          DashboardError(
            messageAr: 'فشل تحميل لوحة التحكم. حاول مجددًا.',
            code: _firstCodeOf(results),
          ),
        );
        return;
      }
      final deviceList = _mapsAt(devicesBody, 'devices');
      final activityList = _mapsAt(activityBody, 'events');
      final sessionList = _mapsAt(sessionsBody, 'sessions');
      // A malformed ELEMENT (e.g. data: [42]) is a format failure too: cast
      // is lazy, so a non-Map element throws a TypeError only when iterated —
      // an Error, which the on Exception clause below cannot catch, leaving
      // the view on DashboardLoading forever.
      if (deviceList == null || activityList == null || sessionList == null) {
        emit(
          const DashboardError(
            messageAr: 'فشل تحميل لوحة التحكم. حاول مجددًا.',
          ),
        );
        return;
      }
      emit(
        DashboardLoaded(
          stats: mapOverview(
            overviewBody!,
            deviceList,
            DateTime.now().millisecondsSinceEpoch,
          ),
          devices: deviceList.map(DeviceCardModel.fromJson).toList(),
          activity: activityList.map(ActivityEventModel.fromJson).toList(),
          activeSessions: sessionList.map(SessionCardModel.fromJson).toList(),
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

  /// `body.data[key]` as an eagerly converted list of objects, or null when
  /// the shape or ANY element is malformed. Unlike `cast`, which is lazy and
  /// only throws a `TypeError` (an Error, not an Exception) once iterated,
  /// this conversion is total: a non-Map element is a format failure the
  /// caller can surface, never a hang.
  List<Map<String, dynamic>>? _mapsAt(Map<String, dynamic>? body, String key) {
    final data = body?['data'];
    if (data is! Map<String, dynamic>) return null;
    final value = data[key];
    if (value is! List) return null;
    final out = <Map<String, dynamic>>[];
    for (final element in value) {
      if (element is Map<String, dynamic>) {
        out.add(element);
      } else {
        return null;
      }
    }
    return out;
  }

  /// The first structured code across the four responses, preferring a
  /// session-expiry code (so a 401 among mixed failures still reaches the
  /// shell's re-auth routing) — a non-ok body's `error`, an
  /// [AdminAuthFailure.code], a `DatabaseFailure.detail`, or a bare 401.
  /// Keyed structurally, never parsed from a message.
  String? _firstCodeOf(List<Either<Failure, Map<String, dynamic>>> results) {
    String? first;
    for (final res in results) {
      final code = _codeOf(res);
      if (code == null) continue;
      if (DashboardError(messageAr: '', code: code).isSessionExpired) {
        return code;
      }
      first ??= code;
    }
    return first;
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
