// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Cloudflare Workers API client for Daftari POS.
///
/// Wraps daftari-api (authenticated REST), daftari-realtime (WebSocket hub),
/// daftari-paymob (HMAC webhook handler), and daftari-admin (static host).
///
/// Auth: Bearer Firebase ID token (from FirebaseAuthService). All calls
/// run via a single http.Client (dependency-injected in tests).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/core/config/env_config.dart';

/// HTTP client for the daftari-api Workers backend.
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl ?? EnvConfig.apiBaseUrl,
      _client = httpClient ?? http.Client();

  Future<Either<Failure, Map<String, dynamic>>> post(
    String path,
    Map<String, dynamic> body, {
    required String idToken,
  }) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      return Right(jsonDecode(res.body) as Map<String, dynamic>? ?? {});
    } on Exception catch (e) {
      return Left(DatabaseFailure('POST $path failed', cause: e));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> get(
    String path, {
    required String idToken,
    Map<String, String>? query,
  }) async {
    try {
      final res = await _client.get(
        query != null
            ? Uri.parse('$baseUrl$path').replace(queryParameters: query)
            : Uri.parse('$baseUrl$path'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );
      return Right(jsonDecode(res.body) as Map<String, dynamic>? ?? {});
    } on Exception catch (e) {
      return Left(DatabaseFailure('GET $path failed', cause: e));
    }
  }
}
