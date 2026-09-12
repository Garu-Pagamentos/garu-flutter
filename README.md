# Garu — Dart / Flutter SDK

Brazilian payment gateway. Charges (PIX / boleto / credit card / **Pix Automático**), customers, products + portal customization, scheduled charges (one-time and recurring), webhook signature verification.

> **Status: `0.5.0`.** Tracks the Garu v0.14.0 backend surface, including Pix Automático (BACEN auto-debit recurring Pix). Public API still **not frozen** until v1.0.0 — minor breakages possible. Validated with `dart analyze` and 49 passing unit tests.

## Install

```yaml
# pubspec.yaml
dependencies:
  garu: 0.5.0
```

## Quickstart

```dart
import 'package:garu/garu.dart';

final garu = Garu(apiKey: 'sk_live_...');

final charge = await garu.charges.create(
  productId: 'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
  paymentMethod: ChargeMethod.pix,
  customer: const CustomerInput(
    name: 'Maria Silva',
    email: 'maria@exemplo.com.br',
    document: '12345678909',
    phone: '11987654321',
  ),
);

print('Charge ${charge.uuid} — pague com ${charge.pix?.code}');
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
| `charges.retrieve(uuid)`          | Fetch a single charge by uuid.                 |
| `charges.refund(uuid, [params])`  | Full or partial refund.                        |
| `charges.cancel(uuid)`            | Cancel an unpaid charge.                       |

A charge is keyed by `uuid`; there is no numeric id. The amount is never a
parameter — the server prices the charge from the product, or from the offer
you name.

`amount` on the response is the product's base price; `chargedTotal` is what the
customer is actually charged. They differ on instalment card sales, where
`chargedTotal` carries the instalment markup. Reconcile against `chargedTotal`.

### Idempotency

The SDK sends `X-Idempotency-Key` **only when you pass one**. It does not invent
one: a key generated per call is different on every attempt, so it protects
nothing while making the request look protected.

Derive the key from something stable in your own domain, so a retry reproduces
it:

```dart
await garu.charges.create(
  productId: productId,
  paymentMethod: ChargeMethod.creditCard,
  customer: customer,
  card: card,
  idempotencyKey: 'booking:${booking.id}:charge',
);
```

Without a key the SDK will not replay a failed `POST` — one attempt, so a
timeout cannot become a second charge.

## Offers

Sell the same product at more than one price, each behind its own link. An offer
overrides the price and nothing else; a bare product link keeps charging
`product.value`.

```dart
final offer = await garu.offers.create(
  'b3f2c1e8-6e4a-4b9f-9d1c-2a1f6c3d4e5f',
  const CreateOfferParams(
    name: 'Black Friday',
    value: 97.0,             // reais, NOT centavos
    slug: 'black-friday',
  ),
);

// Hand out the link...
print('https://garu.com.br/pay/$productUuid?offer=${offer.linkParam}');

// ...or charge it directly. The SERVER resolves the price from the offer.
await garu.charges.create(
  productId: productUuid,
  paymentMethod: ChargeMethod.pix,
  customer: customer,
  offer: offer.linkParam,
);
```

A `slug` is public and guessable by anyone holding the product link. For pricing
that should not circulate, omit it and let the link carry the offer id.

| Method                              | Description                          |
| ----------------------------------- | ------------------------------------ |
| `offers.list(productUuid, {...})`   | A product's offers (active by default). |
| `offers.get(offerId)`               | One offer.                           |
| `offers.create(productUuid, params)`| Create an offer.                     |
| `offers.update(offerId, params)`    | Reprice or deactivate.               |
| `offers.del(offerId)`               | Delete — only while it has never sold. |

## Money units

Every monetary value in this SDK is in **reais** (decimal BRL), never centavos:
`29.90` is R$29,90. This applies to `product.value`, `offer.value`,
`RefundParams.amount`, `charge.amount` and `charge.chargedTotal`.

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
  await garu.charges.refund(chargeUuid, const RefundParams(amount: 10.0));
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

## Pix Automático (recurring auto-debit Pix)

[Pix Automático](https://garu.com.br/changelog/v0.14.0-pix-automatico-assinaturas) is BACEN's auto-debit recurring Pix: the customer authorizes **once** (a consent link / QR in their bank app, under "Pix Automático" / "Recorrência Pix"), and subsequent cycles debit silently — no card on file.

Enable it on the product, then add `'pix_automatic'` to a **recurring** scheduled charge that carries a `productId`:

```dart
// The product must have pixAutomatic enabled (Product.pixAutomatic == true).
final series = await garu.scheduledCharges.create(const CreateScheduledChargeParams(
  customerId: 123,
  productId: 456,           // required for pix_automatic
  amount: 297.5,
  type: 'recurring',        // required for pix_automatic
  dueDate: '2026-06-15',
  methods: [PaymentMethod.pixAutomatic.wireValue], // 'pix_automatic'
  recurrence: {'interval': 'monthly'},
  maxRecoveryDays: 14,
));
```

`methods` containing `'pix_automatic'` without `type: 'recurring'` + a `productId` trips a debug-mode assertion locally and is rejected by the gateway (`400` / `404` / `409`).

### Webhooks — no new event names

Pix Automático fires the **same** events as card-backed subscriptions (`subscription.*`, `transaction.payment.*`). Branch on the payment method to tell them apart:

```dart
final data = verified.event['data'];
if (data is Map<String, dynamic>) {
  final charge = Charge.fromJson(data);
  switch (charge.method) {
    case PaymentMethod.pixAutomatic:
      // auto-debit Pix cycle
      break;
    case PaymentMethod.card:
      // card cycle
      break;
    default:
      break;
  }
}
```

> Pix Automático does **not** retry a refused debit at the network level — Garu fires `subscription.payment_failed`, flips the subscription to `past_due`, and the existing dunning state machine takes over. Cancel via the same routes as any other subscription (`scheduledCharges.cancelRecurrence` / `cancelAtPeriodEnd`); the customer can also revoke authorization in their bank app, which Garu surfaces as `subscription.cancelled`.

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

## What's NOT in v0.5.0

These remain TODO before v1.0.0:

- Strongly-typed event-timeline models for `scheduledCharges.get` detail bundle (currently returns raw `Map<String, dynamic>`)
- Multi-value status filter on `scheduledCharges.list` (currently passes first value only)
- Card tokenization helpers (today: pass raw card to `charges.create`; the backend tokenizes via Celcoin)
- A Flutter example app

## Contributing

This is the early-alpha scaffold. PRs welcome at https://github.com/Garu-Pagamentos/garu-flutter.

## License

MIT — see [LICENSE](./LICENSE).
