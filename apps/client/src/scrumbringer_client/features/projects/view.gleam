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
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, input, label, p, text}
import lustre/event

import domain/project.{type Project}
import domain/project_role
import scrumbringer_client/client_state.{
  type Model, type Msg, ProjectCreateDialogClosed, ProjectCreateDialogOpened,
  ProjectCreateNameChanged, ProjectCreateSubmitted, ProjectDeleteConfirmClosed,
  ProjectDeleteConfirmOpened, ProjectDeleteSubmitted, ProjectEditDialogClosed,
  ProjectEditDialogOpened, ProjectEditNameChanged, ProjectEditSubmitted,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/format_date

// =============================================================================
// Public API
// =============================================================================

/// Main projects section view.
pub fn view_projects(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Projects,
      update_helpers.i18n_t(model, i18n_text.Projects),
      dialog.add_button(
        model,
        i18n_text.CreateProject,
        ProjectCreateDialogOpened,
      ),
    ),
    // Projects list
    view_projects_list(model),
    // Dialogs
    view_projects_create_dialog(model),
    view_projects_edit_dialog(model),
    view_projects_delete_confirm(model),
  ])
}

// =============================================================================
// Private Helpers
// =============================================================================

/// Dialog for creating a new project.
fn view_projects_create_dialog(model: Model) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.CreateProject),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: ProjectCreateDialogClosed,
    ),
    model.projects_create_dialog_open,
    model.projects_create_error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { ProjectCreateSubmitted }),
          attribute.id("project-create-form"),
        ],
        [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
            input([
              attribute.type_("text"),
              attribute.value(model.projects_create_name),
              event.on_input(ProjectCreateNameChanged),
              attribute.required(True),
              attribute.autofocus(True),
            ]),
          ]),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, ProjectCreateDialogClosed),
      button(
        [
          attribute.type_("submit"),
          attribute.form("project-create-form"),
          attribute.disabled(model.projects_create_in_flight),
          attribute.class(case model.projects_create_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.projects_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

/// Dialog for editing a project (Story 4.8 AC39).
fn view_projects_edit_dialog(model: Model) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.EditProject),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: ProjectEditDialogClosed,
    ),
    model.projects_edit_dialog_open,
    model.projects_edit_error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { ProjectEditSubmitted }),
          attribute.id("project-edit-form"),
        ],
        [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
            input([
              attribute.type_("text"),
              attribute.value(model.projects_edit_name),
              event.on_input(ProjectEditNameChanged),
              attribute.required(True),
              attribute.autofocus(True),
            ]),
          ]),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, ProjectEditDialogClosed),
      button(
        [
          attribute.type_("submit"),
          attribute.form("project-edit-form"),
          attribute.disabled(model.projects_edit_in_flight),
          attribute.class(case model.projects_edit_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.projects_edit_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Saving)
            False -> update_helpers.i18n_t(model, i18n_text.Save)
          }),
        ],
      ),
    ],
  )
}

/// Delete confirmation dialog (Story 4.8 AC39).
fn view_projects_delete_confirm(model: Model) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.DeleteProjectTitle),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: ProjectDeleteConfirmClosed,
    ),
    model.projects_delete_confirm_open,
    opt.None,
    // Content
    [
      p([attribute.class("dialog-message")], [
        text(
          update_helpers.i18n_t(
            model,
            i18n_text.DeleteProjectConfirm(model.projects_delete_name),
          ),
        ),
      ]),
      p([attribute.class("dialog-warning")], [
        text(update_helpers.i18n_t(model, i18n_text.DeleteProjectWarning)),
      ]),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, ProjectDeleteConfirmClosed),
      button(
        [
          attribute.class("btn-danger"),
          attribute.disabled(model.projects_delete_in_flight),
          event.on_click(ProjectDeleteSubmitted),
        ],
        [
          text(case model.projects_delete_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Deleting)
            False -> update_helpers.i18n_t(model, i18n_text.Delete)
          }),
        ],
      ),
    ],
  )
}

fn view_projects_list(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote_with_forbidden(
    model.projects,
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

fn view_project_actions(model: Model, p: Project) -> Element(Msg) {
  div([attribute.class("actions-row")], [
    // Edit button
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.EditProject),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.EditProject),
        ),
        event.on_click(ProjectEditDialogOpened(p.id, p.name)),
      ],
      [icons.nav_icon(icons.Pencil, icons.Small)],
    ),
    // Delete button
    button(
      [
        attribute.class("btn-xs btn-icon btn-delete"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.DeleteProject),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.DeleteProject),
        ),
        event.on_click(ProjectDeleteConfirmOpened(p.id, p.name)),
      ],
      [icons.nav_icon(icons.Trash, icons.Small)],
    ),
  ])
}
