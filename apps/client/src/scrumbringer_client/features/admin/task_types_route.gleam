//// Root adapter for task type admin messages.

import gleam/dict
import gleam/list
import gleam/option as opt

import lustre/effect

import domain/api_error.{type ApiError}
import domain/remote.{Loaded}
import domain/task_type.{type TaskType}
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/route_support
import scrumbringer_client/features/task_types/update as task_types_update
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

pub fn try_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> opt.Option(#(client_state.Model, effect.Effect(client_state.Msg))) {
  case
    task_types_update.try_update(
      model.admin.task_types,
      inner,
      context(model),
      feedback_context(model),
      error_feedback_context(model),
    )
  {
    opt.Some(update) ->
      opt.Some(apply_update(model, inner, update, refresh_section))
    opt.None -> opt.None
  }
}

fn apply_update(
  model: client_state.Model,
  inner: admin_messages.Msg,
  update: task_types_update.Update(client_state.Msg),
  refresh_section: fn(client_state.Model) ->
    #(client_state.Model, effect.Effect(client_state.Msg)),
) -> #(client_state.Model, effect.Effect(client_state.Msg)) {
  let task_types_update.Update(
    task_types,
    local_fx,
    auth_policy,
    refresh_policy,
  ) = update

  route_support.apply_auth_check(
    model,
    route_support.auth_check_before(auth_error(auth_policy)),
    fn() {
      let model =
        client_state.update_admin(model, fn(admin) {
          update_task_types(admin, fn(_) { task_types })
        })
        |> sync_member_task_types(inner)
      let #(model, refresh_fx) = case refresh_policy {
        task_types_update.NoRefresh -> #(model, effect.none())
        task_types_update.RefreshSection -> refresh_section(model)
      }
      #(model, effect.batch([local_fx, refresh_fx]))
    },
  )
}

fn sync_member_task_types(
  model: client_state.Model,
  inner: admin_messages.Msg,
) -> client_state.Model {
  case model.core.selected_project_id {
    opt.None -> model
    opt.Some(project_id) ->
      case inner {
        admin_messages.TaskTypeCreated(Ok(task_type))
        | admin_messages.TaskTypeCrudCreated(task_type) ->
          update_member_task_types(model, project_id, fn(task_types) {
            upsert_task_type(task_types, task_type)
          })

        admin_messages.TaskTypeCrudUpdated(task_type) ->
          update_member_task_types(model, project_id, fn(task_types) {
            replace_task_type(task_types, task_type)
          })

        admin_messages.TaskTypeCrudDeleted(type_id) ->
          update_member_task_types(model, project_id, fn(task_types) {
            list.filter(task_types, fn(task_type) { task_type.id != type_id })
          })

        _ -> model
      }
  }
}

fn update_member_task_types(
  model: client_state.Model,
  project_id: Int,
  f: fn(List(TaskType)) -> List(TaskType),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    let current_task_types = task_types_for_project(pool, project_id)
    let next_task_types = f(current_task_types)

    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_task_types: case pool.member_task_types {
          Loaded(_) -> Loaded(next_task_types)
          other -> other
        },
        member_task_types_by_project: dict.insert(
          pool.member_task_types_by_project,
          project_id,
          next_task_types,
        ),
      ),
    )
  })
}

fn task_types_for_project(
  pool: member_pool.Model,
  project_id: Int,
) -> List(TaskType) {
  case dict.get(pool.member_task_types_by_project, project_id) {
    Ok(task_types) -> task_types
    Error(_) ->
      case pool.member_task_types {
        Loaded(task_types) -> task_types
        _ -> []
      }
  }
}

fn upsert_task_type(
  task_types: List(TaskType),
  task_type: TaskType,
) -> List(TaskType) {
  case list.any(task_types, fn(existing) { existing.id == task_type.id }) {
    True -> replace_task_type(task_types, task_type)
    False -> list.append(task_types, [task_type])
  }
}

fn replace_task_type(
  task_types: List(TaskType),
  task_type: TaskType,
) -> List(TaskType) {
  list.map(task_types, fn(existing) {
    case existing.id == task_type.id {
      True -> task_type
      False -> existing
    }
  })
}

fn auth_error(policy: task_types_update.AuthPolicy) -> opt.Option(ApiError) {
  case policy {
    task_types_update.NoAuthCheck -> opt.None
    task_types_update.CheckAuth(err) -> opt.Some(err)
  }
}

fn update_task_types(
  admin: admin_state.AdminModel,
  f: fn(admin_task_types.Model) -> admin_task_types.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, task_types: f(admin.task_types))
}

fn context(
  model: client_state.Model,
) -> task_types_update.Context(client_state.Msg) {
  task_types_update.Context(
    selected_project_id: model.core.selected_project_id,
    on_task_type_created: fn(result) {
      client_state.admin_msg(admin_messages.TaskTypeCreated(result))
    },
    select_project_first: i18n.t(model.ui.locale, i18n_text.SelectProjectFirst),
    name_and_icon_required: i18n.t(
      model.ui.locale,
      i18n_text.NameAndIconRequired,
    ),
  )
}

fn feedback_context(
  model: client_state.Model,
) -> task_types_update.FeedbackContext(client_state.Msg) {
  task_types_update.FeedbackContext(
    task_type_created: i18n.t(model.ui.locale, i18n_text.TaskTypeCreated),
    task_type_updated: i18n.t(model.ui.locale, i18n_text.TaskTypeUpdated),
    task_type_deleted: i18n.t(model.ui.locale, i18n_text.TaskTypeDeleted),
    on_success_toast: app_effects.toast_success,
  )
}

fn error_feedback_context(
  model: client_state.Model,
) -> task_types_update.ErrorFeedbackContext(client_state.Msg) {
  task_types_update.ErrorFeedbackContext(
    not_permitted: i18n.t(model.ui.locale, i18n_text.NotPermitted),
    on_warning_toast: app_effects.toast_warning,
  )
}
