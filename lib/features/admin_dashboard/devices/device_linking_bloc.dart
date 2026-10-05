// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/backend/workers/api_client.dart';

/// Device-linking wizard (T40 / DAFTARI-86).
/// Three-step flow:
/// 1. Owner sign-in (Firebase ID token)
/// 2. Device naming
/// 3. Link submitted → POST /admin/devices/link

part 'device_linking_event.dart';
part 'device_linking_state.dart';

class DeviceLinkingBloc extends Bloc<DeviceLinkingEvent, DeviceLinkingState> {
  final ApiClient _api;
  final Future<String?> Function() _ownerTokenProvider;

  DeviceLinkingBloc({
    required ApiClient api,
    required Future<String?> Function() ownerTokenProvider,
  }) : _api = api,
       _ownerTokenProvider = ownerTokenProvider,
       super(const DeviceLinkingInitial()) {
    on<OwnerSignInRequested>(_onOwnerSignInRequested);
    on<DeviceNamed>(_onDeviceNamed);
    on<LinkSubmitted>(_onLinkSubmitted);
    on<LinkingReset>(_onLinkingReset);
  }

  Future<void> _onOwnerSignInRequested(
    OwnerSignInRequested event,
    Emitter<DeviceLinkingState> emit,
  ) async {
    emit(const DeviceLinkingLoading());
    try {
      final token = await _ownerTokenProvider();
      if (token == null) {
        emit(
          const DeviceLinkingError(
            'تعذر الحصول على رمز المالك. سجل دخول المالك أولاً.',
          ),
        );
        return;
      }
      // Validate the token by calling /auth/me
      await _api.getAuthMe(token);
      emit(const DeviceNaming());
    } catch (e) {
      emit(DeviceLinkingError('فشل تسجيل دخول المالك: ${e.toString()}'));
    }
  }

  void _onDeviceNamed(DeviceNamed event, Emitter<DeviceLinkingState> emit) {
    if (event.deviceName.trim().isEmpty) {
      emit(const DeviceLinkingError('اسم الجهاز مطلوب'));
      return;
    }
    if (event.deviceName.trim().length > 64) {
      emit(
        const DeviceLinkingError('اسم الجهاز طويل جداً (الحد الأقصى 64 حرف)'),
      );
      return;
    }
    if (event.deviceHwid.trim().isEmpty) {
      emit(const DeviceLinkingError('معرف الجهاز مطلوب'));
      return;
    }
    if (event.deviceHwid.trim().length > 128) {
      emit(
        const DeviceLinkingError('معرف الجهاز طويل جداً (الحد الأقصى 128 حرف)'),
      );
      return;
    }
    emit(
      DeviceLinkingReady(
        deviceHwid: event.deviceHwid.trim(),
        deviceName: event.deviceName.trim(),
        platform: event.platform?.trim().isNotEmpty == true
            ? event.platform!.trim()
            : null,
      ),
    );
  }

  Future<void> _onLinkSubmitted(
    LinkSubmitted event,
    Emitter<DeviceLinkingState> emit,
  ) async {
    if (state is! DeviceLinkingReady) {
      emit(const DeviceLinkingError('الحالة غير صالحة للربط'));
      return;
    }
    final ready = state as DeviceLinkingReady;
    emit(const DeviceLinkingLoading());
    try {
      final token = await _ownerTokenProvider();
      if (token == null) {
        emit(const DeviceLinkingError('تعذر الحصول على رمز المالك'));
        return;
      }
      final result = await _api.linkDevice(
        token,
        ready.deviceHwid,
        ready.deviceName,
        platform: ready.platform,
      );
      result.fold(
        (failure) =>
            emit(DeviceLinkingError('فشل ربط الجهاز: ${failure.message}')),
        (device) => emit(DeviceLinkingSuccess(device: device)),
      );
    } catch (e) {
      emit(DeviceLinkingError('فشل ربط الجهاز: ${e.toString()}'));
    }
  }

  void _onLinkingReset(LinkingReset event, Emitter<DeviceLinkingState> emit) {
    emit(const DeviceLinkingInitial());
  }
}
