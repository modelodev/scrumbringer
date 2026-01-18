//// Admin org users search update handlers.
////
//// ## Mission
////
//// Handles org users search flows for member autocomplete.
////
//// ## Responsibilities
////
//// - Search query input handling
//// - Debounced search execution
//// - Search results handling
////
//// ## Relations
////
//// - **update.gleam**: Main update module that delegates to handlers here
//// - **member_add.gleam**: Uses search results for user selection

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, Login, Model, NotAsked,
  OrgUsersSearchResults,
}

// API modules
import scrumbringer_client/api/org as api_org

// =============================================================================
// Search Input Handlers
// =============================================================================

/// Handle org users search input change.
pub fn handle_org_users_search_changed(
  model: Model,
  query: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, org_users_search_query: query), effect.none())
}

/// Handle org users search debounced.
pub fn handle_org_users_search_debounced(
  model: Model,
  query: String,
) -> #(Model, Effect(Msg)) {
  case string.trim(query) == "" {
    True -> #(
      Model(..model, org_users_search_results: NotAsked),
      effect.none(),
    )
    False -> {
      let model = Model(..model, org_users_search_results: Loading)
      #(model, api_org.list_org_users(query, OrgUsersSearchResults))
    }
  }
}

// =============================================================================
// Search Results Handlers
// =============================================================================

/// Handle org users search results success.
pub fn handle_org_users_search_results_ok(
  model: Model,
  users: List(OrgUser),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, org_users_search_results: Loaded(users)), effect.none())
}

/// Handle org users search results error.
pub fn handle_org_users_search_results_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> #(Model(..model, page: Login, user: opt.None), effect.none())
    False -> #(
      Model(..model, org_users_search_results: Failed(err)),
      effect.none(),
    )
  }
}
