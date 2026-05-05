import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'errors.dart';

/// Internal HTTP runner used by every resource. Handles auth, JSON
/// serialization, retries with exponential backoff + jitter, and
/// `Retry-After` honoring.
class HttpRunner {
  HttpRunner({
    required this.baseUrl,
    required this.apiKey,
    required this.maxRetries,
    required this.timeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final String apiKey;
  final int maxRetries;
  final Duration timeout;
  final http.Client _client;

  static const _retryableStatuses = {408, 429, 500, 502, 503, 504};
  static final _rng = Random();

  /// Run a JSON request. Body is serialized as JSON if provided.
  /// Throws a typed [GaruError] on non-2xx or network failure.
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = baseUrl.resolve(path).replace(
          queryParameters: query == null
              ? null
              : {
                  ...baseUrl.queryParameters,
                  ...query,
                },
        );

    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _send(method, uri, body, extraHeaders).timeout(timeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return _decode(response);
        }
        if (_retryableStatuses.contains(response.statusCode) && attempt < maxRetries) {
          await _delay(attempt, response.headers['retry-after']);
          continue;
        }
        throw _toApiError(response);
      } on GaruApiError {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = GaruConnectionError(message: 'Request timed out', cause: e);
        if (attempt >= maxRetries) throw lastError;
        await _delay(attempt, null);
      } catch (e) {
        lastError = GaruConnectionError(message: 'Connection error: $e', cause: e);
        if (attempt >= maxRetries) throw lastError;
        await _delay(attempt, null);
      }
    }
    throw lastError ?? GaruConnectionError(message: 'Unknown connection failure');
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Object? body,
    Map<String, String>? extra,
  ) {
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...?extra,
    };
    final encoded = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        return _client.delete(uri, headers: headers, body: encoded);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) return parsed;
      // Some endpoints return an array; wrap it for caller convenience.
      return {'data': parsed};
    } catch (_) {
      return {'raw': response.body};
    }
  }

  GaruApiError _toApiError(http.Response response) {
    final requestId = response.headers['x-request-id'];
    Object? body;
    String message = 'HTTP ${response.statusCode}';
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
        if (body is Map && body['message'] is String) {
          message = body['message'] as String;
        }
      } catch (_) {
        body = response.body;
      }
    }
    int? retryAfterSec;
    final retryAfter = response.headers['retry-after'];
    if (retryAfter != null) {
      retryAfterSec = int.tryParse(retryAfter);
    }
    return mapHttpError(
      status: response.statusCode,
      message: message,
      requestId: requestId,
      body: body,
      retryAfterSec: retryAfterSec,
    );
  }

  Future<void> _delay(int attempt, String? retryAfterHeader) async {
    if (retryAfterHeader != null) {
      final secs = int.tryParse(retryAfterHeader);
      if (secs != null && secs > 0) {
        await Future<void>.delayed(Duration(seconds: secs));
        return;
      }
    }
    // Exponential backoff with full jitter: random[0, 2^attempt * base)
    final baseMs = 250;
    final capMs = 8000;
    final maxMs = min(capMs, baseMs * (1 << attempt));
    final waitMs = _rng.nextInt(maxMs);
    await Future<void>.delayed(Duration(milliseconds: waitMs));
  }

  void close() => _client.close();
}
