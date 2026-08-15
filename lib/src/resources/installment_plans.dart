import '../http.dart';
import '../idempotency.dart';
import '../models/installment_plan.dart';
import '../models/refund_request.dart';
import 'v1_query.dart';

/// Inputs for `installmentPlans.create`.
class CreateInstallmentPlanParams {
  const CreateInstallmentPlanParams({
    required this.productId,
    required this.customerId,
    required this.installments,
    this.firstDueDate,
    this.affiliateId,
    this.idempotencyKey,
  }) : assert(
          installments >= 2 && installments <= 12,
          'A carnê has 2..12 parcelas — one parcela is not a carnê, and 12 is '
          'the platform ceiling',
        );

  /// Product UUID. The product must have carnê enabled.
  final String productId;

  /// Numeric customer id, as returned by `customers.create`. Customers predate
  /// the uuid convention and have none.
  final int customerId;

  /// 2..12.
  final int installments;

  /// `YYYY-MM-DD`. Defaults to today; must be within 90 days.
  final String? firstDueDate;

  /// The affiliate who made this sale. FIXED at sale time: every later parcela
  /// inherits it, so omitting it pays that affiliate nothing for the whole
  /// carnê. Must already be active on this product, otherwise the gateway
  /// refuses rather than silently dropping the attribution.
  final int? affiliateId;

  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'customerId': customerId,
        'installments': installments,
        if (firstDueDate != null) 'firstDueDate': firstDueDate,
        if (affiliateId != null) 'affiliateId': affiliateId,
      };
}

/// Outcome of a segunda via request.
class ReissueInstallmentResult {
  const ReissueInstallmentResult({
    required this.status,
    this.reason,
    this.installment,
  });

  /// `emitted`, `skipped` or `failed`.
  final String status;
  final String? reason;
  final Installment? installment;

  bool get emitted => status == 'emitted';

  factory ReissueInstallmentResult.fromJson(Map<String, dynamic> json) =>
      ReissueInstallmentResult(
        status: (json['status'] as String?) ?? 'failed',
        reason: json['reason'] as String?,
        installment: json['installment'] == null
            ? null
            : Installment.fromJson(json['installment'] as Map<String, dynamic>),
      );
}

/// Boleto parcelado (carnê): one product sold as N monthly bank slips.
///
/// Seller-financed consumer credit, not a card instalment. Only the FIRST
/// boleto exists at creation; the rest are emitted month by month, and the
/// sale activates when parcela 1 compensates.
class InstallmentPlans {
  InstallmentPlans(this._http);

  final HttpRunner _http;

  /// Sell a product as a carnê.
  ///
  /// Always sends `X-Idempotency-Key`, which matters more here than anywhere
  /// else in the API: this call registers a REAL boleto at the bank, so a
  /// blind retry hands one buyer two payable barcodes.
  ///
  /// ```dart
  /// final carne = await garu.installmentPlans.create(
  ///   const CreateInstallmentPlanParams(
  ///     productId: '40381e8e-6ee7-4b8e-9393-766a6e2109d2',
  ///     customerId: 4821,
  ///     installments: 12,
  ///   ),
  /// );
  /// print(carne.totalScheduled);            // 1560
  /// print(carne.installmentsDetail.first.barcodeLine);
  /// ```
  Future<InstallmentPlan> create(CreateInstallmentPlanParams params) async {
    final json = await _http.request(
      'POST',
      '/api/v1/installment-plans',
      body: params.toJson(),
      extraHeaders: {
        'X-Idempotency-Key': params.idempotencyKey ?? generateIdempotencyKey(),
      },
    );
    return InstallmentPlan.fromJson(json);
  }

  /// List carnês, newest first.
  ///
  /// [dueFrom] and [dueTo] filter on the FIRST parcela's due date, which is
  /// what identifies the plan; filtering on every parcela would return one
  /// carnê twelve times.
  ///
  /// ```dart
  /// final atRisk = await garu.installmentPlans.list(status: ['defaulted']);
  /// ```
  Future<V1List<InstallmentPlan>> list({
    int? page,
    int? limit,
    List<String>? status,
    int? customerId,
    String? productId,
    String? dueFrom,
    String? dueTo,
  }) async {
    // Built by hand rather than through `query:`, which is single-valued: the
    // gateway expects `status` REPEATED (`?status=active&status=defaulted`).
    // Comma-joining would arrive as one invalid enum value and 400.
    final path = buildV1ListPath('/api/v1/installment-plans', {
      'page': page,
      'limit': limit,
      'customerId': customerId,
      'productId': productId,
      'dueFrom': dueFrom,
      'dueTo': dueTo,
    }, repeated: {
      'status': status
    });

    final json = await _http.request('GET', path);
    return V1List.fromJson(json, InstallmentPlan.fromJson);
  }

  /// Retrieve one carnê with every parcela.
  ///
  /// ```dart
  /// final carne = await garu.installmentPlans.get(uuid);
  /// final open = carne.installmentsDetail.where((i) => i.status != 'paid');
  /// ```
  Future<InstallmentPlan> get(String uuid) async {
    final json = await _http.request(
      'GET',
      '/api/v1/installment-plans/${Uri.encodeComponent(uuid)}',
    );
    return InstallmentPlan.fromJson(json);
  }

  /// Issue a segunda via for one parcela, once the current slip has expired.
  ///
  /// A boleto stays payable at any bank until its due date plus five days, so
  /// the gateway refuses while the old barcode is still live — two live
  /// barcodes for one parcela is how a buyer pays it twice.
  ///
  /// ```dart
  /// final result = await garu.installmentPlans.reissueInstallment(uuid, 4);
  /// if (result.emitted) send(result.installment!.barcodeLine!);
  /// ```
  Future<ReissueInstallmentResult> reissueInstallment(
    String uuid,
    int number,
  ) async {
    final json = await _http.request(
      'POST',
      '/api/v1/installment-plans/${Uri.encodeComponent(uuid)}'
          '/installments/$number/reissue',
    );
    return ReissueInstallmentResult.fromJson(json);
  }

  /// Move ONE parcela to a later date. Its siblings keep theirs.
  ///
  /// ```dart
  /// await garu.installmentPlans.postponeInstallment(uuid, 4, '2026-12-20');
  /// ```
  Future<Installment> postponeInstallment(
    String uuid,
    int number,
    String newDueDate,
  ) async {
    final json = await _http.request(
      'POST',
      '/api/v1/installment-plans/${Uri.encodeComponent(uuid)}'
          '/installments/$number/postpone',
      body: {'newDueDate': newDueDate},
    );
    return Installment.fromJson(json);
  }

  /// Record a parcela as paid, for when the buyer paid but no webhook arrived.
  ///
  /// The gateway asks the provider to confirm the charge really compensated
  /// first, because this settles the transaction and pays affiliate and
  /// co-producer commissions.
  ///
  /// ```dart
  /// final parcela = await garu.installmentPlans.markInstallmentPaid(uuid, 3);
  /// print(parcela.status); // 'paid'
  /// ```
  Future<Installment> markInstallmentPaid(String uuid, int number) async {
    final json = await _http.request(
      'POST',
      '/api/v1/installment-plans/${Uri.encodeComponent(uuid)}'
          '/installments/$number/mark-paid',
    );
    return Installment.fromJson(json);
  }

  /// Cancel the carnê. Emission and reminders stop and open slips are
  /// cancelled at the provider.
  ///
  /// Money already collected is NOT returned — use [requestRefund] for that.
  ///
  /// ```dart
  /// await garu.installmentPlans.cancel(uuid, note: 'Comprador desistiu');
  /// ```
  Future<InstallmentPlan> cancel(String uuid, {String? note}) async {
    final json = await _http.request(
      'POST',
      '/api/v1/installment-plans/${Uri.encodeComponent(uuid)}/cancel',
      body: {if (note != null) 'note': note},
    );
    return InstallmentPlan.fromJson(json);
  }

  /// Ask for this carnê to be refunded.
  ///
  /// Garu does NOT move the money: a boleto cannot be reversed and the funds
  /// already settled to the seller. This records the request and notifies the
  /// seller team; the carnê keeps running until someone confirms.
  ///
  /// ```dart
  /// final request = await garu.installmentPlans.requestRefund(
  ///   uuid,
  ///   reason: 'Produto não entregue',
  /// );
  /// print(request.status); // 'pending' — nothing has moved yet
  /// ```
  Future<RefundRequest> requestRefund(
    String uuid, {
    num? amount,
    String? reason,
  }) async {
    final json = await _http.request(
      'POST',
      '/api/v1/installment-plans/${Uri.encodeComponent(uuid)}/refund-requests',
      body: {
        if (amount != null) 'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );
    return RefundRequest.fromJson(json);
  }
}
