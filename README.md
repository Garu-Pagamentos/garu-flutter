# Garu — Dart / Flutter SDK

Brazilian payment gateway. Charges (PIX / boleto / credit card), webhook verification, error hierarchy, idempotent retries.

> **Status: `0.1.0-alpha`.** This package is a **starter scaffold** — it is **not yet at parity** with [`@garuhq/node`](https://www.npmjs.com/package/@garuhq/node). Public API is **not frozen** until v1.0.0. See [CHANGELOG.md](./CHANGELOG.md) for the full TODO list. For a production integration today, prefer `@garuhq/node` from a backend service and call it from your Flutter app via your own API.

## Install

```yaml
# pubspec.yaml
dependencies:
  garu: ^0.1.0
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

## What's NOT in v0.1.0

These ship in `@garuhq/node` already and will land here before v1.0.0:

- `customers` resource (CRUD + billing email override)
- `products` resource (list/get + per-product portal config — B2B2C primitive)
- `scheduledCharges` resource (one-time + recurring + listAttempts billing audit)
- `meta` resource (discover supported payment methods + webhook events)
- Strongly-typed models for `Charge`, `Customer`, `Product`, `ScheduledChargeRecord`, `GaruFailureCode` enum
- Card tokenization helpers (cycle 1 interactive flow)
- A Flutter example app

## Contributing

This is the early-alpha scaffold. PRs welcome at https://github.com/Garu-Pagamentos/garu-flutter.

## License

MIT — see [LICENSE](./LICENSE).
