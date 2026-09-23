// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Session Management with Conflict Resolution
///
/// Implements the Two-Layer Model:
/// Layer 1: Firebase Auth (tenant_id = Firebase UID)
/// Layer 2: Real-time DB session tracking by username within tenant
library;

import 'dart:async';

import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';

/// Represents a user session on a device
class UserSession {
  final String deviceId;
  final String deviceType; // 'pos' | 'web'
  final int loginTimestamp;
  final int lastHeartbeat;
  final SessionStatus status;
  final bool isPrimary;

  UserSession({
    required this.deviceId,
    required this.deviceType,
    required this.loginTimestamp,
    required this.lastHeartbeat,
    this.status = SessionStatus.active,
    this.isPrimary = false,
  });

  String get id => '$deviceId:$loginTimestamp';
}

enum SessionStatus { active, inactive, terminated }
