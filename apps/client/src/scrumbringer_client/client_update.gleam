//// Update module for Scrumbringer client.
////
//// ## Mission
////
//// Handles all state transitions in the Lustre application. Contains the
//// central `update` function and message-specific handlers.
////
//// ## Responsibilities
////
//// - Process `Msg` variants and update `Model`
//// - Produce effects for side-effects (API calls, navigation, timers)
//// - Coordinate with child component updates (accept_invite, reset_password)
////
//// ## Non-responsibilities
////
//// - Type definitions (see `client_state.gleam`)
//// - View rendering (see `scrumbringer_client.gleam` / future `client_view.gleam`)
//// - API request construction (see `api.gleam`)
////
//// ## Current Status
////
//// This module is a placeholder. The update function (~2700 lines) remains in
//// `scrumbringer_client.gleam` pending extraction of shared helper functions.
////
//// ## Planned Structure
////
//// Future refactoring should extract domain-specific handlers:
//// - `update/auth.gleam`: login, logout, password reset
//// - `update/member.gleam`: member section, tasks, pool
//// - `update/admin.gleam`: admin section, projects, capabilities
////
//// ## Dependencies (when fully extracted)
////
//// The update function will need:
//// - `client_state`: Model, Msg, Remote types
//// - `api`: API effects
//// - `client_ffi`: browser FFI
//// - `router`: URL handling
//// - `accept_invite`, `reset_password`: child component updates

// =============================================================================
// Placeholder - actual update lives in scrumbringer_client.gleam
// =============================================================================

// This module exists to:
// 1. Document the intended architecture
// 2. Reserve the module name for future extraction
// 3. Track the refactoring plan

// When extracted, the update function will have this signature:
// pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg))
