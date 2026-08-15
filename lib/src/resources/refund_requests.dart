import '../http.dart';
import '../models/installment_plan.dart';
import '../models/refund_request.dart';
import 'v1_query.dart';

/// Refunds Garu has been asked to make and cannot make for you.
///
/// A boleto cannot be reversed and Celcoin exposes no Pix devolução, so the
/// funds already settled to the seller and the return is a bank transfer only
/// they can make. This resource records the request, notifies the seller team,
/// and waits for them to assert the money went back.
///
/// Card and Woovi Pix never appear here — they have real automated reversals
/// via `charges.refund`.
class RefundRequests {
  RefundRequests(this._http);

  final HttpRunner _http;

  /// List refund requests, newest first. Covers carnê and Pix/boleto alike.
  ///
  /// ```dart
  /// // What do I still owe a buyer?
  /// final owed = await garu.refundRequests.list(status: ['pending']);
  /// final total = owed.data.fold<num>(0, (sum, r) => sum + r.amount);
  /// ```
  Future<V1List<RefundRequest>> list({
    int? page,
    int? limit,
    List<String>? status,
    String? planId,
    String? chargeId,
  }) async {
    final path = buildV1ListPath('/api/v1/refund-requests', {
      'page': page,
      'limit': limit,
      'planId': planId,
      'chargeId': chargeId,
    }, repeated: {
      'status': status
    });

    final json = await _http.request('GET', path);
    return V1List.fromJson(json, RefundRequest.fromJson);
  }

  /// Retrieve one refund request.
  ///
  /// ```dart
  /// final request = await garu.refundRequests.get(uuid);
  /// // Exactly one of these is set.
  /// print(request.installmentPlanId ?? request.chargeId);
  /// ```
  Future<RefundRequest> get(String uuid) async {
    final json = await _http.request(
      'GET',
      '/api/v1/refund-requests/${Uri.encodeComponent(uuid)}',
    );
    return RefundRequest.fromJson(json);
  }

  /// Record that you returned the money. Call this AFTER transferring it.
  ///
  /// Confirming closes a carnê as refunded, stops remaining parcelas, cancels
  /// open slips at the provider and claws back affiliate and co-producer
  /// commissions on the parcelas that cleared. Idempotent.
  ///
  /// ```dart
  /// // 1. You send the money to the buyer, out of band.
  /// // 2. Then tell Garu it happened.
  /// await garu.refundRequests.confirm(
  ///   uuid,
  ///   note: 'Pix devolvido em 14/08, e2e E12345678',
  /// );
  /// ```
  Future<RefundRequest> confirm(String uuid, {String? note}) async {
    final json = await _http.request(
      'POST',
      '/api/v1/refund-requests/${Uri.encodeComponent(uuid)}/confirm',
      body: {if (note != null) 'note': note},
    );
    return RefundRequest.fromJson(json);
  }

  /// Decline the request. The carnê is untouched and keeps running.
  /// Idempotent.
  ///
  /// ```dart
  /// await garu.refundRequests.reject(uuid, note: 'Produto entregue em 02/08');
  /// ```
  Future<RefundRequest> reject(String uuid, {String? note}) async {
    final json = await _http.request(
      'POST',
      '/api/v1/refund-requests/${Uri.encodeComponent(uuid)}/reject',
      body: {if (note != null) 'note': note},
    );
    return RefundRequest.fromJson(json);
  }
}
