//// Task detail workflow for the member pool.

import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/note/entity as note_entity
import domain/remote.{Failed, Loaded}
import domain/task.{type Task, type TaskDependency}
import scrumbringer_client/api/activity as activity_api
import scrumbringer_client/api/tasks/dependencies as task_dependencies_api
import scrumbringer_client/api/tasks/notes as task_notes_api
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/detail_edit_form
import scrumbringer_client/features/tasks/detail_state
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/ui/show_tabs
import scrumbringer_client/ui/toast

pub type EditContext(parent_msg) {
  EditContext(
    current_task: opt.Option(Task),
    can_edit: Bool,
    on_task_updated: fn(ApiResult(Task)) -> parent_msg,
    title_required: String,
    title_too_long_max_56: String,
    type_required: String,
    priority_must_be_1_to_5: String,
  )
}

pub type Model {
  Model(
    pool: member_pool.Model,
    notes: member_notes.Model,
    dependencies: member_dependencies.Model,
  )
}

pub type Context(parent_msg) {
  Context(
    on_notes_fetched: fn(ApiResult(List(note_entity.Note))) -> parent_msg,
    on_dependencies_fetched: fn(ApiResult(List(TaskDependency))) -> parent_msg,
    on_activity_fetched: fn(ApiResult(activity_api.ActivityPage)) -> parent_msg,
  )
}

pub type DispatchContext(parent_msg) {
  DispatchContext(
    open_context: Context(parent_msg),
    edit_context: EditContext(parent_msg),
    success_context: SuccessContext(parent_msg),
    error_context: ErrorContext(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuthAfter(ApiError)
}

pub type Update(parent_msg) {
  Update(Model, Effect(parent_msg), AuthPolicy)
}

pub type SuccessContext(parent_msg) {
  SuccessContext(
    task_updated: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorContext(parent_msg) {
  ErrorContext(
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub fn try_update(
  model: Model,
  inner: pool_messages.Msg,
  context: DispatchContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberTaskDetailsOpened(task_id) ->
      handle_task_details_opened(model, task_id, context.open_context)
      |> without_auth_check

    pool_messages.MemberTaskDetailsClosed ->
      handle_task_details_closed(model)
      |> without_auth_check

    pool_messages.MemberTaskDetailTabClicked(tab) ->
      handle_task_detail_tab_clicked(model.pool, tab)
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditStarted ->
      handle_task_detail_edit_started(
        model.pool,
        context.edit_context.current_task,
        context.edit_context.can_edit,
      )
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditCancelled ->
      handle_task_detail_edit_cancelled(
        model.pool,
        context.edit_context.current_task,
      )
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditTitleChanged(value) ->
      handle_task_detail_edit_title_changed(model.pool, value)
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditDescriptionChanged(value) ->
      handle_task_detail_edit_description_changed(model.pool, value)
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditPriorityChanged(value) ->
      handle_task_detail_edit_priority_changed(model.pool, value)
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditTypeIdChanged(value) ->
      handle_task_detail_edit_type_id_changed(model.pool, value)
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditCardIdChanged(value) ->
      handle_task_detail_edit_card_id_changed(model.pool, value)
      |> pool_result(model)

    pool_messages.MemberTaskDetailEditSubmitted ->
      handle_task_detail_edit_submitted(model.pool, context.edit_context)
      |> pool_result(model)

    pool_messages.MemberActivityMoreClicked ->
      handle_activity_more_clicked(model, context.open_context)
      |> without_auth_check

    pool_messages.MemberTaskUpdated(Ok(task)) ->
      updated_ok(model.pool, task, context.success_context)
      |> pool_result(model)

    pool_messages.MemberTaskUpdated(Error(err)) ->
      updated_error(model.pool, err, context.error_context)
      |> pool_result_after_auth(model, err)

    pool_messages.MemberActivityFetched(Ok(page)) ->
      #(
        Model(..model, notes: activity_loaded(model.notes, page)),
        effect.none(),
      )
      |> without_auth_check

    pool_messages.MemberActivityFetched(Error(err)) ->
      #(Model(..model, notes: activity_failed(model.notes, err)), effect.none())
      |> model_result_after_auth(err)

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, NoAuthCheck))
}

fn model_result_after_auth(
  result: #(Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, CheckAuthAfter(err)))
}

fn pool_result(
  result: #(member_pool.Model, Effect(parent_msg)),
  model: Model,
) -> opt.Option(Update(parent_msg)) {
  let #(pool, fx) = result
  opt.Some(Update(Model(..model, pool: pool), fx, NoAuthCheck))
}

fn pool_result_after_auth(
  result: #(member_pool.Model, Effect(parent_msg)),
  model: Model,
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  let #(pool, fx) = result
  opt.Some(Update(Model(..model, pool: pool), fx, CheckAuthAfter(err)))
}

/// Open task details dialog and fetch notes, dependencies, and metrics.
fn handle_task_details_opened(
  model: Model,
  task_id: Int,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  let current_task =
    helpers_lookup.find_task_by_id_in_cache(
      model.pool.member_tasks,
      model.pool.member_tasks_by_project,
      task_id,
    )
  let #(pool, notes, dependencies) =
    detail_state.open(
      model.pool,
      model.notes,
      model.dependencies,
      task_id,
      current_task,
    )
  let next_model = Model(pool: pool, notes: notes, dependencies: dependencies)

  let notes_fx =
    task_notes_api.list_task_notes(task_id, context.on_notes_fetched)
  let deps_fx =
    task_dependencies_api.list_task_dependencies(
      task_id,
      context.on_dependencies_fetched,
    )
  let activity_fx =
    activity_api.list_task_activity(task_id, context.on_activity_fetched)
  #(next_model, effect.batch([notes_fx, deps_fx, activity_fx]))
}

fn handle_activity_more_clicked(
  model: Model,
  context: Context(parent_msg),
) -> #(Model, Effect(parent_msg)) {
  case
    model.notes.member_activity_loading_more,
    model.notes.member_notes_task_id,
    model.notes.member_activity
  {
    False, opt.Some(task_id), Loaded(events) -> {
      let next_notes =
        member_notes.Model(..model.notes, member_activity_loading_more: True)
      #(
        Model(..model, notes: next_notes),
        activity_api.list_task_activity_page(
          task_id,
          30,
          list.length(events),
          context.on_activity_fetched,
        ),
      )
    }
    _, _, _ -> #(model, effect.none())
  }
}

fn activity_loaded(
  notes: member_notes.Model,
  page: activity_api.ActivityPage,
) -> member_notes.Model {
  let activity_api.ActivityPage(activity: events, pagination: pagination) = page
  let next_events = case
    notes.member_activity_loading_more,
    notes.member_activity
  {
    True, Loaded(current) -> list.append(current, events)
    _, _ -> events
  }

  member_notes.Model(
    ..notes,
    member_activity: Loaded(next_events),
    member_activity_total: pagination.total,
    member_activity_loading_more: False,
  )
}

fn activity_failed(
  notes: member_notes.Model,
  err: ApiError,
) -> member_notes.Model {
  case notes.member_activity_loading_more {
    True -> member_notes.Model(..notes, member_activity_loading_more: False)
    False ->
      member_notes.Model(
        ..notes,
        member_activity: Failed(err),
        member_activity_loading_more: False,
      )
  }
}

/// Close task details dialog.
fn handle_task_details_closed(model: Model) -> #(Model, Effect(parent_msg)) {
  let #(pool, notes, dependencies) = detail_state.close(model.pool, model.notes)
  #(Model(pool: pool, notes: notes, dependencies: dependencies), effect.none())
}

fn handle_task_detail_tab_clicked(
  model: member_pool.Model,
  tab: show_tabs.TaskShowTab,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.select_tab(model, tab), effect.none())
}

fn handle_task_detail_edit_started(
  model: member_pool.Model,
  maybe_task: opt.Option(Task),
  can_edit: Bool,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.start_edit(model, maybe_task, can_edit), effect.none())
}

fn handle_task_detail_edit_cancelled(
  model: member_pool.Model,
  maybe_task: opt.Option(Task),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.cancel_edit(model, maybe_task), effect.none())
}

fn handle_task_detail_edit_title_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_title(model, value), effect.none())
}

fn handle_task_detail_edit_description_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_description(model, value), effect.none())
}

fn handle_task_detail_edit_priority_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_priority(model, value), effect.none())
}

fn handle_task_detail_edit_type_id_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_type_id(model, value), effect.none())
}

fn handle_task_detail_edit_card_id_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_card_id(model, value), effect.none())
}

fn handle_task_detail_edit_submitted(
  model: member_pool.Model,
  context: EditContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_detail_edit_in_flight {
    True -> #(model, effect.none())
    False -> submit_task_detail_edit(model, context)
  }
}

fn submit_task_detail_edit(
  model: member_pool.Model,
  context: EditContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case context.current_task, context.can_edit {
    opt.Some(current_task), True -> {
      case
        detail_edit_form.evaluate(
          current_task,
          detail_edit_form.Input(
            title: model.member_task_detail_edit_title,
            description: model.member_task_detail_edit_description,
            priority: model.member_task_detail_edit_priority,
            type_id: model.member_task_detail_edit_type_id,
            card_id: model.member_task_detail_edit_card_id,
          ),
          detail_edit_form.Labels(
            title_required: context.title_required,
            title_too_long_max_56: context.title_too_long_max_56,
            type_required: context.type_required,
            priority_must_be_1_to_5: context.priority_must_be_1_to_5,
          ),
        )
      {
        detail_edit_form.Invalid(message) -> #(
          detail_state.edit_invalid(model, message),
          effect.none(),
        )
        detail_edit_form.Unchanged(submission) -> #(
          detail_state.edit_unchanged(model, submission),
          effect.none(),
        )
        detail_edit_form.Changed(submission) -> #(
          detail_state.edit_started_submit(model, submission),
          task_operations_api.update_task(
            current_task.id,
            task_operations_api.TaskUpdatePayload(
              version: current_task.version,
              title: submission.title,
              description: submission.description,
              priority: submission.priority,
              type_id: submission.type_id,
              card_id: submission.card_id,
            ),
            context.on_task_updated,
          ),
        )
      }
    }
    _, _ -> #(model, effect.none())
  }
}

fn updated_ok(
  model: member_pool.Model,
  updated_task: Task,
  context: SuccessContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    detail_state.task_updated(model, updated_task),
    context.on_success_toast(context.task_updated),
  )
}

fn updated_error(
  model: member_pool.Model,
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    detail_state.task_update_failed(model, err.message),
    error_effect(err, context),
  )
}

fn error_effect(
  err: ApiError,
  context: ErrorContext(parent_msg),
) -> Effect(parent_msg) {
  let #(message, variant) = error_feedback(err)

  case variant {
    toast.Warning -> context.on_warning_toast(message)
    toast.Error -> context.on_error_toast(message)
    _ -> context.on_error_toast(message)
  }
}

pub fn error_feedback(err: ApiError) -> #(String, toast.ToastVariant) {
  case err.status {
    403 | 409 | 422 -> #(err.message, toast.Warning)
    _ -> #(err.message, toast.Error)
  }
}
