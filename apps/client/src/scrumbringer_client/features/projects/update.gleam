//// Projects feature update handlers.
////
//// ## Mission
////
//// Handles project CRUD dialog state.
////
//// ## Responsibilities
////
//// - Project create/edit/delete form state and submission
//// - Dialog operation states and validation
////
//// ## Non-responsibilities
////
//// - Root model assembly for project CRUD dialogs (see `features/admin/update.gleam`)
//// - Navigation (see `client_update.gleam`)
////
//// ## Relations
////
//// - **features/admin/update.gleam**: Assembles root state and toasts
//// - **api/projects.gleam**: Provides API effects for project operations

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/projects as api_projects

// Domain types
import domain/api_error.{type ApiError, type ApiResult}
import domain/project.{type Project, type ProjectDepthName, ProjectDepthName}
import domain/project/settings as project_settings
import scrumbringer_client/client_state/admin/projects as admin_projects
import scrumbringer_client/client_state/types.{
  type DialogState, type OperationState, DialogClosed, DialogOpen,
  Error as OpError, Idle, InFlight,
}
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    on_project_created: fn(ApiResult(Project)) -> parent_msg,
    on_project_updated: fn(ApiResult(Project)) -> parent_msg,
    on_project_deleted: fn(ApiResult(Nil)) -> parent_msg,
    on_depth_reduction_previewed: fn(
      ApiResult(api_projects.DepthReductionImpact),
    ) ->
      parent_msg,
    name_required: String,
    pool_soft_limit_positive: String,
    maximum_depth_positive: String,
    add_level_names_before_increasing_depth: String,
    review_affected_cards_before_lowering_depth: String,
    depth_names_required: String,
  )
}

type Success {
  ProjectCreated
  ProjectUpdated
  ProjectDeleted
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    project_created: String,
    project_updated: String,
    project_deleted: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
    on_error_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type CorePolicy {
  NoCoreChange
  CoreProjectCreated(Project)
  CoreProjectUpdated(Project)
  CoreProjectDeleted(opt.Option(Int))
}

pub type Update(parent_msg) {
  Update(admin_projects.Model, Effect(parent_msg), AuthPolicy, CorePolicy)
}

pub fn try_update(
  model: admin_projects.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
  error_feedback: ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.ProjectCreateDialogOpened ->
      handle_project_create_dialog_opened(model)
      |> without_policies

    admin_messages.ProjectCreateDialogClosed ->
      handle_project_create_dialog_closed(model)
      |> without_policies

    admin_messages.ProjectCreateNameChanged(name) ->
      handle_project_create_name_changed(model, name)
      |> without_policies

    admin_messages.ProjectCreateHealthyPoolLimitChanged(value) ->
      handle_project_create_healthy_pool_limit_changed(model, value)
      |> without_policies

    admin_messages.ProjectCreateMaxDepthChanged(value) ->
      handle_project_create_max_depth_changed(model, value)
      |> without_policies

    admin_messages.ProjectCreateDepthSingularChanged(depth, value) ->
      handle_project_create_depth_singular_changed(model, depth, value)
      |> without_policies

    admin_messages.ProjectCreateDepthPluralChanged(depth, value) ->
      handle_project_create_depth_plural_changed(model, depth, value)
      |> without_policies

    admin_messages.ProjectCreateNextClicked ->
      handle_project_create_next_clicked(model, context)
      |> without_policies

    admin_messages.ProjectCreateBackClicked ->
      handle_project_create_back_clicked(model)
      |> without_policies

    admin_messages.ProjectCreateSubmitted ->
      handle_project_create_submitted(model, context)
      |> without_policies

    admin_messages.ProjectCreated(Ok(project)) ->
      handle_project_created_ok(model, feedback)
      |> with_core_policy(CoreProjectCreated(project))

    admin_messages.ProjectCreated(Error(err)) ->
      handle_project_created_error(model, err, error_feedback)
      |> with_auth_policy(CheckAuth(err))

    admin_messages.ProjectEditDialogOpened(
      project_id,
      project_name,
      healthy_pool_limit,
      card_depth_names,
    ) ->
      handle_project_edit_dialog_opened(
        model,
        project_id,
        project_name,
        healthy_pool_limit,
        card_depth_names,
      )
      |> without_policies

    admin_messages.ProjectEditDialogClosed ->
      handle_project_edit_dialog_closed(model)
      |> without_policies

    admin_messages.ProjectEditNameChanged(name) ->
      handle_project_edit_name_changed(model, name)
      |> without_policies

    admin_messages.ProjectEditHealthyPoolLimitChanged(value) ->
      handle_project_edit_healthy_pool_limit_changed(model, value)
      |> without_policies

    admin_messages.ProjectEditMaxDepthChanged(value) ->
      handle_project_edit_max_depth_changed(model, value)
      |> without_policies

    admin_messages.ProjectEditDepthSingularChanged(depth, value) ->
      handle_project_edit_depth_singular_changed(model, depth, value)
      |> without_policies

    admin_messages.ProjectEditDepthPluralChanged(depth, value) ->
      handle_project_edit_depth_plural_changed(model, depth, value)
      |> without_policies

    admin_messages.ProjectEditDepthReductionReviewClicked ->
      handle_project_edit_depth_reduction_review_clicked(model, context)
      |> without_policies

    admin_messages.ProjectEditDepthReductionPreviewed(result) ->
      handle_project_edit_depth_reduction_previewed(model, result)
      |> without_policies

    admin_messages.ProjectEditDepthReductionConfirmed ->
      handle_project_edit_depth_reduction_confirmed(model)
      |> without_policies

    admin_messages.ProjectEditSubmitted ->
      handle_project_edit_submitted(model, context)
      |> without_policies

    admin_messages.ProjectUpdated(Ok(project)) ->
      handle_project_updated_ok(model, feedback)
      |> with_core_policy(CoreProjectUpdated(project))

    admin_messages.ProjectUpdated(Error(err)) ->
      handle_project_updated_error(model, err, error_feedback)
      |> with_auth_policy(CheckAuth(err))

    admin_messages.ProjectDeleteConfirmOpened(project_id, project_name) ->
      handle_project_delete_confirm_opened(model, project_id, project_name)
      |> without_policies

    admin_messages.ProjectDeleteConfirmClosed ->
      handle_project_delete_confirm_closed(model)
      |> without_policies

    admin_messages.ProjectDeleteSubmitted ->
      handle_project_delete_submitted(model, context)
      |> without_policies

    admin_messages.ProjectDeleted(Ok(_)) ->
      handle_project_deleted_ok(model, feedback)
      |> with_core_policy(
        CoreProjectDeleted(project_dialog_delete_id(model.projects_dialog)),
      )

    admin_messages.ProjectDeleted(Error(err)) ->
      handle_project_deleted_error(model, err, error_feedback)
      |> with_auth_policy(CheckAuth(err))

    _ -> opt.None
  }
}

fn without_policies(
  result: #(admin_projects.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, NoAuthCheck, NoCoreChange)
}

fn with_auth_policy(
  result: #(admin_projects.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, auth_policy, NoCoreChange)
}

fn with_core_policy(
  result: #(admin_projects.Model, Effect(parent_msg)),
  core_policy: CorePolicy,
) -> opt.Option(Update(parent_msg)) {
  with_policies(result, NoAuthCheck, core_policy)
}

fn with_policies(
  result: #(admin_projects.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
  core_policy: CorePolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy, core_policy))
}

// =============================================================================
// Project Create Handlers
// =============================================================================

/// Handle project create dialog opened.
fn handle_project_create_dialog_opened(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(
      model,
      DialogOpen(form: create_form(""), operation: Idle),
    ),
    effect.none(),
  )
}

/// Handle project create dialog closed.
fn handle_project_create_dialog_closed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(set_projects_dialog(model, DialogClosed(operation: Idle)), effect.none())
}

/// Handle project create name input change.
fn handle_project_create_name_changed(
  model: admin_projects.Model,
  name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(
        step: step,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        ..,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogCreate(
          step: step,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: card_depth_names,
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_create_healthy_pool_limit_changed(
  model: admin_projects.Model,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(
        step: step,
        name: name,
        max_depth: max_depth,
        card_depth_names: card_depth_names,
        ..,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogCreate(
          step: step,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: value,
          card_depth_names: card_depth_names,
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_create_max_depth_changed(
  model: admin_projects.Model,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(
        step: step,
        name: name,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        ..,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogCreate(
          step: step,
          name: name,
          max_depth: value,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: resize_depth_names(value, card_depth_names),
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_create_depth_singular_changed(
  model: admin_projects.Model,
  depth: Int,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  update_project_create_depth_name(model, depth, fn(depth_name) {
    ProjectDepthName(..depth_name, singular_name: value)
  })
}

fn handle_project_create_depth_plural_changed(
  model: admin_projects.Model,
  depth: Int,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  update_project_create_depth_name(model, depth, fn(depth_name) {
    ProjectDepthName(..depth_name, plural_name: value)
  })
}

fn update_project_create_depth_name(
  model: admin_projects.Model,
  depth: Int,
  update_depth_name: fn(ProjectDepthName) -> ProjectDepthName,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(
        step: step,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogCreate(
          step: step,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: update_depth_names(
            card_depth_names,
            depth,
            update_depth_name,
          ),
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_create_next_clicked(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  advance_project_create(model, context)
}

fn handle_project_create_back_clicked(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(step: step, ..) as form,
      operation: _,
    ) -> #(
      set_projects_dialog(
        model,
        DialogOpen(
          form: admin_projects.ProjectDialogCreate(
            ..form,
            step: previous_create_step(step),
          ),
          operation: Idle,
        ),
      ),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

/// Handle project create form submission.
fn handle_project_create_submitted(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  advance_project_create(model, context)
}

fn advance_project_create(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(
        step: step,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
      ),
      operation: op,
    ) -> {
      case operation_in_flight(op) {
        True -> #(model, effect.none())
        False ->
          advance_project_create_step(
            model,
            step,
            name,
            max_depth,
            healthy_pool_limit,
            card_depth_names,
            context,
          )
      }
    }
    _ -> #(model, effect.none())
  }
}

fn advance_project_create_step(
  model: admin_projects.Model,
  step: admin_projects.ProjectCreateStep,
  name: String,
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case step {
    admin_projects.ProjectCreateGeneral ->
      advance_project_create_general(model, name, context)

    admin_projects.ProjectCreateStructurePool ->
      advance_project_create_structure(
        model,
        max_depth,
        healthy_pool_limit,
        card_depth_names,
        context,
      )

    admin_projects.ProjectCreateCapabilities ->
      set_project_create_step(model, admin_projects.ProjectCreateTeam)

    admin_projects.ProjectCreateTeam ->
      set_project_create_step(model, admin_projects.ProjectCreateReview)

    admin_projects.ProjectCreateReview ->
      submit_project_create(
        model,
        name,
        max_depth,
        healthy_pool_limit,
        card_depth_names,
        False,
        context,
      )
  }
}

fn advance_project_create_general(
  model: admin_projects.Model,
  name: String,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case string.trim(name) == "" {
    True -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(
          model.projects_dialog,
          context.name_required,
        ),
      ),
      effect.none(),
    )
    False ->
      set_project_create_step(model, admin_projects.ProjectCreateStructurePool)
  }
}

fn advance_project_create_structure(
  model: admin_projects.Model,
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case
    validate_project_settings(
      max_depth,
      healthy_pool_limit,
      card_depth_names,
      admin_projects.NoDepthReduction,
      context,
    )
  {
    Error(message) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      effect.none(),
    )
    Ok(_) ->
      set_project_create_step(model, admin_projects.ProjectCreateCapabilities)
  }
}

fn set_project_create_step(
  model: admin_projects.Model,
  step: admin_projects.ProjectCreateStep,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogCreate(..) as form,
      operation: _,
    ) -> #(
      set_projects_dialog(
        model,
        DialogOpen(
          form: admin_projects.ProjectDialogCreate(..form, step: step),
          operation: Idle,
        ),
      ),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

fn previous_create_step(
  step: admin_projects.ProjectCreateStep,
) -> admin_projects.ProjectCreateStep {
  case step {
    admin_projects.ProjectCreateGeneral -> admin_projects.ProjectCreateGeneral
    admin_projects.ProjectCreateStructurePool ->
      admin_projects.ProjectCreateGeneral
    admin_projects.ProjectCreateCapabilities ->
      admin_projects.ProjectCreateStructurePool
    admin_projects.ProjectCreateTeam -> admin_projects.ProjectCreateCapabilities
    admin_projects.ProjectCreateReview -> admin_projects.ProjectCreateTeam
  }
}

fn submit_project_create(
  model: admin_projects.Model,
  name: String,
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  in_flight: Bool,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> {
      let trimmed = string.trim(name)
      case trimmed == "" {
        True -> #(
          set_projects_dialog(
            model,
            update_project_dialog_error(
              model.projects_dialog,
              context.name_required,
            ),
          ),
          effect.none(),
        )
        False ->
          submit_project_create_settings(
            model,
            trimmed,
            max_depth,
            healthy_pool_limit,
            card_depth_names,
            context,
          )
      }
    }
  }
}

fn submit_project_create_settings(
  model: admin_projects.Model,
  name: String,
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case
    validate_project_settings(
      max_depth,
      healthy_pool_limit,
      card_depth_names,
      admin_projects.NoDepthReduction,
      context,
    )
  {
    Error(message) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      effect.none(),
    )
    Ok(#(limit, depth_names)) ->
      submit_project_create_valid(model, name, limit, depth_names, context)
  }
}

fn submit_project_create_valid(
  model: admin_projects.Model,
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let model =
    set_projects_dialog(
      model,
      update_project_dialog_in_flight(model.projects_dialog),
    )
  #(
    model,
    api_projects.create_project(
      name,
      healthy_pool_limit,
      card_depth_names,
      context.on_project_created,
    ),
  )
}

/// Handle project created success.
fn handle_project_created_ok(
  model: admin_projects.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(model, DialogClosed(operation: Idle)),
    success_effect(ProjectCreated, feedback),
  )
}

/// Handle project created error.
fn handle_project_created_error(
  model: admin_projects.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  case model.projects_dialog {
    DialogOpen(form: admin_projects.ProjectDialogCreate(..), ..) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      forbidden_warning_effect(err, message, feedback),
    )
    _ -> #(model, effect.none())
  }
}

// =============================================================================
// Project Edit Handlers (Story 4.8 AC39)
// =============================================================================

/// Handle project edit dialog opened.
fn handle_project_edit_dialog_opened(
  model: admin_projects.Model,
  project_id: Int,
  project_name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let normalized_depth_names = normalize_depth_names(card_depth_names)

  #(
    set_projects_dialog(
      model,
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: project_id,
          name: project_name,
          max_depth: int.to_string(list.length(normalized_depth_names)),
          healthy_pool_limit: int.to_string(healthy_pool_limit),
          card_depth_names: normalized_depth_names,
          depth_reduction: admin_projects.NoDepthReduction,
        ),
        operation: Idle,
      ),
    ),
    effect.none(),
  )
}

/// Handle project edit dialog closed.
fn handle_project_edit_dialog_closed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(set_projects_dialog(model, DialogClosed(operation: Idle)), effect.none())
}

/// Handle project edit name input change.
fn handle_project_edit_name_changed(
  model: admin_projects.Model,
  name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: id,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        depth_reduction: depth_reduction,
        ..,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: id,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: card_depth_names,
          depth_reduction: depth_reduction,
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_edit_healthy_pool_limit_changed(
  model: admin_projects.Model,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: id,
        name: name,
        max_depth: max_depth,
        card_depth_names: card_depth_names,
        depth_reduction: depth_reduction,
        ..,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: id,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: value,
          card_depth_names: card_depth_names,
          depth_reduction: depth_reduction,
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_edit_max_depth_changed(
  model: admin_projects.Model,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: id,
        name: name,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        ..,
      ),
      operation: op,
    ) -> {
      let normalized = normalize_depth_names(card_depth_names)
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: id,
          name: name,
          max_depth: value,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: normalized,
          depth_reduction: depth_reduction_for_max_depth(value, normalized),
        ),
        operation: op,
      )
    }
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_edit_depth_singular_changed(
  model: admin_projects.Model,
  depth: Int,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  update_project_edit_depth_name(model, depth, fn(depth_name) {
    ProjectDepthName(..depth_name, singular_name: value)
  })
}

fn handle_project_edit_depth_plural_changed(
  model: admin_projects.Model,
  depth: Int,
  value: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  update_project_edit_depth_name(model, depth, fn(depth_name) {
    ProjectDepthName(..depth_name, plural_name: value)
  })
}

fn update_project_edit_depth_name(
  model: admin_projects.Model,
  depth: Int,
  update_depth_name: fn(ProjectDepthName) -> ProjectDepthName,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: id,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        depth_reduction: depth_reduction,
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: id,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: update_depth_names(
            card_depth_names,
            depth,
            update_depth_name,
          ),
          depth_reduction: depth_reduction,
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_edit_depth_reduction_review_clicked(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: project_id,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        depth_reduction: admin_projects.DepthReductionNeedsReview(new_max_depth),
      ),
      operation: op,
    ) -> {
      let next_model =
        set_projects_dialog(
          model,
          DialogOpen(
            form: admin_projects.ProjectDialogEdit(
              id: project_id,
              name: name,
              max_depth: max_depth,
              healthy_pool_limit: healthy_pool_limit,
              card_depth_names: card_depth_names,
              depth_reduction: admin_projects.DepthReductionLoading(
                new_max_depth,
              ),
            ),
            operation: op,
          ),
        )

      #(
        next_model,
        api_projects.preview_depth_reduction(
          project_id,
          new_max_depth,
          context.on_depth_reduction_previewed,
        ),
      )
    }
    _ -> #(model, effect.none())
  }
}

fn handle_project_edit_depth_reduction_previewed(
  model: admin_projects.Model,
  result: ApiResult(api_projects.DepthReductionImpact),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case result {
    Ok(impact) -> set_depth_reduction_ready(model, impact)
    Error(err) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(
          model.projects_dialog,
          "Could not review depth reduction: " <> err.message,
        ),
      ),
      effect.none(),
    )
  }
}

fn set_depth_reduction_ready(
  model: admin_projects.Model,
  impact: api_projects.DepthReductionImpact,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: id,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        depth_reduction: admin_projects.DepthReductionLoading(new_max_depth),
      ),
      operation: op,
    ) ->
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: id,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: card_depth_names,
          depth_reduction: admin_projects.DepthReductionReady(
            new_max_depth,
            impact,
          ),
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

fn handle_project_edit_depth_reduction_confirmed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let next_state = case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: id,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        depth_reduction: admin_projects.DepthReductionReady(
          new_max_depth,
          impact,
        ),
      ),
      operation: op,
    )
      if impact.blocked == False
    ->
      DialogOpen(
        form: admin_projects.ProjectDialogEdit(
          id: id,
          name: name,
          max_depth: max_depth,
          healthy_pool_limit: healthy_pool_limit,
          card_depth_names: card_depth_names,
          depth_reduction: admin_projects.DepthReductionConfirmed(new_max_depth),
        ),
        operation: op,
      )
    other -> other
  }

  #(set_projects_dialog(model, next_state), effect.none())
}

/// Handle project edit form submission.
fn handle_project_edit_submitted(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogEdit(
        id: project_id,
        name: name,
        max_depth: max_depth,
        healthy_pool_limit: healthy_pool_limit,
        card_depth_names: card_depth_names,
        depth_reduction: depth_reduction,
      ),
      operation: op,
    ) ->
      submit_project_edit(
        model,
        project_id,
        name,
        max_depth,
        healthy_pool_limit,
        card_depth_names,
        depth_reduction,
        operation_in_flight(op),
        context,
      )
    _ -> #(model, effect.none())
  }
}

fn submit_project_edit(
  model: admin_projects.Model,
  project_id: Int,
  name: String,
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  depth_reduction: admin_projects.DepthReductionState,
  in_flight: Bool,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> {
      let trimmed = string.trim(name)
      case trimmed == "" {
        True -> #(
          set_projects_dialog(
            model,
            update_project_dialog_error(
              model.projects_dialog,
              context.name_required,
            ),
          ),
          effect.none(),
        )
        False ->
          submit_project_edit_settings(
            model,
            project_id,
            trimmed,
            max_depth,
            healthy_pool_limit,
            card_depth_names,
            depth_reduction,
            context,
          )
      }
    }
  }
}

fn submit_project_edit_settings(
  model: admin_projects.Model,
  project_id: Int,
  name: String,
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  depth_reduction: admin_projects.DepthReductionState,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case
    validate_project_settings(
      max_depth,
      healthy_pool_limit,
      card_depth_names,
      depth_reduction,
      context,
    )
  {
    Error(message) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      effect.none(),
    )
    Ok(#(limit, depth_names)) ->
      submit_project_edit_valid(
        model,
        project_id,
        name,
        limit,
        depth_names,
        context,
      )
  }
}

fn validate_project_settings(
  max_depth: String,
  healthy_pool_limit: String,
  card_depth_names: List(ProjectDepthName),
  depth_reduction: admin_projects.DepthReductionState,
  context: Context(parent_msg),
) -> Result(#(Int, List(ProjectDepthName)), String) {
  let Context(pool_soft_limit_positive:, ..) = context
  case int.parse(string.trim(healthy_pool_limit)) {
    Error(_) -> Error(pool_soft_limit_positive)
    Ok(value) if value <= 0 -> Error(pool_soft_limit_positive)
    Ok(value) ->
      validate_depth_settings(
        max_depth,
        value,
        card_depth_names,
        depth_reduction,
        context,
      )
  }
}

fn validate_depth_settings(
  max_depth: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  depth_reduction: admin_projects.DepthReductionState,
  context: Context(parent_msg),
) -> Result(#(Int, List(ProjectDepthName)), String) {
  let Context(maximum_depth_positive:, ..) = context
  case int.parse(string.trim(max_depth)) {
    Error(_) -> Error(maximum_depth_positive)
    Ok(value) if value <= 0 -> Error(maximum_depth_positive)
    Ok(value) -> {
      let normalized = normalize_depth_names(card_depth_names)
      let current_depth = list.length(normalized)
      case value == current_depth {
        True -> validate_depth_names(healthy_pool_limit, normalized, context)
        False ->
          validate_pending_depth_change(
            value,
            current_depth,
            healthy_pool_limit,
            normalized,
            depth_reduction,
            context,
          )
      }
    }
  }
}

fn validate_pending_depth_change(
  max_depth: Int,
  current_depth: Int,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  depth_reduction: admin_projects.DepthReductionState,
  context: Context(parent_msg),
) -> Result(#(Int, List(ProjectDepthName)), String) {
  let Context(
    add_level_names_before_increasing_depth:,
    review_affected_cards_before_lowering_depth:,
    ..,
  ) = context
  case max_depth > current_depth {
    True -> Error(add_level_names_before_increasing_depth)
    False ->
      case depth_reduction {
        admin_projects.DepthReductionConfirmed(confirmed_depth)
          if confirmed_depth == max_depth
        ->
          validate_depth_names(
            healthy_pool_limit,
            list.take(card_depth_names, max_depth),
            context,
          )
        _ -> Error(review_affected_cards_before_lowering_depth)
      }
  }
}

fn validate_depth_names(
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  context: Context(parent_msg),
) -> Result(#(Int, List(ProjectDepthName)), String) {
  let Context(depth_names_required:, ..) = context
  let normalized = normalize_depth_names(card_depth_names)
  case project_settings.valid_card_depth_names(normalized) {
    False -> Error(depth_names_required)
    True -> Ok(#(healthy_pool_limit, normalized))
  }
}

fn normalize_depth_names(
  card_depth_names: List(ProjectDepthName),
) -> List(ProjectDepthName) {
  case card_depth_names {
    [] -> project_settings.default_card_depth_names()
    _ -> card_depth_names
  }
}

fn create_form(name: String) -> admin_projects.ProjectDialogForm {
  let depth_names = project_settings.default_card_depth_names()
  admin_projects.ProjectDialogCreate(
    step: admin_projects.ProjectCreateGeneral,
    name: name,
    max_depth: int.to_string(list.length(depth_names)),
    healthy_pool_limit: "20",
    card_depth_names: depth_names,
  )
}

fn resize_depth_names(
  max_depth: String,
  card_depth_names: List(ProjectDepthName),
) -> List(ProjectDepthName) {
  case int.parse(string.trim(max_depth)) {
    Ok(value) if value > 0 ->
      depth_names_for_count(normalize_depth_names(card_depth_names), value)
    _ -> normalize_depth_names(card_depth_names)
  }
}

fn depth_names_for_count(
  card_depth_names: List(ProjectDepthName),
  count: Int,
) -> List(ProjectDepthName) {
  case count <= list.length(card_depth_names) {
    True -> list.take(card_depth_names, count)
    False ->
      depth_names_for_count(
        list.append(card_depth_names, [
          default_depth_name(list.length(card_depth_names) + 1),
        ]),
        count,
      )
  }
}

fn default_depth_name(depth: Int) -> ProjectDepthName {
  case
    project_settings.default_card_depth_names()
    |> list.find(fn(depth_name) {
      let ProjectDepthName(depth: candidate_depth, ..) = depth_name
      candidate_depth == depth
    })
  {
    Ok(depth_name) -> depth_name
    Error(Nil) ->
      ProjectDepthName(
        depth: depth,
        singular_name: "Level " <> int.to_string(depth),
        plural_name: "Level " <> int.to_string(depth) <> "s",
      )
  }
}

fn update_depth_names(
  card_depth_names: List(ProjectDepthName),
  target_depth: Int,
  update_depth_name: fn(ProjectDepthName) -> ProjectDepthName,
) -> List(ProjectDepthName) {
  normalize_depth_names(card_depth_names)
  |> list.map(fn(depth_name) {
    let ProjectDepthName(depth: depth, ..) = depth_name
    case depth == target_depth {
      True -> update_depth_name(depth_name)
      False -> depth_name
    }
  })
}

fn depth_reduction_for_max_depth(
  max_depth: String,
  card_depth_names: List(ProjectDepthName),
) -> admin_projects.DepthReductionState {
  case int.parse(string.trim(max_depth)) {
    Ok(value) ->
      case value < list.length(card_depth_names) && value > 0 {
        True -> admin_projects.DepthReductionNeedsReview(value)
        False -> admin_projects.NoDepthReduction
      }
    _ -> admin_projects.NoDepthReduction
  }
}

fn submit_project_edit_valid(
  model: admin_projects.Model,
  project_id: Int,
  name: String,
  healthy_pool_limit: Int,
  card_depth_names: List(ProjectDepthName),
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let model =
    set_projects_dialog(
      model,
      update_project_dialog_in_flight(model.projects_dialog),
    )
  #(
    model,
    api_projects.update_project(
      project_id,
      name,
      healthy_pool_limit,
      card_depth_names,
      context.on_project_updated,
    ),
  )
}

/// Handle project updated success.
fn handle_project_updated_ok(
  model: admin_projects.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(model, DialogClosed(operation: Idle)),
    success_effect(ProjectUpdated, feedback),
  )
}

/// Handle project updated error.
fn handle_project_updated_error(
  model: admin_projects.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  case model.projects_dialog {
    DialogOpen(form: admin_projects.ProjectDialogEdit(id: _, ..), ..) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_error(model.projects_dialog, message),
      ),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

// =============================================================================
// Project Delete Handlers (Story 4.8 AC39)
// =============================================================================

/// Handle project delete confirm opened.
fn handle_project_delete_confirm_opened(
  model: admin_projects.Model,
  project_id: Int,
  project_name: String,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(
      model,
      DialogOpen(
        form: admin_projects.ProjectDialogDelete(
          id: project_id,
          name: project_name,
        ),
        operation: Idle,
      ),
    ),
    effect.none(),
  )
}

/// Handle project delete confirm closed.
fn handle_project_delete_confirm_closed(
  model: admin_projects.Model,
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(set_projects_dialog(model, DialogClosed(operation: Idle)), effect.none())
}

/// Handle project delete submission.
fn handle_project_delete_submitted(
  model: admin_projects.Model,
  context: Context(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  case model.projects_dialog {
    DialogOpen(
      form: admin_projects.ProjectDialogDelete(id: project_id, name: _name),
      operation: op,
    ) ->
      case operation_in_flight(op) {
        True -> #(model, effect.none())
        False -> {
          let model =
            set_projects_dialog(
              model,
              update_project_dialog_in_flight(model.projects_dialog),
            )
          #(
            model,
            api_projects.delete_project(project_id, context.on_project_deleted),
          )
        }
      }
    _ -> #(model, effect.none())
  }
}

/// Handle project deleted success.
fn handle_project_deleted_ok(
  model: admin_projects.Model,
  feedback: FeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  #(
    set_projects_dialog(model, DialogClosed(operation: Idle)),
    success_effect(ProjectDeleted, feedback),
  )
}

/// Handle project deleted error.
fn handle_project_deleted_error(
  model: admin_projects.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_projects.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  case model.projects_dialog {
    DialogOpen(form: admin_projects.ProjectDialogDelete(id: _, name: _), ..) -> #(
      set_projects_dialog(
        model,
        update_project_dialog_idle(model.projects_dialog),
      ),
      delete_error_effect(err, message, feedback),
    )
    _ -> #(model, effect.none())
  }
}

// =============================================================================
// Dialog Helpers
// =============================================================================

fn operation_in_flight(operation: OperationState) -> Bool {
  case operation {
    InFlight -> True
    _ -> False
  }
}

fn set_projects_dialog(
  _model: admin_projects.Model,
  dialog: DialogState(admin_projects.ProjectDialogForm),
) -> admin_projects.Model {
  admin_projects.Model(projects_dialog: dialog)
}

fn update_project_dialog_error(
  dialog: DialogState(admin_projects.ProjectDialogForm),
  message: String,
) -> DialogState(admin_projects.ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) ->
      DialogOpen(form: form, operation: OpError(message))
    DialogClosed(..) -> DialogClosed(operation: OpError(message))
  }
}

fn update_project_dialog_in_flight(
  dialog: DialogState(admin_projects.ProjectDialogForm),
) -> DialogState(admin_projects.ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) -> DialogOpen(form: form, operation: InFlight)
    DialogClosed(..) -> DialogClosed(operation: InFlight)
  }
}

fn update_project_dialog_idle(
  dialog: DialogState(admin_projects.ProjectDialogForm),
) -> DialogState(admin_projects.ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) -> DialogOpen(form: form, operation: Idle)
    DialogClosed(..) -> DialogClosed(operation: Idle)
  }
}

fn success_effect(
  success: Success,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(success_message(success, context))
}

fn error_message(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

fn forbidden_warning_effect(
  err: ApiError,
  message: String,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(message)
    _ -> effect.none()
  }
}

fn delete_error_effect(
  err: ApiError,
  message: String,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(message)
    _ -> feedback.on_error_toast(message)
  }
}

fn success_message(success: Success, context: FeedbackContext(parent_msg)) {
  case success {
    ProjectCreated -> context.project_created
    ProjectUpdated -> context.project_updated
    ProjectDeleted -> context.project_deleted
  }
}

fn project_dialog_delete_id(
  dialog: DialogState(admin_projects.ProjectDialogForm),
) -> opt.Option(Int) {
  case dialog {
    DialogOpen(form: admin_projects.ProjectDialogDelete(id: id, name: _), ..) ->
      opt.Some(id)
    _ -> opt.None
  }
}
