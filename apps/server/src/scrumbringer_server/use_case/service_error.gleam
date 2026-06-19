////
//// Shared service error type for database-facing modules.
////
//// This keeps error contracts consistent across services without introducing
//// extra abstraction layers.

import pog

/// Common error variants for service operations.
pub type ServiceError {
  /// Resource not found.
  NotFound
  /// Resource already exists.
  AlreadyExists
  /// Invalid foreign key or related reference.
  InvalidReference(String)
  /// Validation failed with a message.
  ValidationError(String)
  /// Domain conflict (e.g., in-use, last admin).
  Conflict(String)
  /// Database error.
  DbError(pog.QueryError)
  /// Unexpected state or missing row.
  Unexpected(String)
}
