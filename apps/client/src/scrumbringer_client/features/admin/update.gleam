//// Admin feature update handlers.
////
//// ## Mission
////
//// Provides unified access to admin-specific flows: org settings, project
//// members management, and org user search.
////
//// ## Responsibilities
////
//// - Re-export handlers from split modules
//// - Handle members fetch results
////
//// ## Non-responsibilities
////
//// - API calls (see `api/*.gleam`)
//// - User permissions checking (see `permissions.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches admin messages to handlers here
//// - **org_settings.gleam**: Org settings handlers
//// - **member_add.gleam**: Member add dialog handlers
//// - **member_remove.gleam**: Member remove handlers
//// - **search.gleam**: Org users search handlers

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/project.{type ProjectMember}
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Login, Model,
}

// Re-export from split modules
import scrumbringer_client/features/admin/member_add
import scrumbringer_client/features/admin/member_remove
import scrumbringer_client/features/admin/org_settings
import scrumbringer_client/features/admin/search

// =============================================================================
// Re-exports: Org Settings
// =============================================================================

pub const handle_org_users_cache_fetched_ok = org_settings.handle_org_users_cache_fetched_ok

pub const handle_org_users_cache_fetched_error = org_settings.handle_org_users_cache_fetched_error

pub const handle_org_settings_users_fetched_ok = org_settings.handle_org_settings_users_fetched_ok

pub const handle_org_settings_users_fetched_error = org_settings.handle_org_settings_users_fetched_error

pub const handle_org_settings_role_changed = org_settings.handle_org_settings_role_changed

pub const handle_org_settings_save_clicked = org_settings.handle_org_settings_save_clicked

pub const handle_org_settings_saved_ok = org_settings.handle_org_settings_saved_ok

pub const handle_org_settings_saved_error = org_settings.handle_org_settings_saved_error

// =============================================================================
// Re-exports: Member Add
// =============================================================================

pub const handle_member_add_dialog_opened = member_add.handle_member_add_dialog_opened

pub const handle_member_add_dialog_closed = member_add.handle_member_add_dialog_closed

pub const handle_member_add_role_changed = member_add.handle_member_add_role_changed

pub const handle_member_add_user_selected = member_add.handle_member_add_user_selected

pub const handle_member_add_submitted = member_add.handle_member_add_submitted

pub const handle_member_added_ok = member_add.handle_member_added_ok

pub const handle_member_added_error = member_add.handle_member_added_error

// =============================================================================
// Re-exports: Member Remove
// =============================================================================

pub const handle_member_remove_clicked = member_remove.handle_member_remove_clicked

pub const handle_member_remove_cancelled = member_remove.handle_member_remove_cancelled

pub const handle_member_remove_confirmed = member_remove.handle_member_remove_confirmed

pub const handle_member_removed_ok = member_remove.handle_member_removed_ok

pub const handle_member_removed_error = member_remove.handle_member_removed_error

// =============================================================================
// Re-exports: Search
// =============================================================================

pub const handle_org_users_search_changed = search.handle_org_users_search_changed

pub const handle_org_users_search_debounced = search.handle_org_users_search_debounced

pub const handle_org_users_search_results_ok = search.handle_org_users_search_results_ok

pub const handle_org_users_search_results_error = search.handle_org_users_search_results_error

// =============================================================================
// Members Fetched Handlers
// =============================================================================

/// Handle members fetch success.
pub fn handle_members_fetched_ok(
  model: Model,
  members: List(ProjectMember),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, members: Loaded(members)), effect.none())
}

/// Handle members fetch error.
pub fn handle_members_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(Model(..model, members: Failed(err)), effect.none())
  }
}
