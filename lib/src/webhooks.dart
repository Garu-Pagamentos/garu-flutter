import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'errors.dart';

/// Inputs for [GaruWebhooks.verify].
class VerifyWebhookParams {
  const VerifyWebhookParams({
    required this.payload,
    required this.signature,
    required this.secret,
    this.toleranceSeconds = 300,
    this.now,
  });

  /// Raw request body bytes (DO NOT parse and re-serialize JSON before
  /// passing — that breaks the signature).
  final List<int> payload;

  /// Value of the `X-Garu-Signature` header. Format: `t=<unix>,v1=<hex>`.
  final String signature;

  /// HMAC secret configured for this endpoint in the dashboard.
  final String secret;

  /// Reject signatures with timestamps more than this many seconds away
  /// from [now]. Default 5 min.
  final int toleranceSeconds;

  /// Override the current time (for tests).
  final DateTime? now;
}

/// Result of a successful [GaruWebhooks.verify] call.
class VerifiedWebhook {
  const VerifiedWebhook({required this.event, required this.timestamp});

  /// Parsed JSON event body.
  final Map<String, dynamic> event;

  /// Timestamp from the signature header.
  final DateTime timestamp;
}

/// Webhook signature verification. Stateless — instantiate via [Garu.webhooks]
/// or use as `const GaruWebhooks()`.
class GaruWebhooks {
  const GaruWebhooks();

  /// Verifies an incoming webhook's HMAC signature using constant-time
  /// comparison. Throws [GaruSignatureVerificationError] on:
  /// - malformed signature header
  /// - timestamp outside tolerance window
  /// - HMAC mismatch
  ///
  /// ```dart
  /// final verified = Garu.webhooks.verify(VerifyWebhookParams(
  ///   payload: rawBodyBytes,
  ///   signature: request.headers['x-garu-signature']!,
  ///   secret: env['GARU_WEBHOOK_SECRET']!,
  /// ));
  /// ```
  VerifiedWebhook verify(VerifyWebhookParams params) {
    final parsed = _parseSignature(params.signature);
    if (parsed == null) {
      throw GaruSignatureVerificationError(
        message: 'Malformed X-Garu-Signature header',
      );
    }

    final now = params.now ?? DateTime.now().toUtc();
    final delta = (now.millisecondsSinceEpoch ~/ 1000) - parsed.timestamp;
    if (delta.abs() > params.toleranceSeconds) {
      throw GaruSignatureVerificationError(
        message: 'Signature timestamp outside tolerance window',
      );
    }

    final signed = '${parsed.timestamp}.${utf8.decode(params.payload)}';
    final hmac = Hmac(sha256, utf8.encode(params.secret));
    final expected = hmac.convert(utf8.encode(signed)).bytes;
    final got = _hexToBytes(parsed.v1);
    if (got == null || !_constantTimeEquals(expected, got)) {
      throw GaruSignatureVerificationError(message: 'Signature mismatch');
    }

    final body = jsonDecode(utf8.decode(params.payload)) as Map<String, dynamic>;
    return VerifiedWebhook(
      event: body,
      timestamp: DateTime.fromMillisecondsSinceEpoch(parsed.timestamp * 1000, isUtc: true),
    );
  }

  _ParsedSignature? _parseSignature(String header) {
    int? t;
    String? v1;
    for (final part in header.split(',')) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      final k = part.substring(0, eq).trim();
      final v = part.substring(eq + 1).trim();
      if (k == 't') t = int.tryParse(v);
      if (k == 'v1') v1 = v;
    }
    if (t == null || v1 == null) return null;
    return _ParsedSignature(timestamp: t, v1: v1);
  }

  Uint8List? _hexToBytes(String hex) {
    if (hex.length.isOdd) return null;
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _ParsedSignature {
  _ParsedSignature({required this.timestamp, required this.v1});
  final int timestamp;
  final String v1;
}
