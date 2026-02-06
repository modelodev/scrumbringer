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
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

import lustre/effect.{type Effect}
import lustre_http as http_client

import scrumbringer_client/client_ffi

// Import types from shared domain
import domain/api_error.{
  type ApiError, type ApiResult as SharedApiResult, ApiError,
}
import domain/api_error/codec as api_error_codec

// Re-export ApiResult for backwards compatibility
/// Represents ApiResult.
pub type ApiResult(a) =
  SharedApiResult(a)

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

/// Decoder for nullable int fields.
pub fn nullable_int() -> decode.Decoder(option.Option(Int)) {
  decode.optional(decode.int)
}

/// Decoder for nullable string fields.
pub fn nullable_string() -> decode.Decoder(option.Option(String)) {
  decode.optional(decode.string)
}

/// Helper for optional fields that map to Option values.
pub fn optional_field(
  name: String,
  decoder: decode.Decoder(a),
  next: fn(option.Option(a)) -> decode.Decoder(b),
) -> decode.Decoder(b) {
  decode.optional_field(name, option.None, decode.optional(decoder), next)
}

/// Wrap a decoder to extract from { "data": ... } envelope.
pub fn envelope(payload: decode.Decoder(a)) -> decode.Decoder(a) {
  decode.field("data", payload, decode.success)
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
  case
    json.parse(from: text, using: api_error_codec.api_error_decoder(status))
  {
    Ok(err) -> err
    Error(_) ->
      ApiError(status: status, code: "HTTP_ERROR", message: "Request failed")
  }
}

fn normalize_url(url: String) -> String {
  case string.starts_with(url, "/") {
    True -> client_ffi.location_origin() <> url
    False -> url
  }
}

fn method_from_string(method: String) -> http.Method {
  case string.uppercase(method) {
    "POST" -> http.Post
    "PUT" -> http.Put
    "PATCH" -> http.Patch
    "DELETE" -> http.Delete
    "HEAD" -> http.Head
    "OPTIONS" -> http.Options
    _ -> http.Get
  }
}

fn build_request(
  method: String,
  url: String,
  headers: List(#(String, String)),
  body: option.Option(String),
) -> request.Request(String) {
  let req = case request.to(normalize_url(url)) {
    Ok(req) -> req
    Error(_) -> request.new() |> request.set_path(url)
  }

  let req = request.set_method(req, method_from_string(method))

  let req =
    list.fold(headers, req, fn(req, header) {
      let #(key, value) = header
      request.set_header(req, string.lowercase(key), value)
    })

  case body {
    option.Some(body_string) -> request.set_body(req, body_string)
    option.None -> req
  }
}

fn http_error_to_api_error(err: http_client.HttpError) -> ApiError {
  case err {
    http_client.BadUrl(url) ->
      ApiError(status: 0, code: "BAD_URL", message: "Bad URL: " <> url)
    http_client.NetworkError ->
      ApiError(status: 0, code: "NETWORK_ERROR", message: "Network error")
    http_client.JsonError(_) ->
      ApiError(status: 0, code: "DECODE_ERROR", message: "Failed to decode")
    http_client.NotFound -> decode_failure(404, "")
    http_client.Unauthorized -> decode_failure(401, "")
    http_client.InternalServerError(body) -> decode_failure(500, body)
    http_client.OtherError(status, body) -> decode_failure(status, body)
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
  let csrf = read_cookie("sb_csrf")

  let base_headers = [#("accept", "application/json")]

  let headers = case body {
    option.Some(_) -> [#("content-type", "application/json"), ..base_headers]
    option.None -> base_headers
  }

  let headers = list.append(headers, build_csrf_headers(method, csrf))

  let body_string = option.map(body, json.to_string)

  let req = build_request(method, url, headers, body_string)

  http_client.send(
    req,
    http_client.expect_text_response(
      fn(res: response.Response(String)) {
        let response.Response(status: status, headers: _, body: text) = res

        case status >= 200 && status < 300 {
          True ->
            case status == 204 || string.length(text) == 0 {
              True ->
                Error(ApiError(
                  status: status,
                  code: "EMPTY",
                  message: "Empty response",
                ))
              False -> decode_success(status, text, decoder)
            }

          False -> Error(decode_failure(status, text))
        }
      },
      http_error_to_api_error,
      to_msg,
    ),
  )
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
  let csrf = read_cookie("sb_csrf")

  let base_headers = [#("accept", "application/json")]

  let headers = case body {
    option.Some(_) -> [#("content-type", "application/json"), ..base_headers]
    option.None -> base_headers
  }

  let headers = list.append(headers, build_csrf_headers(method, csrf))

  let body_string = option.map(body, json.to_string)

  let req = build_request(method, url, headers, body_string)

  http_client.send(
    req,
    http_client.expect_text_response(
      fn(res: response.Response(String)) {
        let response.Response(status: status, headers: _, body: text) = res

        case status >= 200 && status < 300 {
          True -> Ok(Nil)
          False -> Error(decode_failure(status, text))
        }
      },
      http_error_to_api_error,
      to_msg,
    ),
  )
}
