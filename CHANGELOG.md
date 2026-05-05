## 0.1.0 (alpha)

Initial scaffold. NOT yet at parity with `@garuhq/node`.

**Shipped:**
- `Garu` client with API key auth, configurable base URL, retries
- Error hierarchy: `GaruError`, `GaruApiError`, `GaruAuthenticationError`,
  `GaruPermissionError`, `GaruNotFoundError`, `GaruValidationError`,
  `GaruRateLimitError`, `GaruServerError`, `GaruConnectionError`,
  `GaruSignatureVerificationError`
- `garu.charges.create` (PIX / boleto), `list`, `get`, `refund`
- `Garu.webhooks.verify` — HMAC-SHA256 + constant-time comparison
- Idempotency key auto-attach (UUID v4) on mutations
- Exponential backoff retry on connection errors / 408 / 429 / 5xx
- Honors `Retry-After`

**Not yet shipped (TODO before v1.0.0 / parity with `@garuhq/node`):**
- Customers resource (CRUD + billing email override)
- Products resource (list/get + portalConfig)
- Scheduled charges (create/list/get/lifecycle/listAttempts)
- Meta resource
- Strongly-typed `Charge`, `Customer`, `Product`, `ScheduledChargeRecord` models
  (currently `Map<String, dynamic>` in many places)
- `GaruFailureCode` enum
- Card tokenization helpers
- Example Flutter app

Public API surface is **not frozen**. Breaking changes possible until v1.0.0.
