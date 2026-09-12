import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a UUIDv4 suitable for use as an `X-Idempotency-Key`.
///
/// Only useful when you can STORE the result and reuse it across retries of the
/// same logical operation. Generated fresh on each attempt it protects nothing
/// — see [idempotencyHeaders].
String generateIdempotencyKey() => _uuid.v4();

/// Build the `X-Idempotency-Key` header block for a write, **only** when the
/// caller supplied a key.
///
/// Until 0.8.0 this SDK invented a UUIDv4 whenever the caller passed nothing.
/// That is worse than sending no key at all: an idempotency key only means
/// something if the SAME key comes back on a retry, and a key invented per call
/// is different every time. It bought no protection while making the request
/// look protected — the docstrings even promised it was "safe to retry".
///
/// What that cost elsewhere: on 2026-09-08 an integrator's HTTP client timed out
/// at 30s on a card charge that was still being created, retried, drew a fresh
/// UUIDv4, and charged a real buyer a second time. `@garuhq/node` removed the
/// same behaviour in 5.0.0.
///
/// Sending no header is the honest signal. The write is then covered by the
/// gateway's own duplicate guard, which for an API-key caller is not advisory:
/// same buyer, product, rail and instalment count inside 60s either replays the
/// original charge or refuses with 409.
///
/// For real protection, derive the key from something stable in YOUR domain (an
/// order id, a booking id) so that a retry reproduces it:
///
/// ```dart
/// await garu.charges.create(
///   productId: productId,
///   paymentMethod: 'creditCard',
///   customer: customer,
///   card: card,
///   idempotencyKey: 'booking:${booking.id}:charge',
/// );
/// ```
Map<String, String> idempotencyHeaders(String? key) =>
    key == null ? const {} : {'X-Idempotency-Key': key};
