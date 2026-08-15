/// A refund Garu has been ASKED to make and has not made.
///
/// Garu never moves this money. A boleto cannot be reversed and Celcoin
/// exposes no Pix devolução, so the funds already settled to the seller and
/// the return is a bank transfer only they can make. Confirming a request
/// records that the seller *asserts* the money went back; Garu never observes
/// the transfer.
class RefundRequest {
  const RefundRequest({
    required this.uuid,
    required this.status,
    required this.amount,
    this.reason,
    this.installmentPlanId,
    this.chargeId,
    this.requestedBy = const {},
    this.resolvedBy,
    this.sellerNote,
    this.resolvedAt,
    this.createdAt,
    this.raw = const {},
  });

  final String uuid;

  /// `pending`, `confirmed` or `rejected`.
  final String status;

  /// Amount the seller is being asked to return, in reais.
  final num amount;
  final String? reason;

  /// Exactly one of [installmentPlanId] and [chargeId] is set.
  final String? installmentPlanId;
  final String? chargeId;

  final Map<String, dynamic> requestedBy;
  final Map<String, dynamic>? resolvedBy;
  final String? sellerNote;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  /// Money the seller still owes a buyer. `false` once resolved either way.
  bool get isOutstanding => status == 'pending';

  /// True for a carnê refund, false for a single Pix or boleto charge.
  bool get isForInstallmentPlan => installmentPlanId != null;

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) =>
        json[key] == null ? null : DateTime.tryParse(json[key] as String);

    return RefundRequest(
      uuid: (json['uuid'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      amount: (json['amount'] as num?) ?? 0,
      reason: json['reason'] as String?,
      installmentPlanId: json['installmentPlanId'] as String?,
      chargeId: json['chargeId'] as String?,
      requestedBy: (json['requestedBy'] as Map<String, dynamic>?) ?? const {},
      resolvedBy: json['resolvedBy'] as Map<String, dynamic>?,
      sellerNote: json['sellerNote'] as String?,
      resolvedAt: parse('resolvedAt'),
      createdAt: parse('createdAt'),
      raw: json,
    );
  }
}
