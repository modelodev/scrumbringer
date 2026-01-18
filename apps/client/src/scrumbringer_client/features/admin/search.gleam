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
//// - Search results handling with stale response protection
////
//// ## Stale Response Protection
////
//// Each search request is assigned a token (incrementing integer).
//// When results arrive, the token is compared with the current expected token.
//// Results with outdated tokens are ignored to prevent stale data display.
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
/// Generates a new token for this request to detect stale responses.
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
      // Generate new token for this request
      let token = model.org_users_search_token + 1
      let model =
        Model(
          ..model,
          org_users_search_results: Loading,
          org_users_search_token: token,
        )
      // Pass token to API call so it's included in the response message
      #(model, api_org.list_org_users(query, fn(result) {
        OrgUsersSearchResults(token, result)
      }))
    }
  }
}

// =============================================================================
// Search Results Handlers
// =============================================================================

/// Handle org users search results success.
/// Ignores stale responses by checking token.
pub fn handle_org_users_search_results_ok(
  model: Model,
  token: Int,
  users: List(OrgUser),
) -> #(Model, Effect(Msg)) {
  // Ignore stale results (token doesn't match current expected token)
  case token == model.org_users_search_token {
    True -> #(Model(..model, org_users_search_results: Loaded(users)), effect.none())
    False -> #(model, effect.none())
  }
}

/// Handle org users search results error.
/// Ignores stale responses by checking token.
pub fn handle_org_users_search_results_error(
  model: Model,
  token: Int,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  // Ignore stale results
  case token == model.org_users_search_token {
    True ->
      case err.status == 401 {
        True -> #(Model(..model, page: Login, user: opt.None), effect.none())
        False -> #(
          Model(..model, org_users_search_results: Failed(err)),
          effect.none(),
        )
      }
    False -> #(model, effect.none())
  }
}
