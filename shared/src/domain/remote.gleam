//// Remote data state for async operations.
////
//// ## Mission
////
//// Represents the lifecycle of data fetched from an API.
//// Used across client for consistent handling of async state.
////
//// ## States
////
//// - NotAsked: Data has not been requested yet
//// - Loading: Request is in flight
//// - Loaded(a): Data successfully loaded
//// - Failed(ApiError): Request failed with error

import domain/api_error.{type ApiError}

// =============================================================================
// Types
// =============================================================================

/// Remote data state for async operations.
pub type Remote(a) {
  /// Data has not been requested yet.
  NotAsked
  /// Request is in flight.
  Loading
  /// Data successfully loaded.
  Loaded(a)
  /// Request failed with error.
  Failed(ApiError)
}

// =============================================================================
// Transformations
// =============================================================================

/// Map over the loaded value, preserving other states.
pub fn map(remote: Remote(a), f: fn(a) -> b) -> Remote(b) {
  case remote {
    NotAsked -> NotAsked
    Loading -> Loading
    Loaded(a) -> Loaded(f(a))
    Failed(err) -> Failed(err)
  }
}

/// Get the loaded value or a default.
pub fn unwrap(remote: Remote(a), default: a) -> a {
  case remote {
    Loaded(a) -> a
    NotAsked -> default
    Loading -> default
    Failed(_) -> default
  }
}

/// Check if loaded.
pub fn is_loaded(remote: Remote(a)) -> Bool {
  case remote {
    Loaded(_) -> True
    NotAsked -> False
    Loading -> False
    Failed(_) -> False
  }
}

/// Check if loading.
pub fn is_loading(remote: Remote(a)) -> Bool {
  case remote {
    Loading -> True
    NotAsked -> False
    Loaded(_) -> False
    Failed(_) -> False
  }
}

/// Check if failed.
pub fn is_failed(remote: Remote(a)) -> Bool {
  case remote {
    Failed(_) -> True
    NotAsked -> False
    Loading -> False
    Loaded(_) -> False
  }
}

/// Convert to Option, discarding error info.
pub fn to_option(remote: Remote(a)) -> Result(a, Nil) {
  case remote {
    Loaded(a) -> Ok(a)
    NotAsked -> Error(Nil)
    Loading -> Error(Nil)
    Failed(_) -> Error(Nil)
  }
}
