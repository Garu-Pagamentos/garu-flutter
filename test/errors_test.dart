import 'package:garu/garu.dart';
import 'package:test/test.dart';

void main() {
  group('mapHttpError', () {
    test('401 → GaruAuthenticationError', () {
      final err = mapHttpError(status: 401, message: 'unauthorized');
      expect(err, isA<GaruAuthenticationError>());
      expect(err.status, 401);
      expect(err.code, GaruErrorCode.authentication);
    });

    test('404 → GaruNotFoundError', () {
      final err = mapHttpError(status: 404, message: 'not found');
      expect(err, isA<GaruNotFoundError>());
      expect(err.code, GaruErrorCode.notFound);
    });

    test('422 → GaruValidationError', () {
      final err = mapHttpError(
        status: 422,
        message: 'validation',
        body: {'errors': <String>[]},
      );
      expect(err, isA<GaruValidationError>());
      expect(err.status, 422);
      expect(err.body, {'errors': <String>[]});
    });

    test('429 → GaruRateLimitError carries retryAfterSec', () {
      final err = mapHttpError(status: 429, message: 'slow down', retryAfterSec: 30);
      expect(err, isA<GaruRateLimitError>());
      expect((err as GaruRateLimitError).retryAfterSec, 30);
    });

    test('5xx → GaruServerError', () {
      final err = mapHttpError(status: 503, message: 'unavailable');
      expect(err, isA<GaruServerError>());
      expect(err.code, GaruErrorCode.server);
    });

    test('preserves requestId for ops correlation', () {
      final err = mapHttpError(
        status: 500,
        message: 'oops',
        requestId: 'req_abc123',
      );
      expect(err.requestId, 'req_abc123');
    });
  });
}
