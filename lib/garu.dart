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
export 'src/failure_codes.dart' show GaruFailureCode;
export 'src/models/charge.dart' show Charge;
export 'src/models/customer.dart' show Customer;
export 'src/models/paginated.dart' show PaginatedList, PaginationMeta;
export 'src/models/product.dart' show Product, ProductPortalConfig, SetProductPortalConfigParams;
export 'src/models/scheduled_charge.dart'
    show
        ChargeNowOutcome,
        ChargeNowResult,
        ScheduledChargeAttempt,
        ScheduledChargeAttemptSource,
        ScheduledChargeAttemptStatus,
        ScheduledChargeRecord;
export 'src/resources/charges.dart' show Charges, CardInput, CustomerInput, RefundParams;
export 'src/resources/customers.dart' show Customers, CustomerParams;
export 'src/resources/meta.dart' show Meta;
export 'src/resources/products.dart' show Products, ProductPortalConfigResource;
export 'src/resources/scheduled_charges.dart'
    show CreateScheduledChargeParams, ScheduledCharges;
export 'src/webhooks.dart' show GaruWebhooks, VerifiedWebhook, VerifyWebhookParams;
