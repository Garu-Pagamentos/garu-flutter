import 'dart:convert';

import 'package:garu/garu.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('scheduledCharges.chargeNow', () {
    test('POSTs to /charge-now with no body and parses a dispatched result',
        () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'outcome': 'dispatched',
            'cycleNumber': 3,
            'message': 'Charge dispatched for cycle 3.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final result = await garu.scheduledCharges.chargeNow('scc_01HG');

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/scheduled-charges/scc_01HG/charge-now');
      expect(captured.body, isEmpty);
      // No JSON body means no Content-Type is attached by the runner.
      expect(captured.headers.containsKey('content-type'), isFalse);
      expect(captured.headers['authorization'], 'Bearer sk_test_x');

      expect(result.outcome, ChargeNowOutcome.dispatched);
      expect(result.cycleNumber, 3);
      expect(result.reason, isNull);

      garu.close();
    });

    test('URL-encodes the id so it cannot inject path/query segments', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'outcome': 'dispatched', 'message': 'ok'}),
          200,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.scheduledCharges.chargeNow('scc_1/../999?x=1');

      // The id stays a single decoded path segment — its `/` and `?` cannot
      // spawn extra segments or leak a query string.
      expect(captured.url.pathSegments, [
        'api',
        'scheduled-charges',
        'scc_1/../999?x=1',
        'charge-now',
      ]);
      expect(captured.url.query, isEmpty);

      garu.close();
    });

    test('maps a failed outcome with reason', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({
              'outcome': 'failed',
              'cycleNumber': 2,
              'reason': 'card_expired',
              'message': 'The saved card has expired.',
            }),
            200,
          ));
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final result = await garu.scheduledCharges.chargeNow('scc_01HG');
      expect(result.outcome, ChargeNowOutcome.failed);
      expect(result.reason, 'card_expired');
      expect(result.cycleNumber, 2);

      garu.close();
    });

    test('throws GaruApiError on 400 (not in a billable status)', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'message': 'Charge is not in a billable status'}),
            400,
          ));
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      expect(
        () => garu.scheduledCharges.chargeNow('scc_01HG'),
        throwsA(isA<GaruApiError>()),
      );

      garu.close();
    });
  });

  group('scheduledCharges.create — pix_automatic', () {
    test('sends a recurring pix_automatic series and parses it back', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'id': 'scc_pa',
            'sellerId': 7,
            'customerId': 123,
            'productId': 456,
            'amount': 297.5,
            'type': 'recurring',
            'status': 'scheduled',
            'dueDate': '2026-06-15',
            'methods': ['pix_automatic'],
          }),
          200,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final record = await garu.scheduledCharges.create(
        const CreateScheduledChargeParams(
          customerId: 123,
          productId: 456,
          amount: 297.5,
          type: 'recurring',
          dueDate: '2026-06-15',
          methods: ['pix_automatic'],
          recurrence: {'interval': 'monthly'},
        ),
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['methods'], ['pix_automatic']);
      expect(body['productId'], 456);
      expect(record.methods, contains('pix_automatic'));

      garu.close();
    });

    test('asserts pix_automatic requires type recurring', () {
      final garu = Garu(apiKey: 'sk_test_x', httpClient: MockClient((_) async {
        return http.Response('{}', 200);
      }));
      expect(
        garu.scheduledCharges.create(
          const CreateScheduledChargeParams(
            customerId: 1,
            productId: 456,
            amount: 10,
            type: 'one_time',
            dueDate: '2026-06-15',
            methods: ['pix_automatic'],
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
      garu.close();
    });

    test('asserts pix_automatic requires a productId', () {
      final garu = Garu(apiKey: 'sk_test_x', httpClient: MockClient((_) async {
        return http.Response('{}', 200);
      }));
      expect(
        garu.scheduledCharges.create(
          const CreateScheduledChargeParams(
            customerId: 1,
            amount: 10,
            type: 'recurring',
            dueDate: '2026-06-15',
            methods: ['pix_automatic'],
            recurrence: {'interval': 'monthly'},
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
      garu.close();
    });
  });

  group('scheduledCharges.create — maxRecoveryDays', () {
    test('sends maxRecoveryDays in the request body when provided', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'id': 'scc_new',
            'sellerId': 7,
            'customerId': 99,
            'amount': 49.9,
            'type': 'recurring',
            'status': 'scheduled',
            'dueDate': '2026-06-01',
            'maxRecoveryDays': 30,
          }),
          200,
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final record = await garu.scheduledCharges.create(
        const CreateScheduledChargeParams(
          customerId: 99,
          amount: 49.9,
          type: 'recurring',
          dueDate: '2026-06-01',
          methods: ['card'],
          recurrence: {'interval': 'monthly'},
          maxRecoveryDays: 30,
        ),
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['maxRecoveryDays'], 30);
      expect(record.maxRecoveryDays, 30);

      garu.close();
    });
  });
}
