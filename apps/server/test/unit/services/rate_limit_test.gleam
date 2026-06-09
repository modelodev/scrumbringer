import scrumbringer_server/services/rate_limit
import support/assertions as expect

pub fn allow_denies_when_limit_reached_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 100)
  |> expect.equal(True)

  rate_limit.allow("key", 1, 60, 110)
  |> expect.equal(False)
}

pub fn allow_allows_after_window_expires_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 100)
  |> expect.equal(True)

  rate_limit.allow("key", 1, 60, 160)
  |> expect.equal(True)

  rate_limit.allow("key", 1, 60, 161)
  |> expect.equal(False)
}

pub fn allow_is_key_scoped_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key-a", 1, 60, 100)
  |> expect.equal(True)

  rate_limit.allow("key-b", 1, 60, 100)
  |> expect.equal(True)
}

pub fn reset_clears_state_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 100)
  |> expect.equal(True)

  rate_limit.allow("key", 1, 60, 110)
  |> expect.equal(False)

  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 120)
  |> expect.equal(True)
}
