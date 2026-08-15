/// Boleto parcelado (carnê) — one product sold as N monthly bank slips.
///
/// This is seller-financed consumer credit, not a card instalment. Nobody
/// guarantees a boleto: a buyer who stops at parcela 4 leaves the seller with
/// four parcelas and no advance from anyone.
library;

/// One monthly slip of a carnê.
class Installment {
  const Installment({
    required this.number,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paidAt,
    this.barcodeLine,
    this.boletoPdfUrl,
    this.reissueCount = 0,
  });

  /// 1-based position in the plan.
  final int number;
  final num amount;

  /// `YYYY-MM-DD` in São Paulo time.
  final String dueDate;

  /// `scheduled`, `due_today`, `processing`, `paid`, `overdue`, `failed`
  /// or `canceled`.
  final String status;
  final DateTime? paidAt;

  /// Null until the slip is registered. Parcelas 2..N are emitted month by
  /// month, so most of a fresh plan has no barcode yet — never render an empty
  /// line to a buyer as if it were payable.
  final String? barcodeLine;
  final String? boletoPdfUrl;
  final int reissueCount;

  bool get isPayable => barcodeLine != null && status != 'paid';

  factory Installment.fromJson(Map<String, dynamic> json) {
    final boleto = json['boleto'] as Map<String, dynamic>?;
    return Installment(
      number: (json['number'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?) ?? 0,
      dueDate: (json['dueDate'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'scheduled',
      paidAt: json['paidAt'] == null
          ? null
          : DateTime.tryParse(json['paidAt'] as String),
      barcodeLine: boleto?['barcodeLine'] as String?,
      boletoPdfUrl: boleto?['pdfUrl'] as String?,
      reissueCount: (json['reissueCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class InstallmentPlan {
  const InstallmentPlan({
    required this.uuid,
    required this.status,
    required this.installments,
    required this.installmentsPaid,
    required this.baseValue,
    required this.fator,
    required this.installmentAmount,
    required this.totalScheduled,
    required this.totalCollected,
    required this.firstDueDate,
    this.graceDays,
    this.cancelReason,
    this.productUuid,
    this.productName,
    this.customerName,
    this.customerEmail,
    this.activatedAt,
    this.completedAt,
    this.canceledAt,
    this.createdAt,
    this.installmentsDetail = const [],
    this.raw = const {},
  });

  final String uuid;

  /// `pending_activation`, `active`, `completed`, `defaulted`, `canceled`
  /// or `refunded`.
  final String status;
  final int installments;
  final int installmentsPaid;

  /// The cash price the buyer would have paid in one go.
  final num baseValue;

  /// Interest multiplier snapshotted at sale time; never recomputed, so a
  /// repriced seller cannot rewrite a sale their buyer already agreed to.
  final num fator;
  final num installmentAmount;

  /// `installmentAmount * installments` — what the carnê bills in total.
  final num totalScheduled;

  /// What has actually cleared. May exceed [totalScheduled] once a bank adds
  /// multa or mora, which is exactly why the two are separate fields. Never
  /// substitute one for the other when reconciling.
  final num totalCollected;

  final String firstDueDate;
  final int? graceDays;
  final String? cancelReason;
  final String? productUuid;
  final String? productName;
  final String? customerName;
  final String? customerEmail;
  final DateTime? activatedAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;
  final DateTime? createdAt;

  /// Present on retrieve and create; empty on list responses.
  final List<Installment> installmentsDetail;

  final Map<String, dynamic> raw;

  /// A plan is not a sale until parcela 1 compensates.
  bool get isSale => status != 'pending_activation' && status != 'canceled';

  /// What the buyer still owes on the schedule as billed. Deliberately derived
  /// from [totalScheduled], not from [totalCollected] alone, because multa and
  /// mora can push collections above the scheduled total.
  num get remainingScheduled {
    final left = totalScheduled - totalCollected;
    return left > 0 ? left : 0;
  }

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    DateTime? parse(String key) =>
        json[key] == null ? null : DateTime.tryParse(json[key] as String);

    return InstallmentPlan(
      uuid: (json['uuid'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending_activation',
      installments: (json['installments'] as num?)?.toInt() ?? 0,
      installmentsPaid: (json['installmentsPaid'] as num?)?.toInt() ?? 0,
      baseValue: (json['baseValue'] as num?) ?? 0,
      fator: (json['fator'] as num?) ?? 1,
      installmentAmount: (json['installmentAmount'] as num?) ?? 0,
      totalScheduled: (json['totalScheduled'] as num?) ?? 0,
      totalCollected: (json['totalCollected'] as num?) ?? 0,
      firstDueDate: (json['firstDueDate'] as String?) ?? '',
      graceDays: (json['graceDays'] as num?)?.toInt(),
      cancelReason: json['cancelReason'] as String?,
      productUuid: product?['uuid'] as String?,
      productName: product?['name'] as String?,
      customerName: customer?['name'] as String?,
      customerEmail: customer?['email'] as String?,
      activatedAt: parse('activatedAt'),
      completedAt: parse('completedAt'),
      canceledAt: parse('canceledAt'),
      createdAt: parse('createdAt'),
      installmentsDetail:
          ((json['installmentsDetail'] as List<dynamic>?) ?? const [])
              .map((e) => Installment.fromJson(e as Map<String, dynamic>))
              .toList(),
      raw: json,
    );
  }
}

/// Envelope returned by the `/api/v1` list endpoints.
///
/// Distinct from [PaginatedList]: v1 returns a flat
/// `{ data, count, totalCount, totalPages }` rather than nesting under `meta`.
class V1List<T> {
  const V1List({
    required this.data,
    required this.count,
    required this.totalCount,
    required this.totalPages,
  });

  final List<T> data;

  /// Items on this page.
  final int count;

  /// Items matching the filter across all pages.
  final int totalCount;
  final int totalPages;

  factory V1List.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final rawData = (json['data'] as List<dynamic>?) ?? const <dynamic>[];
    return V1List(
      data: rawData.map((e) => parseItem(e as Map<String, dynamic>)).toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}
