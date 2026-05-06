import '../failure_codes.dart';

/// A Garu transaction (charge) record. Returned by `charges.create`,
/// `charges.get`, and the items of `charges.list`.
class Charge {
  Charge({
    required this.id,
    required this.value,
    required this.paymentMethod,
    required this.status,
    required this.date,
    this.galaxPayId,
    this.productId,
    this.customerId,
    this.failureCode,
    this.failureReason,
    this.gatewayFailureCode,
    this.refundedAt,
    this.raw = const {},
  });

  final int id;
  final num value;
  final String paymentMethod;
  final String status;
  final DateTime date;

  final int? galaxPayId;
  final int? productId;
  final int? customerId;

  /// Set on `transaction.payment.failed` / `scheduled_charge.cycle_failed`.
  final GaruFailureCode? failureCode;
  final String? failureReason;
  final String? gatewayFailureCode;

  final DateTime? refundedAt;

  /// The full server response — use this for fields not yet typed.
  final Map<String, dynamic> raw;

  factory Charge.fromJson(Map<String, dynamic> json) => Charge(
        id: (json['id'] as num).toInt(),
        value: (json['value'] as num?) ?? 0,
        paymentMethod: (json['paymentMethod'] as String?) ?? 'unknown',
        status: (json['status'] as String?) ?? 'unknown',
        date: _parseDate(json['date']) ?? DateTime.now().toUtc(),
        galaxPayId: (json['galaxPayId'] as num?)?.toInt(),
        productId: (json['productId'] as num?)?.toInt(),
        customerId: (json['customerId'] as num?)?.toInt(),
        failureCode:
            json['failureCode'] != null ? GaruFailureCode.fromWire(json['failureCode'] as String) : null,
        failureReason: json['failureReason'] as String?,
        gatewayFailureCode: json['gatewayFailureCode'] as String?,
        refundedAt: _parseDate(json['refundedAt']),
        raw: json,
      );
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
