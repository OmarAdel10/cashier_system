// Copyright (c) 2026 Daftari POS. All rights reserved.

part of 'device_linking_bloc.dart';

sealed class DeviceLinkingEvent extends Equatable {
  const DeviceLinkingEvent();
}

class OwnerSignInRequested extends DeviceLinkingEvent {
  const OwnerSignInRequested();
  @override
  List<Object?> get props => [];
}

class DeviceNamed extends DeviceLinkingEvent {
  final String deviceHwid;
  final String deviceName;
  final String? platform;
  const DeviceNamed({
    required this.deviceHwid,
    required this.deviceName,
    this.platform,
  });
  @override
  List<Object?> get props => [deviceHwid, deviceName, platform];
}

class LinkSubmitted extends DeviceLinkingEvent {
  const LinkSubmitted();
  @override
  List<Object?> get props => [];
}

class LinkingReset extends DeviceLinkingEvent {
  const LinkingReset();
  @override
  List<Object?> get props => [];
}