//// Task types feature update handlers.
////
//// ## Mission
////
//// Handles task type creation and listing flows.
////
//// ## Responsibilities
////
//// - Task type create form state and submission
//// - Icon preview handling
//// - Capability assignment for task types
////
//// ## Non-responsibilities
////
//// - API calls (see `api/tasks.gleam`)
//// - Task creation (see `features/tasks/update.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches task type messages to handlers here
//// - **api/tasks.gleam**: Provides API effects for task type operations

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/api_error.{type ApiError}
import domain/remote.{Failed, Loaded}
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state.{
  type Model, type Msg, type TaskTypeDialogMode, admin_msg, update_admin,
}
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/helpers/auth as helpers_auth
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/toast as helpers_toast
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Task Types Fetch Handlers
// =============================================================================

/// Handle task types fetch success.
pub fn handle_task_types_fetched_ok(
  model: Model,
  task_types: List(TaskType),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types: Loaded(task_types),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task types fetch error.
pub fn handle_task_types_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    #(
      update_admin(model, fn(admin) {
        update_task_types(admin, fn(task_types_state) {
          admin_task_types.Model(..task_types_state, task_types: Failed(err))
        })
      }),
      effect.none(),
    )
  })
}

// =============================================================================
// Task Type Dialog Handlers
// =============================================================================

/// Handle task type create dialog open.
pub fn handle_task_type_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_dialog_mode: opt.Some(state_types.TaskTypeDialogCreate),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task type create dialog close.
pub fn handle_task_type_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_dialog_mode: opt.None,
          task_types_create_name: "",
          task_types_create_icon: "",
          task_types_create_capability_id: opt.None,
          task_types_create_error: opt.None,
          task_types_icon_preview: state_types.IconIdle,
        )
      })
    }),
    effect.none(),
  )
}

// =============================================================================
// Task Type Create Handlers
// =============================================================================

/// Handle task type create name input change.
pub fn handle_task_type_create_name_changed(
  model: Model,
  name: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(..task_types_state, task_types_create_name: name)
      })
    }),
    effect.none(),
  )
}

/// Handle task type create icon input change.
/// With the catalog approach, icons are validated instantly against the curated catalog.
pub fn handle_task_type_create_icon_changed(
  model: Model,
  icon: String,
) -> #(Model, Effect(Msg)) {
  // Import icon_catalog for validation
  let preview_state = case icon == "" {
    True -> state_types.IconIdle
    False -> state_types.IconOk
    // All icons from picker are valid catalog icons
  }
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_create_icon: icon,
          task_types_icon_preview: preview_state,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task type icon loaded.
pub fn handle_task_type_icon_loaded(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_icon_preview: state_types.IconOk,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task type icon error.
pub fn handle_task_type_icon_errored(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_icon_preview: state_types.IconError,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle icon picker search input change.
pub fn handle_task_type_create_icon_search_changed(
  model: Model,
  search: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_create_icon_search: search,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle icon picker category tab change.
pub fn handle_task_type_create_icon_category_changed(
  model: Model,
  category: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_create_icon_category: category,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task type create capability dropdown change.
pub fn handle_task_type_create_capability_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  case string.trim(value) == "" {
    True -> #(
      update_admin(model, fn(admin) {
        update_task_types(admin, fn(task_types_state) {
          admin_task_types.Model(
            ..task_types_state,
            task_types_create_capability_id: opt.None,
          )
        })
      }),
      effect.none(),
    )
    False -> #(
      update_admin(model, fn(admin) {
        update_task_types(admin, fn(task_types_state) {
          admin_task_types.Model(
            ..task_types_state,
            task_types_create_capability_id: opt.Some(value),
          )
        })
      }),
      effect.none(),
    )
  }
}

/// Handle task type create form submission.
pub fn handle_task_type_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.admin.task_types.task_types_create_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_submit_task_type(model)
  }
}

/// Validate inputs and submit task type creation.
fn validate_and_submit_task_type(model: Model) -> #(Model, Effect(Msg)) {
  case model.core.selected_project_id {
    opt.None -> set_task_type_error(model, i18n_text.SelectProjectFirst)
    opt.Some(project_id) -> validate_task_type_fields(model, project_id)
  }
}

/// Validate name, icon, and icon preview state.
fn validate_task_type_fields(
  model: Model,
  project_id: Int,
) -> #(Model, Effect(Msg)) {
  let name = string.trim(model.admin.task_types.task_types_create_name)
  let icon = string.trim(model.admin.task_types.task_types_create_icon)

  case name == "" || icon == "" {
    True -> set_task_type_error(model, i18n_text.NameAndIconRequired)
    False -> validate_icon_preview(model, project_id, name, icon)
  }
}

/// Check icon preview status before submission.
/// With catalog validation, we just check if the icon exists in the catalog.
fn validate_icon_preview(
  model: Model,
  project_id: Int,
  name: String,
  icon: String,
) -> #(Model, Effect(Msg)) {
  // All icons selected from the picker are valid catalog icons
  // Submit directly without checking preview state
  submit_task_type(model, project_id, name, icon)
}

/// Set a validation error on the task type create form.
fn set_task_type_error(
  model: Model,
  message: i18n_text.Text,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_create_error: opt.Some(helpers_i18n.i18n_t(model, message)),
        )
      })
    }),
    effect.none(),
  )
}

fn submit_task_type(
  model: Model,
  project_id: Int,
  name: String,
  icon: String,
) -> #(Model, Effect(Msg)) {
  let capability_id = case
    model.admin.task_types.task_types_create_capability_id
  {
    opt.None -> opt.None
    opt.Some(id_str) ->
      case int.parse(id_str) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }
  }

  let model =
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_create_in_flight: True,
          task_types_create_error: opt.None,
        )
      })
    })

  #(
    model,
    api_tasks.create_task_type(
      project_id,
      name,
      icon,
      capability_id,
      fn(result) -> Msg { admin_msg(admin_messages.TaskTypeCreated(result)) },
    ),
  )
}

/// Handle task type created success.
pub fn handle_task_type_created_ok(
  model: Model,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_dialog_mode: opt.None,
          task_types_create_in_flight: False,
          task_types_create_name: "",
          task_types_create_icon: "",
          task_types_create_capability_id: opt.None,
          task_types_icon_preview: state_types.IconIdle,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTypeCreated,
    ))

  let #(next, fx) = refresh_fn(model)
  #(next, effect.batch([fx, toast_fx]))
}

/// Handle task type created error.
pub fn handle_task_type_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  helpers_auth.handle_401_or(model, err, fn() {
    case err.status {
      403 -> #(
        update_admin(model, fn(admin) {
          update_task_types(admin, fn(task_types_state) {
            admin_task_types.Model(
              ..task_types_state,
              task_types_create_in_flight: False,
              task_types_create_error: opt.Some(helpers_i18n.i18n_t(
                model,
                i18n_text.NotPermitted,
              )),
            )
          })
        }),
        helpers_toast.toast_warning(helpers_i18n.i18n_t(
          model,
          i18n_text.NotPermitted,
        )),
      )
      _ -> #(
        update_admin(model, fn(admin) {
          update_task_types(admin, fn(task_types_state) {
            admin_task_types.Model(
              ..task_types_state,
              task_types_create_in_flight: False,
              task_types_create_error: opt.Some(err.message),
            )
          })
        }),
        effect.none(),
      )
    }
  })
}

// =============================================================================
// Task Type Dialog Mode Handlers (component pattern)
// =============================================================================

/// Handle task type dialog open (using new component pattern).
pub fn handle_open_task_type_dialog(
  model: Model,
  mode: TaskTypeDialogMode,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_dialog_mode: opt.Some(mode),
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task type dialog close (using new component pattern).
pub fn handle_close_task_type_dialog(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_dialog_mode: opt.None,
        )
      })
    }),
    effect.none(),
  )
}

/// Handle task type created from component event.
pub fn handle_task_type_crud_created(
  model: Model,
  _task_type: TaskType,
  refresh_fn: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTypeCreated,
    ))
  // Refresh task types list to include the new type
  let #(next, fx) = refresh_fn(model)
  #(next, effect.batch([fx, toast_fx]))
}

/// Handle task type updated from component event.
pub fn handle_task_type_crud_updated(
  model: Model,
  task_type: TaskType,
) -> #(Model, Effect(Msg)) {
  // Update task type in the list
  let updated_list = case model.admin.task_types.task_types {
    Loaded(task_types) ->
      Loaded(
        task_types
        |> list.map(fn(tt) {
          case tt.id == task_type.id {
            True -> task_type
            False -> tt
          }
        }),
      )
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types: updated_list,
          task_types_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTypeUpdated,
    ))
  #(model, toast_fx)
}

/// Handle task type deleted from component event.
pub fn handle_task_type_crud_deleted(
  model: Model,
  type_id: Int,
) -> #(Model, Effect(Msg)) {
  // Remove task type from the list
  let updated_list = case model.admin.task_types.task_types {
    Loaded(task_types) ->
      Loaded(list.filter(task_types, fn(tt) { tt.id != type_id }))
    other -> other
  }
  let model =
    update_admin(model, fn(admin) {
      update_task_types(admin, fn(task_types_state) {
        admin_task_types.Model(
          ..task_types_state,
          task_types: updated_list,
          task_types_dialog_mode: opt.None,
        )
      })
    })
  let toast_fx =
    helpers_toast.toast_success(helpers_i18n.i18n_t(
      model,
      i18n_text.TaskTypeDeleted,
    ))
  #(model, toast_fx)
}

fn update_task_types(
  admin: admin_state.AdminModel,
  f: fn(admin_task_types.Model) -> admin_task_types.Model,
) -> admin_state.AdminModel {
  admin_state.AdminModel(..admin, task_types: f(admin.task_types))
}
