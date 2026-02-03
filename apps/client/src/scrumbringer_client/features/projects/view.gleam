//// Projects admin view.
////
//// ## Mission
////
//// Renders the projects management UI for org admins.
////
//// ## Responsibilities
////
//// - Projects list table with members count and creation date (AC38)
//// - Project creation dialog
//// - Project edit dialog (AC39)
//// - Project delete confirmation (AC39)
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to view_projects from admin section
//// - **features/projects/update.gleam**: Handles project messages

import gleam/int
import gleam/option as opt

import lustre/attribute
import lustre/element
import lustre/element/html.{button, div, form, input, p, text}
import lustre/event

import domain/project.{type Project}
import domain/project_role
import scrumbringer_client/client_state.{
  type Model, type Msg, ProjectCreateDialogClosed, ProjectCreateDialogOpened,
  ProjectCreateNameChanged, ProjectCreateSubmitted, ProjectDeleteConfirmClosed,
  ProjectDeleteConfirmOpened, ProjectDeleteSubmitted, ProjectEditDialogClosed,
  ProjectEditDialogOpened, ProjectEditNameChanged, ProjectEditSubmitted,
  admin_msg,
}
import scrumbringer_client/client_state/types.{
  type OperationState, DialogOpen, Error as OpError, InFlight,
  ProjectDialogCreate, ProjectDialogDelete, ProjectDialogEdit,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/format_date

// =============================================================================
// Public API
// =============================================================================

/// Main projects section view.
pub fn view_projects(model: Model) -> element.Element(Msg) {
  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Projects,
      update_helpers.i18n_t(model, i18n_text.Projects),
      dialog.add_button(
        model,
        i18n_text.CreateProject,
        admin_msg(ProjectCreateDialogOpened),
      ),
    ),
    // Projects list
    view_projects_list(model),
    // Dialogs
    view_project_dialogs(model),
  ])
}

/// Project dialogs (create/edit/delete) for reuse in other views.
pub fn view_project_dialogs(model: Model) -> element.Element(Msg) {
  element.fragment([
    view_projects_create_dialog(model),
    view_projects_edit_dialog(model),
    view_projects_delete_confirm(model),
  ])
}

// =============================================================================
// Private Helpers
// =============================================================================

/// Dialog for creating a new project.
fn view_projects_create_dialog(model: Model) -> element.Element(Msg) {
  let #(is_open, name, in_flight, error) = case model.admin.projects_dialog {
    DialogOpen(form: ProjectDialogCreate(name: name), operation: op) -> #(
      True,
      name,
      operation_in_flight(op),
      operation_error(op),
    )
    _ -> #(False, "", False, opt.None)
  }

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.CreateProject),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: admin_msg(ProjectCreateDialogClosed),
    ),
    is_open,
    error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { admin_msg(ProjectCreateSubmitted) }),
          attribute.id("project-create-form"),
        ],
        [
          form_field.view(
            update_helpers.i18n_t(model, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(name),
              event.on_input(fn(value) {
                admin_msg(ProjectCreateNameChanged(value))
              }),
              attribute.required(True),
              attribute.autofocus(True),
            ]),
          ),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, admin_msg(ProjectCreateDialogClosed)),
      button(
        [
          attribute.type_("submit"),
          attribute.form("project-create-form"),
          attribute.disabled(in_flight),
          attribute.class(case in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

/// Dialog for editing a project (Story 4.8 AC39).
fn view_projects_edit_dialog(model: Model) -> element.Element(Msg) {
  let #(is_open, name, in_flight, error) = case model.admin.projects_dialog {
    DialogOpen(form: ProjectDialogEdit(id: _, name: name), operation: op) -> #(
      True,
      name,
      operation_in_flight(op),
      operation_error(op),
    )
    _ -> #(False, "", False, opt.None)
  }

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.EditProject),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: admin_msg(ProjectEditDialogClosed),
    ),
    is_open,
    error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { admin_msg(ProjectEditSubmitted) }),
          attribute.id("project-edit-form"),
        ],
        [
          form_field.view(
            update_helpers.i18n_t(model, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(name),
              event.on_input(fn(value) {
                admin_msg(ProjectEditNameChanged(value))
              }),
              attribute.required(True),
              attribute.autofocus(True),
            ]),
          ),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, admin_msg(ProjectEditDialogClosed)),
      button(
        [
          attribute.type_("submit"),
          attribute.form("project-edit-form"),
          attribute.disabled(in_flight),
          attribute.class(case in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Saving)
            False -> update_helpers.i18n_t(model, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}

/// Delete confirmation dialog (Story 4.8 AC39).
fn view_projects_delete_confirm(model: Model) -> element.Element(Msg) {
  let #(is_open, name, in_flight) = case model.admin.projects_dialog {
    DialogOpen(form: ProjectDialogDelete(id: _, name: name), operation: op) -> #(
      True,
      name,
      operation_in_flight(op),
    )
    _ -> #(False, "", False)
  }

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.DeleteProjectTitle),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: admin_msg(ProjectDeleteConfirmClosed),
    ),
    is_open,
    opt.None,
    // Content
    [
      p([attribute.class("dialog-message")], [
        text(update_helpers.i18n_t(model, i18n_text.DeleteProjectConfirm(name))),
      ]),
      p([attribute.class("dialog-warning")], [
        text(update_helpers.i18n_t(model, i18n_text.DeleteProjectWarning)),
      ]),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, admin_msg(ProjectDeleteConfirmClosed)),
      button(
        [
          attribute.class("btn-danger"),
          attribute.disabled(in_flight),
          event.on_click(admin_msg(ProjectDeleteSubmitted)),
        ],
        [
          text(case in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Deleting)
            False -> update_helpers.i18n_t(model, i18n_text.Delete)
          }),
        ],
      ),
    ],
  )
}

fn operation_in_flight(operation: OperationState) -> Bool {
  case operation {
    InFlight -> True
    _ -> False
  }
}

fn operation_error(operation: OperationState) -> opt.Option(String) {
  case operation {
    OpError(message) -> opt.Some(message)
    _ -> opt.None
  }
}

fn view_projects_list(model: Model) -> element.Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote_with_forbidden(
    model.core.projects,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoProjectsYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(t(i18n_text.Name), fn(p: Project) { text(p.name) }),
        // Members count (AC38)
        data_table.column_with_class(
          t(i18n_text.MembersCount),
          fn(p: Project) { text(int.to_string(p.members_count)) },
          "col-center",
          "cell-center",
        ),
        // Created date (AC38)
        data_table.column_with_class(
          t(i18n_text.CreatedAt),
          fn(p: Project) { text(format_date.date_only(p.created_at)) },
          "col-center",
          "cell-center",
        ),
        // My role
        data_table.column_with_class(
          t(i18n_text.MyRole),
          fn(p: Project) { text(project_role.to_string(p.my_role)) },
          "col-center",
          "cell-center",
        ),
        // Actions (AC39)
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(p: Project) { view_project_actions(model, p) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(p: Project) { int.to_string(p.id) }),
  )
}

fn view_project_actions(model: Model, p: Project) -> element.Element(Msg) {
  action_buttons.edit_delete_row(
    edit_title: update_helpers.i18n_t(model, i18n_text.EditProject),
    edit_click: admin_msg(ProjectEditDialogOpened(p.id, p.name)),
    delete_title: update_helpers.i18n_t(model, i18n_text.DeleteProject),
    delete_click: admin_msg(ProjectDeleteConfirmOpened(p.id, p.name)),
  )
}
