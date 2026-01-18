//// API error domain types for ScrumBringer.
////
//// Defines the common API error and result types used across client and server.
////
//// ## Usage
////
//// ```gleam
//// import shared/domain/api_error.{type ApiError, type ApiResult}
////
//// case result {
////   Ok(data) -> use_data(data)
////   Error(ApiError(status: 404, code: "NOT_FOUND", message: msg)) -> show_not_found(msg)
////   Error(err) -> show_error(err.message)
//// }
//// ```

// =============================================================================
// Types
// =============================================================================

/// Represents an API error with HTTP status, error code, and message.
///
/// ## Example
///
/// ```gleam
/// ApiError(status: 404, code: "NOT_FOUND", message: "Task not found")
/// ```
pub type ApiError {
  ApiError(status: Int, code: String, message: String)
}

/// Result type for API operations.
///
/// ## Example
///
/// ```gleam
/// fn fetch_task(id: Int) -> ApiResult(Task) {
///   // ...
/// }
/// ```
pub type ApiResult(a) =
  Result(a, ApiError)
