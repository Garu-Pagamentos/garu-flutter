import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:garu/garu.dart';
import 'package:test/test.dart';

void main() {
  const secret = 'whsec_test_secret_value';
  final body = utf8.encode('{"event":"transaction.payment.succeeded","id":42}');

  String sign(int timestamp, List<int> payload, String hmacSecret) {
    final signed = '$timestamp.${utf8.decode(payload)}';
    final mac = Hmac(sha256, utf8.encode(hmacSecret)).convert(utf8.encode(signed));
    return 't=$timestamp,v1=${mac.toString()}';
  }

  group('GaruWebhooks.verify', () {
    test('roundtrips a valid signature', () {
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = sign(ts, body, secret);

      final verified = const GaruWebhooks().verify(VerifyWebhookParams(
        payload: body,
        signature: header,
        secret: secret,
      ));

      expect(verified.event['event'], 'transaction.payment.succeeded');
      expect(verified.event['id'], 42);
    });

    test('throws on tampered payload', () {
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = sign(ts, body, secret);
      final tamperedBody = utf8.encode('{"event":"transaction.payment.succeeded","id":99}');

      expect(
        () => const GaruWebhooks().verify(VerifyWebhookParams(
          payload: tamperedBody,
          signature: header,
          secret: secret,
        )),
        throwsA(isA<GaruSignatureVerificationError>()),
      );
    });

    test('throws on wrong secret', () {
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final header = sign(ts, body, 'wrong_secret');

      expect(
        () => const GaruWebhooks().verify(VerifyWebhookParams(
          payload: body,
          signature: header,
          secret: secret,
        )),
        throwsA(isA<GaruSignatureVerificationError>()),
      );
    });

    test('throws when timestamp is too old', () {
      final ts = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) - 600;
      final header = sign(ts, body, secret);

      expect(
        () => const GaruWebhooks().verify(VerifyWebhookParams(
          payload: body,
          signature: header,
          secret: secret,
          toleranceSeconds: 300,
        )),
        throwsA(isA<GaruSignatureVerificationError>()),
      );
    });

    test('throws on malformed header', () {
      expect(
        () => const GaruWebhooks().verify(VerifyWebhookParams(
          payload: body,
          signature: 'not-a-real-sig',
          secret: secret,
        )),
        throwsA(isA<GaruSignatureVerificationError>()),
      );
    });
  });
}
