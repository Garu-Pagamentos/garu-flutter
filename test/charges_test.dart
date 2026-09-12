import 'dart:convert';

import 'package:garu/garu.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A minimal v1 charge body, overridable per test.
Map<String, dynamic> chargeJson([Map<String, dynamic> extra = const {}]) => {
      'uuid': '6f1c9b2e-4a7d-4f0b-9a3e-1d2c3b4a5e6f',
      'status': 'pending',
      'paymentMethod': 'pix',
      'amount': 29.9,
      'chargedTotal': 29.9,
      'installments': 1,
      'createdAt': '2026-09-12T14:22:01.000Z',
      ...extra,
    };

const _customer = CustomerInput(
  name: 'Maria Silva',
  email: 'maria@exemplo.com.br',
  document: '12345678909',
  phone: '11987654321',
);

void main() {
  group('charges.create', () {
    test('posts to /api/v1/charges — the route that exists', () async {
      // `/api/charges` answers 404 in production and always has; every charge
      // this SDK ever tried to create failed there. Probed 2026-09-12:
      //   POST /api/charges    -> 404
      //   POST /api/v1/charges -> 401 (exists, wants auth)
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(chargeJson()), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.create(
        productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        paymentMethod: ChargeMethod.pix,
        customer: _customer,
      );

      expect(captured.url.path, '/api/v1/charges');
      expect(captured.method, 'POST');
      garu.close();
    });

    test('sends the customer block the v1 contract validates', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(chargeJson()), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.create(
        productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        paymentMethod: ChargeMethod.pix,
        customer: _customer,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      final customer = body['customer'] as Map<String, dynamic>;
      expect(customer.keys.toSet(), {'name', 'email', 'document', 'phone'});
      // `personType` was sent until 0.8.0 and is not in the v1 DTO, so
      // ValidationPipe({whitelist: true}) dropped it silently.
      expect(customer.containsKey('personType'), isFalse);
      garu.close();
    });

    test('sends a card the way v1 validates it: expirationDate + installments',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
            jsonEncode(chargeJson({'paymentMethod': 'creditCard'})), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.create(
        productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        paymentMethod: ChargeMethod.creditCard,
        customer: _customer,
        card: const CardInput(
          number: '4111111111111111',
          holderName: 'MARIA SILVA',
          expirationDate: '2030-12',
          cvv: '123',
          installments: 2,
        ),
      );

      final card =
          (jsonDecode(captured.body) as Map<String, dynamic>)['card'] as Map;
      // expirationMonth/expirationYear were sent until 0.8.0; the required
      // `expirationDate` was missing, so every card charge would 400.
      expect(card['expirationDate'], '2030-12');
      expect(card['installments'], 2);
      expect(card.containsKey('expirationMonth'), isFalse);
      garu.close();
    });

    test('never sends an amount — the server prices the charge', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(chargeJson()), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.create(
        productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
        paymentMethod: ChargeMethod.pix,
        customer: _customer,
        offer: 'black-friday',
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('amount'), isFalse);
      // The offer names the price; it never carries one.
      expect(body['offer'], 'black-friday');
      garu.close();
    });

    test('sends no idempotency key unless the caller supplies one', () async {
      // A key invented per call is different on every attempt, so it protects
      // nothing while making the request look protected. That is what charged
      // a real buyer three times on 2026-09-08.
      final keys = <String?>[];
      final client = MockClient((req) async {
        keys.add(req.headers['X-Idempotency-Key']);
        return http.Response(jsonEncode(chargeJson()), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.create(
        productId: 'p',
        paymentMethod: ChargeMethod.pix,
        customer: _customer,
      );
      await garu.charges.create(
        productId: 'p',
        paymentMethod: ChargeMethod.pix,
        customer: _customer,
        idempotencyKey: 'order:4472:charge',
      );

      expect(keys, [null, 'order:4472:charge']);
      garu.close();
    });
  });

  group('charges money', () {
    test('keeps the base price and what was actually charged apart', () {
      // Figures derived from the gateway's own ladder at the platform default
      // fator of 1.2, not copied from what this SDK happens to return:
      //   per parcela = 349 * (1 + (2-1)/11 * (1.2-1)) / 2 = 177.67
      //   collected   = 177.67 * 2                         = 355.34
      // A R$349 sale in 2x collects ~R$355, not ~R$178. Reading either number
      // as the other is the 21-month undercharge: `amount` is the base price,
      // `chargedTotal` is what the buyer actually pays.
      final charge = PublicCharge.fromJson(chargeJson({
        'paymentMethod': 'creditCard',
        'amount': 349.0,
        'chargedTotal': 355.34,
        'installments': 2,
      }));

      expect(charge.amount, 349.0);
      expect(charge.chargedTotal, 355.34);
      // The buyer pays the markup, so the total is above the sticker price.
      expect(charge.chargedTotal, greaterThan(charge.amount));
      // And it is the TOTAL, not one parcela — half of it would be ~177.67.
      expect(charge.chargedTotal / charge.installments, closeTo(177.67, 0.01));
      expect(charge.chargedTotal, greaterThan(300));
    });

    test('falls back to amount when chargedTotal is absent', () {
      final charge = PublicCharge.fromJson({
        'uuid': 'u',
        'status': 'pending',
        'paymentMethod': 'pix',
        'amount': 29.9,
        'createdAt': '2026-09-12T14:22:01.000Z',
      });
      expect(charge.chargedTotal, 29.9);
    });

    test('parses the rails a buyer actually pays with', () {
      final pix = PublicCharge.fromJson(chargeJson({
        'pix': {'code': '00020126580014BR.GOV.BCB.PIX'},
      }));
      expect(pix.pix?.code, '00020126580014BR.GOV.BCB.PIX');
      expect(pix.boleto, isNull);

      final boleto = PublicCharge.fromJson(chargeJson({
        'paymentMethod': 'boleto',
        'boleto': {
          'barcodeLine':
              '23793.38128 60007.827136 65000.063305 4 96550000034990',
          'pdfUrl': 'https://garu.com.br/boleto/abc.pdf',
        },
      }));
      expect(boleto.boleto?.pdfUrl, 'https://garu.com.br/boleto/abc.pdf');
    });
  });

  group('charges.refund', () {
    test('refunds by uuid and sends the amount in reais', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
            jsonEncode(chargeJson({
              'refund': {
                'amount': 10.0,
                'reason': 'Cliente desistiu',
                'refundedAt': '2026-09-12T15:00:00.000Z'
              }
            })),
            200,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final charge = await garu.charges.refund(
        '6f1c9b2e-4a7d-4f0b-9a3e-1d2c3b4a5e6f',
        const RefundParams(amount: 10.0, reason: 'Cliente desistiu'),
      );

      expect(captured.url.path,
          '/api/v1/charges/6f1c9b2e-4a7d-4f0b-9a3e-1d2c3b4a5e6f/refund');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      // R$10,00. Sent as 1000 until 0.8.0, which the gateway read as R$1.000,00.
      expect(body['amount'], 10.0);
      expect(charge.refund?.amount, 10.0);
      garu.close();
    });

    test('sends no body at all for a full refund', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(chargeJson()), 200,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.refund('6f1c9b2e-4a7d-4f0b-9a3e-1d2c3b4a5e6f');

      expect(captured.body, isEmpty);
      expect(captured.headers.containsKey('X-Idempotency-Key'), isFalse);
      garu.close();
    });
  });

  group('charges.retrieve / list / cancel', () {
    test('retrieve URL-encodes the uuid so it cannot inject path segments',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(chargeJson()), 200,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.charges.retrieve('../../admin/sellers');

      expect(captured.url.path, '/api/v1/charges/..%2F..%2Fadmin%2Fsellers');
      garu.close();
    });

    test('list parses the v1 envelope', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
            jsonEncode({
              'data': [
                chargeJson(),
                chargeJson({'uuid': 'second'})
              ],
              'totalCount': 2,
              'totalPages': 1,
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final page = await garu.charges.list(status: 'paid', limit: 50);

      expect(captured.url.path, '/api/v1/charges');
      expect(captured.url.queryParameters['status'], 'paid');
      expect(captured.url.queryParameters['limit'], '50');
      expect(page.data.map((c) => c.uuid),
          ['6f1c9b2e-4a7d-4f0b-9a3e-1d2c3b4a5e6f', 'second']);
      expect(page.totalCount, 2);
      garu.close();
    });

    test('cancel reports whether the charge was canceled', () async {
      final client = MockClient((req) async => http.Response(
          jsonEncode({'canceled': true}), 200,
          headers: {'content-type': 'application/json'}));
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      expect(await garu.charges.cancel('6f1c9b2e-...'), isTrue);
      garu.close();
    });
  });
}
