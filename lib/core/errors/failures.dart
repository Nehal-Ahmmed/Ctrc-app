abstract class Failure {
  final String message;
  const Failure(this.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// The stored session was rejected by the backend, or there is no longer one on
/// this device.
///
/// Kept apart from a plain [AuthFailure] because it is the only failure that
/// should sign somebody out. A backend that is asleep, or a phone with no
/// signal, must leave the session exactly where it was.
class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([
    super.message = 'Your session has ended. Please sign in again.',
  ]);
}

class ValidationFailure extends Failure {
  final Map<String, String>? errors;
  const ValidationFailure(super.message, {this.errors});
}
