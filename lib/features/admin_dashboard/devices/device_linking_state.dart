// Copyright (c) 2026 Daftari POS. All rights reserved.

part of 'device_linking_bloc.dart';

sealed class DeviceLinkingState extends Equatable {
  const DeviceLinkingState();
}

class DeviceLinkingInitial extends DeviceLinkingState {
  const DeviceLinkingInitial();
  @override
  List<Object?> get props => [];
}

class DeviceLinkingLoading extends DeviceLinkingState {
  const DeviceLinkingLoading();
  @override
  List<Object?> get props => [];
}

class DeviceNaming extends DeviceLinkingState {
  const DeviceNaming();
  @override
  List<Object?> get props => [];
}

class DeviceLinkingReady extends DeviceLinkingState {
  final String deviceHwid;
  final String deviceName;
  final String? platform;
  const DeviceLinkingReady({
    required this.deviceHwid,
    required this.deviceName,
    this.platform,
  });
  @override
  List<Object?> get props => [deviceHwid, deviceName, platform];
}

class DeviceLinkingSuccess extends DeviceLinkingState {
  final Map<String, dynamic> device;
  const DeviceLinkingSuccess({required this.device});
  @override
  List<Object?> get props => [device];
}

class DeviceLinkingError extends DeviceLinkingState {
  final String message;
  const DeviceLinkingError(this.message);
  @override
  List<Object?> get props => [message];
}