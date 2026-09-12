import 'dart:convert';

import 'package:garu/garu.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _customer = CustomerInput(
  name: 'Maria Silva',
  email: 'maria@exemplo.com.br',
  document: '12345678909',
  phone: '11987654321',
);

void main() {
  group('retry policy on writes', () {
    test('a POST with no idempotency key is sent exactly once', () async {
      // Replaying an unkeyed create is how one buyer gets two charges. The
      // gateway has nothing to deduplicate against without a key, and
      // /api/v1/installment-plans has no duplicate guard at all — a replay
      // there registers a second real boleto.
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response('{"message":"upstream down"}', 503,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client, maxRetries: 2);

      await expectLater(
        garu.charges.create(
            productId: 'p',
            paymentMethod: ChargeMethod.pix,
            customer: _customer),
        throwsA(isA<GaruApiError>()),
      );
      expect(calls, 1);
      garu.close();
    });

    test('a POST carrying an idempotency key is retried', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (calls < 3) {
          return http.Response('{"message":"upstream down"}', 503,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            jsonEncode({
              'uuid': 'u',
              'status': 'pending',
              'paymentMethod': 'pix',
              'amount': 29.9,
              'chargedTotal': 29.9,
              'installments': 1,
              'createdAt': '2026-09-12T14:22:01.000Z',
            }),
            201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client, maxRetries: 2);

      final charge = await garu.charges.create(
        productId: 'p',
        paymentMethod: ChargeMethod.pix,
        customer: _customer,
        idempotencyKey: 'order:4472:charge',
      );

      expect(calls, 3);
      expect(charge.uuid, 'u');
      garu.close();
    });

    test('reads are still retried — replaying a GET costs nothing', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        if (calls < 2) {
          return http.Response('{"message":"nope"}', 503,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(
            jsonEncode({'data': <dynamic>[], 'totalCount': 0, 'totalPages': 0}),
            200,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client, maxRetries: 2);

      await garu.charges.list();

      expect(calls, 2);
      garu.close();
    });
  });
}
