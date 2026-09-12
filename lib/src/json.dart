/// Read a money field that the API may send as a JSON number OR as a string.
///
/// Both shapes are live. The versioned `/api/v1/*` responses map their decimals
/// with `Number(...)` and send `29.9`, but the older endpoints hand the Postgres
/// `numeric` column straight through and send `"29.90"` — confirmed against
/// production on 2026-09-12, where `GET /api/products/uuid/{uuid}` answered
/// `"value": "29.90"`. That string is the documented wire format of those
/// endpoints and is deliberately preserved by the gateway, so the SDK has to
/// read it rather than wait for it to change.
///
/// JavaScript coerces the difference away; Dart does not. `'29.90' as num`
/// throws, which is why `products.get()` crashed on every real product.
num? toNumOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

/// [toNumOrNull] with a fallback, for fields the API declares non-null.
num toNumOr(Object? v, num fallback) => toNumOrNull(v) ?? fallback;
