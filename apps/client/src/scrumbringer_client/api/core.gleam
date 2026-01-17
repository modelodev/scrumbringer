//// Core API infrastructure for Scrumbringer client.
////
//// ## Mission
////
//// Provides the foundational HTTP request/response handling used by all API
//// modules. Handles CSRF tokens, JSON encoding/decoding, and error handling.
////
//// ## Responsibilities
////
//// - Define `ApiError` and `ApiResult` types
//// - CSRF token management (`should_attach_csrf`, `build_csrf_headers`)
//// - HTTP request primitives (`request`, `request_nil`)
//// - JSON response decoding (`decode_success`, `decode_failure`)
////
//// ## Non-responsibilities
////
//// - Domain-specific types (see `api/tasks.gleam`, etc.)
//// - Business logic
////
//// ## Usage
////
//// ```gleam
//// import scrumbringer_client/api/core
////
//// pub fn fetch_items(to_msg: fn(core.ApiResult(List(Item))) -> msg) -> Effect(msg) {
////   core.request("GET", "/api/v1/items", None, items_decoder(), to_msg)
//// }
//// ```

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

import lustre/effect.{type Effect}

import scrumbringer_client/client_ffi

// =============================================================================
// Types
// =============================================================================

/// Represents an API error with HTTP status, error code, and message.
///
/// ## Example
///
/// ```gleam
/// case result {
///   Ok(data) -> use_data(data)
///   Error(ApiError(status: 404, code: "NOT_FOUND", message: msg)) ->
///     show_not_found(msg)
///   Error(err) -> show_error(err.message)
/// }
/// ```
pub type ApiError {
  ApiError(status: Int, code: String, message: String)
}

/// Result type for API operations.
pub type ApiResult(a) =
  Result(a, ApiError)

// =============================================================================
// CSRF Handling
// =============================================================================

/// Check if a method requires CSRF protection.
///
/// ## Example
///
/// ```gleam
/// should_attach_csrf("POST")  // True
/// should_attach_csrf("GET")   // False
/// ```
pub fn should_attach_csrf(method: String) -> Bool {
  case string.uppercase(method) {
    "POST" | "PUT" | "PATCH" | "DELETE" -> True
    _ -> False
  }
}

/// Build CSRF headers for a request if needed.
///
/// ## Example
///
/// ```gleam
/// let headers = build_csrf_headers("POST", Some("token123"))
/// // [#("X-CSRF", "token123")]
/// ```
pub fn build_csrf_headers(
  method: String,
  csrf: option.Option(String),
) -> List(#(String, String)) {
  case should_attach_csrf(method), csrf {
    True, option.Some(token) -> [#("X-CSRF", token)]
    _, _ -> []
  }
}

// =============================================================================
// Cookie Handling
// =============================================================================

fn read_cookie(name: String) -> option.Option(String) {
  case client_ffi.read_cookie(name) {
    "" -> option.None
    value -> option.Some(value)
  }
}

// =============================================================================
// Response Decoding
// =============================================================================

/// Wrap a decoder to extract from { "data": ... } envelope.
pub fn envelope(payload: decode.Decoder(a)) -> decode.Decoder(a) {
  decode.field("data", payload, decode.success)
}

fn api_error_decoder(status: Int) -> decode.Decoder(ApiError) {
  let error_inner = {
    use code <- decode.field("code", decode.string)
    use message <- decode.field("message", decode.string)
    decode.success(#(code, message))
  }

  decode.field("error", error_inner, fn(inner) {
    let #(code, message) = inner
    decode.success(ApiError(status: status, code: code, message: message))
  })
}

/// Decode a successful JSON response.
pub fn decode_success(
  status: Int,
  text: String,
  decoder: decode.Decoder(a),
) -> ApiResult(a) {
  json.parse(from: text, using: envelope(decoder))
  |> result.map_error(fn(_) {
    ApiError(
      status: status,
      code: "DECODE_ERROR",
      message: "Failed to decode response",
    )
  })
}

/// Decode an error response.
pub fn decode_failure(status: Int, text: String) -> ApiError {
  case json.parse(from: text, using: api_error_decoder(status)) {
    Ok(err) -> err
    Error(_) ->
      ApiError(status: status, code: "HTTP_ERROR", message: "Request failed")
  }
}

// =============================================================================
// Request Functions
// =============================================================================

/// Make an HTTP request and decode the JSON response.
///
/// ## Example
///
/// ```gleam
/// request("GET", "/api/v1/users", None, users_decoder(), UsersFetched)
/// ```
pub fn request(
  method: String,
  url: String,
  body: option.Option(json.Json),
  decoder: decode.Decoder(a),
  to_msg: fn(ApiResult(a)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let csrf = read_cookie("sb_csrf")

    let base_headers = [#("Accept", "application/json")]

    let headers = case body {
      option.Some(_) -> [#("Content-Type", "application/json"), ..base_headers]
      option.None -> base_headers
    }

    let headers = list.append(headers, build_csrf_headers(method, csrf))

    let body_string = option.map(body, json.to_string)

    client_ffi.send(method, url, headers, body_string, fn(result) {
      let #(status, text) = result

      let msg = case status >= 200 && status < 300 {
        True -> {
          case status == 204 || string.length(text) == 0 {
            True ->
              to_msg(
                Error(ApiError(
                  status: status,
                  code: "EMPTY",
                  message: "Empty response",
                )),
              )
            False -> decode_success(status, text, decoder) |> to_msg
          }
        }

        False -> to_msg(Error(decode_failure(status, text)))
      }

      dispatch(msg)
    })
  })
}

/// Make an HTTP request expecting no response body (204 No Content).
///
/// ## Example
///
/// ```gleam
/// request_nil("DELETE", "/api/v1/users/123", None, UserDeleted)
/// ```
pub fn request_nil(
  method: String,
  url: String,
  body: option.Option(json.Json),
  to_msg: fn(ApiResult(Nil)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let csrf = read_cookie("sb_csrf")

    let base_headers = [#("Accept", "application/json")]

    let headers = case body {
      option.Some(_) -> [#("Content-Type", "application/json"), ..base_headers]
      option.None -> base_headers
    }

    let headers = list.append(headers, build_csrf_headers(method, csrf))

    let body_string = option.map(body, json.to_string)

    client_ffi.send(method, url, headers, body_string, fn(result) {
      let #(status, text) = result

      let msg = case status >= 200 && status < 300 {
        True -> to_msg(Ok(Nil))
        False -> to_msg(Error(decode_failure(status, text)))
      }

      dispatch(msg)
    })
  })
}
