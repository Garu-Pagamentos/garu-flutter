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
