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
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element
import lustre/element/html.{div, form, input, p, text}
import lustre/event

import domain/project.{type Project, type ProjectDepthName, ProjectDepthName}
import domain/project/project_codec
import domain/project_role
import domain/remote.{type Remote, Loaded}
import scrumbringer_client/client_state/admin/projects as projects_state
import scrumbringer_client/client_state/types.{
  type OperationState, DialogOpen, Error as OpError, InFlight,
}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/utils/format_date

// =============================================================================
// Public API
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    projects: Remote(List(Project)),
    project_dialog: projects_state.Model,
    on_create_dialog_opened: msg,
    on_create_dialog_closed: msg,
    on_create_submitted: msg,
    on_create_name_changed: fn(String) -> msg,
    on_edit_dialog_opened: fn(Int, String) -> msg,
    on_edit_dialog_closed: msg,
    on_edit_submitted: msg,
    on_edit_name_changed: fn(String) -> msg,
    on_delete_confirm_opened: fn(Int, String) -> msg,
    on_delete_confirm_closed: msg,
    on_delete_submitted: msg,
  )
}

/// Main projects section view.
pub fn view_projects(config: Config(msg)) -> element.Element(msg) {
  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Projects,
      t(config, i18n_text.Projects),
      dialog.add_button_with_locale(
        config.locale,
        i18n_text.CreateProject,
        config.on_create_dialog_opened,
      ),
    ),
    // Projects list
    view_projects_list(config),
    // Dialogs
    view_project_dialogs(config),
  ])
}

/// Project dialogs (create/edit/delete) for reuse in other views.
pub fn view_project_dialogs(config: Config(msg)) -> element.Element(msg) {
  element.fragment([
    view_projects_create_dialog(config),
    view_projects_edit_dialog(config),
    view_projects_delete_confirm(config),
  ])
}

// =============================================================================
// Private Helpers
// =============================================================================

/// Dialog for creating a new project.
fn view_projects_create_dialog(config: Config(msg)) -> element.Element(msg) {
  let #(is_open, name, in_flight, error) = case
    config.project_dialog.projects_dialog
  {
    DialogOpen(
      form: projects_state.ProjectDialogCreate(name: name),
      operation: op,
    ) -> #(True, name, operation_in_flight(op), operation_error(op))
    _ -> #(False, "", False, opt.None)
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.CreateProject),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_create_dialog_closed,
    ),
    is_open,
    error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { config.on_create_submitted }),
          attribute.id("project-create-form"),
        ],
        [
          form_field.view(
            t(config, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(name),
              event.on_input(fn(value) { config.on_create_name_changed(value) }),
              attribute.required(True),
              attribute.autofocus(True),
            ]),
          ),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_create_dialog_closed,
      ),
      dialog.submit_button_with_locale_form(
        config.locale,
        "project-create-form",
        in_flight,
        False,
        i18n_text.Create,
        i18n_text.Creating,
      ),
    ],
  )
}

fn edit_project_depth_names(config: Config(msg)) -> List(ProjectDepthName) {
  case config.project_dialog.projects_dialog, config.projects {
    DialogOpen(form: projects_state.ProjectDialogEdit(id: project_id, ..), ..),
      Loaded(projects)
    ->
      case list.find(projects, fn(project) { project.id == project_id }) {
        Ok(project) -> project.card_depth_names
        Error(_) -> project_codec.default_card_depth_names()
      }
    _, _ -> project_codec.default_card_depth_names()
  }
}

fn view_project_structure_settings(
  depth_names: List(ProjectDepthName),
) -> element.Element(msg) {
  let depth_names = case depth_names {
    [] -> project_codec.default_card_depth_names()
    _ -> depth_names
  }

  div(
    [
      attribute.class("project-structure-settings"),
      attribute.attribute("data-testid", "project-structure-settings"),
    ],
    [
      p([attribute.class("project-structure-settings__title")], [
        text("Structure and Pool"),
      ]),
      p([attribute.class("project-structure-settings__hint")], [
        text(
          "Visible level names define how cards are grouped before work reaches the Pool.",
        ),
      ]),
      div([attribute.class("project-structure-settings__summary")], [
        text("Maximum depth: " <> int.to_string(list.length(depth_names))),
      ]),
      div([attribute.class("project-structure-settings__levels")], {
        depth_names
        |> list.map(fn(depth_name) { view_depth_name(depth_name) })
      }),
      div([attribute.class("project-structure-settings__summary")], [
        text("Pool soft limit: 20 tasks"),
      ]),
      div(
        [
          attribute.class("project-depth-reduction-confirmation"),
          attribute.attribute(
            "data-testid",
            "project-depth-reduction-confirmation",
          ),
          attribute.attribute("aria-hidden", "true"),
          attribute.attribute("hidden", ""),
        ],
        [
          text(
            "Depth reduction confirmation appears before closing cards outside a new limit.",
          ),
        ],
      ),
    ],
  )
}

fn view_depth_name(depth_name: ProjectDepthName) -> element.Element(msg) {
  let ProjectDepthName(depth:, singular_name:, plural_name:) = depth_name
  div([attribute.class("project-structure-settings__level")], [
    text(int.to_string(depth) <> " " <> singular_name <> " / " <> plural_name),
  ])
}

/// Dialog for editing a project (Story 4.8 AC39).
fn view_projects_edit_dialog(config: Config(msg)) -> element.Element(msg) {
  let #(is_open, name, in_flight, error) = case
    config.project_dialog.projects_dialog
  {
    DialogOpen(
      form: projects_state.ProjectDialogEdit(id: _, name: name),
      operation: op,
    ) -> #(True, name, operation_in_flight(op), operation_error(op))
    _ -> #(False, "", False, opt.None)
  }

  let depth_names = edit_project_depth_names(config)

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.EditProject),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_edit_dialog_closed,
    ),
    is_open,
    error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { config.on_edit_submitted }),
          attribute.id("project-edit-form"),
        ],
        [
          form_field.view(
            t(config, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(name),
              event.on_input(fn(value) { config.on_edit_name_changed(value) }),
              attribute.required(True),
              attribute.autofocus(True),
            ]),
          ),
          view_project_structure_settings(depth_names),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_edit_dialog_closed,
      ),
      dialog.submit_button_with_locale_form(
        config.locale,
        "project-edit-form",
        in_flight,
        False,
        i18n_text.Save,
        i18n_text.Saving,
      ),
    ],
  )
}

/// Delete confirmation dialog (Story 4.8 AC39).
fn view_projects_delete_confirm(config: Config(msg)) -> element.Element(msg) {
  let #(is_open, name, in_flight) = case config.project_dialog.projects_dialog {
    DialogOpen(
      form: projects_state.ProjectDialogDelete(id: _, name: name),
      operation: op,
    ) -> #(True, name, operation_in_flight(op))
    _ -> #(False, "", False)
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(config, i18n_text.DeleteProjectTitle),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_delete_confirm_closed,
    ),
    is_open,
    opt.None,
    // Content
    [
      p([attribute.class("dialog-message")], [
        text(t(config, i18n_text.DeleteProjectConfirm(name))),
      ]),
      p([attribute.class("dialog-warning")], [
        text(t(config, i18n_text.DeleteProjectWarning)),
      ]),
    ],
    // Footer buttons
    [
      dialog.cancel_button_with_locale(
        config.locale,
        config.on_delete_confirm_closed,
      ),
      ui_button.text(
        case in_flight {
          True -> t(config, i18n_text.Deleting)
          False -> t(config, i18n_text.Delete)
        },
        config.on_delete_submitted,
        ui_button.Danger,
        ui_button.EntityAction,
      )
        |> ui_button.with_disabled(in_flight)
        |> ui_button.view,
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

fn view_projects_list(config: Config(msg)) -> element.Element(msg) {
  let translate = fn(key) { t(config, key) }

  data_table.view_remote_with_forbidden(
    config.projects,
    loading_msg: translate(i18n_text.LoadingEllipsis),
    empty_msg: translate(i18n_text.NoProjectsYet),
    forbidden_msg: translate(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(translate(i18n_text.Name), fn(p: Project) {
          text(p.name)
        }),
        // Members count (AC38)
        data_table.column_with_class(
          translate(i18n_text.MembersCount),
          fn(p: Project) { text(int.to_string(p.members_count)) },
          "col-center",
          "cell-center",
        ),
        // Created date (AC38)
        data_table.column_with_class(
          translate(i18n_text.CreatedAt),
          fn(p: Project) { text(format_date.date_only(p.created_at)) },
          "col-center",
          "cell-center",
        ),
        // My role
        data_table.column_with_class(
          translate(i18n_text.MyRole),
          fn(p: Project) { text(project_role.to_string(p.my_role)) },
          "col-center",
          "cell-center",
        ),
        // Actions (AC39)
        data_table.column_with_class(
          translate(i18n_text.Actions),
          fn(p: Project) { view_project_actions(config, p) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(p: Project) { int.to_string(p.id) }),
  )
}

fn view_project_actions(config: Config(msg), p: Project) -> element.Element(msg) {
  action_buttons.edit_delete_row(
    edit_title: t(config, i18n_text.EditProject),
    edit_click: config.on_edit_dialog_opened(p.id, p.name),
    delete_title: t(config, i18n_text.DeleteProject),
    delete_click: config.on_delete_confirm_opened(p.id, p.name),
  )
}

fn t(config: Config(msg), text: i18n_text.Text) -> String {
  i18n.t(config.locale, text)
}
