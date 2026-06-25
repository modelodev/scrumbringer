//// HTTP response mapping for shared service errors.

import scrumbringer_server/http/api
import scrumbringer_server/use_case/service_error.{
  type ServiceError, AlreadyExists, Conflict, DbError, InvalidReference,
  NotFound, Unexpected, ValidationError,
}
import wisp

/// Maps shared service errors to the common HTTP response contract.
pub fn to_response(error: ServiceError) -> wisp.Response {
  case error {
    NotFound -> api.error(404, "NOT_FOUND", "Not found")
    DbError(_) -> api.error(500, "INTERNAL", "Database error")
    ValidationError(message) -> api.error(422, "VALIDATION_ERROR", message)
    InvalidReference(_) ->
      api.error(422, "VALIDATION_ERROR", "Invalid reference")
    Conflict(_) -> api.error(409, "CONFLICT", "Conflict")
    Unexpected(_) -> api.error(500, "INTERNAL", "Unexpected error")
    AlreadyExists -> api.error(409, "CONFLICT", "Conflict")
  }
}

/// Maps shared service errors for endpoints whose public contract groups
/// unexpected repository state with database failures.
pub fn to_database_response(error: ServiceError) -> wisp.Response {
  case error {
    Unexpected(_) -> api.error(500, "INTERNAL", "Database error")
    other -> to_response(other)
  }
}
