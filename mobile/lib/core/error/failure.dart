/// Domain-level failures.
///
/// We surface failures as typed values (via [Result]) rather than throwing
/// across layers, so the presentation layer can switch on them and show the
/// right message — critical for an offline app where "no network" is a normal,
/// expected state, not an error to scare the user with.
sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device has no connectivity. Expected and benign in offline-first flows —
/// the local write still succeeded; only sync is deferred.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

/// The server rejected the request (4xx/5xx).
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;
}

/// Local database read/write failed.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Local storage error']);
}

/// Authentication/session problem (expired token, not signed in).
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication required']);
}

/// Input or business-rule validation failed (e.g. selling more than in stock).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
