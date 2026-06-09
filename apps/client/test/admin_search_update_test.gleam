import gleam/option

import lustre/effect

import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{ProjectMember}
import domain/project_role
import domain/remote
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/search

fn user(id: Int, email: String) -> OrgUser {
  OrgUser(
    id: id,
    email: email,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn context() -> search.Context(Nil) {
  search.Context(on_search_results: fn(_token, _result) { Nil })
}

fn try_context() -> search.Context(String) {
  search.Context(on_search_results: fn(_token, _result) { "search-results" })
}

pub fn search_changed_preserves_token_and_results_test() {
  let existing = [user(1, "old@example.com")]
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoaded("old", 4, existing),
    )

  let #(next, fx) = search.handle_org_users_search_changed(model, "new")

  let assert True =
    next.org_users_search
    == state_types.OrgUsersSearchLoaded("new", 4, existing)
  let assert True = fx == effect.none()
}

pub fn debounced_blank_query_returns_idle_without_effect_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoading("old", 3),
    )

  let #(next, fx) =
    search.handle_org_users_search_debounced(model, "  ", context())

  let assert state_types.OrgUsersSearchIdle("  ", 3) = next.org_users_search
  let assert True = fx == effect.none()
}

pub fn debounced_query_sets_loading_with_next_token_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchIdle("", 3),
    )

  let #(next, _fx) =
    search.handle_org_users_search_debounced(model, "qa", context())

  let assert state_types.OrgUsersSearchLoading("qa", 4) = next.org_users_search
}

pub fn stale_success_response_is_ignored_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoading("qa@example.com", 2),
    )

  let #(next, fx) =
    search.handle_org_users_search_results_ok(model, 1, [
      user(9, "qa@example.com"),
    ])

  let assert True = next == model
  let assert True = fx == effect.none()
}

pub fn exact_match_selects_user_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoading("qa@example.com", 2),
    )

  let #(next, fx) =
    search.handle_org_users_search_results_ok(model, 2, [
      user(9, "qa@example.com"),
    ])

  let assert option.Some(selected) = next.members_add_selected_user
  let assert 9 = selected.id
  let assert True = fx == effect.none()
}

pub fn matching_existing_member_is_not_auto_selected_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members: remote.Loaded([
        ProjectMember(
          user_id: 9,
          role: project_role.Member,
          created_at: "2026-01-01T00:00:00Z",
          claimed_count: 0,
        ),
      ]),
      org_users_search: state_types.OrgUsersSearchLoading("qa@example.com", 2),
    )

  let #(next, fx) =
    search.handle_org_users_search_results_ok(model, 2, [
      user(9, "qa@example.com"),
    ])

  let assert option.None = next.members_add_selected_user
  let assert True = fx == effect.none()
}

pub fn current_error_response_sets_failed_state_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoading("qa", 2),
    )
  let err = ApiError(status: 500, code: "ERR", message: "Search failed")

  let #(next, fx) = search.handle_org_users_search_results_error(model, 2, err)

  let assert True =
    next.org_users_search == state_types.OrgUsersSearchFailed("qa", 2, err)
  let assert True = fx == effect.none()
}

pub fn try_update_search_changed_returns_local_update_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchIdle("", 3),
    )

  let assert option.Some(search.Update(next, fx, search.NoAuthCheck)) =
    search.try_update(
      model,
      admin_messages.OrgUsersSearchChanged("qa"),
      try_context(),
    )

  let assert state_types.OrgUsersSearchIdle("qa", 3) = next.org_users_search
  let assert True = fx == effect.none()
}

pub fn try_update_search_results_ok_returns_local_update_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoading("qa@example.com", 2),
    )

  let assert option.Some(search.Update(next, fx, search.NoAuthCheck)) =
    search.try_update(
      model,
      admin_messages.OrgUsersSearchResults(
        2,
        Ok([
          user(9, "qa@example.com"),
        ]),
      ),
      try_context(),
    )

  let assert state_types.OrgUsersSearchLoaded(_, 2, [_]) = next.org_users_search
  let assert option.Some(selected) = next.members_add_selected_user
  let assert 9 = selected.id
  let assert True = fx == effect.none()
}

pub fn try_update_search_results_error_returns_auth_policy_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "auth")
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_search: state_types.OrgUsersSearchLoading("qa", 2),
    )

  let assert option.Some(search.Update(next, fx, search.CheckAuth(auth_err))) =
    search.try_update(
      model,
      admin_messages.OrgUsersSearchResults(2, Error(err)),
      try_context(),
    )

  let assert state_types.OrgUsersSearchFailed("qa", 2, _) =
    next.org_users_search
  let assert True = auth_err == err
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_search_messages_test() {
  let assert option.None =
    search.try_update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
      try_context(),
    )
}
