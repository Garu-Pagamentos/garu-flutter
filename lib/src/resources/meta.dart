import '../http.dart';

/// Public metadata about the Garu API. No authentication required.
class Meta {
  Meta(this._http);

  final HttpRunner _http;

  /// Discover supported payment methods, webhook event types, and the
  /// API version.
  Future<Map<String, dynamic>> get() {
    return _http.request('GET', '/api/meta');
  }
}
