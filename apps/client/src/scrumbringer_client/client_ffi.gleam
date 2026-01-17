//// FFI Module for Scrumbringer Client
////
//// Mission: Provide a clean boundary for JavaScript interop in the client.
////
//// Responsibilities:
//// - Expose browser APIs (history, location, DOM, clipboard)
//// - Expose timing utilities (now_ms, set_timeout, parse_iso_ms)
//// - Expose event registration (popstate, keydown)
//// - Expose HTTP primitives (send, cookies, URL encoding)
////
//// Non-responsibilities:
//// - Lustre effects (see main client module)
//// - Business logic (see client_update)
//// - Type definitions (see client_state)
//// - API request/response handling (see api.gleam)
////
//// Relations:
//// - Used by: scrumbringer_client (for effects and init), api (for HTTP)
//// - Uses: fetch.ffi.mjs (JavaScript module)

import gleam/option.{type Option}

// =============================================================================
// Navigation APIs
// =============================================================================

/// Push a new entry to browser history.
///
/// Example:
/// ```gleam
/// history_push_state("/projects/123")
/// ```
@external(javascript, "./fetch.ffi.mjs", "history_push_state")
pub fn history_push_state(_path: String) -> Nil {
  Nil
}

/// Replace the current history entry.
///
/// Example:
/// ```gleam
/// history_replace_state("/login")
/// ```
@external(javascript, "./fetch.ffi.mjs", "history_replace_state")
pub fn history_replace_state(_path: String) -> Nil {
  Nil
}

/// Register a callback for browser back/forward navigation.
///
/// Example:
/// ```gleam
/// register_popstate(fn(_) { dispatch(UrlChanged) })
/// ```
@external(javascript, "./fetch.ffi.mjs", "register_popstate")
pub fn register_popstate(_cb: fn(Nil) -> Nil) -> Nil {
  Nil
}

// =============================================================================
// Location APIs
// =============================================================================

/// Get the current location origin (e.g., "https://example.com").
@external(javascript, "./fetch.ffi.mjs", "location_origin")
pub fn location_origin() -> String {
  ""
}

/// Get the current location pathname (e.g., "/projects/123").
@external(javascript, "./fetch.ffi.mjs", "location_pathname")
pub fn location_pathname() -> String {
  ""
}

/// Get the current location hash (e.g., "#section").
@external(javascript, "./fetch.ffi.mjs", "location_hash")
pub fn location_hash() -> String {
  ""
}

/// Get the current location search query (e.g., "?foo=bar").
@external(javascript, "./fetch.ffi.mjs", "location_search")
pub fn location_search() -> String {
  ""
}

// =============================================================================
// DOM APIs
// =============================================================================
//
// Design note: These functions return sentinel values (empty strings, zeros)
// when elements are not found. This is intentional for UI code where:
// 1. Elements are expected to exist (rendered by the same app)
// 2. Silent failure with defaults is acceptable for these use cases
// 3. Distinguishing "not found" from "found with default value" would require
//    JavaScript changes to return tagged Result-like structures
//
// For stricter error handling, consider adding try_* variants that modify
// the JavaScript to return {ok: value} or {error: reason} objects.
// =============================================================================

/// Focus an element by its ID.
///
/// Returns silently if element is not found (no-op).
///
/// ## Example
///
/// ```gleam
/// focus_element("login-email")
/// ```
@external(javascript, "./fetch.ffi.mjs", "focus_element")
pub fn focus_element(_id: String) -> Nil {
  Nil
}

/// Get the value of an input element by ID.
///
/// Returns `""` if element is not found or has no value.
/// **Note**: Cannot distinguish "not found" from "empty input value".
///
/// ## Example
///
/// ```gleam
/// let email = input_value("login-email")
/// ```
@external(javascript, "./fetch.ffi.mjs", "input_value")
pub fn input_value(_id: String) -> String {
  ""
}

/// Get the client offset (left, top) of an element by ID.
///
/// Returns `#(0, 0)` if element is not found.
/// **Note**: Cannot distinguish "not found" from "element at origin".
///
/// ## Example
///
/// ```gleam
/// let #(left, top) = element_client_offset("canvas")
/// ```
@external(javascript, "./fetch.ffi.mjs", "element_client_offset")
pub fn element_client_offset(_id: String) -> #(Int, Int) {
  #(0, 0)
}

/// Get the client rect (left, top, width, height) of an element by ID.
///
/// Returns `#(0, 0, 0, 0)` if element is not found.
/// **Note**: Cannot distinguish "not found" from "collapsed element at origin".
///
/// ## Example
///
/// ```gleam
/// let #(left, top, width, height) = element_client_rect("canvas")
/// ```
@external(javascript, "./fetch.ffi.mjs", "element_client_rect")
pub fn element_client_rect(_id: String) -> #(Int, Int, Int, Int) {
  #(0, 0, 0, 0)
}

// =============================================================================
// Keyboard APIs
// =============================================================================

/// Register a global keydown handler.
///
/// The callback receives a tuple:
/// (key, ctrl_pressed, meta_pressed, shift_pressed, is_editing, modal_open)
///
/// Example:
/// ```gleam
/// register_keydown(fn(payload) {
///   let #(key, ctrl, meta, shift, editing, modal) = payload
///   dispatch(GlobalKeyDown(key, ctrl, meta, shift, editing, modal))
/// })
/// ```
@external(javascript, "./fetch.ffi.mjs", "register_keydown")
pub fn register_keydown(
  _cb: fn(#(String, Bool, Bool, Bool, Bool, Bool)) -> Nil,
) -> Nil {
  Nil
}

// =============================================================================
// Clipboard APIs
// =============================================================================

/// Copy text to the clipboard, calling the callback with success status.
///
/// Example:
/// ```gleam
/// copy_to_clipboard("Hello", fn(success) {
///   dispatch(CopyFinished(success))
/// })
/// ```
@external(javascript, "./fetch.ffi.mjs", "copy_to_clipboard")
pub fn copy_to_clipboard(_text: String, _cb: fn(Bool) -> Nil) -> Nil {
  Nil
}

// =============================================================================
// Time APIs
// =============================================================================

/// Get the current time in milliseconds since epoch.
///
/// Example:
/// ```gleam
/// let now = now_ms()
/// ```
@external(javascript, "./fetch.ffi.mjs", "now_ms")
pub fn now_ms() -> Int {
  0
}

/// Parse an ISO date string to milliseconds since epoch.
///
/// Example:
/// ```gleam
/// let ms = parse_iso_ms("2024-01-15T10:30:00Z")
/// ```
@external(javascript, "./fetch.ffi.mjs", "parse_iso_ms")
pub fn parse_iso_ms(_iso: String) -> Int {
  0
}

/// Calculate days elapsed since an ISO date string.
///
/// Example:
/// ```gleam
/// let days = days_since_iso("2024-01-01T00:00:00Z")
/// ```
@external(javascript, "./fetch.ffi.mjs", "days_since_iso")
pub fn days_since_iso(_iso: String) -> Int {
  0
}

/// Schedule a callback after a delay in milliseconds.
/// Returns a timer ID that can be used for cancellation.
///
/// Example:
/// ```gleam
/// let timer_id = set_timeout(1000, fn(_) {
///   dispatch(TimerFired)
///   Nil
/// })
/// ```
@external(javascript, "./fetch.ffi.mjs", "set_timeout")
pub fn set_timeout(_ms: Int, _cb: fn(Nil) -> Nil) -> Int {
  0
}

// =============================================================================
// Device APIs
// =============================================================================

/// Check if the current device appears to be mobile.
///
/// Example:
/// ```gleam
/// let layout = case is_mobile() {
///   True -> MobileLayout
///   False -> DesktopLayout
/// }
/// ```
@external(javascript, "./fetch.ffi.mjs", "is_mobile")
pub fn is_mobile() -> Bool {
  False
}

// =============================================================================
// HTTP and Cookie APIs
// =============================================================================

/// Read a browser cookie by name.
///
/// Returns the cookie value or empty string if not found.
/// **Note**: Cannot distinguish "not found" from "empty value".
///
/// ## Example
///
/// ```gleam
/// let session = read_cookie("session_id")
/// ```
@external(javascript, "./fetch.ffi.mjs", "read_cookie")
pub fn read_cookie(_name: String) -> String {
  ""
}

/// Send an HTTP request with the specified method, URL, headers, and body.
///
/// The callback receives a tuple of (status_code, response_body).
/// This is a low-level primitive; prefer using api.gleam for typed requests.
///
/// ## Example
///
/// ```gleam
/// send("GET", "/api/users", [#("Accept", "application/json")], None, fn(response) {
///   let #(status, body) = response
///   // handle response
/// })
/// ```
@external(javascript, "./fetch.ffi.mjs", "send")
pub fn send(
  _method: String,
  _url: String,
  _headers: List(#(String, String)),
  _body: Option(String),
  _callback: fn(#(Int, String)) -> Nil,
) -> Nil {
  Nil
}

/// URL-encode a string component.
///
/// ## Example
///
/// ```gleam
/// let encoded = encode_uri_component("hello world")
/// // "hello%20world"
/// ```
@external(javascript, "./fetch.ffi.mjs", "encode_uri_component")
pub fn encode_uri_component(_value: String) -> String {
  ""
}
