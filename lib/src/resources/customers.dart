import '../http.dart';
import '../models/customer.dart';
import '../models/paginated.dart';

/// Inputs for `customers.create` / `customers.update`.
class CustomerParams {
  const CustomerParams({
    this.name,
    this.email,
    this.document,
    this.phone,
    this.personType,
    this.billingEmail,
  });

  final String? name;
  final String? email;
  final String? document;
  final String? phone;

  /// `'fisica'` (CPF) or `'juridica'` (CNPJ).
  final String? personType;

  /// Per-customer override for billing emails.
  final String? billingEmail;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (document != null) 'document': document,
        if (phone != null) 'phone': phone,
        if (personType != null) 'personType': personType,
        if (billingEmail != null) 'billingEmail': billingEmail,
      };
}

/// Customers resource. Mirrors `garu.customers` in `@garuhq/node`.
class Customers {
  Customers(this._http);

  final HttpRunner _http;

  Future<Customer> create(CustomerParams params) async {
    final json = await _http.request('POST', '/api/customers', body: params.toJson());
    return Customer.fromJson(json);
  }

  Future<PaginatedList<Customer>> list({
    int? page,
    int? limit,
    String? search,
  }) async {
    final query = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (search != null) 'search': search,
    };
    final json = await _http.request('GET', '/api/customers', query: query);
    return PaginatedList.fromJson(json, Customer.fromJson);
  }

  Future<Customer> get(int id) async {
    final json = await _http.request('GET', '/api/customers/$id');
    return Customer.fromJson(json);
  }

  Future<Customer> update(int id, CustomerParams params) async {
    final json = await _http.request('PATCH', '/api/customers/$id', body: params.toJson());
    return Customer.fromJson(json);
  }

  Future<Map<String, dynamic>> delete(int id) {
    return _http.request('DELETE', '/api/customers/$id');
  }

  /// Override the billing email used for this customer (independent from
  /// the customer's primary email).
  Future<Customer> setBillingEmailOverride(int id, String? billingEmail) async {
    final json = await _http.request(
      'POST',
      '/api/customers/$id/billing-email-override',
      body: {'billingEmail': billingEmail},
    );
    return Customer.fromJson(json);
  }
}
