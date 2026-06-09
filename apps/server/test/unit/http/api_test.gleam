import scrumbringer_server/http/api
import support/assertions as expect

pub fn parse_cookie_secure_value_disables_for_false_test() {
  api.parse_cookie_secure_value("false")
  |> expect.is_false
}

pub fn parse_cookie_secure_value_disables_for_zero_test() {
  api.parse_cookie_secure_value("0")
  |> expect.is_false
}

pub fn parse_cookie_secure_value_defaults_true_for_other_values_test() {
  api.parse_cookie_secure_value("")
  |> expect.is_true

  api.parse_cookie_secure_value("true")
  |> expect.is_true

  api.parse_cookie_secure_value("FALSE")
  |> expect.is_true
}
