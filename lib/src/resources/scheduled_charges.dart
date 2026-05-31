import '../http.dart';
import '../idempotency.dart';
import '../models/paginated.dart';
import '../models/payment_method.dart';
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
    this.maxRecoveryDays,
    this.idempotencyKey,
  })  : assert(
          maxRecoveryDays == null ||
              (maxRecoveryDays >= 1 && maxRecoveryDays <= 365),
          'maxRecoveryDays must be between 1 and 365',
        );

  final int customerId;
  final num amount;

  /// `'one_time'` or `'recurring'`.
  final String type;

  /// `YYYY-MM-DD` (São Paulo time).
  final String dueDate;

  /// One or more of `'pix'`, `'boleto'`, `'card'`, `'pix_automatic'` — see
  /// [PaymentMethod] for typed wire values (`PaymentMethod.card.wireValue`).
  ///
  /// `'card'` requires `productId`. `'pix_automatic'` (Pix Automático,
  /// BACEN auto-debit recurring Pix) additionally requires
  /// `type == 'recurring'` and a `productId` whose product has
  /// `pixAutomatic` enabled — both checked by a debug-mode `assert` here and
  /// authoritatively by the gateway (400 / 404 / 409 otherwise).
  final List<String> methods;
  final int? productId;
  final String? description;

  /// Required when `type == 'recurring'`. Pass at minimum
  /// `{'interval': 'monthly'}`.
  final Map<String, dynamic>? recurrence;
  final int? trialDays;

  /// Days the gateway keeps recovering a missed cycle before giving up
  /// (1–365). Omit to use the system default (14).
  final int? maxRecoveryDays;
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
        if (maxRecoveryDays != null) 'maxRecoveryDays': maxRecoveryDays,
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
    // Pix Automático (BACEN auto-debit recurring Pix) only makes sense on a
    // recurring series tied to a product. Checked in debug builds; the gateway
    // is authoritative and rejects violations with 400 / 404 / 409.
    assert(
      !params.methods.contains(PaymentMethod.pixAutomatic.wireValue) ||
          (params.type == 'recurring' && params.productId != null),
      "methods containing 'pix_automatic' requires type: 'recurring' and a productId",
    );
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
    return _http.request('GET', '/api/scheduled-charges/${Uri.encodeComponent(id)}');
  }

  Future<ScheduledChargeRecord> markPaid(String id, {int? cycleNumber, String? note}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/mark-paid',
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
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/postpone',
      body: {'dueDate': newDueDate},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  Future<ScheduledChargeRecord> pause(String id, {String? reason}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/pause',
      body: {if (reason != null) 'reason': reason},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  Future<ScheduledChargeRecord> resume(String id) async {
    final json = await _http.request('POST', '/api/scheduled-charges/${Uri.encodeComponent(id)}/resume');
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Dispatch the charge + customer notification immediately, instead of
  /// waiting for the due date — the same path the daily billing cron runs.
  ///
  /// Idempotent: a cycle that already went out reports
  /// [ChargeNowOutcome.alreadySent] and is **not** re-charged, so this is
  /// safe to retry. The charge must be in a billable status
  /// (`scheduled` / `due_today`); a recurring series must have an open
  /// cycle. Otherwise the gateway raises a 400 [GaruApiError] (404 if the
  /// charge isn't yours).
  ///
  /// ```dart
  /// final result = await garu.scheduledCharges.chargeNow('scc_01HG...');
  /// switch (result.outcome) {
  ///   case ChargeNowOutcome.dispatched:
  ///     print('Charging cycle ${result.cycleNumber} now');
  ///   case ChargeNowOutcome.alreadySent:
  ///     print('Already sent — no double charge');
  ///   case ChargeNowOutcome.notSent:
  ///     print('Skipped: ${result.reason}'); // no_email | lock_lost | ...
  ///   case ChargeNowOutcome.failed:
  ///     print('Failed: ${result.reason}');  // card_expired | ...
  ///   case ChargeNowOutcome.unknown:
  ///     print(result.message);
  /// }
  /// ```
  Future<ChargeNowResult> chargeNow(String id) async {
    final json = await _http.request('POST', '/api/scheduled-charges/${Uri.encodeComponent(id)}/charge-now');
    return ChargeNowResult.fromJson(json);
  }

  /// Hard-stop future cycles (recurring only). The in-flight cycle can
  /// still be paid; only after that does the series transition to
  /// `recurrence_canceled`. Final.
  Future<ScheduledChargeRecord> cancelRecurrence(String id, {String? reason}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/cancel-recurrence',
      body: {if (reason != null) 'reason': reason},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Stripe-style soft-cancel. Reversible.
  Future<ScheduledChargeRecord> cancelAtPeriodEnd(String id, {required bool enabled}) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/cancel-at-period-end',
      body: {'enabled': enabled},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Swap the saved card. The new payment method must belong to the same
  /// customer.
  Future<ScheduledChargeRecord> changePaymentMethod(String id, int paymentMethodId) async {
    final json = await _http.request(
      'POST',
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/payment-method',
      body: {'paymentMethodId': paymentMethodId},
    );
    return ScheduledChargeRecord.fromJson(json);
  }

  /// Clear the saved card. Future cycles fall back to the email-with-link
  /// flow so the customer can re-enter card details or pay via PIX/Boleto.
  Future<ScheduledChargeRecord> clearPaymentMethod(String id) async {
    final json = await _http.request('DELETE', '/api/scheduled-charges/${Uri.encodeComponent(id)}/payment-method');
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
      '/api/scheduled-charges/${Uri.encodeComponent(id)}/attempts',
      query: query,
    );
    return PaginatedList.fromJson(json, ScheduledChargeAttempt.fromJson);
  }
}
