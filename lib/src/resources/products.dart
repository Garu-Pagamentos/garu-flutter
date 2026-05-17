import '../http.dart';
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
    final json = await _http.request('GET', '/api/products/${Uri.encodeComponent(productId)}/portal-config');
    if (json.isEmpty || json['productId'] == null) return null;
    return ProductPortalConfig.fromJson(json);
  }

  /// Create or merge the portal customization. Both `set` and `patch`
  /// have the same merge semantics — only fields present in the body
  /// are written, unspecified fields keep their persisted value. Use
  /// [clear] to reset everything.
  Future<ProductPortalConfig> set(String productId, SetProductPortalConfigParams params) async {
    final json = await _http.request(
      'POST',
      '/api/products/${Uri.encodeComponent(productId)}/portal-config',
      body: params.toJson(),
    );
    return ProductPortalConfig.fromJson(json);
  }

  /// Same merge semantics as [set] — alias for HTTP-PATCH-preferring callers.
  Future<ProductPortalConfig> patch(String productId, SetProductPortalConfigParams params) async {
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
    return _http.request('DELETE', '/api/products/${Uri.encodeComponent(productId)}/portal-config');
  }
}

/// Products resource. List / get / per-product portal customization.
class Products {
  Products(this._http) : portalConfig = ProductPortalConfigResource(_http);

  final HttpRunner _http;
  final ProductPortalConfigResource portalConfig;

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
    final json = await _http.request('GET', '/api/products/seller', query: query);
    return PaginatedList.fromJson(json, Product.fromJson);
  }

  Future<Product> get(String uuid) async {
    final json = await _http.request('GET', '/api/products/uuid/$uuid');
    return Product.fromJson(json);
  }
}
