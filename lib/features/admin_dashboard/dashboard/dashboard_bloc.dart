// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/backend/workers/api_client.dart';
import '../../../core/backend/workers/realtime_client.dart';
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

// ---- state ----

sealed class DashboardState {
  const DashboardState();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardError extends DashboardState {
  final String messageAr;
  const DashboardError({required this.messageAr});
}

class DashboardLoaded extends DashboardState {
  final OverviewStats stats;
  final List<DeviceCardModel> devices;
  final List<SessionCardModel> activeSessions;
  final List<ActivityEventModel> activity;

  const DashboardLoaded({
    required this.stats,
    required this.devices,
    required this.activeSessions,
    required this.activity,
  });
}

/// The dashboard's data bloc (T12): loads the four admin sources in
/// parallel and refreshes on realtime pushes (T15 wires the socket).
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ApiClient _api;
  final Future<String?> Function() _tokenProvider;
  final RealtimeClient? _realtime;
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  DashboardBloc({
    required ApiClient api,
    required Future<String?> Function() tokenProvider,
    RealtimeClient? realtime,
  }) : _api = api,
       _tokenProvider = tokenProvider,
       _realtime = realtime,
       super(const DashboardLoading()) {
    on<OverviewRequested>(_onOverview);
    on<RealtimeEventReceived>(_onRealtime);
    // The realtime push → refresh (T15 wiring; the bloc owns the client's
    // lifecycle — close() disposes the socket).
    if (realtime != null) {
      _realtimeSub = realtime.events.listen(
        (event) => add(RealtimeEventReceived(event)),
      );
      realtime.connect();
    }
  }

  @override
  Future<void> close() async {
    await _realtimeSub?.cancel();
    await _realtime?.close();
    return super.close();
  }

  Future<void> _onOverview(
    OverviewRequested event,
    Emitter<DashboardState> emit,
  ) async {
    final token = await _tokenProvider();
    if (token == null) {
      emit(
        const DashboardError(messageAr: 'انتهت الجلسة. سجل الدخول من جديد.'),
      );
      return;
    }
    try {
      final results = await Future.wait([
        _api.get('/admin/overview', idToken: token),
        _api.get('/admin/devices', idToken: token),
        _api.get('/admin/activity', idToken: token),
        _api.get('/sessions/active', idToken: token),
      ]);
      final overviewBody = results[0].fold((_) => null, (b) => b);
      final devicesBody = results[1].fold((_) => null, (b) => b);
      final activityBody = results[2].fold((_) => null, (b) => b);
      final sessionsBody = results[3].fold((_) => null, (b) => b);
      if (overviewBody == null || devicesBody == null) {
        emit(
          const DashboardError(
            messageAr: 'فشل تحميل لوحة التحكم. حاول مجددًا.',
          ),
        );
        return;
      }
      final deviceList = (devicesBody['data']?['devices'] as List?) ?? const [];
      emit(
        DashboardLoaded(
          stats: mapOverview(
            overviewBody,
            deviceList.cast<Map<String, dynamic>>(),
            DateTime.now().millisecondsSinceEpoch,
          ),
          devices: deviceList
              .cast<Map<String, dynamic>>()
              .map(DeviceCardModel.fromJson)
              .toList(),
          activity:
              (((activityBody?['data']?['events'] as List?) ?? const [])
                      .cast<Map<String, dynamic>>())
                  .map(ActivityEventModel.fromJson)
                  .toList(),
          activeSessions:
              (((sessionsBody?['data']?['sessions'] as List?) ?? const [])
                      .cast<Map<String, dynamic>>())
                  .map(SessionCardModel.fromJson)
                  .toList(),
        ),
      );
    } on Exception {
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
}
