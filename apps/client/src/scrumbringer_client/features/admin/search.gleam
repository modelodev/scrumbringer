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

import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, OrgUsersSearchFailed, OrgUsersSearchIdle,
  OrgUsersSearchLoaded, OrgUsersSearchLoading, OrgUsersSearchResults, admin_msg,
  update_admin,
}
import scrumbringer_client/update_helpers

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
  let next_state = case model.admin.org_users_search {
    OrgUsersSearchIdle(_, token) -> OrgUsersSearchIdle(query, token)
    OrgUsersSearchLoading(_, token) -> OrgUsersSearchLoading(query, token)
    OrgUsersSearchLoaded(_, token, results) ->
      OrgUsersSearchLoaded(query, token, results)
    OrgUsersSearchFailed(_, token, err) ->
      OrgUsersSearchFailed(query, token, err)
  }
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, org_users_search: next_state)
    }),
    effect.none(),
  )
}

/// Handle org users search debounced.
/// Generates a new token for this request to detect stale responses.
pub fn handle_org_users_search_debounced(
  model: Model,
  query: String,
) -> #(Model, Effect(Msg)) {
  let current_token = case model.admin.org_users_search {
    OrgUsersSearchIdle(_, token)
    | OrgUsersSearchLoading(_, token)
    | OrgUsersSearchLoaded(_, token, _)
    | OrgUsersSearchFailed(_, token, _) -> token
  }

  case string.trim(query) == "" {
    True -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          org_users_search: OrgUsersSearchIdle(query, current_token),
        )
      }),
      effect.none(),
    )
    False -> {
      // Generate new token for this request
      let token = current_token + 1
      let model =
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_users_search: OrgUsersSearchLoading(query, token),
          )
        })
      // Pass token to API call so it's included in the response message
      #(
        model,
        api_org.list_org_users(query, fn(result) {
          admin_msg(OrgUsersSearchResults(token, result))
        }),
      )
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
  case model.admin.org_users_search {
    OrgUsersSearchLoading(query, current_token) if token == current_token -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          org_users_search: OrgUsersSearchLoaded(query, current_token, users),
        )
      }),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

// Justification: nested case improves clarity for branching logic.
/// Handle org users search results error.
/// Ignores stale responses by checking token.
pub fn handle_org_users_search_results_error(
  model: Model,
  token: Int,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case model.admin.org_users_search {
    OrgUsersSearchLoading(query, current_token) if token == current_token ->
      update_helpers.handle_401_or(model, err, fn() {
        #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              org_users_search: OrgUsersSearchFailed(query, current_token, err),
            )
          }),
          effect.none(),
        )
      })
    _ -> #(model, effect.none())
  }
}
