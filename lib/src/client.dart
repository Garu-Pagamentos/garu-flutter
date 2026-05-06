import 'package:http/http.dart' as http;

import 'http.dart';
import 'resources/charges.dart';
import 'resources/customers.dart';
import 'resources/meta.dart';
import 'resources/products.dart';
import 'resources/scheduled_charges.dart';
import 'webhooks.dart';

/// Configuration for [Garu]. All fields except [apiKey] have sensible defaults.
class GaruOptions {
  const GaruOptions({
    required this.apiKey,
    this.baseUrl = 'https://garu.com.br',
    this.maxRetries = 2,
    this.timeout = const Duration(seconds: 30),
    this.httpClient,
  });

  final String apiKey;
  final String baseUrl;
  final int maxRetries;
  final Duration timeout;
  final http.Client? httpClient;
}

/// Garu — Brazilian payment gateway client.
///
/// ```dart
/// final garu = Garu(apiKey: 'sk_live_...');
/// ```
class Garu {
  Garu({
    required String apiKey,
    String baseUrl = 'https://garu.com.br',
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 30),
    http.Client? httpClient,
  }) : this.fromOptions(GaruOptions(
          apiKey: apiKey,
          baseUrl: baseUrl,
          maxRetries: maxRetries,
          timeout: timeout,
          httpClient: httpClient,
        ));

  Garu.fromOptions(GaruOptions options)
      : _http = HttpRunner(
          baseUrl: Uri.parse(options.baseUrl),
          apiKey: options.apiKey,
          maxRetries: options.maxRetries,
          timeout: options.timeout,
          client: options.httpClient,
        ) {
    charges = Charges(_http);
    customers = Customers(_http);
    products = Products(_http);
    scheduledCharges = ScheduledCharges(_http);
    meta = Meta(_http);
  }

  final HttpRunner _http;
  late final Charges charges;
  late final Customers customers;
  late final Products products;
  late final ScheduledCharges scheduledCharges;
  late final Meta meta;

  /// Webhook signature verification helpers (no client instance required).
  static const GaruWebhooks webhooks = GaruWebhooks();

  /// Release the underlying HTTP client. Call when the SDK is no longer
  /// needed — typically only relevant in tests or short-lived scripts.
  void close() => _http.close();
}
