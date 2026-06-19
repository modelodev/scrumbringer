//// In-memory rate limiting for abuse control.
////
//// This rate limiter is best-effort and in-memory. It is intended as an MVP
//// abuse-control mechanism, not a hard security boundary. State is not
//// persisted across restarts.

/// Checks if a request should be allowed based on rate limits.
///
/// Returns `True` when the request is allowed, `False` when rate limited.
///
/// ## Example
/// ```gleam
/// let now = time.now_unix_seconds()
/// case rate_limit.allow("login:" <> user_id, 5, 60, now) {
///   True -> process_login(request)
///   False -> Error(TooManyRequests)
/// }
/// ```
pub fn allow(
  key: String,
  limit: Int,
  window_seconds: Int,
  now_unix: Int,
) -> Bool {
  rate_limit_allow_ffi(key, limit, window_seconds, now_unix)
}

/// Reset in-memory rate limit state (test helper).
pub fn reset_for_tests() -> Bool {
  rate_limit_reset_ffi()
}

@external(erlang, "scrumbringer_server_ffi", "rate_limit_allow")
fn rate_limit_allow_ffi(
  _key: String,
  _limit: Int,
  _window_seconds: Int,
  _now_unix: Int,
) -> Bool {
  True
}

@external(erlang, "scrumbringer_server_ffi", "rate_limit_reset")
fn rate_limit_reset_ffi() -> Bool {
  True
}
