import '../http.dart';
import '../idempotency.dart';
import '../models/paginated.dart';
import '../models/scheduled_charge.dart';

/// Inputs for `scheduledCharges.create`.
class CreateScheduledChargeParams {
  const CreateScheduledChargeParams({
    required this.customerId,
    required this.amount,
    required this.type,
    required this.dueDate,
    required this.methods,
    this.productId,
    this.description,
    this.recurrence,
    this.trialDays,
    this.idempotencyKey,
  });

  final int customerId;
  final num amount;

  /// `'one_time'` or `'recurring'`.
  final String type;

  /// `YYYY-MM-DD` (São Paulo time).
  final String dueDate;

  /// One or more of `'pix'`, `'boleto'`, `'card'`. `'card'` requires `productId`.
  final List<String> methods;
  final int? productId;
  final String? description;

  /// Required when `type == 'recurring'`. Pass at minimum
  /// `{'interval': 'monthly'}`.
  final Map<String, dynamic>? recurrence;
  final int? trialDays;
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'amount': amount,
        'type': type,
        'dueDate': dueDate,
        'methods': methods,
        if (productId != null) 'productId': productId,
        if (description != null) 'description': description,
        if (recurrence != null) 'recurrence': recurrence,
        if (trialDays != null) 'trialDays': trialDays,
      };
}

/// Scheduled charges resource — full lifecycle: create, list, get, mark paid,
/// postpone, pause/resume, cancel-recurrence, soft-cancel, change/clear
/// payment method, list per-attempt log.
class ScheduledCharges {
  ScheduledCharges(this._http);

  final HttpRunner _http;

  /// Create a one-time or recurring scheduled charge. Auto-attaches
  /// `X-Idempotency-Key` (UUIDv4) unless provided.
  Future<ScheduledChargeRecord> create(CreateScheduledChargeParams params) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges',
      body: params.toJson(),
      extraHeaders: {
        'X-Idempotency-Key': params.idempotencyKey ?? generateIdempotencyKey(),
      },
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  Future<PaginatedList<ScheduledChargeRecord>> list({
    int? page,
    int? limit,
    int? customerId,
    Object? status,
    String? type,
    String? dueFrom,
    String? dueTo,
    String? search,
  }) async {
    final query = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (customerId != null) 'customerId': '$customerId',
      if (type != null) 'type': type,
      if (dueFrom != null) 'dueFrom': dueFrom,
      if (dueTo != null) 'dueTo': dueTo,
      if (search != null) 'search': search,
    };
    // Status can be a single string or a list; pass as repeated query param.
    final extraStatus = <String>[];
    if (status is String) extraStatus.add(status);
    if (status is List) {
      for (final s in status) {
        extraStatus.add(s.toString());
      }
    }
    if (extraStatus.isNotEmpty) query['status'] = extraStatus.first;
    // (Multi-value query keys handled server-side; the SDK passes the first
    // for now — pass status as comma-separated if you need multiple in v0.x.)

    final json = await _http.request('GET', '/api/scheduled-charges', query: query);
    return PaginatedList.fromJson(json, ScheduledChargeRecord.fromJson);
  }

  /// Detail bundle: charge + event timeline + linked transactions. Returns
  /// the raw map for now; typed models for events/transactions land in v1.
  Future<Map<String, dynamic>> get(String id) {
    return _http.request('GET', '/api/scheduled-charges/$id');
  }

  Future<ScheduledChargeRecord> markPaid(String id, {int? cycleNumber, String? note}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/$id/mark-paid',
      body: {
        if (cycleNumber != null) 'cycleNumber': cycleNumber,
        if (note != null) 'note': note,
      },
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  Future<ScheduledChargeRecord> postpone(String id, String newDueDate) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/$id/postpone',
      body: {'dueDate': newDueDate},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  Future<ScheduledChargeRecord> pause(String id, {String? reason}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/$id/pause',
      body: {if (reason != null) 'reason': reason},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  Future<ScheduledChargeRecord> resume(String id) async {
    final json = await _http.request('POST', '/api/scheduled-charges/$id/resume');
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Hard-stop future cycles (recurring only). The in-flight cycle can
  /// still be paid; only after that does the series transition to
  /// `recurrence_canceled`. Final.
  Future<ScheduledChargeRecord> cancelRecurrence(String id, {String? reason}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/$id/cancel-recurrence',
      body: {if (reason != null) 'reason': reason},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Stripe-style soft-cancel. Reversible.
  Future<ScheduledChargeRecord> cancelAtPeriodEnd(String id, {required bool enabled}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/$id/cancel-at-period-end',
      body: {'enabled': enabled},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Swap the saved card. The new payment method must belong to the same
  /// customer.
  Future<ScheduledChargeRecord> changePaymentMethod(String id, int paymentMethodId) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/$id/payment-method',
      body: {'paymentMethodId': paymentMethodId},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Clear the saved card. Future cycles fall back to the email-with-link
  /// flow so the customer can re-enter card details or pay via PIX/Boleto.
  Future<ScheduledChargeRecord> clearPaymentMethod(String id) async {
    final json = await _http.request('DELETE', '/api/scheduled-charges/$id/payment-method');
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Per-attempt billing log (SPEC §4.2). One row per logical billing
  /// event. Carries the canonical `failureCode` for declines.
  Future<PaginatedList<ScheduledChargeAttempt>> listAttempts(
    String id, {
    int? page,
    int? limit,
    int? cycleNumber,
  }) async {
    final query = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (cycleNumber != null) 'cycleNumber': '$cycleNumber',
    };
    final json = await _http.request(
      'GET',
      '/api/scheduled-charges/$id/attempts',
      query: query,
    );
    return PaginatedList.fromJson(json, ScheduledChargeAttempt.fromJson);
  }
}
