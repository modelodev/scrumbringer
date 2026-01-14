// Returns True when the request is allowed.
//
// This rate limiter is best-effort and in-memory. It is intended as an MVP
// abuse-control, not a hard security boundary.
pub fn allow(
  key: String,
  limit: Int,
  window_seconds: Int,
  now_unix: Int,
) -> Bool {
  rate_limit_allow_ffi(key, limit, window_seconds, now_unix)
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
