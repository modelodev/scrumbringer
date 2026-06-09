import gleam/option
import scrumbringer_server/http/client_ip

pub fn from_headers_prefers_first_forwarded_ip_test() {
  let assert option.Some("203.0.113.10") =
    client_ip.from_headers(
      option.Some(" 203.0.113.10, 10.0.0.2 "),
      option.Some("198.51.100.5"),
    )
}

pub fn from_headers_falls_back_to_real_ip_test() {
  let assert option.Some("198.51.100.5") =
    client_ip.from_headers(option.None, option.Some(" 198.51.100.5 "))
}

pub fn from_headers_falls_back_when_forwarded_ip_is_blank_test() {
  let assert option.Some("198.51.100.5") =
    client_ip.from_headers(
      option.Some(" , 10.0.0.2"),
      option.Some("198.51.100.5"),
    )
}

pub fn from_headers_returns_none_for_missing_or_blank_headers_test() {
  let assert option.None = client_ip.from_headers(option.None, option.None)
  let assert option.None =
    client_ip.from_headers(option.Some(" "), option.Some(""))
}
