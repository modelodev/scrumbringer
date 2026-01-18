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
  type Model, type Msg, Admin, Failed, Loaded, Login, Member, Model, ProjectCreated,
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
    update_helpers.ensure_selected_project(
      model.selected_project_id,
      projects,
    )
  let model =
    Model(
      ..model,
      projects: Loaded(projects),
      selected_project_id: selected,
    )

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
        update_helpers.clear_drag_state(Model(..model, page: Login, user: opt.None))
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
    should_pause_fn(
      model.page == Member,
      model.selected_project_id,
      selected,
    )

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
        True -> api_tasks.pause_me_active_task(client_state.MemberActiveTaskPaused)
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
          #(model, api_projects.create_project(name, ProjectCreated))
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

