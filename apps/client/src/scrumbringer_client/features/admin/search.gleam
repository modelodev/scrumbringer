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
  type Model, type Msg, admin_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages

// API modules
import scrumbringer_client/api/org as api_org
import scrumbringer_client/helpers/auth as helpers_auth

// =============================================================================
// Search Input Handlers
// =============================================================================

/// Handle org users search input change.
pub fn handle_org_users_search_changed(
  model: Model,
  query: String,
) -> #(Model, Effect(Msg)) {
  let next_state = case model.admin.members.org_users_search {
    state_types.OrgUsersSearchIdle(_, token) ->
      state_types.OrgUsersSearchIdle(query, token)
    state_types.OrgUsersSearchLoading(_, token) ->
      state_types.OrgUsersSearchLoading(query, token)
    state_types.OrgUsersSearchLoaded(_, token, results) ->
      state_types.OrgUsersSearchLoaded(query, token, results)
    state_types.OrgUsersSearchFailed(_, token, err) ->
      state_types.OrgUsersSearchFailed(query, token, err)
  }
  #(
    update_admin(model, fn(admin) {
      update_members(admin, fn(members_state) {
        admin_members.Model(..members_state, org_users_search: next_state)
      })
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
  let current_token = case model.admin.members.org_users_search {
    state_types.OrgUsersSearchIdle(_, token)
    | state_types.OrgUsersSearchLoading(_, token)
    | state_types.OrgUsersSearchLoaded(_, token, _)
    | state_types.OrgUsersSearchFailed(_, token, _) -> token
  }

  case string.trim(query) == "" {
    True -> #(
      update_admin(model, fn(admin) {
        update_members(admin, fn(members_state) {
          admin_members.Model(
            ..members_state,
            org_users_search: state_types.OrgUsersSearchIdle(
              query,
              current_token,
            ),
          )
        })
      }),
      effect.none(),
    )
    False -> {
      // Generate new token for this request
      let token = current_token + 1
      let model =
        update_admin(model, fn(admin) {
          update_members(admin, fn(members_state) {
            admin_members.Model(
              ..members_state,
              org_users_search: state_types.OrgUsersSearchLoading(query, token),
            )
          })
        })
      // Pass token to API call so it's included in the response message
      #(
        model,
        api_org.list_org_users(query, fn(result) {
          admin_msg(admin_messages.OrgUsersSearchResults(token, result))
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
  case model.admin.members.org_users_search {
    state_types.OrgUsersSearchLoading(query, current_token)
      if token == current_token
    -> #(
      update_admin(model, fn(admin) {
        update_members(admin, fn(members_state) {
          admin_members.Model(
            ..members_state,
            org_users_search: state_types.OrgUsersSearchLoaded(
              query,
              current_token,
              users,
            ),
          )
        })
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
  case model.admin.members.org_users_search {
    state_types.OrgUsersSearchLoading(query, current_token)
      if token == current_token
    ->
      helpers_auth.handle_401_or(model, err, fn() {
        #(
          update_admin(model, fn(admin) {
            update_members(admin, fn(members_state) {
              admin_members.Model(
                ..members_state,
                org_users_search: state_types.OrgUsersSearchFailed(
                  query,
                  current_token,
                  err,
                ),
              )
            })
          }),
          effect.none(),
        )
      })
    _ -> #(model, effect.none())
  }
}

fn update_members(
  admin: admin_state.AdminModel,
  f: fn(admin_members.Model) -> admin_members.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, members: f(admin.members))
}
