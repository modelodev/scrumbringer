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

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/api_error.{type ApiError}
import domain/project.{type Project}
import scrumbringer_client/client_state.{
  type Model, type Msg, Admin, AdminModel, CoreModel, Failed, Loaded, Login,
  Member, MemberModel, ProjectCreated, ProjectDeleted, ProjectDialogClosed,
  ProjectDialogCreate, ProjectDialogDelete, ProjectDialogEdit, ProjectUpdated,
  admin_msg, pool_msg, update_admin, update_core, update_member,
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
      model.core.selected_project_id,
      projects,
    )
  let model =
    update_core(model, fn(core) {
      CoreModel(
        ..core,
        projects: Loaded(projects),
        selected_project_id: selected,
      )
    })

  let model = update_helpers.ensure_default_section(model)

  case model.core.page {
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
          update_core(model, fn(core) {
            CoreModel(..core, page: Login, user: opt.None)
          }),
        )
      #(model, replace_url_fn(model))
    }

    False -> #(
      update_core(model, fn(core) { CoreModel(..core, projects: Failed(err)) }),
      effect.none(),
    )
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
      model.core.page == Member,
      model.core.selected_project_id,
      selected,
    )

  let model = case selected {
    opt.None ->
      update_member(
        update_core(model, fn(core) {
          CoreModel(..core, selected_project_id: selected)
        }),
        fn(member) {
          MemberModel(
            ..member,
            member_filters_type_id: "",
            member_task_types: client_state.NotAsked,
          )
        },
      )
    _ ->
      update_core(model, fn(core) {
        CoreModel(..core, selected_project_id: selected)
      })
  }

  case model.core.page {
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
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        projects_dialog: ProjectDialogCreate("", False, opt.None),
      )
    }),
    effect.none(),
  )
}

/// Handle project create dialog closed.
pub fn handle_project_create_dialog_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, projects_dialog: ProjectDialogClosed)
    }),
    effect.none(),
  )
}

/// Handle project create name input change.
pub fn handle_project_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  let next_state = case model.admin.projects_dialog {
    ProjectDialogCreate(_name, in_flight, error) ->
      ProjectDialogCreate(name, in_flight, error)
    other -> other
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, projects_dialog: next_state)
    }),
    effect.none(),
  )
}

/// Handle project create form submission.
pub fn handle_project_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.projects_dialog {
    ProjectDialogCreate(name, in_flight, _error) -> {
      case in_flight {
        True -> #(model, effect.none())
        False -> {
          case
            update_helpers.validate_required_string(
              model,
              name,
              i18n_text.NameRequired,
            )
          {
            Error(err) -> #(
              update_admin(model, fn(admin) {
                AdminModel(
                  ..admin,
                  projects_dialog: ProjectDialogCreate(
                    name,
                    False,
                    opt.Some(err),
                  ),
                )
              }),
              effect.none(),
            )
            Ok(non_empty) -> {
              let trimmed = update_helpers.non_empty_string_value(non_empty)
              let model =
                update_admin(model, fn(admin) {
                  AdminModel(
                    ..admin,
                    projects_dialog: ProjectDialogCreate(name, True, opt.None),
                  )
                })
              #(
                model,
                api_projects.create_project(trimmed, fn(result) {
                  admin_msg(ProjectCreated(result))
                }),
              )
            }
          }
        }
      }
    }
    _ -> #(model, effect.none())
  }
}

/// Handle project created success.
pub fn handle_project_created_ok(
  model: Model,
  project: Project,
) -> #(Model, Effect(Msg)) {
  let updated_projects = case model.core.projects {
    Loaded(projects) -> [project, ..projects]
    _ -> [project]
  }

  let model =
    update_admin(
      update_core(model, fn(core) {
        CoreModel(
          ..core,
          projects: Loaded(updated_projects),
          selected_project_id: opt.Some(project.id),
        )
      }),
      fn(admin) { AdminModel(..admin, projects_dialog: ProjectDialogClosed) },
    )
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.ProjectCreated,
    ))
  #(model, toast_fx)
}

/// Handle project created error.
pub fn handle_project_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 ->
      case model.admin.projects_dialog {
        ProjectDialogCreate(name, _in_flight, _error) -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              projects_dialog: ProjectDialogCreate(
                name,
                False,
                opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
              ),
            )
          }),
          update_helpers.toast_warning(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          )),
        )
        _ -> #(model, effect.none())
      }
    _ ->
      case model.admin.projects_dialog {
        ProjectDialogCreate(name, _in_flight, _error) -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              projects_dialog: ProjectDialogCreate(
                name,
                False,
                opt.Some(err.message),
              ),
            )
          }),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
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
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        projects_dialog: ProjectDialogEdit(
          project_id,
          project_name,
          False,
          opt.None,
        ),
      )
    }),
    effect.none(),
  )
}

/// Handle project edit dialog closed.
pub fn handle_project_edit_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, projects_dialog: ProjectDialogClosed)
    }),
    effect.none(),
  )
}

/// Handle project edit name input change.
pub fn handle_project_edit_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  let next_state = case model.admin.projects_dialog {
    ProjectDialogEdit(id, _name, in_flight, error) ->
      ProjectDialogEdit(id, name, in_flight, error)
    other -> other
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, projects_dialog: next_state)
    }),
    effect.none(),
  )
}

/// Handle project edit form submission.
pub fn handle_project_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.projects_dialog {
    ProjectDialogEdit(project_id, name, in_flight, _error) -> {
      case in_flight {
        True -> #(model, effect.none())
        False -> {
          case
            update_helpers.validate_required_string(
              model,
              name,
              i18n_text.NameRequired,
            )
          {
            Error(err) -> #(
              update_admin(model, fn(admin) {
                AdminModel(
                  ..admin,
                  projects_dialog: ProjectDialogEdit(
                    project_id,
                    name,
                    False,
                    opt.Some(err),
                  ),
                )
              }),
              effect.none(),
            )
            Ok(non_empty) -> {
              let trimmed = update_helpers.non_empty_string_value(non_empty)
              let model =
                update_admin(model, fn(admin) {
                  AdminModel(
                    ..admin,
                    projects_dialog: ProjectDialogEdit(
                      project_id,
                      name,
                      True,
                      opt.None,
                    ),
                  )
                })
              #(
                model,
                api_projects.update_project(project_id, trimmed, fn(result) {
                  admin_msg(ProjectUpdated(result))
                }),
              )
            }
          }
        }
      }
    }
    _ -> #(model, effect.none())
  }
}

/// Handle project updated success.
pub fn handle_project_updated_ok(
  model: Model,
  project: Project,
) -> #(Model, Effect(Msg)) {
  // Update the project in the list
  let updated_projects = case model.core.projects {
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

  let model =
    update_admin(
      update_core(model, fn(core) {
        CoreModel(..core, projects: Loaded(updated_projects))
      }),
      fn(admin) { AdminModel(..admin, projects_dialog: ProjectDialogClosed) },
    )
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(model, i18n_text.Saved))
  #(model, toast_fx)
}

/// Handle project updated error.
pub fn handle_project_updated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 ->
      case model.admin.projects_dialog {
        ProjectDialogEdit(id, name, _in_flight, _error) -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              projects_dialog: ProjectDialogEdit(
                id,
                name,
                False,
                opt.Some(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
              ),
            )
          }),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
    _ ->
      case model.admin.projects_dialog {
        ProjectDialogEdit(id, name, _in_flight, _error) -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              projects_dialog: ProjectDialogEdit(
                id,
                name,
                False,
                opt.Some(err.message),
              ),
            )
          }),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }
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
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        projects_dialog: ProjectDialogDelete(project_id, project_name, False),
      )
    }),
    effect.none(),
  )
}

/// Handle project delete confirm closed.
pub fn handle_project_delete_confirm_closed(
  model: Model,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, projects_dialog: ProjectDialogClosed)
    }),
    effect.none(),
  )
}

/// Handle project delete submission.
pub fn handle_project_delete_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.projects_dialog {
    ProjectDialogDelete(project_id, name, in_flight) -> {
      case in_flight {
        True -> #(model, effect.none())
        False -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: ProjectDialogDelete(project_id, name, True),
              )
            })
          #(
            model,
            api_projects.delete_project(project_id, fn(result) {
              admin_msg(ProjectDeleted(result))
            }),
          )
        }
      }
    }
    _ -> #(model, effect.none())
  }
}

/// Handle project deleted success.
pub fn handle_project_deleted_ok(model: Model) -> #(Model, Effect(Msg)) {
  let deleted_id = case model.admin.projects_dialog {
    ProjectDialogDelete(id, _name, _in_flight) -> opt.Some(id)
    _ -> opt.None
  }

  // Remove the project from the list
  let updated_projects = case model.core.projects {
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
  let selected = case model.core.selected_project_id, deleted_id {
    opt.Some(sel), opt.Some(del) if sel == del -> opt.None
    _, _ -> model.core.selected_project_id
  }

  let model =
    update_admin(
      update_core(model, fn(core) {
        CoreModel(
          ..core,
          projects: Loaded(updated_projects),
          selected_project_id: selected,
        )
      }),
      fn(admin) { AdminModel(..admin, projects_dialog: ProjectDialogClosed) },
    )
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(model, i18n_text.Deleted))
  #(model, toast_fx)
}

/// Handle project deleted error.
pub fn handle_project_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 ->
      case model.admin.projects_dialog {
        ProjectDialogDelete(id, name, _in_flight) -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              projects_dialog: ProjectDialogDelete(id, name, False),
            )
          }),
          update_helpers.toast_warning(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          )),
        )
        _ -> #(model, effect.none())
      }
    _ ->
      case model.admin.projects_dialog {
        ProjectDialogDelete(id, name, _in_flight) -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              projects_dialog: ProjectDialogDelete(id, name, False),
            )
          }),
          update_helpers.toast_error(err.message),
        )
        _ -> #(model, effect.none())
      }
  }
}
