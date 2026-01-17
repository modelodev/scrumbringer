//// Update function and handlers for Scrumbringer client.
////
//// ## Mission
////
//// Contains the main Lustre update function and all message handlers.
//// Handles state transitions and effect creation for the entire application.
////
//// ## Current Status
////
//// This module is a placeholder for future extraction. The update function
//// (163 handlers, ~2800 lines) remains in `scrumbringer_client.gleam` due to:
////
//// - Tight coupling with Model, Msg constructors, and API effects
//// - Complex hydration and bootstrap logic
//// - 60+ Msg constructors used across handlers
////
//// ## Planned Extraction (Future Sprint)
////
//// The extraction will be done incrementally by domain:
////
//// 1. **Auth handlers**: MeFetched, Login*, Logout*, ForgotPassword*, AcceptInvite*, ResetPassword*
//// 2. **Admin handlers**: Project*, Capability*, Member*, TaskType*, InviteLink*, OrgSettings*
//// 3. **Member handlers**: MemberPool*, MemberTask*, MemberCreate*, MemberDrag*, MemberNotes*
//// 4. **Metrics handlers**: *Metrics*, NowWorking*
////
//// Each domain group can be extracted to its own handler module, with the main
//// update function dispatching to them.
////
//// ## Responsibilities (when complete)
////
//// - Main `update` function dispatching messages to handlers
//// - Effect creation (API calls, navigation, timers, clipboard)
//// - Route application and URL management
//// - Hydration and bootstrap logic
////
//// ## Non-responsibilities
////
//// - Type definitions (see `client_state.gleam`)
//// - View rendering (see `scrumbringer_client.gleam`)
//// - API request logic (see `api.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg, and state types
//// - **scrumbringer_client.gleam**: Entry point with update function (current location)
//// - **api.gleam**: Provides API effects
//// - **router.gleam**: Provides URL parsing

// This module will receive imports as handlers are extracted.
// Placeholder to maintain module structure for future extraction.
