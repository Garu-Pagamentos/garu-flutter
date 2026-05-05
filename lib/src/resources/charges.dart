import '../http.dart';
import '../idempotency.dart';

/// Customer block accepted by [Charges.create].
class CustomerInput {
  const CustomerInput({
    required this.name,
    required this.email,
    required this.document,
    required this.phone,
    this.personType = 'fisica',
  });

  final String name;
  final String email;
  final String document;
  final String phone;
  final String personType;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'document': document,
        'phone': phone,
        'personType': personType,
      };
}

/// Raw card data for `paymentMethod: 'credit_card'`. PCI considerations: the
/// SDK forwards directly to the Garu API which uses Celcoin tokenization
/// server-side. PAN/CVV never persist on Garu's side.
class CardInput {
  const CardInput({
    required this.number,
    required this.holderName,
    required this.expirationMonth,
    required this.expirationYear,
    required this.cvv,
  });

  final String number;
  final String holderName;
  final String expirationMonth;
  final String expirationYear;
  final String cvv;

  Map<String, dynamic> toJson() => {
        'number': number,
        'holderName': holderName,
        'expirationMonth': expirationMonth,
        'expirationYear': expirationYear,
        'cvv': cvv,
      };
}

/// Refund parameters. Omit `amount` for a full refund; pass it (in centavos)
/// for a partial refund.
class RefundParams {
  const RefundParams({this.amount, this.reason});

  /// Refund amount in centavos. e.g. `1000` = R$10.00. Omit for full refund.
  final int? amount;
  final String? reason;
}

/// Charges resource — create / list / get / refund. Mirrors `garu.charges`
/// in `@garuhq/node`.
class Charges {
  Charges(this._http);

  final HttpRunner _http;

  /// Create a charge. Auto-attaches `X-Idempotency-Key` (UUIDv4) unless
  /// [idempotencyKey] is provided.
  ///
  /// Returns the raw response map (full type modeling deferred to v1.0.0).
  Future<Map<String, dynamic>> create({
    required String productId,
    required String paymentMethod,
    required CustomerInput customer,
    CardInput? card,
    int? amount,
    String? description,
    String? idempotencyKey,
  }) {
    final body = <String, dynamic>{
      'productId': productId,
      'paymentMethod': paymentMethod,
      'customer': customer.toJson(),
      if (card != null) 'card': card.toJson(),
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
    };
    return _http.request(
      'POST',
      '/api/charges',
      body: body,
      extraHeaders: {
        'X-Idempotency-Key': idempotencyKey ?? generateIdempotencyKey(),
      },
    );
  }

  /// List charges. Returns the API's paginated envelope (`data`, `meta`).
  Future<Map<String, dynamic>> list({
    int? page,
    int? limit,
    String? status,
    String? customerId,
  }) {
    final query = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (status != null) 'status': status,
      if (customerId != null) 'customerId': customerId,
    };
    return _http.request('GET', '/api/charges', query: query);
  }

  /// Fetch a single charge by id.
  Future<Map<String, dynamic>> get(int id) {
    return _http.request('GET', '/api/charges/$id');
  }

  /// Refund a charge. Omit `amount` in [params] for a full refund.
  Future<Map<String, dynamic>> refund(int id, [RefundParams? params]) {
    final body = <String, dynamic>{
      if (params?.amount != null) 'amount': params!.amount,
      if (params?.reason != null) 'reason': params!.reason,
    };
    return _http.request(
      'POST',
      '/api/charges/$id/refund',
      body: body.isEmpty ? null : body,
      extraHeaders: {'X-Idempotency-Key': generateIdempotencyKey()},
    );
  }
}
