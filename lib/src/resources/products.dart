import '../http.dart';
import '../idempotency.dart';
import '../models/paginated.dart';
import '../models/product.dart';

/// Per-product portal customization (B2B2C primitive — see SPEC §4.1).
///
/// `productId` accepts either the product UUID (preferred — same identifier
/// returned by `products.list()` and webhook payloads) or the legacy numeric
/// id as a string. UUID support added in Garu v0.10.0.
///
/// Breaking change in Flutter SDK v0.3.0: signature changed from `int` to
/// `String`. Pass integer ids as `'$id'` if you have them.
class ProductPortalConfigResource {
  ProductPortalConfigResource(this._http);

  final HttpRunner _http;

  /// Read the portal customization for a product. Returns `null` when no
  /// per-product config exists (the product falls back to seller-level
  /// portal config).
  Future<ProductPortalConfig?> get(String productId) async {
    final json = await _http.request(
        'GET', '/api/products/${Uri.encodeComponent(productId)}/portal-config');
    if (json.isEmpty || json['productId'] == null) return null;
    return ProductPortalConfig.fromJson(json);
  }

  /// Create or merge the portal customization. Both `set` and `patch`
  /// have the same merge semantics — only fields present in the body
  /// are written, unspecified fields keep their persisted value. Use
  /// [clear] to reset everything.
  Future<ProductPortalConfig> set(
      String productId, SetProductPortalConfigParams params) async {
    final json = await _http.request(
      'POST',
      '/api/products/${Uri.encodeComponent(productId)}/portal-config',
      body: params.toJson(),
    );
    return ProductPortalConfig.fromJson(json);
  }

  /// Same merge semantics as [set] — alias for HTTP-PATCH-preferring callers.
  Future<ProductPortalConfig> patch(
      String productId, SetProductPortalConfigParams params) async {
    final json = await _http.request(
      'PATCH',
      '/api/products/${Uri.encodeComponent(productId)}/portal-config',
      body: params.toJson(),
    );
    return ProductPortalConfig.fromJson(json);
  }

  /// Remove the per-product config. The product falls back to the
  /// seller-level portal config.
  Future<Map<String, dynamic>> clear(String productId) {
    return _http.request('DELETE',
        '/api/products/${Uri.encodeComponent(productId)}/portal-config');
  }
}

/// Inputs for `products.create`. `name` is required; every other field is
/// optional and omitted from the wire body when null.
class CreateProductParams {
  const CreateProductParams({
    required this.name,
    this.value,
    this.description,
    this.image,
    this.tags,
    this.pix,
    this.boleto,
    this.creditCard,
    this.pixAutomatic,
    this.installments,
    this.isSubscription,
    this.subscriptionType,
    this.unitLabel,
    this.returnUrl,
    this.returnUrlButtonText,
    this.statementDescriptor,
    this.idempotencyKey,
  });

  final String name;

  /// Price in **reais** (decimal BRL) — `29.90` is R$29,90.
  ///
  /// NOT centavos. Until 0.8.0 this field was an `int` documented as
  /// centavos, so `2990` meant R$29,90; the gateway read the same number as
  /// reais and priced the product at R$2.990,00.
  ///
  /// Must be at least R$ 5,00, the platform minimum price, or `0`. Omitting
  /// it, or passing `0`, creates a product with no price: it is accepted, but
  /// it cannot be sold through its payment link. From `0.01` to `4.99`, or a
  /// negative value, the gateway answers 400. Not checked when
  /// [isSubscription] is true: that price lives on the subscription prices.
  final num? value;
  final String? description;
  final String? image;
  final List<String>? tags;
  final bool? pix;
  final bool? boleto;
  final bool? creditCard;

  /// Expose Pix Automático (BACEN auto-debit recurring Pix) on the checkout.
  final bool? pixAutomatic;
  final int? installments;
  final bool? isSubscription;
  final String? subscriptionType;
  final String? unitLabel;
  final String? returnUrl;
  final String? returnUrlButtonText;
  final String? statementDescriptor;

  /// Idempotency key for the create request. Omit it and no key is sent.
  /// Pass your own — derived from something stable in your domain — to make a
  /// retry across process restarts safe: the gateway returns the original
  /// product instead of creating a duplicate. Sent as the `X-Idempotency-Key`
  /// header, not in the body.
  final String? idempotencyKey;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (value != null) 'value': value,
        if (description != null) 'description': description,
        if (image != null) 'image': image,
        if (tags != null) 'tags': tags,
        if (pix != null) 'pix': pix,
        if (boleto != null) 'boleto': boleto,
        if (creditCard != null) 'creditCard': creditCard,
        if (pixAutomatic != null) 'pixAutomatic': pixAutomatic,
        if (installments != null) 'installments': installments,
        if (isSubscription != null) 'isSubscription': isSubscription,
        if (subscriptionType != null) 'subscriptionType': subscriptionType,
        if (unitLabel != null) 'unitLabel': unitLabel,
        if (returnUrl != null) 'returnUrl': returnUrl,
        if (returnUrlButtonText != null)
          'returnUrlButtonText': returnUrlButtonText,
        if (statementDescriptor != null)
          'statementDescriptor': statementDescriptor,
      };
}

/// Inputs for `products.update`. Every field is optional — only the fields
/// you set are sent, so updates stay partial (PATCH merge semantics).
class UpdateProductParams {
  const UpdateProductParams({
    this.name,
    this.value,
    this.description,
    this.image,
    this.tags,
    this.pix,
    this.boleto,
    this.creditCard,
    this.pixAutomatic,
    this.installments,
    this.isSubscription,
    this.subscriptionType,
    this.unitLabel,
    this.returnUrl,
    this.returnUrlButtonText,
    this.statementDescriptor,
  });

  final String? name;

  /// Price in **reais** (decimal BRL) — `29.90` is R$29,90.
  ///
  /// NOT centavos. Until 0.8.0 this field was an `int` documented as
  /// centavos, so `2990` meant R$29,90; the gateway read the same number as
  /// reais and priced the product at R$2.990,00.
  ///
  /// `0` (no price) or at least R$ 5,00, else 400. Leave it null to keep the
  /// current price: the minimum is checked only when a price is sent (or a
  /// subscription product turns one-time), so a product priced below R$ 5,00
  /// before the minimum existed keeps selling.
  final num? value;
  final String? description;
  final String? image;
  final List<String>? tags;
  final bool? pix;
  final bool? boleto;
  final bool? creditCard;

  /// Expose Pix Automático (BACEN auto-debit recurring Pix) on the checkout.
  final bool? pixAutomatic;
  final int? installments;
  final bool? isSubscription;
  final String? subscriptionType;
  final String? unitLabel;
  final String? returnUrl;
  final String? returnUrlButtonText;
  final String? statementDescriptor;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (value != null) 'value': value,
        if (description != null) 'description': description,
        if (image != null) 'image': image,
        if (tags != null) 'tags': tags,
        if (pix != null) 'pix': pix,
        if (boleto != null) 'boleto': boleto,
        if (creditCard != null) 'creditCard': creditCard,
        if (pixAutomatic != null) 'pixAutomatic': pixAutomatic,
        if (installments != null) 'installments': installments,
        if (isSubscription != null) 'isSubscription': isSubscription,
        if (subscriptionType != null) 'subscriptionType': subscriptionType,
        if (unitLabel != null) 'unitLabel': unitLabel,
        if (returnUrl != null) 'returnUrl': returnUrl,
        if (returnUrlButtonText != null)
          'returnUrlButtonText': returnUrlButtonText,
        if (statementDescriptor != null)
          'statementDescriptor': statementDescriptor,
      };
}

/// Products resource. Create / update / list / get / per-product portal
/// customization.
class Products {
  Products(this._http) : portalConfig = ProductPortalConfigResource(_http);

  final HttpRunner _http;
  final ProductPortalConfigResource portalConfig;

  /// Create a product. POSTs to `/api/products` (gateway returns 201).
  ///
  /// Sends `X-Idempotency-Key` only when
  /// [CreateProductParams.idempotencyKey] is supplied.
  Future<Product> create(CreateProductParams params) async {
    final json = await _http.request(
      'POST',
      '/api/products',
      body: params.toJson(),
      extraHeaders: idempotencyHeaders(params.idempotencyKey),
    );
    return Product.fromJson(json);
  }

  /// Update a product. `id` accepts the numeric id (`int`) or the product
  /// UUID (`String`). Only the fields set on [params] are sent, so the
  /// update is partial.
  Future<Product> update(Object id, UpdateProductParams params) async {
    final json = await _http.request(
      'PATCH',
      '/api/products/${Uri.encodeComponent('$id')}',
      body: params.toJson(),
    );
    return Product.fromJson(json);
  }

  Future<PaginatedList<Product>> list({
    int? page,
    int? limit,
    String? search,
    String? tab,
  }) async {
    final query = <String, String>{
      if (page != null) 'page': '$page',
      if (limit != null) 'limit': '$limit',
      if (search != null) 'search': search,
      if (tab != null) 'tab': tab,
    };
    final json =
        await _http.request('GET', '/api/products/seller', query: query);
    return PaginatedList.fromJson(json, Product.fromJson);
  }

  Future<Product> get(String uuid) async {
    final json = await _http.request('GET', '/api/products/uuid/$uuid');
    return Product.fromJson(json);
  }
}
