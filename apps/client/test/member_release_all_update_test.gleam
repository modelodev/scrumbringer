import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{ProjectMember}
import domain/project_role
import domain/remote.{Loaded}
import gleam/int
import gleam/option
import lustre/effect

import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/member_release_all
import scrumbringer_client/features/admin/msg as admin_messages

fn feedback_context() -> member_release_all.FeedbackContext(String) {
  member_release_all.FeedbackContext(
    not_permitted: "Not permitted",
    release_all_self_error: "Cannot release your own tasks",
    release_all_none: fn(user_name) { user_name <> " has no tasks" },
    release_all_success: fn(released_count, user_name) {
      user_name <> " released " <> int.to_string(released_count)
    },
    release_all_error: fn(user_name) { "Could not release " <> user_name },
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
    on_warning_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn context() -> member_release_all.Context(String) {
  member_release_all.Context(
    selected_project_id: option.Some(3),
    on_member_release_all_result: fn(_) { "release-all-result" },
  )
}

fn update(model: admin_members.Model, msg: admin_messages.Msg) {
  member_release_all.try_update(model, msg, context(), feedback_context())
}

fn update_with_context(
  model: admin_members.Model,
  msg: admin_messages.Msg,
  context: member_release_all.Context(String),
) {
  member_release_all.try_update(model, msg, context, feedback_context())
}

fn no_project_context() -> member_release_all.Context(String) {
  member_release_all.Context(
    selected_project_id: option.None,
    on_member_release_all_result: fn(_) { "release-all-result" },
  )
}

fn sample_user(id: Int, email: String) -> OrgUser {
  OrgUser(
    id: id,
    email: email,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn sample_member(user_id: Int, claimed_count: Int) {
  ProjectMember(
    user_id: user_id,
    role: project_role.Member,
    created_at: "2026-01-01T00:00:00Z",
    claimed_count: claimed_count,
  )
}

pub fn try_update_release_all_click_uses_cached_org_user_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_cache: Loaded([sample_user(9, "qa@example.com")]),
    )

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.NoAuthCheck,
  )) = update(model, admin_messages.MemberReleaseAllClicked(9, 3))

  let assert option.Some(admin_members.ReleaseAllTarget(user, 3)) =
    next.members_release_confirm
  let assert 9 = user.id
  let assert "qa@example.com" = user.email
  let assert option.None = next.members_release_error
  let assert True = fx == effect.none()
}

pub fn try_update_release_all_click_falls_back_when_user_cache_missing_test() {
  let assert option.Some(member_release_all.Update(
    next,
    _fx,
    member_release_all.NoAuthCheck,
  )) =
    update(
      admin_members.default_model(),
      admin_messages.MemberReleaseAllClicked(42, 5),
    )

  let assert option.Some(admin_members.ReleaseAllTarget(user, 5)) =
    next.members_release_confirm
  let assert 42 = user.id
  let assert "User #42" = user.email
}

pub fn try_update_release_all_cancel_clears_confirmation_and_error_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 3,
      )),
      members_release_error: option.Some("old error"),
    )

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.NoAuthCheck,
  )) = update(model, admin_messages.MemberReleaseAllCancelled)

  let assert option.None = next.members_release_confirm
  let assert option.None = next.members_release_error
  let assert True = fx == effect.none()
}

pub fn try_update_release_all_confirm_without_project_is_noop_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 3,
      )),
    )

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.NoAuthCheck,
  )) =
    update_with_context(
      model,
      admin_messages.MemberReleaseAllConfirmed,
      no_project_context(),
    )

  let assert option.None = next.members_release_in_flight
  let assert True = fx == effect.none()
}

pub fn try_update_release_all_success_resets_claimed_count_for_target_user_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members: Loaded([sample_member(9, 4), sample_member(10, 2)]),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 4,
      )),
      members_release_in_flight: option.Some(9),
      members_release_error: option.Some("old error"),
    )
  let result =
    api_projects.ReleaseAllResult(released_count: 4, task_ids: [1, 2, 3, 4])

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.NoAuthCheck,
  )) = update(model, admin_messages.MemberReleaseAllResult(Ok(result)))

  let assert Loaded(members) = next.members
  let assert [released_member, other_member] = members
  let assert 0 = released_member.claimed_count
  let assert 2 = other_member.claimed_count
  let assert option.None = next.members_release_confirm
  let assert option.None = next.members_release_in_flight
  let assert option.None = next.members_release_error
  let assert True = fx != effect.none()
}

pub fn try_update_release_all_error_sets_local_message_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_in_flight: option.Some(9),
    )
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.CheckAuth(auth_err),
  )) = update(model, admin_messages.MemberReleaseAllResult(Error(err)))

  let assert option.None = next.members_release_in_flight
  let assert option.Some("Not permitted") = next.members_release_error
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn try_update_release_all_self_release_error_uses_local_message_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 4,
      )),
      members_release_in_flight: option.Some(9),
    )
  let err = ApiError(status: 409, code: "SELF_RELEASE", message: "backend")

  let assert option.Some(member_release_all.Update(
    next,
    _fx,
    member_release_all.CheckAuth(auth_err),
  )) = update(model, admin_messages.MemberReleaseAllResult(Error(err)))

  let assert option.Some("Cannot release your own tasks") =
    next.members_release_error
  let assert True = auth_err == err
}

pub fn try_update_release_all_not_found_error_uses_backend_message_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 4,
      )),
      members_release_in_flight: option.Some(9),
    )
  let err = ApiError(status: 404, code: "NOT_FOUND", message: "No member")

  let assert option.Some(member_release_all.Update(
    next,
    _fx,
    member_release_all.CheckAuth(auth_err),
  )) = update(model, admin_messages.MemberReleaseAllResult(Error(err)))

  let assert option.Some("No member") = next.members_release_error
  let assert True = auth_err == err
}

pub fn try_update_release_all_generic_error_includes_target_user_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 4,
      )),
      members_release_in_flight: option.Some(9),
    )
  let err = ApiError(status: 500, code: "ERR", message: "backend")

  let assert option.Some(member_release_all.Update(
    next,
    _fx,
    member_release_all.CheckAuth(auth_err),
  )) = update(model, admin_messages.MemberReleaseAllResult(Error(err)))

  let assert option.Some("Could not release qa@example.com") =
    next.members_release_error
  let assert True = auth_err == err
}

pub fn try_update_release_all_clicked_returns_local_update_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      org_users_cache: Loaded([sample_user(9, "qa@example.com")]),
    )

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.NoAuthCheck,
  )) =
    member_release_all.try_update(
      model,
      admin_messages.MemberReleaseAllClicked(9, 3),
      context(),
      feedback_context(),
    )

  let assert option.Some(admin_members.ReleaseAllTarget(user, 3)) =
    next.members_release_confirm
  let assert 9 = user.id
  let assert True = fx == effect.none()
}

pub fn try_update_release_all_confirmed_sets_in_flight_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 3,
      )),
    )

  let assert option.Some(member_release_all.Update(
    next,
    _fx,
    member_release_all.NoAuthCheck,
  )) =
    member_release_all.try_update(
      model,
      admin_messages.MemberReleaseAllConfirmed,
      context(),
      feedback_context(),
    )

  let assert option.Some(9) = next.members_release_in_flight
  let assert option.None = next.members_release_error
}

pub fn try_update_release_all_ok_updates_local_member_test() {
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members: Loaded([sample_member(9, 4), sample_member(10, 2)]),
      members_release_confirm: option.Some(admin_members.ReleaseAllTarget(
        user: sample_user(9, "qa@example.com"),
        claimed_count: 4,
      )),
      members_release_in_flight: option.Some(9),
    )
  let result =
    api_projects.ReleaseAllResult(released_count: 4, task_ids: [1, 2, 3, 4])

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.NoAuthCheck,
  )) =
    member_release_all.try_update(
      model,
      admin_messages.MemberReleaseAllResult(Ok(result)),
      context(),
      feedback_context(),
    )

  let assert Loaded([released_member, other_member]) = next.members
  let assert 0 = released_member.claimed_count
  let assert 2 = other_member.claimed_count
  let assert option.None = next.members_release_confirm
  let assert True = fx != effect.none()
}

pub fn try_update_release_all_error_returns_auth_policy_test() {
  let err = ApiError(status: 403, code: "FORBIDDEN", message: "backend")
  let model =
    admin_members.Model(
      ..admin_members.default_model(),
      members_release_in_flight: option.Some(9),
    )

  let assert option.Some(member_release_all.Update(
    next,
    fx,
    member_release_all.CheckAuth(auth_err),
  )) =
    member_release_all.try_update(
      model,
      admin_messages.MemberReleaseAllResult(Error(err)),
      context(),
      feedback_context(),
    )

  let assert option.None = next.members_release_in_flight
  let assert option.Some("Not permitted") = next.members_release_error
  let assert True = auth_err == err
  let assert True = fx != effect.none()
}

pub fn try_update_ignores_non_release_all_messages_test() {
  let assert option.None =
    member_release_all.try_update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
      context(),
      feedback_context(),
    )
}
