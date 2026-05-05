/// Garu — Brazilian payment gateway SDK for Dart / Flutter.
///
/// ```dart
/// import 'package:garu/garu.dart';
///
/// final garu = Garu(apiKey: 'sk_live_...');
/// final charge = await garu.charges.create(
///   productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
///   paymentMethod: 'pix',
///   customer: const CustomerInput(
///     name: 'Maria Silva',
///     email: 'maria@exemplo.com.br',
///     document: '12345678909',
///     phone: '11987654321',
///   ),
/// );
/// ```
library;

export 'src/client.dart' show Garu, GaruOptions;
export 'src/errors.dart';
export 'src/resources/charges.dart' show Charges, CustomerInput, CardInput, RefundParams;
export 'src/webhooks.dart' show GaruWebhooks, VerifyWebhookParams, VerifiedWebhook;
