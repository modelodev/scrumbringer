//// User Projects dialog handlers.
////
//// ## Mission
////
//// Provides handlers for viewing and managing a user's project memberships
//// from the org settings section.
////
//// ## Responsibilities
////
//// - Open/close user projects dialog
//// - Fetch user's projects
//// - Add user to projects
//// - Remove user from projects
////
//// ## Relations
////
//// - **features/admin/update.gleam**: Re-exports these handlers
//// - **api/org.gleam**: API functions for user projects

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError}
import domain/org.{type OrgUser}
import domain/project.{type Project}
import scrumbringer_client/api/org as api_org
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, Loaded, Loading, Model, NotAsked,
  UserProjectAdded, UserProjectRemoved, UserProjectsFetched,
}

// =============================================================================
// Dialog Open/Close
// =============================================================================

/// Handle opening the user projects dialog.
pub fn handle_user_projects_dialog_opened(
  model: Model,
  user: OrgUser,
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      user_projects_dialog_open: True,
      user_projects_dialog_user: opt.Some(user),
      user_projects_list: Loading,
      user_projects_add_project_id: opt.None,
      user_projects_in_flight: False,
      user_projects_error: opt.None,
    )

  #(model, api_org.list_user_projects(user.id, UserProjectsFetched))
}

/// Handle closing the user projects dialog.
pub fn handle_user_projects_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      user_projects_dialog_open: False,
      user_projects_dialog_user: opt.None,
      user_projects_list: NotAsked,
      user_projects_add_project_id: opt.None,
      user_projects_in_flight: False,
      user_projects_error: opt.None,
    ),
    effect.none(),
  )
}

// =============================================================================
// Fetch User Projects
// =============================================================================

/// Handle successful user projects fetch.
pub fn handle_user_projects_fetched_ok(
  model: Model,
  projects: List(Project),
) -> #(Model, Effect(Msg)) {
  #(Model(..model, user_projects_list: Loaded(projects)), effect.none())
}

/// Handle user projects fetch error.
pub fn handle_user_projects_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  #(
    Model(..model, user_projects_list: Failed(err), user_projects_error: opt.Some(err.message)),
    effect.none(),
  )
}

// =============================================================================
// Add User to Project
// =============================================================================

/// Handle project selection change for add.
pub fn handle_user_projects_add_project_changed(
  model: Model,
  project_id_str: String,
) -> #(Model, Effect(Msg)) {
  let project_id = case int.parse(project_id_str) {
    Ok(id) -> opt.Some(id)
    Error(_) -> opt.None
  }

  #(Model(..model, user_projects_add_project_id: project_id), effect.none())
}

/// Handle submit add user to project.
pub fn handle_user_projects_add_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.user_projects_dialog_user, model.user_projects_add_project_id {
    opt.Some(user), opt.Some(project_id) -> {
      let model =
        Model(..model, user_projects_in_flight: True, user_projects_error: opt.None)

      #(model, api_org.add_user_to_project(user.id, project_id, UserProjectAdded))
    }

    _, _ -> #(model, effect.none())
  }
}

/// Handle successful add user to project.
pub fn handle_user_project_added_ok(
  model: Model,
  project: Project,
) -> #(Model, Effect(Msg)) {
  let updated_projects = case model.user_projects_list {
    Loaded(projects) -> Loaded(list.append(projects, [project]))
    other -> other
  }

  #(
    Model(
      ..model,
      user_projects_list: updated_projects,
      user_projects_add_project_id: opt.None,
      user_projects_in_flight: False,
    ),
    effect.none(),
  )
}

/// Handle add user to project error.
pub fn handle_user_project_added_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      user_projects_in_flight: False,
      user_projects_error: opt.Some(err.message),
    ),
    effect.none(),
  )
}

// =============================================================================
// Remove User from Project
// =============================================================================

/// Handle remove user from project click.
pub fn handle_user_project_remove_clicked(
  model: Model,
  project_id: Int,
) -> #(Model, Effect(Msg)) {
  case model.user_projects_dialog_user {
    opt.Some(user) -> {
      let model =
        Model(..model, user_projects_in_flight: True, user_projects_error: opt.None)

      #(
        model,
        api_org.remove_user_from_project(user.id, project_id, UserProjectRemoved),
      )
    }

    opt.None -> #(model, effect.none())
  }
}

/// Handle successful remove user from project.
pub fn handle_user_project_removed_ok(model: Model) -> #(Model, Effect(Msg)) {
  // Refetch the user's projects to get the updated list
  case model.user_projects_dialog_user {
    opt.Some(user) -> {
      let model =
        Model(..model, user_projects_list: Loading, user_projects_in_flight: False)

      #(model, api_org.list_user_projects(user.id, UserProjectsFetched))
    }

    opt.None -> #(Model(..model, user_projects_in_flight: False), effect.none())
  }
}

/// Handle remove user from project error.
pub fn handle_user_project_removed_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      user_projects_in_flight: False,
      user_projects_error: opt.Some(err.message),
    ),
    effect.none(),
  )
}
