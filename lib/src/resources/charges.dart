import '../http.dart';
import '../idempotency.dart';
import '../models/public_charge.dart';

/// Payment method accepted by [Charges.create].
///
/// These are the exact strings `/api/v1/charges` validates. Note `creditCard`,
/// not `credit_card`: the v1 contract is camelCase throughout.
abstract final class ChargeMethod {
  static const pix = 'pix';
  static const boleto = 'boleto';
  static const creditCard = 'creditCard';
}

/// The payer. `name`, `email`, `document` and `phone` are required; the address
/// block is optional and only worth sending when you already hold it.
class CustomerInput {
  const CustomerInput({
    required this.name,
    required this.email,
    required this.document,
    required this.phone,
    this.zipCode,
    this.street,
    this.number,
    this.complement,
    this.neighborhood,
    this.city,
    this.state,
  });

  /// Full name, 3 to 255 characters.
  final String name;
  final String email;

  /// CPF (11 digits) or CNPJ (14 digits), digits only — no dots, slashes or
  /// dashes. The API rejects punctuation.
  final String document;

  /// Area code + number, 10 or 11 digits, digits only.
  final String phone;

  /// CEP, 8 digits, no hyphen.
  final String? zipCode;
  final String? street;
  final String? number;
  final String? complement;
  final String? neighborhood;
  final String? city;

  /// Two-letter state code, uppercase (`'SP'`).
  final String? state;

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'document': document,
        'phone': phone,
        if (zipCode != null) 'zipCode': zipCode,
        if (street != null) 'street': street,
        if (number != null) 'number': number,
        if (complement != null) 'complement': complement,
        if (neighborhood != null) 'neighborhood': neighborhood,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
      };
}

/// Raw card data for `paymentMethod: 'creditCard'`.
///
/// The SDK forwards this to the Garu API, which tokenizes server-side; the PAN
/// and CVV are never persisted by Garu. They do still travel through your
/// process, so call this from your server, in a PCI-compliant environment —
/// never from a Flutter app running on a customer's device.
class CardInput {
  const CardInput({
    required this.number,
    required this.holderName,
    required this.expirationDate,
    required this.cvv,
    this.installments = 1,
  });

  /// 13 to 19 digits, no spaces.
  final String number;

  /// Holder name as printed on the card.
  final String holderName;

  /// Expiry as `YYYY-MM` (e.g. `'2030-12'`).
  final String expirationDate;

  /// 3 or 4 digits.
  final String cvv;

  /// 1 to 12. Above 1 the buyer pays the instalment markup (`fator`), so the
  /// charge collects MORE than the product price — compare `amount` against
  /// `chargedTotal` on the response.
  final int installments;

  Map<String, dynamic> toJson() => {
        'number': number,
        'holderName': holderName,
        'expirationDate': expirationDate,
        'cvv': cvv,
        'installments': installments,
      };
}

/// Refund parameters. Omit `amount` for a full refund.
class RefundParams {
  const RefundParams({this.amount, this.reason, this.idempotencyKey});

  /// Amount to refund in **reais** (decimal BRL) — `10.0` is R$10,00, NOT ten
  /// centavos. Omit for a full refund. Capped at the charge's `chargedTotal`.
  final num? amount;
  final String? reason;

  /// Pix and boleto refunds open a refund REQUEST rather than reversing
  /// automatically, so a blind retry can open a second one. Pass a stable key
  /// to make the retry return the original request. Ignored for card.
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
        if (amount != null) 'amount': amount,
        if (reason != null) 'reason': reason,
      };
}

/// Charges — create and manage payments against a product.
///
/// Backed by `/api/v1/charges`, the versioned public contract. A charge is
/// keyed by `uuid`; there is no numeric id.
class Charges {
  Charges(this._http);

  final HttpRunner _http;

  /// Create a charge (PIX, boleto, or credit card).
  ///
  /// The amount is NOT a parameter. The server resolves it from the product, or
  /// from [offer] when you pass one, so a caller can never name its own price.
  ///
  /// Pass [idempotencyKey] to make this safe to retry: the same key returns the
  /// original charge for 24h. Derive it from something stable in your own domain
  /// (an order id, a booking id) so a retry reproduces it. Omit it and no key is
  /// sent — the SDK does not invent one, because a key generated per call is
  /// different every time and protects nothing.
  ///
  /// ```dart
  /// final charge = await garu.charges.create(
  ///   productId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  ///   paymentMethod: ChargeMethod.pix,
  ///   customer: const CustomerInput(
  ///     name: 'Maria Silva',
  ///     email: 'maria@exemplo.com.br',
  ///     document: '12345678909',
  ///     phone: '11987654321',
  ///   ),
  /// );
  /// // render charge.pix!.code as a QR in your own checkout
  /// ```
  Future<PublicCharge> create({
    required String productId,
    required String paymentMethod,
    required CustomerInput customer,
    CardInput? card,
    String? offer,
    String? checkoutSessionToken,
    String? additionalInfo,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'productId': productId,
      'paymentMethod': paymentMethod,
      'customer': customer.toJson(),
      // Sent as the slug or the offer id. The SERVER resolves the price from
      // it — nothing about the amount comes from here.
      if (offer != null) 'offer': offer,
      if (card != null) 'card': card.toJson(),
      if (checkoutSessionToken != null)
        'checkoutSessionToken': checkoutSessionToken,
      if (additionalInfo != null) 'additionalInfo': additionalInfo,
    };
    final json = await _http.request(
      'POST',
      '/api/v1/charges',
      body: body,
      extraHeaders: idempotencyHeaders(idempotencyKey),
    );
    return PublicCharge.fromJson(json);
  }

  /// Retrieve a charge by uuid.
  Future<PublicCharge> retrieve(String uuid) async {
    final json = await _http.request(
      'GET',
      '/api/v1/charges/${Uri.encodeComponent(uuid)}',
    );
    return PublicCharge.fromJson(json);
  }

  /// List charges for the authenticated account, newest first by default.
  Future<PublicChargeList> list({
    int? page,
    int? limit,
    String? status,
    String? paymentMethod,
    String? productId,
    String? createdAfter,
    String? createdBefore,
    String? search,
    String? sort,
  }) async {
    final query = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (status != null) 'status': status,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (productId != null) 'productId': productId,
      if (createdAfter != null) 'createdAfter': createdAfter,
      if (createdBefore != null) 'createdBefore': createdBefore,
      if (search != null) 'search': search,
      if (sort != null) 'sort': sort,
    };
    final json = await _http.request('GET', '/api/v1/charges', query: query);
    return PublicChargeList.fromJson(json);
  }

  /// Refund a charge, fully or partially. `amount` is in **reais**.
  ///
  /// ```dart
  /// await garu.charges.refund('6f1c9b2e-...');                        // full
  /// await garu.charges.refund('6f1c9b2e-...', const RefundParams(amount: 10.0));
  /// ```
  Future<PublicCharge> refund(String uuid, [RefundParams? params]) async {
    final body = params?.toJson() ?? const <String, dynamic>{};
    final json = await _http.request(
      'POST',
      '/api/v1/charges/${Uri.encodeComponent(uuid)}/refund',
      body: body.isEmpty ? null : body,
      extraHeaders: idempotencyHeaders(params?.idempotencyKey),
    );
    return PublicCharge.fromJson(json);
  }

  /// Cancel an unpaid charge.
  Future<bool> cancel(String uuid) async {
    final json = await _http.request(
      'DELETE',
      '/api/v1/charges/${Uri.encodeComponent(uuid)}',
    );
    return json['canceled'] == true;
  }
}
