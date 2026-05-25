import '../failure_codes.dart';

/// A scheduled charge series record. Both one-time and recurring charges
/// use this shape — `type` discriminates.
class ScheduledChargeRecord {
  ScheduledChargeRecord({
    required this.id,
    required this.sellerId,
    required this.customerId,
    required this.amount,
    required this.type,
    required this.status,
    required this.dueDate,
    this.productId,
    this.methods = const [],
    this.paymentMethodId,
    this.recurrence,
    this.trialEndsAt,
    this.cancelAtPeriodEnd,
    this.maxRecoveryDays,
    this.raw = const {},
  });

  final String id;
  final int sellerId;
  final int customerId;
  final num amount;
  final String type;
  final String status;
  final String dueDate;
  final int? productId;
  final List<String> methods;
  final int? paymentMethodId;
  final Map<String, dynamic>? recurrence;
  final DateTime? trialEndsAt;
  final bool? cancelAtPeriodEnd;

  /// Days the gateway keeps retrying / accepting payment for a missed cycle
  /// before giving up. `null` when the series uses the system default (14).
  final int? maxRecoveryDays;

  final Map<String, dynamic> raw;

  factory ScheduledChargeRecord.fromJson(Map<String, dynamic> json) =>
      ScheduledChargeRecord(
        id: (json['id'] as String?) ?? '',
        sellerId: (json['sellerId'] as num?)?.toInt() ?? 0,
        customerId: (json['customerId'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?) ?? 0,
        type: (json['type'] as String?) ?? 'one_time',
        status: (json['status'] as String?) ?? 'scheduled',
        dueDate: (json['dueDate'] as String?) ?? '',
        productId: (json['productId'] as num?)?.toInt(),
        methods: ((json['methods'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        paymentMethodId: (json['paymentMethodId'] as num?)?.toInt(),
        recurrence: json['recurrence'] as Map<String, dynamic>?,
        trialEndsAt: _parseDate(json['trialEndsAt']),
        cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool?,
        maxRecoveryDays: (json['maxRecoveryDays'] as num?)?.toInt(),
        raw: json,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sellerId': sellerId,
        'customerId': customerId,
        'amount': amount,
        'type': type,
        'status': status,
        'dueDate': dueDate,
        if (productId != null) 'productId': productId,
        'methods': methods,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
        if (recurrence != null) 'recurrence': recurrence,
        if (trialEndsAt != null) 'trialEndsAt': trialEndsAt!.toIso8601String(),
        if (cancelAtPeriodEnd != null) 'cancelAtPeriodEnd': cancelAtPeriodEnd,
        if (maxRecoveryDays != null) 'maxRecoveryDays': maxRecoveryDays,
      };
}

/// Outcome of [ScheduledCharges.chargeNow] — what the gateway did when asked
/// to dispatch a cycle immediately instead of on its due date.
enum ChargeNowOutcome {
  /// The charge + customer notification were dispatched now.
  dispatched('dispatched'),

  /// This cycle had already gone out — nothing was re-charged (idempotent).
  alreadySent('already_sent'),

  /// Nothing was sent for a recoverable reason (see [ChargeNowResult.reason]:
  /// `no_email` | `lock_lost` | `no_saved_payment_method`).
  notSent('not_sent'),

  /// The charge attempt failed (see [ChargeNowResult.reason]: `card_expired`
  /// | `payment_method_missing` | `customer_missing` | a raw gateway code).
  failed('failed'),

  /// A value the gateway introduced after this SDK build. Inspect
  /// [ChargeNowResult.raw]; never thrown on, for forward compatibility.
  unknown('unknown');

  const ChargeNowOutcome(this.wireValue);
  final String wireValue;

  static ChargeNowOutcome fromWire(String? v) {
    if (v == null) return ChargeNowOutcome.unknown;
    for (final o in ChargeNowOutcome.values) {
      if (o.wireValue == v) return o;
    }
    return ChargeNowOutcome.unknown;
  }
}

/// Result of [ScheduledCharges.chargeNow].
class ChargeNowResult {
  ChargeNowResult({
    required this.outcome,
    required this.message,
    this.cycleNumber,
    this.reason,
    this.raw = const {},
  });

  /// What happened — branch on this.
  final ChargeNowOutcome outcome;

  /// Human-readable summary, always present.
  final String message;

  /// The cycle that was acted on, or `null` when no cycle was selected.
  final int? cycleNumber;

  /// Machine-readable detail for [ChargeNowOutcome.notSent] /
  /// [ChargeNowOutcome.failed]; `null` otherwise.
  final String? reason;

  final Map<String, dynamic> raw;

  factory ChargeNowResult.fromJson(Map<String, dynamic> json) => ChargeNowResult(
        outcome: ChargeNowOutcome.fromWire(json['outcome'] as String?),
        message: (json['message'] as String?) ?? '',
        cycleNumber: (json['cycleNumber'] as num?)?.toInt(),
        reason: json['reason'] as String?,
        raw: json,
      );
}

/// Source of a billing attempt — drives the "what happened here" narrative
/// in the per-attempt log (SPEC §3.1).
enum ScheduledChargeAttemptSource {
  cycle1Interactive('cycle1_interactive'),
  silentCharge('silent_charge'),
  cardRetry('card_retry'),
  manualMarkPaid('manual_mark_paid'),
  fallbackPix('fallback_pix'),
  unknown('unknown');

  const ScheduledChargeAttemptSource(this.wireValue);
  final String wireValue;

  static ScheduledChargeAttemptSource fromWire(String? v) {
    if (v == null) return ScheduledChargeAttemptSource.unknown;
    for (final s in ScheduledChargeAttemptSource.values) {
      if (s.wireValue == v) return s;
    }
    return ScheduledChargeAttemptSource.unknown;
  }
}

enum ScheduledChargeAttemptStatus {
  pending('pending'),
  succeeded('succeeded'),
  declined('declined'),
  canceled('canceled'),
  errored('errored'),
  unknown('unknown');

  const ScheduledChargeAttemptStatus(this.wireValue);
  final String wireValue;

  static ScheduledChargeAttemptStatus fromWire(String? v) {
    if (v == null) return ScheduledChargeAttemptStatus.unknown;
    for (final s in ScheduledChargeAttemptStatus.values) {
      if (s.wireValue == v) return s;
    }
    return ScheduledChargeAttemptStatus.unknown;
  }
}

/// One row from the per-attempt billing log (SPEC §3.1, §4.2). Returned
/// by `scheduledCharges.listAttempts`.
class ScheduledChargeAttempt {
  ScheduledChargeAttempt({
    required this.id,
    required this.cycleId,
    required this.cycleNumber,
    required this.attemptNumber,
    required this.attemptedAt,
    required this.source,
    required this.paymentMethod,
    required this.status,
    this.paymentMethodId,
    this.cardLast4,
    this.cardBrand,
    this.failureCode,
    this.failureReason,
    this.gatewayFailureCode,
    this.gatewayChargeId,
    this.transactionId,
  });

  final int id;
  final String cycleId;
  final int cycleNumber;
  final int attemptNumber;
  final DateTime attemptedAt;
  final ScheduledChargeAttemptSource source;
  final String paymentMethod;
  final ScheduledChargeAttemptStatus status;
  final int? paymentMethodId;
  final String? cardLast4;
  final String? cardBrand;
  final GaruFailureCode? failureCode;
  final String? failureReason;
  final String? gatewayFailureCode;
  final int? gatewayChargeId;
  final int? transactionId;

  factory ScheduledChargeAttempt.fromJson(Map<String, dynamic> json) =>
      ScheduledChargeAttempt(
        id: (json['id'] as num).toInt(),
        cycleId: (json['cycleId'] as String?) ?? '',
        cycleNumber: (json['cycleNumber'] as num?)?.toInt() ?? 0,
        attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 0,
        attemptedAt:
            _parseDate(json['attemptedAt']) ?? DateTime.now().toUtc(),
        source: ScheduledChargeAttemptSource.fromWire(json['source'] as String?),
        paymentMethod: (json['paymentMethod'] as String?) ?? 'card',
        status: ScheduledChargeAttemptStatus.fromWire(json['status'] as String?),
        paymentMethodId: (json['paymentMethodId'] as num?)?.toInt(),
        cardLast4: json['cardLast4'] as String?,
        cardBrand: json['cardBrand'] as String?,
        failureCode: json['failureCode'] != null
            ? GaruFailureCode.fromWire(json['failureCode'] as String)
            : null,
        failureReason: json['failureReason'] as String?,
        gatewayFailureCode: json['gatewayFailureCode'] as String?,
        gatewayChargeId: (json['gatewayChargeId'] as num?)?.toInt(),
        transactionId: (json['transactionId'] as num?)?.toInt(),
      );
}

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
