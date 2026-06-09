//// Client IP extraction helpers for HTTP handlers.

import gleam/http/request
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import wisp

pub fn from_request(req: wisp.Request) -> Option(String) {
  from_headers(
    optional_header(req, "x-forwarded-for"),
    optional_header(req, "x-real-ip"),
  )
}

pub fn from_headers(
  x_forwarded_for: Option(String),
  x_real_ip: Option(String),
) -> Option(String) {
  case first_ip(x_forwarded_for) {
    Some(ip) -> Some(ip)
    None -> first_ip(x_real_ip)
  }
}

fn optional_header(req: wisp.Request, name: String) -> Option(String) {
  case request.get_header(req, name) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn first_ip(header: Option(String)) -> Option(String) {
  case header {
    None -> None
    Some(value) ->
      value
      |> string.split(",")
      |> list.first
      |> option_from_result
      |> trim_non_empty
  }
}

fn option_from_result(value: Result(String, Nil)) -> Option(String) {
  case value {
    Ok(item) -> Some(item)
    Error(_) -> None
  }
}

fn trim_non_empty(value: Option(String)) -> Option(String) {
  case value {
    None -> None
    Some(raw) -> {
      let trimmed = string.trim(raw)
      case trimmed {
        "" -> None
        _ -> Some(trimmed)
      }
    }
  }
}
