//// Admin org users search update handlers.
////
//// Handles org users search state for member autocomplete. The admin
//// coordinator owns root model assembly and auth handling.

import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/org.{type OrgUser}
import domain/project.{ProjectMember}
import domain/remote.{Loaded}
import scrumbringer_client/api/org as api_org
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(on_search_results: fn(Int, ApiResult(List(OrgUser))) -> parent_msg)
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_members.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: admin_members.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.OrgUsersSearchChanged(query) ->
      handle_org_users_search_changed(model, query)
      |> without_auth_check

    admin_messages.OrgUsersSearchDebounced(query) ->
      handle_org_users_search_debounced(model, query, context)
      |> without_auth_check

    admin_messages.OrgUsersSearchResults(token, Ok(users)) ->
      handle_org_users_search_results_ok(model, token, users)
      |> without_auth_check

    admin_messages.OrgUsersSearchResults(token, Error(err)) ->
      handle_org_users_search_results_error(model, token, err)
      |> with_auth_check(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck)
}

fn with_auth_check(
  result: #(admin_members.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err))
}

fn with_policy(
  result: #(admin_members.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy))
}

// =============================================================================
// Search Input Handlers
// =============================================================================

fn handle_org_users_search_changed(
  model: admin_members.Model,
  query: String,
) -> #(admin_members.Model, Effect(parent_msg)) {
  let next_state = case model.org_users_search {
    admin_members.OrgUsersSearchIdle(_, token) ->
      admin_members.OrgUsersSearchIdle(query, token)
    admin_members.OrgUsersSearchLoading(_, token) ->
      admin_members.OrgUsersSearchLoading(query, token)
    admin_members.OrgUsersSearchLoaded(_, token, results) ->
      admin_members.OrgUsersSearchLoaded(query, token, results)
    admin_members.OrgUsersSearchFailed(_, token, err) ->
      admin_members.OrgUsersSearchFailed(query, token, err)
  }

  #(admin_members.Model(..model, org_users_search: next_state), effect.none())
}

fn handle_org_users_search_debounced(
  model: admin_members.Model,
  query: String,
  context: Context(parent_msg),
) -> #(admin_members.Model, Effect(parent_msg)) {
  let current_token = current_search_token(model.org_users_search)

  case string.trim(query) == "" {
    True -> #(
      admin_members.Model(
        ..model,
        org_users_search: admin_members.OrgUsersSearchIdle(query, current_token),
      ),
      effect.none(),
    )
    False -> {
      let token = current_token + 1
      let model =
        admin_members.Model(
          ..model,
          org_users_search: admin_members.OrgUsersSearchLoading(query, token),
        )

      #(
        model,
        api_org.list_org_users(query, fn(result) {
          context.on_search_results(token, result)
        }),
      )
    }
  }
}

fn current_search_token(search: admin_members.OrgUsersSearchState) -> Int {
  case search {
    admin_members.OrgUsersSearchIdle(_, token)
    | admin_members.OrgUsersSearchLoading(_, token)
    | admin_members.OrgUsersSearchLoaded(_, token, _)
    | admin_members.OrgUsersSearchFailed(_, token, _) -> token
  }
}

// =============================================================================
// Search Results Handlers
// =============================================================================

fn handle_org_users_search_results_ok(
  model: admin_members.Model,
  token: Int,
  users: List(OrgUser),
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.org_users_search {
    admin_members.OrgUsersSearchLoading(query, current_token)
      if token == current_token
    -> {
      let selected_user = exact_non_member_match(model, query, users)

      #(
        admin_members.Model(
          ..model,
          org_users_search: admin_members.OrgUsersSearchLoaded(
            query,
            current_token,
            users,
          ),
          members_add_selected_user: selected_user,
        ),
        effect.none(),
      )
    }
    _ -> #(model, effect.none())
  }
}

fn exact_non_member_match(
  model: admin_members.Model,
  query: String,
  users: List(OrgUser),
) -> opt.Option(OrgUser) {
  let normalized_query = string.lowercase(string.trim(query))

  case normalized_query == "" {
    True -> opt.None
    False ->
      case
        list.find(users, fn(user) {
          string.lowercase(user.email) == normalized_query
          && !is_already_project_member(model, user.id)
        })
      {
        Ok(user) -> opt.Some(user)
        Error(_) -> opt.None
      }
  }
}

fn is_already_project_member(model: admin_members.Model, user_id: Int) -> Bool {
  case model.members {
    Loaded(members) ->
      list.any(members, fn(member) {
        let ProjectMember(user_id: member_user_id, ..) = member
        member_user_id == user_id
      })
    _ -> False
  }
}

fn handle_org_users_search_results_error(
  model: admin_members.Model,
  token: Int,
  err: ApiError,
) -> #(admin_members.Model, Effect(parent_msg)) {
  case model.org_users_search {
    admin_members.OrgUsersSearchLoading(query, current_token)
      if token == current_token
    -> #(
      admin_members.Model(
        ..model,
        org_users_search: admin_members.OrgUsersSearchFailed(
          query,
          current_token,
          err,
        ),
      ),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}
