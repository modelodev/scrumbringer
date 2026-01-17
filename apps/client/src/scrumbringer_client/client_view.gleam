//// View functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides all view rendering functions for the Lustre SPA. Pure functions
//// that transform Model state into Element(Msg) trees.
////
//// ## Current Status
////
//// This module documents the planned view extraction. The actual view function
//// (~3400 lines, 70 functions) remains in `scrumbringer_client.gleam` pending
//// incremental extraction.
////
//// ## Extraction Progress
////
//// Views ready to extract (auth pages):
//// - view_login (~52 lines)
//// - view_forgot_password (~68 lines)
//// - view_accept_invite (~53 lines)
//// - view_reset_password (~53 lines)
////
//// Views needing split (>100 lines):
//// - view_member_notes (221 lines)
//// - view_member_task_card (204 lines)
//// - view_member_filters (173 lines)
//// - view_member_bar_task_row (131 lines)
//// - view_member_create_dialog (116 lines)
////
//// ## Planned Structure
////
//// Future refactoring will organize views by domain:
//// - `view/auth.gleam`: login, forgot password, accept invite, reset password
//// - `view/admin.gleam`: admin dashboard, nav, section routing
//// - `view/admin_sections.gleam`: projects, members, capabilities, invites, etc.
//// - `view/member.gleam`: member dashboard, pool, tasks, skills
//// - `view/shared.gleam`: toast, topbar, theme/locale switches
////
//// ## Challenges
////
//// Extraction requires careful handling of:
//// - 60+ Msg constructors used in event handlers
//// - Model field access patterns
//// - Correct i18n text values (e.g., `Logout` not `LogOut`)
//// - Theme values (`Default`/`Dark` not `Light`/`Dark`)
////
//// ## Dependencies
////
//// When fully extracted, client_view will need:
//// - `client_state`: Model, Msg, Page, Remote types
//// - `update_helpers`: i18n_t, active_projects, selected_project
//// - `styles`, `theme`: styling
//// - `router`: URL generation
//// - `i18n/text`: translation keys
////
//// ## Usage (future)
////
//// ```gleam
//// import scrumbringer_client/client_view
////
//// // In lustre.application
//// lustre.application(init, update, client_view.view)
//// ```

// =============================================================================
// Placeholder - actual view lives in scrumbringer_client.gleam
// =============================================================================
//
// To complete extraction:
// 1. Move view functions one domain at a time
// 2. Fix Msg constructor imports for each batch
// 3. Verify i18n text keys match actual values
// 4. Run tests after each batch
// 5. Update main to import and use client_view.view
