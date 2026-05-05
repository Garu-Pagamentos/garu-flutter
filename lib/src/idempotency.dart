import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a UUIDv4 string for use as `X-Idempotency-Key`.
///
/// The Garu backend caches the response of the first request keyed by
/// (apiKey, idempotencyKey) for 24h, so retries on transient network
/// failures don't double-create resources.
String generateIdempotencyKey() => _uuid.v4();
