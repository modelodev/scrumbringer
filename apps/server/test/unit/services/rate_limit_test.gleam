import gleeunit/should
import scrumbringer_server/services/rate_limit

pub fn allow_denies_when_limit_reached_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 100)
  |> should.equal(True)

  rate_limit.allow("key", 1, 60, 110)
  |> should.equal(False)
}

pub fn allow_allows_after_window_expires_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 100)
  |> should.equal(True)

  rate_limit.allow("key", 1, 60, 160)
  |> should.equal(True)

  rate_limit.allow("key", 1, 60, 161)
  |> should.equal(False)
}

pub fn allow_is_key_scoped_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key-a", 1, 60, 100)
  |> should.equal(True)

  rate_limit.allow("key-b", 1, 60, 100)
  |> should.equal(True)
}

pub fn reset_clears_state_test() {
  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 100)
  |> should.equal(True)

  rate_limit.allow("key", 1, 60, 110)
  |> should.equal(False)

  rate_limit.reset_for_tests()

  rate_limit.allow("key", 1, 60, 120)
  |> should.equal(True)
}
