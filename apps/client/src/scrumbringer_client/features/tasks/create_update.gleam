//// Task creation update handlers.

import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/remote.{Failed, NotAsked}
import domain/task.{type Task}
import domain/task_type.{type TaskType}
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/api/tasks/task_types as task_types_api
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/create_form
import scrumbringer_client/features/tasks/create_state

pub type Context(parent_msg) {
  Context(
    selected_project_id: opt.Option(Int),
    on_task_types_fetched: fn(Int, ApiResult(List(TaskType))) -> parent_msg,
    on_task_created: fn(ApiResult(Task)) -> parent_msg,
    select_project_first: String,
    title_required: String,
    title_too_long_max_56: String,
    type_required: String,
    priority_must_be_1_to_5: String,
  )
}

pub type Policy {
  NoPolicy
  RefreshMemberAfterCreated(Task)
  CheckAuthBefore(ApiError)
}

pub type Update(parent_msg) {
  Update(member_pool.Model, Effect(parent_msg), Policy)
}

pub fn try_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: Context(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    pool_messages.MemberCreateDialogOpened ->
      handle_dialog_opened(model, context)
      |> without_policy

    pool_messages.MemberCreateDialogOpenedWithCard(card_id) ->
      handle_dialog_opened_with_card(model, card_id, context)
      |> without_policy

    pool_messages.MemberCreateDialogClosed ->
      handle_dialog_closed(model)
      |> without_policy

    pool_messages.MemberCreateTitleChanged(value) ->
      handle_title_changed(model, value)
      |> without_policy

    pool_messages.MemberCreateDescriptionChanged(value) ->
      handle_description_changed(model, value)
      |> without_policy

    pool_messages.MemberCreatePriorityChanged(value) ->
      handle_priority_changed(model, value)
      |> without_policy

    pool_messages.MemberCreateTypeIdChanged(value) ->
      handle_type_id_changed(model, value)
      |> without_policy

    pool_messages.MemberCreateCardIdChanged(value) ->
      handle_card_id_changed(model, value)
      |> without_policy

    pool_messages.MemberCreateTypeOptionsRetryClicked ->
      handle_type_options_retry_clicked(model, context)
      |> without_policy

    pool_messages.MemberCreateSubmitted ->
      handle_submitted(model, context)
      |> without_policy

    pool_messages.MemberTaskCreated(Ok(task)) ->
      handle_created_ok(model)
      |> with_policy(RefreshMemberAfterCreated(task))

    pool_messages.MemberTaskCreated(Error(err)) ->
      handle_created_error(model, err.message)
      |> with_policy(CheckAuthBefore(err))

    _ -> opt.None
  }
}

fn without_policy(
  result: #(member_pool.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoPolicy)
}

fn with_policy(
  result: #(member_pool.Model, Effect(parent_msg)),
  policy: Policy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, policy))
}

fn handle_dialog_opened(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let next = create_state.open(model)

  #(next, fetch_task_types_if_needed(next, context))
}

fn handle_dialog_opened_with_card(
  model: member_pool.Model,
  card_id: Int,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let next = create_state.open_with_card(model, card_id)

  #(next, fetch_task_types_if_needed(next, context))
}

fn handle_type_options_retry_clicked(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(model, fetch_task_types(context))
}

fn fetch_task_types_if_needed(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> Effect(parent_msg) {
  case model.member_task_types {
    NotAsked | Failed(_) -> fetch_task_types(context)
    _ -> effect.none()
  }
}

fn fetch_task_types(context: Context(parent_msg)) -> Effect(parent_msg) {
  case context.selected_project_id {
    opt.Some(project_id) ->
      task_types_api.list_task_types(project_id, fn(result) {
        context.on_task_types_fetched(project_id, result)
      })
    opt.None -> effect.none()
  }
}

fn handle_dialog_closed(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.close(model), effect.none())
}

fn handle_title_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.title_changed(model, value), effect.none())
}

fn handle_description_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.description_changed(model, value), effect.none())
}

fn handle_priority_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.priority_changed(model, value), effect.none())
}

fn handle_type_id_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.type_id_changed(model, value), effect.none())
}

fn handle_card_id_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.card_id_changed(model, value), effect.none())
}

fn handle_submitted(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_create(model, context)
  }
}

fn validate_and_create(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case
    create_form.validate(create_input(model, context), create_labels(context))
  {
    Error(message) -> #(
      create_state.submit_invalid(model, message),
      effect.none(),
    )
    Ok(submission) -> submit_create(model, submission, context)
  }
}

fn create_input(
  model: member_pool.Model,
  context: Context(parent_msg),
) -> create_form.Input {
  create_state.input(model, context.selected_project_id)
}

fn create_labels(context: Context(parent_msg)) -> create_form.Labels {
  create_form.Labels(
    select_project_first: context.select_project_first,
    title_required: context.title_required,
    title_too_long_max_56: context.title_too_long_max_56,
    type_required: context.type_required,
    priority_must_be_1_to_5: context.priority_must_be_1_to_5,
  )
}

fn submit_create(
  model: member_pool.Model,
  submission: create_form.Submission,
  context: Context(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let model = create_state.submit_ready(model)

  #(
    model,
    task_operations_api.create_task_with_card(
      submission.project_id,
      submission.title,
      submission.description,
      submission.priority,
      submission.type_id,
      submission.card_id,
      context.on_task_created,
    ),
  )
}

fn handle_created_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.created(model), effect.none())
}

fn handle_created_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.create_failed(model, message), effect.none())
}
