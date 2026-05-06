import 'package:garu/garu.dart';
import 'package:test/test.dart';

void main() {
  group('GaruFailureCode', () {
    test('parses all known wire values', () {
      expect(GaruFailureCode.fromWire('insufficient_funds'), GaruFailureCode.insufficientFunds);
      expect(GaruFailureCode.fromWire('card_expired'), GaruFailureCode.cardExpired);
      expect(GaruFailureCode.fromWire('do_not_honor_repeated'),
          GaruFailureCode.doNotHonorRepeated);
    });

    test('falls back to unknown for unrecognized values (forward compat)', () {
      expect(GaruFailureCode.fromWire('some_future_code'), GaruFailureCode.unknown);
      expect(GaruFailureCode.fromWire(null), GaruFailureCode.unknown);
    });

    test('isPermanent flags card_expired / card_canceled / fraud_suspected', () {
      expect(GaruFailureCode.cardExpired.isPermanent, isTrue);
      expect(GaruFailureCode.cardCanceled.isPermanent, isTrue);
      expect(GaruFailureCode.fraudSuspected.isPermanent, isTrue);
      expect(GaruFailureCode.insufficientFunds.isPermanent, isFalse);
      expect(GaruFailureCode.cardDeclined.isPermanent, isFalse);
    });
  });

  group('PaginatedList', () {
    test('parses standard envelope', () {
      final list = PaginatedList.fromJson({
        'data': [
          {'id': 1, 'name': 'A'},
          {'id': 2, 'name': 'B'},
        ],
        'meta': {'page': 2, 'limit': 10, 'total': 25, 'totalPages': 3},
      }, (json) => json);

      expect(list.data, hasLength(2));
      expect(list.data[0]['id'], 1);
      expect(list.meta.page, 2);
      expect(list.meta.totalPages, 3);
    });

    test('handles missing meta gracefully', () {
      final list = PaginatedList.fromJson({'data': <Map<String, dynamic>>[]}, (json) => json);
      expect(list.data, isEmpty);
      expect(list.meta.page, 1);
    });
  });

  group('Charge.fromJson', () {
    test('parses a paid PIX charge', () {
      final c = Charge.fromJson({
        'id': 42,
        'value': 297.5,
        'paymentMethod': 'pix',
        'status': 'paid',
        'date': '2026-05-05T10:00:00Z',
        'productId': 17,
        'customerId': 99,
      });
      expect(c.id, 42);
      expect(c.value, 297.5);
      expect(c.paymentMethod, 'pix');
      expect(c.status, 'paid');
      expect(c.failureCode, isNull);
    });

    test('parses a failed charge with failure metadata', () {
      final c = Charge.fromJson({
        'id': 43,
        'value': 49.9,
        'paymentMethod': 'creditcard',
        'status': 'denied',
        'date': '2026-05-05T11:00:00Z',
        'failureCode': 'insufficient_funds',
        'failureReason': 'Saldo insuficiente',
        'gatewayFailureCode': '51',
      });
      expect(c.failureCode, GaruFailureCode.insufficientFunds);
      expect(c.failureReason, 'Saldo insuficiente');
      expect(c.gatewayFailureCode, '51');
    });
  });

  group('ScheduledChargeAttempt.fromJson', () {
    test('parses a card_retry decline', () {
      final a = ScheduledChargeAttempt.fromJson({
        'id': 1234,
        'cycleId': 'scc_01HG',
        'cycleNumber': 3,
        'attemptNumber': 4,
        'attemptedAt': '2026-05-04T19:00:00Z',
        'source': 'card_retry',
        'paymentMethod': 'card',
        'paymentMethodId': 99,
        'cardLast4': '4242',
        'cardBrand': 'visa',
        'status': 'declined',
        'failureCode': 'insufficient_funds',
        'failureReason': 'Saldo insuficiente',
        'gatewayFailureCode': '51',
        'gatewayChargeId': 887766,
        'transactionId': 5544,
      });

      expect(a.source, ScheduledChargeAttemptSource.cardRetry);
      expect(a.status, ScheduledChargeAttemptStatus.declined);
      expect(a.failureCode, GaruFailureCode.insufficientFunds);
      expect(a.cardLast4, '4242');
      expect(a.cycleNumber, 3);
      expect(a.attemptNumber, 4);
    });

    test('forward-compatible source values fall back to unknown', () {
      final a = ScheduledChargeAttempt.fromJson({
        'id': 1,
        'cycleId': 'scc_x',
        'cycleNumber': 1,
        'attemptNumber': 1,
        'attemptedAt': '2026-05-04T00:00:00Z',
        'source': 'future_source_v2',
        'paymentMethod': 'card',
        'status': 'pending',
      });
      expect(a.source, ScheduledChargeAttemptSource.unknown);
      expect(a.status, ScheduledChargeAttemptStatus.pending);
    });
  });

  group('ProductPortalConfig + SetProductPortalConfigParams', () {
    test('parses persisted config', () {
      final c = ProductPortalConfig.fromJson({
        'productId': 57,
        'businessName': 'Coach Maria',
        'primaryColor': '#257264',
        'allowCancelSubscription': true,
        'requireCancelReason': false,
      });
      expect(c.productId, 57);
      expect(c.businessName, 'Coach Maria');
      expect(c.primaryColor, '#257264');
      expect(c.allowCancelSubscription, isTrue);
      expect(c.requireCancelReason, isFalse);
    });

    test('toJson omits unset fields (merge semantics)', () {
      const params = SetProductPortalConfigParams(
        primaryColor: '#888',
      );
      expect(params.toJson(), {'primaryColor': '#888'});
    });
  });
}
