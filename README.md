# Garu — Dart / Flutter SDK

Brazilian payment gateway. Charges (PIX / boleto / credit card), customers, products + portal customization, scheduled charges (one-time and recurring), webhook signature verification.

> **Status: `0.2.0`.** Feature-complete with [`@garuhq/node@0.8.0`](https://www.npmjs.com/package/@garuhq/node) for the v0.8.0 backend surface. Public API still **not frozen** until v1.0.0 — minor breakages possible. Validated with `dart analyze` and 22 passing unit tests on Dart 3.11.5.

## Install

```yaml
# pubspec.yaml
dependencies:
  garu: 0.2.0
```

## Quickstart

```dart
import 'package:garu/garu.dart';

final garu = Garu(apiKey: 'sk_live_...');

final charge = await garu.charges.create(
  productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
  paymentMethod: 'pix',
  customer: const CustomerInput(
    name: 'Maria Silva',
    email: 'maria@exemplo.com.br',
    document: '12345678909',
    phone: '11987654321',
  ),
);

print('Charge id: ${charge['id']}');
```

## Configuration

```dart
final garu = Garu(
  apiKey: 'sk_live_...',
  baseUrl: 'https://garu.com.br',     // default
  maxRetries: 2,                       // default
  timeout: const Duration(seconds: 30) // default
);
```

## Charges

| Method                            | Description                                    |
| --------------------------------- | ---------------------------------------------- |
| `charges.create({...})`           | Create a PIX, boleto, or credit-card charge.   |
| `charges.list({...})`             | List charges with pagination + filters.        |
| `charges.get(id)`                 | Fetch a single charge by id.                   |
| `charges.refund(id, [params])`    | Full or partial refund.                        |

`create` and `refund` automatically attach `X-Idempotency-Key` (UUIDv4) so retries on transient network failures don't double-process. Pass `idempotencyKey` to override.

## Webhooks

```dart
import 'dart:io';
import 'package:garu/garu.dart';

Future<void> handleWebhook(HttpRequest request) async {
  final body = await _readBody(request);
  try {
    final verified = Garu.webhooks.verify(VerifyWebhookParams(
      payload: body, // raw bytes — DO NOT parse-and-reserialize
      signature: request.headers.value('x-garu-signature') ?? '',
      secret: Platform.environment['GARU_WEBHOOK_SECRET']!,
    ));
    print('Received ${verified.event['event']}');
    request.response.statusCode = 200;
  } on GaruSignatureVerificationError catch (e) {
    request.response.statusCode = 400;
    request.response.write(e.message);
  }
  await request.response.close();
}
```

> **Important:** always pass the **raw request body bytes** to `verify`. Parsing and re-serializing JSON will break the signature check.

## Errors

Every error extends `GaruError`. Switch on the typed subclasses for handling:

```dart
try {
  await garu.charges.refund(4472, const RefundParams(amount: 1000));
} on GaruNotFoundError {
  // 404 — charge missing
} on GaruValidationError catch (e) {
  // 400 / 422 — body or schema invalid
  print(e.body);
} on GaruRateLimitError catch (e) {
  // 429 — honor e.retryAfterSec
} on GaruApiError catch (e) {
  // anything else with a structured response
  print('${e.status} ${e.requestId}: ${e.message}');
} on GaruConnectionError catch (e) {
  // DNS / socket / timeout
}
```

| Error class                       | HTTP / scenario   |
| --------------------------------- | ----------------- |
| `GaruAuthenticationError`         | 401               |
| `GaruPermissionError`             | 403               |
| `GaruNotFoundError`               | 404               |
| `GaruValidationError`             | 400 / 422         |
| `GaruRateLimitError`              | 429               |
| `GaruServerError`                 | 5xx               |
| `GaruConnectionError`             | Network failure   |
| `GaruSignatureVerificationError`  | Webhook mismatch  |

## Retries

The SDK retries automatically on `GaruConnectionError`, `408`, `429`, and `5xx` responses with exponential backoff + full jitter (max ~8s). Honors `Retry-After`. Never retries `4xx` validation errors.

## Customers

```dart
final customer = await garu.customers.create(const CustomerParams(
  name: 'Maria Silva',
  email: 'maria@exemplo.com.br',
  document: '12345678909',
  phone: '11987654321',
  personType: 'fisica',
));

await garu.customers.setBillingEmailOverride(customer.id, 'cobranca@exemplo.com.br');
```

## Products + portal customization (B2B2C)

```dart
final products = await garu.products.list(search: 'curso', limit: 10);

// Per-coach branding under one Seller account (Atletia-style B2B2C)
await garu.products.portalConfig.set(57, const SetProductPortalConfigParams(
  businessName: 'Coach Maria — Corrida & Trilha',
  primaryColor: '#257264',
  logoUrl: 'https://cdn.exemplo.com/coaches/maria.png',
));

// Read or fall through to seller-level config
final cfg = await garu.products.portalConfig.get(57);
```

## Scheduled charges

```dart
// Recurring with 7-day trial
final series = await garu.scheduledCharges.create(const CreateScheduledChargeParams(
  customerId: 42,
  productId: 17,
  amount: 49.9,
  type: 'recurring',
  dueDate: '2026-06-01',
  methods: ['card', 'pix'],
  recurrence: {'interval': 'monthly'},
  trialDays: 7,
));

// Per-attempt billing audit (SPEC §4.2). Each attempt carries the canonical
// failureCode for declines.
final attempts = await garu.scheduledCharges.listAttempts(series.id, cycleNumber: 3);
final declines = attempts.data
    .where((a) => a.status == ScheduledChargeAttemptStatus.declined)
    .toList();

// GaruFailureCode helpers route permanent vs transient failures
final permanentFailures = declines.where((a) => a.failureCode?.isPermanent == true);
```

## Failure codes

```dart
import 'package:garu/garu.dart';

void handleCycleFailed(GaruFailureCode? code) {
  if (code?.isPermanent ?? false) {
    // ask the customer for a new card
  } else {
    // Garu's retry cron will keep trying — relax
  }
}
```

Every `transaction.payment.failed`, `scheduled_charge.cycle_failed`, and `listAttempts` row carries `failureCode` (canonical enum, gateway-independent), `failureReason` (PT-BR human-readable), and `gatewayFailureCode` (raw ABECS for forensics). Full table at [docs.garu.com.br/api-reference/webhooks/codigos-de-falha](https://docs.garu.com.br/api-reference/webhooks/codigos-de-falha).

## What's NOT in v0.2.0

These remain TODO before v1.0.0:

- Strongly-typed event-timeline models for `scheduledCharges.get` detail bundle (currently returns raw `Map<String, dynamic>`)
- Multi-value status filter on `scheduledCharges.list` (currently passes first value only)
- Card tokenization helpers (today: pass raw card to `charges.create`; the backend tokenizes via Celcoin)
- A Flutter example app

## Contributing

This is the early-alpha scaffold. PRs welcome at https://github.com/Garu-Pagamentos/garu-flutter.

## License

MIT — see [LICENSE](./LICENSE).
