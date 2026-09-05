/// Tri-state outcome for every request — never conflate "no response" with "confirmed failure".
/// See ARCHITECTURE.md §9: a Slave must distinguish confirmed success, confirmed failure, and
/// unknown (network drop) — only the first two are safe to act on without a retry-safe replay.
sealed class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

/// The server was reached and returned an error — safe to show the message and let the user correct input.
class ApiFailure<T> extends ApiResult<T> {
  final int statusCode;
  final String message;
  const ApiFailure(this.statusCode, this.message);
}

/// The request may or may not have executed on the server (timeout / connection drop / DNS failure).
/// Never tell the user it succeeded OR failed — only that it's unconfirmed and a retry (same
/// Idempotency-Key) is safe.
class ApiNetworkError<T> extends ApiResult<T> {
  final String message;
  const ApiNetworkError(this.message);
}
