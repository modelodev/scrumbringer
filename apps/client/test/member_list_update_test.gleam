import gleam/option
import lustre/effect
import support/domain_fixtures

import domain/api_error.{ApiError}
import domain/project.{type ProjectMember}
import domain/remote
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/features/admin/member_list
import scrumbringer_client/features/admin/msg as admin_messages

fn context(selected_project_id) -> member_list.Context(Nil) {
  member_list.Context(
    selected_project_id: selected_project_id,
    on_member_capabilities_fetched: fn(_result) { Nil },
  )
}

fn sample_member(user_id: Int) -> ProjectMember {
  domain_fixtures.project_member(user_id)
}

pub fn members_fetched_ok_loads_members_and_preloads_capabilities_test() {
  let members = [sample_member(7), sample_member(8)]

  let assert option.Some(member_list.Update(next, fx, member_list.NoAuthCheck)) =
    member_list.try_update(
      admin_members.default_model(),
      admin_messages.MembersFetched(Ok(members)),
      context(option.Some(3)),
    )

  let assert True = next.members == remote.Loaded(members)
  let assert False = fx == effect.none()
}

pub fn members_fetched_ok_without_project_does_not_preload_test() {
  let members = [sample_member(7)]

  let assert option.Some(member_list.Update(next, fx, member_list.NoAuthCheck)) =
    member_list.try_update(
      admin_members.default_model(),
      admin_messages.MembersFetched(Ok(members)),
      context(option.None),
    )

  let assert True = next.members == remote.Loaded(members)
  let assert True = fx == effect.none()
}

pub fn members_fetched_error_sets_failed_remote_test() {
  let err = ApiError(status: 500, code: "DB", message: "Database error")

  let assert option.Some(member_list.Update(
    next,
    fx,
    member_list.CheckAuth(auth_err),
  )) =
    member_list.try_update(
      admin_members.default_model(),
      admin_messages.MembersFetched(Error(err)),
      context(option.Some(3)),
    )

  let assert True = next.members == remote.Failed(err)
  let assert True = auth_err == err
  let assert True = fx == effect.none()
}

pub fn try_update_members_fetched_ok_returns_local_update_test() {
  let members = [sample_member(7), sample_member(8)]

  let assert option.Some(member_list.Update(next, fx, member_list.NoAuthCheck)) =
    member_list.try_update(
      admin_members.default_model(),
      admin_messages.MembersFetched(Ok(members)),
      context(option.Some(3)),
    )

  let assert True = next.members == remote.Loaded(members)
  let assert False = fx == effect.none()
}

pub fn try_update_members_fetched_error_returns_auth_policy_test() {
  let err = ApiError(status: 401, code: "UNAUTHORIZED", message: "auth")

  let assert option.Some(member_list.Update(
    next,
    fx,
    member_list.CheckAuth(auth_err),
  )) =
    member_list.try_update(
      admin_members.default_model(),
      admin_messages.MembersFetched(Error(err)),
      context(option.Some(3)),
    )

  let assert True = next.members == remote.Failed(err)
  let assert True = auth_err == err
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_member_list_messages_test() {
  let assert option.None =
    member_list.try_update(
      admin_members.default_model(),
      admin_messages.InviteCreateDialogOpened,
      context(option.Some(3)),
    )
}
