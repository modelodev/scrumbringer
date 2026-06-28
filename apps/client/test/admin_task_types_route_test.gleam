import gleam/dict
import gleam/option as opt
import lustre/effect
import support/domain_fixtures

import domain/api_error.{ApiError}
import domain/remote.{Loaded}
import domain/task_type.{type TaskType, TaskType}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/task_types_route
import scrumbringer_client/permissions

fn base_model() -> client_state.Model {
  client_state.update_core(client_state.default_model(), fn(core) {
    client_state.CoreModel(
      ..core,
      page: client_state.Admin,
      active_section: permissions.TaskTypes,
      selected_project_id: opt.Some(3),
    )
  })
}

fn task_type(id: Int, name: String) -> TaskType {
  TaskType(..domain_fixtures.task_type(id, name), icon: "box")
}

fn with_member_task_types(
  model: client_state.Model,
  task_types: List(TaskType),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_task_types: Loaded(task_types),
        member_task_types_by_project: dict.from_list([#(3, task_types)]),
      ),
    )
  })
}

fn no_refresh(model: client_state.Model) {
  #(model, effect.none())
}

fn mark_refreshed(model: client_state.Model) {
  #(
    client_state.update_core(model, fn(core) {
      client_state.CoreModel(..core, active_section: permissions.Cards)
    }),
    effect.none(),
  )
}

pub fn try_update_routes_task_types_fetched_test() {
  let bug = task_type(1, "Bug")

  let assert opt.Some(#(next, fx)) =
    task_types_route.try_update(
      base_model(),
      admin_messages.TaskTypesFetched(Ok([bug])),
      no_refresh,
    )

  let assert Loaded([stored]) = next.admin.task_types.task_types
  let assert 1 = stored.id
  let assert "Bug" = stored.name
  let assert True = fx == effect.none()
}

pub fn try_update_runs_refresh_policy_after_created_test() {
  let assert opt.Some(#(next, fx)) =
    task_types_route.try_update(
      base_model(),
      admin_messages.TaskTypeCreated(Ok(task_type(1, "Bug"))),
      mark_refreshed,
    )

  let assert permissions.Cards = next.core.active_section
  let assert opt.None = next.admin.task_types.task_types_dialog_mode
  let assert True = fx != effect.none()
}

pub fn created_task_type_updates_member_create_cache_test() {
  let bug = task_type(1, "Bug")
  let qa = task_type(2, "QA")
  let model = with_member_task_types(base_model(), [bug])

  let assert opt.Some(#(next, _fx)) =
    task_types_route.try_update(
      model,
      admin_messages.TaskTypeCrudCreated(qa),
      no_refresh,
    )

  let assert Loaded([cached_bug, cached_qa]) =
    next.member.pool.member_task_types
  let assert "Bug" = cached_bug.name
  let assert "QA" = cached_qa.name
  let assert Ok([_, by_project_qa]) =
    dict.get(next.member.pool.member_task_types_by_project, 3)
  let assert "QA" = by_project_qa.name
}

pub fn updated_task_type_updates_member_create_cache_test() {
  let bug = task_type(1, "Bug")
  let qa = task_type(2, "QA")
  let model = with_member_task_types(base_model(), [bug, qa])

  let assert opt.Some(#(next, _fx)) =
    task_types_route.try_update(
      model,
      admin_messages.TaskTypeCrudUpdated(task_type(2, "Quality")),
      no_refresh,
    )

  let assert Loaded([_, updated]) = next.member.pool.member_task_types
  let assert "Quality" = updated.name
}

pub fn deleted_task_type_updates_member_create_cache_test() {
  let bug = task_type(1, "Bug")
  let qa = task_type(2, "QA")
  let model = with_member_task_types(base_model(), [bug, qa])

  let assert opt.Some(#(next, _fx)) =
    task_types_route.try_update(
      model,
      admin_messages.TaskTypeCrudDeleted(2),
      no_refresh,
    )

  let assert Loaded([cached]) = next.member.pool.member_task_types
  let assert "Bug" = cached.name
}

pub fn try_update_handles_unauthorized_before_apply_test() {
  let err =
    ApiError(status: 401, code: "UNAUTHORIZED", message: "Sign in again")

  let assert opt.Some(#(next, fx)) =
    task_types_route.try_update(
      base_model(),
      admin_messages.TaskTypesFetched(Error(err)),
      no_refresh,
    )

  let assert client_state.Login = next.core.page
  let assert opt.None = next.core.user
  let assert True = fx == effect.none()
}

pub fn try_update_ignores_non_task_type_messages_test() {
  let assert opt.None =
    task_types_route.try_update(
      base_model(),
      admin_messages.MemberAddDialogOpened,
      no_refresh,
    )
}
