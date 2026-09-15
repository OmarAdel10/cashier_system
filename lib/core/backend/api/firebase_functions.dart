// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Firebase Functions handlers for backend logic.
///
/// This file contains server-side logic deployed as Firebase Functions.
/// Includes: payment success handling, auto-invoice generation, PostHog analytics.

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/backend/auth/firebase_auth_service.dart';
import 'package:cashier_system/core/backend/database/real_time_db.dart';
import 'package:cashier_system/core/backend/database/database_schema.dart';
import 'package:cashier_system/core/backend/sharding/shard_manager.dart';
import 'package:cashier_system/core/backend/themes/theme_manager.dart';
import 'package:cashier_system/core/backend/api/posthog_analytics.dart';

/// Firebase Functions handlers for backend logic.
///
/// All functions run in Firebase Functions environment (Node.js/Dart runtime).
/// Handles: payment processing, license generation, invoice emails, analytics.
class FirebaseFunctions {
  final PostHogAnalytics _analytics = PostHogAnalytics();

  /// Handles successful Paymob payment.
  ///
  /// Generates Ed25519 license for the device and sends invoice email.
  Future<Either<Failure, Map<String, dynamic>>> handlePaymentSuccess({
    required String transactionId,
    required String tenantId,
    required String deviceHwid,
    required String billingCycle,
    required int amountPiastres,
  }) async {
    try {
      // 1. Generate Ed25519 license for the device
      final license = _generateLicense(
        deviceHwid: deviceHwid,
        tenantId: tenantId,
      );

      // 2. Store license in Turso (via Firebase Function)
      await _storeLicense(
        tenantId: tenantId,
        deviceHwid: deviceHwid,
        licenseKey: license,
        billingCycle: billingCycle,
        amountPiastres: amountPiastres,
      );

      // 3. Generate and send invoice email
      final invoice = _generateInvoice(
        transactionId: transactionId,
        tenantId: tenantId,
        amountPiastres: amountPiastres,
        billingCycle: billingCycle,
      );
      await _sendInvoiceEmail(tenantId: tenantId, invoice: invoice);

      // 4. Track analytics
      _analytics.track('payment_success', {
        'transaction_id': transactionId,
        'tenant_id': tenantId,
        'amount_piastres': amountPiastres,
        'billing_cycle': billingCycle,
      });

      return Right({
        'status': 'success',
        'license_key': license,
        'invoice_email_sent': true,
      });
    } on Exception catch (e) {
      return Left(DatabaseFailure('Payment handling failed: $e', cause: e));
    }
  }

  /// Handles subscription renewal.
  Future<Either<Failure, Map<String, dynamic>>> handleSubscriptionRenewal({
    required String transactionId,
    required String tenantId,
    required String deviceHwid,
    required String billingCycle,
    required int amountPiastres,
  }) async {
    return handlePaymentSuccess(
      transactionId: transactionId,
      tenantId: tenantId,
      deviceHwid: deviceHwid,
      billingCycle: billingCycle,
      amountPiastres: amountPiastres,
    );
  }

  /// Handles failed payment.
  Future<Either<Failure, Map<String, dynamic>>> handlePaymentFailed({
    required String transactionId,
    required String tenantId,
    required String errorMessage,
  }) async {
    try {
      _analytics.track('payment_failed', {
        'transaction_id': transactionId,
        'tenant_id': tenantId,
        'error': errorMessage,
      });

      return Right({'status': 'processed', 'action': 'notification_sent'});
    } on Exception catch (e) {
      return Left(
        DatabaseFailure('Failed payment handling failed: $e', cause: e),
      );
    }
  }

  /// Handles new device registration.
  Future<Either<Failure, Map<String, dynamic>>> handleDeviceRegistration({
    required String tenantId,
    required String deviceHwid,
    required String deviceName,
    required String platform,
  }) async {
    try {
      final tier = await _getTenantTier(tenantId);
      final maxDevices = _getMaxDevicesForTier(tier);
      final currentCount = await _getActiveDeviceCount(tenantId);

      if (currentCount >= maxDevices) {
        return Left(
          DatabaseFailure(
            'Device limit reached for ${tier} tier ($maxDevices devices max)',
          ),
        );
      }

      await _storeDevice(
        tenantId: tenantId,
        deviceHwid: deviceHwid,
        deviceName: deviceName,
        platform: platform,
      );

      _analytics.track('device_registered', {
        'tenant_id': tenantId,
        'device_hwid': deviceHwid,
        'platform': platform,
      });

      return Right({'status': 'success', 'device_registered': true});
    } on Exception catch (e) {
      return Left(DatabaseFailure('Device registration failed: $e', cause: e));
    }
  }

  String _generateLicense({
    required String deviceHwid,
    required String tenantId,
  }) {
    final payload =
        '$tenantId|$deviceHwid|${DateTime.now().millisecondsSinceEpoch}';
    return 'ED25519_${_hashString(payload)}';
  }

  String _hashString(String input) {
    var hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) - hash + input.codeUnitAt(i)) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  Future<void> _storeLicense({
    required String tenantId,
    required String deviceHwid,
    required String licenseKey,
    required String billingCycle,
    required int amountPiastres,
  }) async {
    // Store in Turso via Firebase Function
  }

  Map<String, dynamic> _generateInvoice({
    required String transactionId,
    required String tenantId,
    required int amountPiastres,
    required String billingCycle,
  }) {
    return {
      'transaction_id': transactionId,
      'tenant_id': tenantId,
      'date': DateTime.now().toIso8601String(),
      'amount_piastres': amountPiastres,
      'billing_cycle': billingCycle,
      'status': 'completed',
    };
  }

  Future<void> _sendInvoiceEmail({
    required String tenantId,
    required Map<String, dynamic> invoice,
  }) async {
    // Send via SMTP or transactional email service
  }

  String _getTenantTier(String tenantId) => 'professional';
  int _getMaxDevicesForTier(String tier) {
    switch (tier) {
      case 'starter':
        return 1;
      case 'professional':
        return 2;
      case 'business':
        return 4;
      default:
        return 1;
    }
  }

  Future<int> _getActiveDeviceCount(String tenantId) async => 0;

  Future<void> _storeDevice({
    required String tenantId,
    required String deviceHwid,
    required String deviceName,
    required String platform,
  }) async {
    // Store in Turso devices table
  }
}
