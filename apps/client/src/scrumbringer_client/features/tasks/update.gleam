//// Task mutations workflow for Scrumbringer client.
////
//// ## Mission
////
//// Manages task CRUD operations: create, claim, release, complete.
//// Handles form state, validation, API calls, response processing, and notes.
////
//// ## Responsibilities
////
//// - Handle create task dialog state and form fields
//// - Validate task creation input
//// - Process claim/release/complete button clicks
//// - Handle API responses for task mutations
//// - Trigger data refresh after successful mutations
//// - Handle task details/notes dialog state and form
//// - Process note creation and display
////
//// ## Optimistic Updates
////
//// Task actions (claim/release/complete) use optimistic updates:
//// 1. Snapshot current task list before mutation
//// 2. Apply visual change immediately (task removed from pool)
//// 3. Send API request
//// 4. On success: clear snapshot, refresh from server for truth
//// 5. On error: restore snapshot, show error toast
////
//// ## Non-responsibilities
////
//// - API request construction (see `api/tasks/*`)
//// - View rendering (see `client_view.gleam`)
//// - Model type definitions (see `client_state.gleam`)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg types
//// - **client_update.gleam**: Delegates task mutation messages here
//// - **api/tasks/operations.gleam**: Provides task operation API functions
//// - **api/tasks/notes.gleam**: Provides task note API functions
//// - **api/tasks/dependencies.gleam**: Provides task dependency API functions
//// - **i18n/i18n.gleam**: Translates feedback text

import gleam/option as opt

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks/dependencies as task_dependencies_api
import scrumbringer_client/api/tasks/notes as task_notes_api
import scrumbringer_client/api/tasks/operations as task_operations_api
import scrumbringer_client/api/tasks/task_types as task_types_api

// Domain types
import domain/api_error.{type ApiError, type ApiResult}
import domain/metrics.{type TaskModalMetrics}
import domain/remote.{type Remote, Failed, NotAsked}
import domain/task.{type Task, type TaskDependency, type TaskNote}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state/member/dependencies as member_dependencies
import scrumbringer_client/client_state/member/notes as member_notes
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/tasks/create_form
import scrumbringer_client/features/tasks/create_state
import scrumbringer_client/features/tasks/detail_edit_form
import scrumbringer_client/features/tasks/detail_state
import scrumbringer_client/features/tasks/detail_update as task_detail_update
import scrumbringer_client/features/tasks/mutation_state
import scrumbringer_client/features/tasks/mutation_update as task_mutation_update
import scrumbringer_client/features/tasks/note_form
import scrumbringer_client/features/tasks/note_state
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/ui/task_tabs

// =============================================================================
// Create Dialog Handlers
// =============================================================================

pub type CreateContext(parent_msg) {
  CreateContext(
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

pub type TaskCreatePolicy {
  NoTaskCreatePolicy
  RefreshMemberAfterTaskCreated(Task)
  CheckTaskCreateAuthBefore(ApiError)
}

pub type TaskCreateUpdate(parent_msg) {
  TaskCreateUpdate(member_pool.Model, Effect(parent_msg), TaskCreatePolicy)
}

pub type TaskDetailEditContext(parent_msg) {
  TaskDetailEditContext(
    current_task: opt.Option(Task),
    can_edit: Bool,
    on_task_updated: fn(ApiResult(Task)) -> parent_msg,
    title_required: String,
    title_too_long_max_56: String,
  )
}

pub type NoteContext(parent_msg) {
  NoteContext(
    content_required: String,
    note_added: String,
    on_note_added: fn(ApiResult(TaskNote)) -> parent_msg,
    on_notes_fetched: fn(ApiResult(List(TaskNote))) -> parent_msg,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type NoteUpdate(parent_msg) {
  NoteUpdate(member_notes.Model, Effect(parent_msg), AuthPolicy)
}

pub type TaskDetailModel {
  TaskDetailModel(
    pool: member_pool.Model,
    notes: member_notes.Model,
    dependencies: member_dependencies.Model,
  )
}

pub type TaskDetailContext(parent_msg) {
  TaskDetailContext(
    on_notes_fetched: fn(ApiResult(List(TaskNote))) -> parent_msg,
    on_dependencies_fetched: fn(ApiResult(List(TaskDependency))) -> parent_msg,
    on_metrics_fetched: fn(ApiResult(TaskModalMetrics)) -> parent_msg,
  )
}

pub type TaskDetailDispatchContext(parent_msg) {
  TaskDetailDispatchContext(
    open_context: TaskDetailContext(parent_msg),
    edit_context: TaskDetailEditContext(parent_msg),
    success_context: task_detail_update.SuccessContext(parent_msg),
    error_context: task_detail_update.ErrorContext(parent_msg),
  )
}

pub type TaskDetailAuthPolicy {
  NoTaskDetailAuthCheck
  CheckTaskDetailAuthAfter(ApiError)
}

pub type TaskDetailUpdate(parent_msg) {
  TaskDetailUpdate(TaskDetailModel, Effect(parent_msg), TaskDetailAuthPolicy)
}

pub type TaskMutationContext(parent_msg) {
  TaskMutationContext(
    current_user_id: opt.Option(Int),
    on_task_claimed: fn(ApiResult(Task)) -> parent_msg,
    on_task_released: fn(ApiResult(Task)) -> parent_msg,
    on_task_completed: fn(ApiResult(Task)) -> parent_msg,
  )
}

pub type TaskMutationDispatchContext(parent_msg) {
  TaskMutationDispatchContext(
    mutation_context: TaskMutationContext(parent_msg),
    success_context: task_mutation_update.Context(parent_msg),
    error_context: task_mutation_update.ErrorContext(parent_msg),
  )
}

pub type TaskMutationPolicy {
  NoTaskMutationPolicy
  RefreshMemberAfterTaskMutationSuccess
  CheckTaskMutationAuthAfter(ApiError)
}

pub type TaskMutationUpdate(parent_msg) {
  TaskMutationUpdate(member_pool.Model, Effect(parent_msg), TaskMutationPolicy)
}

pub fn try_task_create_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: CreateContext(parent_msg),
) -> opt.Option(TaskCreateUpdate(parent_msg)) {
  case inner {
    pool_messages.MemberCreateDialogOpened ->
      handle_create_dialog_opened(model, context)
      |> task_create_without_policy

    pool_messages.MemberCreateDialogOpenedWithCard(card_id) ->
      handle_create_dialog_opened_with_card(model, card_id, context)
      |> task_create_without_policy

    pool_messages.MemberCreateDialogClosed ->
      handle_create_dialog_closed(model)
      |> task_create_without_policy

    pool_messages.MemberCreateTitleChanged(value) ->
      handle_create_title_changed(model, value)
      |> task_create_without_policy

    pool_messages.MemberCreateDescriptionChanged(value) ->
      handle_create_description_changed(model, value)
      |> task_create_without_policy

    pool_messages.MemberCreatePriorityChanged(value) ->
      handle_create_priority_changed(model, value)
      |> task_create_without_policy

    pool_messages.MemberCreateTypeIdChanged(value) ->
      handle_create_type_id_changed(model, value)
      |> task_create_without_policy

    pool_messages.MemberCreateCardIdChanged(value) ->
      handle_create_card_id_changed(model, value)
      |> task_create_without_policy

    pool_messages.MemberCreateTypeOptionsRetryClicked ->
      handle_create_type_options_retry_clicked(model, context)
      |> task_create_without_policy

    pool_messages.MemberCreateSubmitted ->
      handle_create_submitted(model, context)
      |> task_create_without_policy

    pool_messages.MemberTaskCreated(Ok(task)) ->
      handle_task_created_ok(model)
      |> task_create_with_policy(RefreshMemberAfterTaskCreated(task))

    pool_messages.MemberTaskCreated(Error(err)) ->
      handle_task_created_error(model, err.message)
      |> task_create_with_policy(CheckTaskCreateAuthBefore(err))

    _ -> opt.None
  }
}

fn task_create_without_policy(
  result: #(member_pool.Model, Effect(parent_msg)),
) -> opt.Option(TaskCreateUpdate(parent_msg)) {
  task_create_with_policy(result, NoTaskCreatePolicy)
}

fn task_create_with_policy(
  result: #(member_pool.Model, Effect(parent_msg)),
  policy: TaskCreatePolicy,
) -> opt.Option(TaskCreateUpdate(parent_msg)) {
  let #(model, fx) = result
  opt.Some(TaskCreateUpdate(model, fx, policy))
}

/// Open the create task dialog.
pub fn handle_create_dialog_opened(
  model: member_pool.Model,
  context: CreateContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let next = create_state.open(model)

  #(next, fetch_task_types_if_needed(next, context))
}

/// Open the create task dialog with a pre-selected card (Story 4.12 AC7, AC9).
pub fn handle_create_dialog_opened_with_card(
  model: member_pool.Model,
  card_id: Int,
  context: CreateContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  let next = create_state.open_with_card(model, card_id)

  #(next, fetch_task_types_if_needed(next, context))
}

/// Retry loading task type options used by create task dialog.
pub fn handle_create_type_options_retry_clicked(
  model: member_pool.Model,
  context: CreateContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(model, fetch_task_types(context))
}

fn fetch_task_types_if_needed(
  model: member_pool.Model,
  context: CreateContext(parent_msg),
) -> Effect(parent_msg) {
  case model.member_task_types {
    NotAsked | Failed(_) -> fetch_task_types(context)
    _ -> effect.none()
  }
}

fn fetch_task_types(context: CreateContext(parent_msg)) -> Effect(parent_msg) {
  case context.selected_project_id {
    opt.Some(project_id) ->
      task_types_api.list_task_types(project_id, fn(result) {
        context.on_task_types_fetched(project_id, result)
      })
    opt.None -> effect.none()
  }
}

/// Close the create task dialog.
pub fn handle_create_dialog_closed(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.close(model), effect.none())
}

/// Handle title field change.
pub fn handle_create_title_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.title_changed(model, value), effect.none())
}

/// Handle description field change.
pub fn handle_create_description_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.description_changed(model, value), effect.none())
}

/// Handle priority field change.
pub fn handle_create_priority_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.priority_changed(model, value), effect.none())
}

/// Handle type_id field change.
pub fn handle_create_type_id_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.type_id_changed(model, value), effect.none())
}

/// Handle card_id field change (Story 4.12).
pub fn handle_create_card_id_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.card_id_changed(model, value), effect.none())
}

/// Handle create task form submission with validation.
pub fn handle_create_submitted(
  model: member_pool.Model,
  context: CreateContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_create(model, context)
  }
}

fn validate_and_create(
  model: member_pool.Model,
  context: CreateContext(parent_msg),
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
  context: CreateContext(parent_msg),
) -> create_form.Input {
  create_state.input(model, context.selected_project_id)
}

fn create_labels(context: CreateContext(parent_msg)) -> create_form.Labels {
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
  context: CreateContext(parent_msg),
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
      submission.milestone_id,
      context.on_task_created,
    ),
  )
}

// =============================================================================
// Task Created Response Handlers
// =============================================================================

/// Handle successful task creation.
pub fn handle_task_created_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.created(model), effect.none())
}

/// Handle failed task creation.
pub fn handle_task_created_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(create_state.create_failed(model, message), effect.none())
}

// =============================================================================
// Claim/Release/Complete Handlers (Optimistic Updates)
// =============================================================================

pub fn try_task_mutation_update(
  model: member_pool.Model,
  inner: pool_messages.Msg,
  context: TaskMutationDispatchContext(parent_msg),
) -> opt.Option(TaskMutationUpdate(parent_msg)) {
  case inner {
    pool_messages.MemberClaimClicked(task_id, version) ->
      handle_claim_clicked(model, task_id, version, context.mutation_context)
      |> task_mutation_without_policy

    pool_messages.MemberReleaseClicked(task_id, version) ->
      handle_release_clicked(model, task_id, version, context.mutation_context)
      |> task_mutation_without_policy

    pool_messages.MemberCompleteClicked(task_id, version) ->
      handle_complete_clicked(model, task_id, version, context.mutation_context)
      |> task_mutation_without_policy

    pool_messages.MemberTaskClaimed(Ok(_)) ->
      task_mutation_success(
        model,
        handle_task_claimed_ok,
        task_mutation_update.Claimed,
        context.success_context,
      )

    pool_messages.MemberTaskReleased(Ok(_)) ->
      task_mutation_success(
        model,
        handle_task_released_ok,
        task_mutation_update.Released,
        context.success_context,
      )

    pool_messages.MemberTaskCompleted(Ok(_)) ->
      task_mutation_success(
        model,
        handle_task_completed_ok,
        task_mutation_update.Completed,
        context.success_context,
      )

    pool_messages.MemberTaskClaimed(Error(err))
    | pool_messages.MemberTaskReleased(Error(err))
    | pool_messages.MemberTaskCompleted(Error(err)) ->
      task_mutation_error(model, err, context.error_context)

    _ -> opt.None
  }
}

fn task_mutation_without_policy(
  result: #(member_pool.Model, Effect(parent_msg)),
) -> opt.Option(TaskMutationUpdate(parent_msg)) {
  let #(model, fx) = result
  opt.Some(TaskMutationUpdate(model, fx, NoTaskMutationPolicy))
}

fn task_mutation_success(
  model: member_pool.Model,
  transition: fn(member_pool.Model) -> #(member_pool.Model, Effect(parent_msg)),
  success: task_mutation_update.Success,
  context: task_mutation_update.Context(parent_msg),
) -> opt.Option(TaskMutationUpdate(parent_msg)) {
  let #(model, local_fx) = transition(model)
  opt.Some(TaskMutationUpdate(
    model,
    effect.batch([
      local_fx,
      task_mutation_update.success_effect(success, context),
    ]),
    RefreshMemberAfterTaskMutationSuccess,
  ))
}

fn task_mutation_error(
  model: member_pool.Model,
  err: ApiError,
  context: task_mutation_update.ErrorContext(parent_msg),
) -> opt.Option(TaskMutationUpdate(parent_msg)) {
  let #(model, local_fx) = handle_mutation_error(model)
  opt.Some(TaskMutationUpdate(
    model,
    effect.batch([
      local_fx,
      task_mutation_update.error_effect(err, context),
    ]),
    CheckTaskMutationAuthAfter(err),
  ))
}

/// Handle claim button click with optimistic update.
/// Immediately marks task as claimed locally, sends API request.
pub fn handle_claim_clicked(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: TaskMutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False ->
      case helpers_lookup.find_task_by_id(model.member_tasks, task_id) {
        opt.Some(task) ->
          case can_claim_task(task) {
            True -> submit_claim(model, task_id, version, context)
            False -> #(model, effect.none())
          }
        _ -> #(model, effect.none())
      }
  }
}

/// Handle drag/drop claim without changing the current task list optimistically.
pub fn handle_claim_dropped(
  model: member_pool.Model,
  task_id: Int,
  context: TaskMutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case
    helpers_lookup.find_task_by_id(model.member_tasks, task_id),
    model.member_task_mutation_in_flight
  {
    opt.Some(task), False ->
      case can_claim_task(task) {
        True -> #(
          mutation_state.start_dropped_claim(model),
          task_operations_api.claim_task(
            task_id,
            task.version,
            context.on_task_claimed,
          ),
        )
        False -> #(model, effect.none())
      }
    opt.Some(_), _ -> #(model, effect.none())
    opt.None, _ -> #(model, effect.none())
  }
}

pub fn can_claim_task(task: Task) -> Bool {
  task.blocked_count == 0
}

fn submit_claim(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: TaskMutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(
    mutation_state.start_claim(model, task_id, context.current_user_id),
    task_operations_api.claim_task(task_id, version, context.on_task_claimed),
  )
}

/// Handle release button click with optimistic update.
/// Immediately marks task as available locally, sends API request.
pub fn handle_release_clicked(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: TaskMutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      mutation_state.start_release(model, task_id),
      task_operations_api.release_task(
        task_id,
        version,
        context.on_task_released,
      ),
    )
  }
}

/// Handle complete button click with optimistic update.
/// Immediately marks task as completed locally, sends API request.
pub fn handle_complete_clicked(
  model: member_pool.Model,
  task_id: Int,
  version: Int,
  context: TaskMutationContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_mutation_in_flight {
    True -> #(model, effect.none())
    False -> #(
      mutation_state.start_complete(model, task_id),
      task_operations_api.complete_task(
        task_id,
        version,
        context.on_task_completed,
      ),
    )
  }
}

fn task_detail_edit_values(
  tasks: Remote(List(Task)),
  task_id: Int,
) -> #(String, String) {
  case helpers_lookup.find_task_by_id(tasks, task_id) {
    opt.Some(current_task) -> #(
      current_task.title,
      detail_edit_form.task_description_text(current_task),
    )
    opt.None -> #("", "")
  }
}

fn submit_task_detail_edit(
  model: member_pool.Model,
  context: TaskDetailEditContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case context.current_task, context.can_edit {
    opt.Some(current_task), True -> {
      case
        detail_edit_form.evaluate(
          current_task,
          detail_edit_form.Input(
            title: model.member_task_detail_edit_title,
            description: model.member_task_detail_edit_description,
          ),
          detail_edit_form.Labels(
            title_required: context.title_required,
            title_too_long_max_56: context.title_too_long_max_56,
          ),
        )
      {
        detail_edit_form.Invalid(message) -> #(
          detail_state.edit_invalid(model, message),
          effect.none(),
        )
        detail_edit_form.Unchanged(title, description) -> #(
          detail_state.edit_unchanged(model, title, description),
          effect.none(),
        )
        detail_edit_form.Changed(title, description) -> {
          #(
            detail_state.edit_started_submit(model, title, description),
            task_operations_api.update_task(
              current_task.id,
              current_task.version,
              title,
              description,
              context.on_task_updated,
            ),
          )
        }
      }
    }
    _, _ -> #(model, effect.none())
  }
}

// =============================================================================
// Mutation Response Handlers
// =============================================================================

/// Clear optimistic state after successful mutation.
fn clear_optimistic_state(model: member_pool.Model) -> member_pool.Model {
  mutation_state.clear(model)
}

/// Handle successful task claim.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_claimed_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(clear_optimistic_state(model), effect.none())
}

/// Handle successful task release.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_released_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(clear_optimistic_state(model), effect.none())
}

/// Handle successful task completion.
/// Clears snapshot and refreshes from server for authoritative state.
pub fn handle_task_completed_ok(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(clear_optimistic_state(model), effect.none())
}

/// Handle task mutation error (claim/release/complete).
/// Restores task list from snapshot (rollback) and shows error toast.
/// Provides user-friendly error messages based on error code.
pub fn handle_mutation_error(
  model: member_pool.Model,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(mutation_state.restore_and_clear(model), effect.none())
}

/// Open task details dialog and fetch notes.
pub fn try_task_detail_update(
  model: TaskDetailModel,
  inner: pool_messages.Msg,
  context: TaskDetailDispatchContext(parent_msg),
) -> opt.Option(TaskDetailUpdate(parent_msg)) {
  case inner {
    pool_messages.MemberTaskDetailsOpened(task_id) ->
      handle_task_details_opened(model, task_id, context.open_context)
      |> task_detail_without_auth_check

    pool_messages.MemberTaskDetailsClosed ->
      handle_task_details_closed(model)
      |> task_detail_without_auth_check

    pool_messages.MemberTaskDetailTabClicked(tab) ->
      handle_task_detail_tab_clicked(model.pool, tab)
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskDetailEditStarted ->
      handle_task_detail_edit_started(
        model.pool,
        context.edit_context.current_task,
        context.edit_context.can_edit,
      )
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskDetailEditCancelled ->
      handle_task_detail_edit_cancelled(
        model.pool,
        context.edit_context.current_task,
      )
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskDetailEditTitleChanged(value) ->
      handle_task_detail_edit_title_changed(model.pool, value)
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskDetailEditDescriptionChanged(value) ->
      handle_task_detail_edit_description_changed(model.pool, value)
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskDetailEditSubmitted ->
      handle_task_detail_edit_submitted(model.pool, context.edit_context)
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskUpdated(Ok(task)) ->
      task_detail_update.updated_ok(model.pool, task, context.success_context)
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskUpdated(Error(err)) ->
      task_detail_update.updated_error(model.pool, err, context.error_context)
      |> task_detail_pool_result_after_auth(model, err)

    pool_messages.MemberTaskMetricsFetched(Ok(metrics)) ->
      handle_task_metrics_fetched_ok(model.pool, metrics)
      |> task_detail_pool_result(model)

    pool_messages.MemberTaskMetricsFetched(Error(err)) ->
      handle_task_metrics_fetched_error(model.pool, err)
      |> task_detail_pool_result(model)

    _ -> opt.None
  }
}

fn task_detail_without_auth_check(
  result: #(TaskDetailModel, Effect(parent_msg)),
) -> opt.Option(TaskDetailUpdate(parent_msg)) {
  let #(model, fx) = result
  opt.Some(TaskDetailUpdate(model, fx, NoTaskDetailAuthCheck))
}

fn task_detail_pool_result(
  result: #(member_pool.Model, Effect(parent_msg)),
  model: TaskDetailModel,
) -> opt.Option(TaskDetailUpdate(parent_msg)) {
  let #(pool, fx) = result
  opt.Some(TaskDetailUpdate(
    TaskDetailModel(..model, pool: pool),
    fx,
    NoTaskDetailAuthCheck,
  ))
}

fn task_detail_pool_result_after_auth(
  result: #(member_pool.Model, Effect(parent_msg)),
  model: TaskDetailModel,
  err: ApiError,
) -> opt.Option(TaskDetailUpdate(parent_msg)) {
  let #(pool, fx) = result
  opt.Some(TaskDetailUpdate(
    TaskDetailModel(..model, pool: pool),
    fx,
    CheckTaskDetailAuthAfter(err),
  ))
}

/// Open task details dialog and fetch notes.
pub fn handle_task_details_opened(
  model: TaskDetailModel,
  task_id: Int,
  context: TaskDetailContext(parent_msg),
) -> #(TaskDetailModel, Effect(parent_msg)) {
  let #(edit_title, edit_description) =
    task_detail_edit_values(model.pool.member_tasks, task_id)
  let #(pool, notes, dependencies) =
    detail_state.open(
      model.pool,
      model.notes,
      model.dependencies,
      task_id,
      edit_title,
      edit_description,
    )
  let next_model =
    TaskDetailModel(pool: pool, notes: notes, dependencies: dependencies)

  let notes_fx =
    task_notes_api.list_task_notes(task_id, context.on_notes_fetched)
  let deps_fx =
    task_dependencies_api.list_task_dependencies(
      task_id,
      context.on_dependencies_fetched,
    )
  let metrics_fx =
    task_operations_api.get_task_metrics(task_id, context.on_metrics_fetched)

  #(next_model, effect.batch([notes_fx, deps_fx, metrics_fx]))
}

/// Close task details dialog.
pub fn handle_task_details_closed(
  model: TaskDetailModel,
) -> #(TaskDetailModel, Effect(parent_msg)) {
  let #(pool, notes, dependencies) = detail_state.close(model.pool, model.notes)
  #(
    TaskDetailModel(pool: pool, notes: notes, dependencies: dependencies),
    effect.none(),
  )
}

/// Handle task detail tab click.
pub fn handle_task_detail_tab_clicked(
  model: member_pool.Model,
  tab: task_tabs.Tab,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.select_tab(model, tab), effect.none())
}

pub fn handle_task_detail_edit_started(
  model: member_pool.Model,
  maybe_task: opt.Option(Task),
  can_edit: Bool,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.start_edit(model, maybe_task, can_edit), effect.none())
}

pub fn handle_task_detail_edit_cancelled(
  model: member_pool.Model,
  maybe_task: opt.Option(Task),
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.cancel_edit(model, maybe_task), effect.none())
}

pub fn handle_task_detail_edit_title_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_title(model, value), effect.none())
}

pub fn handle_task_detail_edit_description_changed(
  model: member_pool.Model,
  value: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.change_edit_description(model, value), effect.none())
}

pub fn handle_task_detail_edit_submitted(
  model: member_pool.Model,
  context: TaskDetailEditContext(parent_msg),
) -> #(member_pool.Model, Effect(parent_msg)) {
  case model.member_task_detail_edit_in_flight {
    True -> #(model, effect.none())
    False -> submit_task_detail_edit(model, context)
  }
}

pub fn handle_task_metrics_fetched_ok(
  model: member_pool.Model,
  metrics: TaskModalMetrics,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.metrics_loaded(model, metrics), effect.none())
}

pub fn handle_task_metrics_fetched_error(
  model: member_pool.Model,
  err: ApiError,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.metrics_failed(model, err), effect.none())
}

pub fn handle_task_updated_ok(
  model: member_pool.Model,
  updated_task: Task,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.task_updated(model, updated_task), effect.none())
}

pub fn handle_task_updated_error(
  model: member_pool.Model,
  message: String,
) -> #(member_pool.Model, Effect(parent_msg)) {
  #(detail_state.task_update_failed(model, message), effect.none())
}

/// Handle notes fetched response (success).
pub fn try_note_update(
  model: member_notes.Model,
  inner: pool_messages.Msg,
  context: NoteContext(parent_msg),
) -> opt.Option(NoteUpdate(parent_msg)) {
  case inner {
    pool_messages.MemberNotesFetched(Ok(notes)) ->
      handle_notes_fetched_ok(model, notes)
      |> note_without_auth_check

    pool_messages.MemberNotesFetched(Error(err)) ->
      handle_notes_fetched_error(model, err)
      |> note_with_auth_check(err)

    pool_messages.MemberNoteContentChanged(value) ->
      handle_note_content_changed(model, value)
      |> note_without_auth_check

    pool_messages.MemberNoteDialogOpened ->
      handle_note_dialog_opened(model)
      |> note_without_auth_check

    pool_messages.MemberNoteDialogClosed ->
      handle_note_dialog_closed(model)
      |> note_without_auth_check

    pool_messages.MemberNoteSubmitted ->
      handle_note_submitted(model, context)
      |> note_without_auth_check

    pool_messages.MemberNoteAdded(Ok(note)) ->
      handle_note_added_ok(model, note, context)
      |> note_without_auth_check

    pool_messages.MemberNoteAdded(Error(err)) ->
      handle_note_added_error(model, err, context)
      |> note_with_auth_check(err)

    _ -> opt.None
  }
}

fn note_without_auth_check(
  result: #(member_notes.Model, Effect(parent_msg)),
) -> opt.Option(NoteUpdate(parent_msg)) {
  let #(model, fx) = result
  opt.Some(NoteUpdate(model, fx, NoAuthCheck))
}

fn note_with_auth_check(
  result: #(member_notes.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(NoteUpdate(parent_msg)) {
  let #(model, fx) = result
  opt.Some(NoteUpdate(model, fx, CheckAuth(err)))
}

/// Handle notes fetched response (success).
pub fn handle_notes_fetched_ok(
  model: member_notes.Model,
  notes: List(TaskNote),
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.loaded(model, notes), effect.none())
}

/// Handle notes fetched response (error).
pub fn handle_notes_fetched_error(
  model: member_notes.Model,
  err: ApiError,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.failed(model, err), effect.none())
}

/// Handle note content field change.
pub fn handle_note_content_changed(
  model: member_notes.Model,
  value: String,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.content_changed(model, value), effect.none())
}

/// Handle note dialog opened (Story 5.4 UX unification).
pub fn handle_note_dialog_opened(
  model: member_notes.Model,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.open_dialog(model), effect.none())
}

/// Handle note dialog closed (Story 5.4 UX unification).
pub fn handle_note_dialog_closed(
  model: member_notes.Model,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.close_dialog(model), effect.none())
}

/// Handle note form submission.
pub fn handle_note_submitted(
  model: member_notes.Model,
  context: NoteContext(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  case model.member_note_in_flight {
    True -> #(model, effect.none())
    False -> submit_note(model, context)
  }
}

fn submit_note(
  model: member_notes.Model,
  context: NoteContext(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  case
    note_form.evaluate(
      note_form.Input(
        task_id: model.member_notes_task_id,
        content: model.member_note_content,
      ),
      note_form.Labels(content_required: context.content_required),
    )
  {
    note_form.NoTaskSelected -> #(model, effect.none())
    note_form.Invalid(message) -> submit_note_invalid(model, message)
    note_form.Ready(task_id, content) ->
      submit_note_with_content(model, task_id, content, context)
  }
}

fn submit_note_invalid(
  model: member_notes.Model,
  message: String,
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.submit_invalid(model, message), effect.none())
}

fn submit_note_with_content(
  model: member_notes.Model,
  task_id: Int,
  content: String,
  context: NoteContext(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(
    note_state.submit_ready(model),
    task_notes_api.add_task_note(task_id, content, context.on_note_added),
  )
}

/// Handle note added response (success).
pub fn handle_note_added_ok(
  model: member_notes.Model,
  note: TaskNote,
  context: NoteContext(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  #(note_state.added(model, note), context.on_success_toast(context.note_added))
}

/// Handle note added response (error).
pub fn handle_note_added_error(
  model: member_notes.Model,
  err: ApiError,
  context: NoteContext(parent_msg),
) -> #(member_notes.Model, Effect(parent_msg)) {
  let model = note_state.add_failed(model, err)

  case model.member_notes_task_id {
    opt.Some(task_id) -> #(
      model,
      task_notes_api.list_task_notes(task_id, context.on_notes_fetched),
    )
    opt.None -> #(model, effect.none())
  }
}
