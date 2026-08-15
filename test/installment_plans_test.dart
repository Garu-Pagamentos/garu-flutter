import 'dart:convert';

import 'package:garu/garu.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const planUuid = 'e5d0d8fe-0000-4000-8000-000000000001';
const productUuid = '40381e8e-6ee7-4b8e-9393-766a6e2109d2';

// A R$1.200 product sold in 12x at production's fator 1,30. Derived by hand:
// 1200 * 1,30 = 1560,00 total; 1560 / 12 = 130,00 a parcela.
final planJson = {
  'uuid': planUuid,
  'status': 'pending_activation',
  'installments': 12,
  'installmentsPaid': 0,
  'baseValue': 1200,
  'fator': 1.3,
  'installmentAmount': 130,
  'totalScheduled': 1560,
  'totalCollected': 0,
  'firstDueDate': '2026-09-05',
  'graceDays': 5,
  'product': {'uuid': productUuid, 'name': 'Curso'},
  'customer': {'name': 'Ana', 'email': 'ana@example.com'},
  'createdAt': '2026-09-01T09:00:00.000Z',
  'installmentsDetail': [
    {
      'number': 1,
      'amount': 130,
      'dueDate': '2026-09-05',
      'status': 'scheduled',
      'paidAt': null,
      'boleto': {'barcodeLine': '50990000010', 'pdfUrl': 'https://garu/b/1'},
      'reissueCount': 0,
    },
    {
      'number': 2,
      'amount': 130,
      'dueDate': '2026-10-05',
      'status': 'scheduled',
      'paidAt': null,
      'boleto': null,
      'reissueCount': 0,
    },
  ],
};

void main() {
  group('installmentPlans.create', () {
    test('posts to the v1 route and parses the money as stored', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(planJson), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      final carne = await garu.installmentPlans.create(
        const CreateInstallmentPlanParams(
          productId: productUuid,
          customerId: 4821,
          installments: 12,
        ),
      );

      expect(captured.url.path, '/api/v1/installment-plans');
      // Hand-derived above, not read back off the fixture builder.
      expect(carne.totalScheduled, 1560);
      expect(carne.installmentAmount, 130);
      expect(carne.installmentsDetail, hasLength(2));
    });

    test('always sends an idempotency key', () async {
      // The call registers a REAL boleto. A retry without a key puts two
      // payable barcodes in one buyer's hands.
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(planJson), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.installmentPlans.create(
        const CreateInstallmentPlanParams(
          productId: productUuid,
          customerId: 4821,
          installments: 12,
        ),
      );

      expect(captured.headers['X-Idempotency-Key'], isNotEmpty);
    });

    test('forwards the affiliate so the commission is not lost', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(planJson), 201,
            headers: {'content-type': 'application/json'});
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.installmentPlans.create(
        const CreateInstallmentPlanParams(
          productId: productUuid,
          customerId: 4821,
          installments: 12,
          affiliateId: 5,
        ),
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['affiliateId'], 5);
    });
  });

  group('installmentPlans.list', () {
    test('repeats the status parameter rather than joining it', () async {
      // The gateway expects `?status=active&status=defaulted`. Comma-joining
      // arrives as one invalid enum value and is rejected with 400.
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'data': <Map<String, dynamic>>[],
            'count': 0,
            'totalCount': 0,
            'totalPages': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final garu = Garu(apiKey: 'sk_test_x', httpClient: client);

      await garu.installmentPlans.list(status: ['active', 'defaulted']);

      expect(
        captured.url.queryParametersAll['status'],
        ['active', 'defaulted'],
      );
    });
  });

  group('Installment', () {
    test('reports no payable slip for a parcela never emitted', () {
      // Parcelas 2..N do not exist as slips until their emission window. A
      // buyer must not be shown an empty barcode as if it were payable.
      final plan = InstallmentPlan.fromJson(planJson);

      expect(plan.installmentsDetail[0].isPayable, isTrue);
      expect(plan.installmentsDetail[1].barcodeLine, isNull);
      expect(plan.installmentsDetail[1].isPayable, isFalse);
    });

    test('a pending_activation plan is not yet a sale', () {
      expect(InstallmentPlan.fromJson(planJson).isSale, isFalse);
    });

    test('remaining never goes negative when multa pushes collections up', () {
      // A bank can add multa or mora, so totalCollected can legitimately
      // exceed totalScheduled. Naive subtraction would report a negative debt.
      final plan = InstallmentPlan.fromJson({
        ...planJson,
        'totalCollected': 1600,
      });

      expect(plan.remainingScheduled, 0);
    });
  });
}
