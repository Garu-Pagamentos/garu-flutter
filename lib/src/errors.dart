/// Stable error codes mirroring `@garuhq/node`. Use these for typed
/// error handling instead of string-matching messages.
enum GaruErrorCode {
  authentication,
  permission,
  notFound,
  validation,
  rateLimit,
  server,
  connection,
  signatureVerification,
  unknown,
}

/// Base class for every error thrown by the SDK.
abstract class GaruError implements Exception {
  GaruError({required this.message, this.cause});

  final String message;
  final Object? cause;
  GaruErrorCode get code;

  @override
  String toString() => '${runtimeType.toString()}: $message';
}

/// HTTP error with structured fields parsed from the response.
class GaruApiError extends GaruError {
  GaruApiError({
    required super.message,
    required this.status,
    this.requestId,
    this.body,
    super.cause,
  });

  final int status;
  final String? requestId;
  final Object? body;

  @override
  GaruErrorCode get code {
    if (status == 401) return GaruErrorCode.authentication;
    if (status == 403) return GaruErrorCode.permission;
    if (status == 404) return GaruErrorCode.notFound;
    if (status == 400 || status == 422) return GaruErrorCode.validation;
    if (status == 429) return GaruErrorCode.rateLimit;
    if (status >= 500) return GaruErrorCode.server;
    return GaruErrorCode.unknown;
  }
}

class GaruAuthenticationError extends GaruApiError {
  GaruAuthenticationError({
    required super.message,
    super.requestId,
    super.body,
  }) : super(status: 401);
}

class GaruPermissionError extends GaruApiError {
  GaruPermissionError({
    required super.message,
    super.requestId,
    super.body,
  }) : super(status: 403);
}

class GaruNotFoundError extends GaruApiError {
  GaruNotFoundError({
    required super.message,
    super.requestId,
    super.body,
  }) : super(status: 404);
}

class GaruValidationError extends GaruApiError {
  GaruValidationError({
    required super.message,
    required super.status,
    super.requestId,
    super.body,
  });
}

/// 429. Carries `retryAfterSec` parsed from `Retry-After` when present.
class GaruRateLimitError extends GaruApiError {
  GaruRateLimitError({
    required super.message,
    this.retryAfterSec,
    super.requestId,
    super.body,
  }) : super(status: 429);

  final int? retryAfterSec;
}

class GaruServerError extends GaruApiError {
  GaruServerError({
    required super.message,
    required super.status,
    super.requestId,
    super.body,
  });
}

/// Network or socket-level failure (DNS, connection refused, timeout).
class GaruConnectionError extends GaruError {
  GaruConnectionError({required super.message, super.cause});

  @override
  GaruErrorCode get code => GaruErrorCode.connection;
}

/// Webhook signature verification failed — payload was tampered with or
/// the wrong secret was used.
class GaruSignatureVerificationError extends GaruError {
  GaruSignatureVerificationError({required super.message});

  @override
  GaruErrorCode get code => GaruErrorCode.signatureVerification;
}

/// Maps a non-2xx HTTP response to the right typed error class.
GaruApiError mapHttpError({
  required int status,
  required String message,
  String? requestId,
  Object? body,
  int? retryAfterSec,
}) {
  if (status == 401) {
    return GaruAuthenticationError(message: message, requestId: requestId, body: body);
  }
  if (status == 403) {
    return GaruPermissionError(message: message, requestId: requestId, body: body);
  }
  if (status == 404) {
    return GaruNotFoundError(message: message, requestId: requestId, body: body);
  }
  if (status == 400 || status == 422) {
    return GaruValidationError(
      message: message,
      status: status,
      requestId: requestId,
      body: body,
    );
  }
  if (status == 429) {
    return GaruRateLimitError(
      message: message,
      retryAfterSec: retryAfterSec,
      requestId: requestId,
      body: body,
    );
  }
  if (status >= 500) {
    return GaruServerError(
      message: message,
      status: status,
      requestId: requestId,
      body: body,
    );
  }
  return GaruApiError(
    message: message,
    status: status,
    requestId: requestId,
    body: body,
  );
}
