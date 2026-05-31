## 0.5.0

Surfaces **Pix Automático** — Brazil's BACEN auto-debit recurring Pix — across the SDK. Tracks Garu backend v0.13.0 + v0.14.0. Every change is additive: existing Card/Pix/Boleto callers need no changes.

Pix Automático lets a customer authorize a recurring debit **once** (a consent link / QR in their bank app); subsequent cycles debit silently with no card on file.

**Added:**
- `PaymentMethod` enum (`pix` / `boleto` / `card` / `pixAutomatic`, plus a forward-compatible `unknown` sentinel). Each value exposes its API `wireValue` (`PaymentMethod.pixAutomatic.wireValue == 'pix_automatic'`) and a `fromWire` parser that resolves unrecognized future values to `unknown` instead of throwing. Exported from `package:garu/garu.dart`.
- `Charge.method` — a typed, forward-compatible `PaymentMethod` view over the raw `Charge.paymentMethod` string. Branch on this on `transaction.*` webhooks to tell a Pix Automático debit apart from a card charge (no new event names — Pix Automático fires the same `subscription.*` / `transaction.payment.*` events as card).
- `Product.pixAutomatic` (non-nullable `bool`, defaults `false`) — whether the public checkout exposes Pix Automático for the product. Read from `Product.fromJson`.
- `scheduledCharges.create` now accepts `'pix_automatic'` in `methods`. A debug-mode `assert` in `create()` enforces the gateway's constraint — `'pix_automatic'` requires `type: 'recurring'` **and** a `productId` — and is compiled out of release/AOT builds; the gateway is authoritative and rejects violations with `400` / `404` / `409`.

**Docs:**
- README gains a "Pix Automático" recipe (create a recurring auto-debit series, branch webhooks on `Charge.method`, failure/cancellation model) and refreshed version/status to `0.5.0`.

**Build:**
- Pinned exact dependency versions in `pubspec.yaml` (`http 1.2.2`, `crypto 3.0.5`, `uuid 4.5.1`, `test 1.25.8`, `lints 4.0.0`) — no more caret ranges.

**Validated:**
- `dart analyze` clean.
- 49 unit tests passing (11 new) — covers `PaymentMethod.fromWire` (known values, `pix_automatic` wire value, `unknown` fallback), `Charge.method` resolution, `Product.pixAutomatic` parse + default, the recurring `pix_automatic` create round-trip, and the `type`/`productId` assertions in `create()`.

## 0.4.0

Adds immediate dispatch for scheduled charges and per-series recovery windows. Both changes are additive — no breaking changes.

**Added:**
- `scheduledCharges.chargeNow(String id)` — dispatch a cycle's charge + customer notification immediately instead of waiting for the due date (the same path the daily billing cron runs). Idempotent: an already-dispatched cycle reports `alreadySent` and is never re-charged, so the call is safe to retry. Returns a typed `ChargeNowResult` { `outcome`, `cycleNumber`, `reason`, `message` }.
- `ChargeNowOutcome` enum — `dispatched` / `alreadySent` / `notSent` / `failed`, plus a forward-compatible `unknown` sentinel. `notSent`/`failed` carry a `reason` (`no_email`, `lock_lost`, `no_saved_payment_method`; `card_expired`, `payment_method_missing`, `customer_missing`, or a raw gateway code).
- `CreateScheduledChargeParams.maxRecoveryDays` (int?, 1–365) — how long the gateway keeps recovering a missed cycle before giving up. Omit for the system default (14). The 1–365 range is checked by a debug-mode `assert` (compiled out of release/AOT builds); the gateway is the authoritative boundary and rejects out-of-range values with a 400.
- `ScheduledChargeRecord.maxRecoveryDays` (int?) on the returned object, with `fromJson`/`toJson` support.

**Security:**
- Every `scheduledCharges` per-id endpoint now interpolates the id through `Uri.encodeComponent(id)`, extending the v0.3.0 path-injection hardening (previously applied only to `products.portalConfig`) to the whole resource. An id containing `/`, `?`, or `#` can no longer spawn extra path segments or leak a query/fragment into the constructed URL.

**Validated:**
- `dart analyze` clean.
- 38 unit tests passing (16 new) across `models_test.dart` and a new `scheduled_charges_test.dart` — covers `chargeNow` HTTP wiring (POST, `/charge-now` path, empty body) against a `MockClient`, id URL-encoding, all four outcomes + the `unknown` fallback, the `maxRecoveryDays` range assertion, and `ScheduledChargeRecord` round-tripping.

## 0.3.0

Tracks Garu backend v0.10.0. Per-product portal-config endpoints now accept the product UUID in addition to the legacy numeric id.

**Breaking:**
- `products.portalConfig.{get,set,patch,clear}` signature changed from `int productId` to `String productId`. Pass the product UUID (preferred — same identifier returned by `products.list()` and webhook payloads) or convert legacy integer ids with `'$id'`.
- `ProductPortalConfig.productId` field type changed from `int` to `String` for symmetry with the request signature — round-tripping a returned `productId` no longer requires manual conversion.

**Security:**
- URL path interpolation now goes through `Uri.encodeComponent(productId)` to prevent query/fragment-segment injection (`?`, `#`, `/` in productId would otherwise corrupt the constructed URL).

**Why:** integer ids are sequential and enumerable. UUIDs are the public-facing identifier across the rest of the API; this brings portal-config in line.

## 0.2.0

Full feature parity with `@garuhq/node@0.8.0`. Public API still pre-1.0 — breaking changes possible until v1.0.0, but the surface is now complete enough for production integrations.

**Added:**
- `customers` resource (CRUD + `setBillingEmailOverride`)
- `products` resource (`list`, `get`) + `products.portalConfig.{get,set,patch,clear}` (B2B2C primitive)
- `scheduledCharges` resource — full lifecycle:
  `create`, `list`, `get`, `markPaid`, `postpone`, `pause`, `resume`,
  `cancelRecurrence`, `cancelAtPeriodEnd`, `changePaymentMethod`,
  `clearPaymentMethod`, `listAttempts` (per-attempt billing audit, SPEC §4.2)
- `meta` resource (discover supported payment methods + webhook events)
- Strongly-typed models: `Charge`, `Customer`, `Product`, `ProductPortalConfig`,
  `SetProductPortalConfigParams`, `ScheduledChargeRecord`, `ScheduledChargeAttempt`,
  `PaginatedList<T>`, `PaginationMeta`
- `GaruFailureCode` enum — 10 canonical values + `isPermanent` helper for
  routing recurring billing failures
- `ScheduledChargeAttemptSource` and `ScheduledChargeAttemptStatus` enums
  with forward-compatible `fromWire` parsers (unrecognized values resolve
  to `.unknown` instead of throwing)

**Validated:**
- `dart analyze` clean (Dart 3.11.5)
- 22 unit tests passing across `webhooks_test.dart`, `models_test.dart`,
  `errors_test.dart` — covers signature verification (5 cases including
  tamper detection + replay window), error mapping by HTTP status, and
  JSON parsing for the v0.8.0 surfaces

**Still TODO before v1.0.0:**
- Strongly-typed event-timeline models for `scheduledCharges.get` detail bundle
- Card tokenization helpers (today: pass raw card to `charges.create`)
- Multi-status filter for `scheduledCharges.list` (currently passes first only)
- Example Flutter app

## 0.1.0 (alpha)

Initial scaffold with `Garu` client, error hierarchy, `charges` resource, and webhook signature verification. NOT at parity with `@garuhq/node`.
