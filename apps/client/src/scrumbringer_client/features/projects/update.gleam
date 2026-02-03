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
import domain/remote.{Failed, Loaded, NotAsked}
import scrumbringer_client/client_state.{
  type DialogState, type Model, type Msg, type OperationState,
  type ProjectDialogForm, Admin, AdminModel, CoreModel, DialogClosed, DialogOpen,
  Error as OpError, Idle, InFlight, Login, Member, MemberModel, ProjectCreated,
  ProjectDeleted, ProjectDialogCreate, ProjectDialogDelete, ProjectDialogEdit,
  ProjectUpdated, admin_msg, pool_msg, update_admin, update_core, update_member,
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

// Justification: nested case improves clarity for branching logic.
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
            member_filters_type_id: opt.None,
            member_task_types: NotAsked,
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
          case update_helpers.now_working_active_task_id(model) {
            opt.Some(task_id) ->
              api_tasks.pause_work_session(task_id, fn(result) {
                pool_msg(client_state.MemberWorkSessionPaused(result))
              })
            opt.None -> effect.none()
          }
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
        projects_dialog: DialogOpen(
          form: ProjectDialogCreate(name: ""),
          operation: Idle,
        ),
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
      AdminModel(..admin, projects_dialog: DialogClosed(operation: Idle))
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
    DialogOpen(form: ProjectDialogCreate(name: _), operation: op) ->
      DialogOpen(form: ProjectDialogCreate(name: name), operation: op)
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
    DialogOpen(form: ProjectDialogCreate(name: name), operation: op) ->
      submit_project_create(model, name, operation_in_flight(op))
    _ -> #(model, effect.none())
  }
}

fn submit_project_create(
  model: Model,
  name: String,
  in_flight: Bool,
) -> #(Model, Effect(Msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> validate_project_create_name(model, name)
  }
}

fn validate_project_create_name(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  case
    update_helpers.validate_required_string(model, name, i18n_text.NameRequired)
  {
    Error(err) -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          projects_dialog: update_project_dialog_error(
            model.admin.projects_dialog,
            err,
          ),
        )
      }),
      effect.none(),
    )
    Ok(non_empty) -> submit_project_create_valid(model, name, non_empty)
  }
}

fn submit_project_create_valid(
  model: Model,
  _name: String,
  non_empty: update_helpers.NonEmptyString,
) -> #(Model, Effect(Msg)) {
  let trimmed = update_helpers.non_empty_string_value(non_empty)
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        projects_dialog: update_project_dialog_in_flight(
          model.admin.projects_dialog,
        ),
      )
    })
  #(
    model,
    api_projects.create_project(trimmed, fn(result) {
      admin_msg(ProjectCreated(result))
    }),
  )
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
      fn(admin) {
        AdminModel(..admin, projects_dialog: DialogClosed(operation: Idle))
      },
    )
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.ProjectCreated,
    ))
  #(model, toast_fx)
}

// Justification: nested case improves clarity for branching logic.
/// Handle project created error.
pub fn handle_project_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 ->
        case model.admin.projects_dialog {
          DialogOpen(form: ProjectDialogCreate(name: _), ..) -> #(
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_error(
                  model.admin.projects_dialog,
                  update_helpers.i18n_t(model, i18n_text.NotPermitted),
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
          DialogOpen(form: ProjectDialogCreate(name: _), ..) -> #(
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_error(
                  model.admin.projects_dialog,
                  err.message,
                ),
              )
            }),
            effect.none(),
          )
          _ -> #(model, effect.none())
        }
    }
  })
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
        projects_dialog: DialogOpen(
          form: ProjectDialogEdit(id: project_id, name: project_name),
          operation: Idle,
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
      AdminModel(..admin, projects_dialog: DialogClosed(operation: Idle))
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
    DialogOpen(form: ProjectDialogEdit(id: id, name: _), operation: op) ->
      DialogOpen(form: ProjectDialogEdit(id: id, name: name), operation: op)
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
    DialogOpen(
      form: ProjectDialogEdit(id: project_id, name: name),
      operation: op,
    ) -> submit_project_edit(model, project_id, name, operation_in_flight(op))
    _ -> #(model, effect.none())
  }
}

fn submit_project_edit(
  model: Model,
  project_id: Int,
  name: String,
  in_flight: Bool,
) -> #(Model, Effect(Msg)) {
  case in_flight {
    True -> #(model, effect.none())
    False -> validate_project_edit_name(model, project_id, name)
  }
}

fn validate_project_edit_name(
  model: Model,
  project_id: Int,
  name: String,
) -> #(Model, Effect(Msg)) {
  case
    update_helpers.validate_required_string(model, name, i18n_text.NameRequired)
  {
    Error(err) -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          projects_dialog: update_project_dialog_error(
            model.admin.projects_dialog,
            err,
          ),
        )
      }),
      effect.none(),
    )
    Ok(non_empty) ->
      submit_project_edit_valid(model, project_id, name, non_empty)
  }
}

fn submit_project_edit_valid(
  model: Model,
  project_id: Int,
  _name: String,
  non_empty: update_helpers.NonEmptyString,
) -> #(Model, Effect(Msg)) {
  let trimmed = update_helpers.non_empty_string_value(non_empty)
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        projects_dialog: update_project_dialog_in_flight(
          model.admin.projects_dialog,
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
      fn(admin) {
        AdminModel(..admin, projects_dialog: DialogClosed(operation: Idle))
      },
    )
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(model, i18n_text.Saved))
  #(model, toast_fx)
}

// Justification: nested case improves clarity for branching logic.
/// Handle project updated error.
pub fn handle_project_updated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 ->
        case model.admin.projects_dialog {
          DialogOpen(form: ProjectDialogEdit(id: _, name: _), ..) -> #(
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_error(
                  model.admin.projects_dialog,
                  update_helpers.i18n_t(model, i18n_text.NotPermitted),
                ),
              )
            }),
            effect.none(),
          )
          _ -> #(model, effect.none())
        }
      _ ->
        case model.admin.projects_dialog {
          DialogOpen(form: ProjectDialogEdit(id: _, name: _), ..) -> #(
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_error(
                  model.admin.projects_dialog,
                  err.message,
                ),
              )
            }),
            effect.none(),
          )
          _ -> #(model, effect.none())
        }
    }
  })
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
        projects_dialog: DialogOpen(
          form: ProjectDialogDelete(id: project_id, name: project_name),
          operation: Idle,
        ),
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
      AdminModel(..admin, projects_dialog: DialogClosed(operation: Idle))
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle project delete submission.
pub fn handle_project_delete_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.projects_dialog {
    DialogOpen(
      form: ProjectDialogDelete(id: project_id, name: _name),
      operation: op,
    ) ->
      case operation_in_flight(op) {
        True -> #(model, effect.none())
        False -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_in_flight(
                  model.admin.projects_dialog,
                ),
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
    _ -> #(model, effect.none())
  }
}

/// Handle project deleted success.
pub fn handle_project_deleted_ok(model: Model) -> #(Model, Effect(Msg)) {
  let deleted_id = project_dialog_delete_id(model.admin.projects_dialog)

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
      fn(admin) {
        AdminModel(..admin, projects_dialog: DialogClosed(operation: Idle))
      },
    )
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(model, i18n_text.Deleted))
  #(model, toast_fx)
}

// Justification: nested case improves clarity for branching logic.
/// Handle project deleted error.
pub fn handle_project_deleted_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  update_helpers.handle_401_or(model, err, fn() {
    case err.status {
      403 ->
        case model.admin.projects_dialog {
          DialogOpen(form: ProjectDialogDelete(id: _, name: _), ..) -> #(
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_idle(
                  model.admin.projects_dialog,
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
          DialogOpen(form: ProjectDialogDelete(id: _, name: _), ..) -> #(
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                projects_dialog: update_project_dialog_idle(
                  model.admin.projects_dialog,
                ),
              )
            }),
            update_helpers.toast_error(err.message),
          )
          _ -> #(model, effect.none())
        }
    }
  })
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

fn update_project_dialog_error(
  dialog: DialogState(ProjectDialogForm),
  message: String,
) -> DialogState(ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) ->
      DialogOpen(form: form, operation: OpError(message))
    DialogClosed(..) -> DialogClosed(operation: OpError(message))
  }
}

fn update_project_dialog_in_flight(
  dialog: DialogState(ProjectDialogForm),
) -> DialogState(ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) -> DialogOpen(form: form, operation: InFlight)
    DialogClosed(..) -> DialogClosed(operation: InFlight)
  }
}

fn update_project_dialog_idle(
  dialog: DialogState(ProjectDialogForm),
) -> DialogState(ProjectDialogForm) {
  case dialog {
    DialogOpen(form: form, ..) -> DialogOpen(form: form, operation: Idle)
    DialogClosed(..) -> DialogClosed(operation: Idle)
  }
}

fn project_dialog_delete_id(
  dialog: DialogState(ProjectDialogForm),
) -> opt.Option(Int) {
  case dialog {
    DialogOpen(form: ProjectDialogDelete(id: id, name: _), ..) -> opt.Some(id)
    _ -> opt.None
  }
}
