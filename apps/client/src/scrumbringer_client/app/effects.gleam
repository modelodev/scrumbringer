//// Application-level effects and utilities.
////
//// ## Mission
////
//// Centralizes shared effect creators and application-level utilities
//// used across features. Reserved for cross-cutting effect logic.
////
//// ## Responsibilities
////
//// - Shared effect creators (navigation, toasts, etc.) — when extracted
//// - Application-level side effects
//// - Cross-feature coordination effects
////
//// ## Non-responsibilities
////
//// - Feature-specific effects (see features/*/update.gleam)
//// - View rendering (see features/*/view.gleam)
//// - State types (see client_state.gleam)
//// - Pure helper functions (see update_helpers.gleam, shared/*)
////
//// ## Relations
////
//// - **update_helpers.gleam**: Pure helpers, no effects
//// - **features/auth/helpers.gleam**: Auth state transitions
//// - **features/***: Feature modules create their own effects

// Placeholder - effects will be extracted from client_update.gleam
// in subsequent refactoring stories when patterns emerge

/// Placeholder constant to indicate this module is reserved for future use.
/// Will be removed when actual effects are migrated here.
pub const effects_reserved = True
