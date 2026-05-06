/// A Garu customer record.
class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.document,
    this.phone,
    this.galaxPayId,
    this.billingEmail,
    this.raw = const {},
  });

  final int id;
  final String name;
  final String email;
  final String document;
  final String? phone;
  final int? galaxPayId;

  /// Per-customer override for billing emails. Falls back to `email` if null.
  final String? billingEmail;

  final Map<String, dynamic> raw;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        document: (json['document'] as String?) ?? '',
        phone: json['phone'] as String?,
        galaxPayId: (json['galaxPayId'] as num?)?.toInt(),
        billingEmail: json['billingEmail'] as String?,
        raw: json,
      );
}
