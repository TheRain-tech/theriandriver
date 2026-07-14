import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../config/firebase_config.dart';

/// Thrown for any non-2xx node-api response, or a network/timeout failure.
/// [statusCode] is null for network/timeout errors (never reached the server).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isNetworkError => statusCode == null;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

/// Minimal REST client for the parts of the driver app that must go through
/// node-api's validated business logic instead of writing to Firestore
/// directly (payment requests, fleet agreement, report-fleet, suspension
/// appeals, revenue aggregation) — everything else keeps using the app's
/// existing direct-Firestore repositories.
///
/// Attaches the driver's live Firebase ID token as a Bearer token, matching
/// node-api's `authenticate` middleware, which verifies that token via the
/// Firebase Admin SDK.
class ApiClient {
  ApiClient._();

  static final instance = ApiClient._();

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = EnvConfig.apiBaseUrl.trim();
    if (base.isEmpty) {
      throw ApiException(
        'TheRain server address is not configured for this build.',
      );
    }
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final full = '$normalizedBase$normalizedPath';
    final cleanQuery = query == null
        ? null
        : {
            for (final entry in query.entries)
              if (entry.value != null) entry.key: entry.value.toString(),
          };
    return Uri.parse(full).replace(
      queryParameters: cleanQuery?.isNotEmpty == true ? cleanQuery : null,
    );
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (FirebaseConfig.isAvailable) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final token = await user.getIdToken();
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }
        } catch (error) {
          debugPrint('[api-client] could not read ID token: $error');
        }
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path, query);
    http.Response response;
    try {
      final headers = await _headers();
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
        'The request timed out. Check your connection and try again.',
      );
    } catch (error) {
      throw ApiException('Network error. Check your connection and try again.');
    }

    Map<String, dynamic>? decoded;
    if (response.body.isNotEmpty) {
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } catch (_) {
        // Non-JSON body (e.g. plain-text 502 from an upstream proxy) — fall
        // through and surface the raw status instead of crashing on parse.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null) return null;
      // node-api's `ok()`/`created()` helpers always wrap payloads as
      // { success: true, data: ... }.
      return decoded.containsKey('data') ? decoded['data'] : decoded;
    }

    final errorBody = decoded?['error'];
    final message =
        (errorBody is Map ? errorBody['message'] : null)?.toString() ??
        decoded?['message']?.toString() ??
        _fallbackMessageFor(response.statusCode);
    final code = (errorBody is Map ? errorBody['code'] : null)?.toString();
    throw ApiException(message, statusCode: response.statusCode, code: code);
  }

  String _fallbackMessageFor(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'You are not authorized to do that. Please sign in again.';
    }
    if (statusCode == 404) return 'That item could not be found.';
    if (statusCode == 409) return 'That request could not be completed.';
    if (statusCode >= 500) {
      return 'TheRain server had a problem. Please try again shortly.';
    }
    return 'Something went wrong. Please try again.';
  }
}
