import gleam/http
import scrumbringer_server/http/metrics_query
import support/assertions as expect
import wisp/simulate

pub fn parse_window_days_uses_default_when_absent_test() {
  let req = simulate.request(http.Get, "/api/org/metrics/overview")

  let assert Ok(30) = metrics_query.parse_window_days(req, 90)
}

pub fn parse_window_days_accepts_value_within_max_test() {
  let req =
    simulate.request(http.Get, "/api/org/metrics/overview?window_days=60")

  let assert Ok(60) = metrics_query.parse_window_days(req, 90)
}

pub fn parse_window_days_rejects_values_outside_max_test() {
  let req =
    simulate.request(http.Get, "/api/org/metrics/overview?window_days=91")

  case metrics_query.parse_window_days(req, 90) {
    Ok(_) -> expect.fail()
    Error(_) -> Nil
  }
}
