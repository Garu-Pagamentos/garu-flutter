import '../json.dart';

/// A charge as `/api/v1/charges` represents it.
///
/// Distinct from [Charge] (`models/charge.dart`), which models the internal
/// `transaction.*` shape that arrives on WEBHOOKS and carries `galaxPayId`,
/// failure codes and numeric ids. The two are not interchangeable; this one is
/// what every `garu.charges.*` call returns.
///
/// MONEY: [amount] is the product's base price and [chargedTotal] is what the
/// customer is actually charged. They differ on instalment card sales, where
/// [chargedTotal] carries the instalment markup and is therefore LARGER. Never
/// collapse the two — reconcile against [chargedTotal].
class PublicCharge {
  const PublicCharge({
    required this.uuid,
    required this.status,
    required this.paymentMethod,
    required this.amount,
    required this.chargedTotal,
    required this.installments,
    required this.createdAt,
    this.product,
    this.customer,
    this.pix,
    this.boleto,
    this.card,
    this.refund,
    this.expiresAt,
    this.raw = const {},
  });

  final String uuid;
  final String status;

  /// `'pix'`, `'boleto'` or `'creditCard'`.
  final String paymentMethod;

  /// The product's base price, in reais.
  final num amount;

  /// What the customer is actually charged, in reais. Equal to [amount] on a
  /// single-instalment sale; larger once the instalment markup applies.
  final num chargedTotal;

  final int installments;

  final ChargeProduct? product;
  final ChargeCustomer? customer;

  /// Present on a PIX charge — `pix.code` is the copy-and-paste / QR payload.
  final ChargePix? pix;

  /// Present on a boleto charge.
  final ChargeBoleto? boleto;

  /// Present on a card charge.
  final ChargeCard? card;

  /// Present once the charge has been refunded, fully or partly.
  final ChargeRefund? refund;

  final DateTime createdAt;
  final DateTime? expiresAt;

  /// The full server response — for fields this build does not yet type.
  final Map<String, dynamic> raw;

  factory PublicCharge.fromJson(Map<String, dynamic> json) => PublicCharge(
        uuid: (json['uuid'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'unknown',
        paymentMethod: (json['paymentMethod'] as String?) ?? 'unknown',
        amount: toNumOr(json['amount'], 0),
        chargedTotal: toNumOr(json['chargedTotal'], toNumOr(json['amount'], 0)),
        installments: toNumOr(json['installments'], 1).toInt(),
        product: json['product'] is Map<String, dynamic>
            ? ChargeProduct.fromJson(json['product'] as Map<String, dynamic>)
            : null,
        customer: json['customer'] is Map<String, dynamic>
            ? ChargeCustomer.fromJson(json['customer'] as Map<String, dynamic>)
            : null,
        pix: json['pix'] is Map<String, dynamic>
            ? ChargePix.fromJson(json['pix'] as Map<String, dynamic>)
            : null,
        boleto: json['boleto'] is Map<String, dynamic>
            ? ChargeBoleto.fromJson(json['boleto'] as Map<String, dynamic>)
            : null,
        card: json['card'] is Map<String, dynamic>
            ? ChargeCard.fromJson(json['card'] as Map<String, dynamic>)
            : null,
        refund: json['refund'] is Map<String, dynamic>
            ? ChargeRefund.fromJson(json['refund'] as Map<String, dynamic>)
            : null,
        createdAt: _parseDate(json['createdAt']) ?? DateTime.now().toUtc(),
        expiresAt: _parseDate(json['expiresAt']),
        raw: json,
      );
}

class ChargeProduct {
  const ChargeProduct({required this.uuid, required this.name});
  final String uuid;
  final String name;
  factory ChargeProduct.fromJson(Map<String, dynamic> j) => ChargeProduct(
        uuid: (j['uuid'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
      );
}

class ChargeCustomer {
  const ChargeCustomer({
    required this.name,
    required this.email,
    required this.document,
  });
  final String name;
  final String email;

  /// Partially masked by the API (SEC-6) — you supplied the full value.
  final String document;
  factory ChargeCustomer.fromJson(Map<String, dynamic> j) => ChargeCustomer(
        name: (j['name'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        document: (j['document'] as String?) ?? '',
      );
}

class ChargePix {
  const ChargePix({required this.code});

  /// The EMV payload. Render as a QR code, and offer it as copy-and-paste.
  final String code;
  factory ChargePix.fromJson(Map<String, dynamic> j) =>
      ChargePix(code: (j['code'] as String?) ?? '');
}

class ChargeBoleto {
  const ChargeBoleto({required this.barcodeLine, required this.pdfUrl});
  final String barcodeLine;

  /// Garu-hosted PDF of the slip.
  final String pdfUrl;
  factory ChargeBoleto.fromJson(Map<String, dynamic> j) => ChargeBoleto(
        barcodeLine: (j['barcodeLine'] as String?) ?? '',
        pdfUrl: (j['pdfUrl'] as String?) ?? '',
      );
}

class ChargeCard {
  const ChargeCard({this.brand, this.last4, this.authorizationCode});
  final String? brand;
  final String? last4;
  final String? authorizationCode;
  factory ChargeCard.fromJson(Map<String, dynamic> j) => ChargeCard(
        brand: j['brand'] as String?,
        last4: j['last4'] as String?,
        authorizationCode: j['authorizationCode'] as String?,
      );
}

class ChargeRefund {
  const ChargeRefund({required this.amount, this.reason, this.refundedAt});

  /// Refunded amount in reais.
  final num amount;
  final String? reason;

  /// Null while a Pix devolução has been requested but has not settled.
  final DateTime? refundedAt;
  factory ChargeRefund.fromJson(Map<String, dynamic> j) => ChargeRefund(
        amount: toNumOr(j['amount'], 0),
        reason: j['reason'] as String?,
        refundedAt: _parseDate(j['refundedAt']),
      );
}

/// One page of `charges.list`.
class PublicChargeList {
  const PublicChargeList({
    required this.data,
    required this.totalCount,
    required this.totalPages,
  });

  final List<PublicCharge> data;
  final int totalCount;
  final int totalPages;

  factory PublicChargeList.fromJson(Map<String, dynamic> json) =>
      PublicChargeList(
        data: (json['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PublicCharge.fromJson)
            .toList(),
        totalCount: toNumOr(json['totalCount'], 0).toInt(),
        totalPages: toNumOr(json['totalPages'], 0).toInt(),
      );
}

DateTime? _parseDate(Object? v) {
  if (v is String) return DateTime.tryParse(v);
  return null;
}
