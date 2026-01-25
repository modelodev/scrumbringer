//// Projects feature update handlers.
////
//// ## Mission
////
//// Handles project creation and selection flows.
////
//// ## Responsibilities
////
//// - Project create form state and submission
//// - Project selection handling
//// - Project fetch responses
////
//// ## Non-responsibilities
////
//// - API calls (see `api/projects.gleam`, `api/tasks.gleam`)
//// - Navigation (see `client_update.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches project messages to handlers here
//// - **api/projects.gleam**: Provides API effects for project operations

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/api_error.{type ApiError}
import domain/project.{type Project}
import scrumbringer_client/client_state.{
  type Model, type Msg, Admin, Failed, Loaded, Login, Member, Model,
  ProjectCreated, ProjectDeleted, ProjectUpdated, admin_msg, pool_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Projects Fetch Handlers
// =============================================================================

/// Handle projects fetch success.
pub fn handle_projects_fetched_ok(
  model: Model,
  projects: List(Project),
  member_refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
  admin_refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
  hydrate_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  let selected =
    update_helpers.ensure_selected_project(model.selected_project_id, projects)
  let model =
    Model(..model, projects: Loaded(projects), selected_project_id: selected)

  let model = update_helpers.ensure_default_section(model)

  case model.page {
    Member -> {
      let #(model, fx) = member_refresh_fn(model)
      let #(model, hyd_fx) = hydrate_fn(model)
      #(model, effect.batch([fx, hyd_fx, replace_url_fn(model)]))
    }

    Admin -> {
      let #(model, fx) = admin_refresh_fn(model)
      let #(model, hyd_fx) = hydrate_fn(model)
      #(model, effect.batch([fx, hyd_fx, replace_url_fn(model)]))
    }

    _ -> {
      let #(model, hyd_fx) = hydrate_fn(model)
      #(model, effect.batch([hyd_fx, replace_url_fn(model)]))
    }
  }
}

/// Handle projects fetch error.
pub fn handle_projects_fetched_error(
  model: Model,
  err: ApiError,
  replace_url_fn: fn(Model) -> Effect(Msg),
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> {
      let model =
        update_helpers.clear_drag_state(
          Model(..model, page: Login, user: opt.None),
        )
      #(model, replace_url_fn(model))
    }

    False -> #(Model(..model, projects: Failed(err)), effect.none())
  }
}

// =============================================================================
// Project Selection Handlers
// =============================================================================

/// Handle project selection.
pub fn handle_project_selected(
  model: Model,
  project_id: String,
  member_refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
  admin_refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
  replace_url_fn: fn(Model) -> Effect(Msg),
  should_pause_fn: fn(Bool, opt.Option(Int), opt.Option(Int)) -> Bool,
) -> #(Model, Effect(Msg)) {
  let selected = case int.parse(project_id) {
    Ok(id) -> opt.Some(id)
    Error(_) -> opt.None
  }

  let should_pause =
    should_pause_fn(model.page == Member, model.selected_project_id, selected)

  let model = case selected {
    opt.None ->
      Model(
        ..model,
        selected_project_id: selected,
        toast: opt.None,
        member_filters_type_id: "",
        member_task_types: client_state.NotAsked,
      )
    _ -> Model(..model, selected_project_id: selected, toast: opt.None)
  }

  case model.page {
    Member -> {
      let #(model, fx) = member_refresh_fn(model)

      let pause_fx = case should_pause {
        True ->
          api_tasks.pause_me_active_task(fn(result) {
            pool_msg(client_state.MemberActiveTaskPaused(result))
          })
        False -> effect.none()
      }

      #(model, effect.batch([fx, pause_fx, replace_url_fn(model)]))
    }

    _ -> {
      let #(model, fx) = admin_refresh_fn(model)
      #(model, effect.batch([fx, replace_url_fn(model)]))
    }
  }
}

// =============================================================================
// Project Create Handlers
// =============================================================================

/// Handle project create dialog opened.
pub fn handle_project_create_dialog_opened(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, projects_create_dialog_open: True), effect.none())
}

/// Handle project create dialog closed.
pub fn handle_project_create_dialog_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      projects_create_dialog_open: False,
      projects_create_name: "",
      projects_create_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle project create name input change.
pub fn handle_project_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, projects_create_name: name), effect.none())
}

/// Handle project create form submission.
pub fn handle_project_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.projects_create_in_flight {
    True -> #(model, effect.none())
    False -> {
      let name = string.trim(model.projects_create_name)

      case name == "" {
        True -> #(
          Model(
            ..model,
            projects_create_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NameRequired,
            )),
          ),
          effect.none(),
        )
        False -> {
          let model =
            Model(
              ..model,
              projects_create_in_flight: True,
              projects_create_error: opt.None,
            )
          #(
            model,
            api_projects.create_project(name, fn(result) {
              admin_msg(ProjectCreated(result))
            }),
          )
        }
      }
    }
  }
}

/// Handle project created success.
pub fn handle_project_created_ok(
  model: Model,
  project: Project,
) -> #(Model, Effect(Msg)) {
  let updated_projects = case model.projects {
    Loaded(projects) -> [project, ..projects]
    _ -> [project]
  }

  #(
    Model(
      ..model,
      projects: Loaded(updated_projects),
      selected_project_id: opt.Some(project.id),
      projects_create_dialog_open: False,
      projects_create_in_flight: False,
      projects_create_name: "",
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.ProjectCreated)),
    ),
    effect.none(),
  )
}

/// Handle project created error.
pub fn handle_project_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        projects_create_in_flight: False,
        projects_create_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        projects_create_in_flight: False,
        projects_create_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Project Edit Handlers (Story 4.8 AC39)
// =============================================================================

/// Handle project edit dialog opened.
pub fn handle_project_edit_dialog_opened(
  model: Model,
  project_id: Int,
  project_name: String,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      projects_edit_dialog_open: True,
      projects_edit_id: opt.Some(project_id),
      projects_edit_name: project_name,
      projects_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle project edit dialog closed.
pub fn handle_project_edit_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      projects_edit_dialog_open: False,
      projects_edit_id: opt.None,
      projects_edit_name: "",
      projects_edit_error: opt.None,
    ),
    effect.none(),
  )
}

/// Handle project edit name input change.
pub fn handle_project_edit_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, projects_edit_name: name), effect.none())
}

/// Handle project edit form submission.
pub fn handle_project_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.projects_edit_in_flight, model.projects_edit_id {
    True, _ -> #(model, effect.none())
    _, opt.None -> #(model, effect.none())
    False, opt.Some(project_id) -> {
      let name = string.trim(model.projects_edit_name)

      case name == "" {
        True -> #(
          Model(
            ..model,
            projects_edit_error: opt.Some(update_helpers.i18n_t(
              model,
              i18n_text.NameRequired,
            )),
          ),
          effect.none(),
        )
        False -> {
          let model =
            Model(
              ..model,
              projects_edit_in_flight: True,
              projects_edit_error: opt.None,
            )
          #(
            model,
            api_projects.update_project(project_id, name, fn(result) {
              admin_msg(ProjectUpdated(result))
            }),
          )
        }
      }
    }
  }
}

/// Handle project updated success.
pub fn handle_project_updated_ok(
  model: Model,
  project: Project,
) -> #(Model, Effect(Msg)) {
  // Update the project in the list
  let updated_projects = case model.projects {
    Loaded(projects) ->
      projects
      |> list.map(fn(p) {
        case p.id == project.id {
          True -> project.Project(..p, name: project.name)
          False -> p
        }
      })
    _ -> []
  }

  #(
    Model(
      ..model,
      projects: Loaded(updated_projects),
      projects_edit_dialog_open: False,
      projects_edit_in_flight: False,
      projects_edit_id: opt.None,
      projects_edit_name: "",
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.Saved)),
    ),
    effect.none(),
  )
}

/// Handle project updated error.
pub fn handle_project_updated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        projects_edit_in_flight: False,
        projects_edit_error: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        projects_edit_in_flight: False,
        projects_edit_error: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}

// =============================================================================
// Project Delete Handlers (Story 4.8 AC39)
// =============================================================================

/// Handle project delete confirm opened.
pub fn handle_project_delete_confirm_opened(
  model: Model,
  project_id: Int,
  project_name: String,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      projects_delete_confirm_open: True,
      projects_delete_id: opt.Some(project_id),
      projects_delete_name: project_name,
    ),
    effect.none(),
  )
}

/// Handle project delete confirm closed.
pub fn handle_project_delete_confirm_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      projects_delete_confirm_open: False,
      projects_delete_id: opt.None,
      projects_delete_name: "",
    ),
    effect.none(),
  )
}

/// Handle project delete submission.
pub fn handle_project_delete_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.projects_delete_in_flight, model.projects_delete_id {
    True, _ -> #(model, effect.none())
    _, opt.None -> #(model, effect.none())
    False, opt.Some(project_id) -> {
      let model = Model(..model, projects_delete_in_flight: True)
      #(
        model,
        api_projects.delete_project(project_id, fn(result) {
          admin_msg(ProjectDeleted(result))
        }),
      )
    }
  }
}

/// Handle project deleted success.
pub fn handle_project_deleted_ok(model: Model) -> #(Model, Effect(Msg)) {
  let deleted_id = model.projects_delete_id

  // Remove the project from the list
  let updated_projects = case model.projects {
    Loaded(projects) ->
      projects
      |> list.filter(fn(p) {
        case deleted_id {
          opt.Some(id) -> p.id != id
          opt.None -> True
        }
      })
    _ -> []
  }

  // Clear selection if the deleted project was selected
  let selected = case model.selected_project_id, deleted_id {
    opt.Some(sel), opt.Some(del) if sel == del -> opt.None
    _, _ -> model.selected_project_id
  }

  #(
    Model(
      ..model,
      projects: Loaded(updated_projects),
      selected_project_id: selected,
      projects_delete_confirm_open: False,
      projects_delete_in_flight: False,
      projects_delete_id: opt.None,
      projects_delete_name: "",
      toast: opt.Some(update_helpers.i18n_t(model, i18n_text.Deleted)),
    ),
    effect.none(),
  )
}

/// Handle project deleted error.
pub fn handle_project_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      Model(
        ..model,
        projects_delete_in_flight: False,
        toast: opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
      ),
      effect.none(),
    )
    _ -> #(
      Model(
        ..model,
        projects_delete_in_flight: False,
        toast: opt.Some(err.message),
      ),
      effect.none(),
    )
  }
}
