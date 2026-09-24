// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'api_client.dart';

/// Simple analytics: batch PostHog events → API /events endpoint.
/// No local persistence, no batching in a service worker — Flutter keeps
/// its own in-memory queue and flushes to the API.
class AnalyticsService {
  final ApiClient _api;

  AnalyticsService({ApiClient? api}) : _api = api ?? ApiClient();

  static const int maxBatch = 50;

  Future<Either<Failure, Map<String, dynamic>>> track(
    String event,
    Map<String, dynamic> props, {
    required String idToken,
  }) {
    return _api.post('/events', {
      'events': [
        {
          'event': event,
          'properties': props..['tenant_id'] = props['tenant_id'] ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ],
    }, idToken: idToken);
  }
}
