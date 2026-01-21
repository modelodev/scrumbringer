//// Projects admin view.
////
//// ## Mission
////
//// Renders the projects management UI for org admins.
////
//// ## Responsibilities
////
//// - Projects list table
//// - Project creation dialog
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to view_projects from admin section
//// - **features/projects/update.gleam**: Handles project messages

import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, input, label, span, table, td, text, th, thead, tr}
import lustre/element/keyed
import lustre/event

import domain/project.{type Project}
import scrumbringer_client/client_state.{
  type Model, type Msg, type Remote, Failed, Loaded, Loading, NotAsked,
  ProjectCreateDialogClosed, ProjectCreateDialogOpened,
  ProjectCreateNameChanged, ProjectCreateSubmitted,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/dialog
import scrumbringer_client/update_helpers

// =============================================================================
// Public API
// =============================================================================

/// Main projects section view.
pub fn view_projects(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    // Section header with add button
    div([attribute.class("admin-section-header")], [
      div([attribute.class("admin-section-title")], [
        span([attribute.class("admin-section-icon")], [text("\u{1F4C1}")]),
        text(update_helpers.i18n_t(model, i18n_text.Projects)),
      ]),
      dialog.add_button(
        model,
        i18n_text.CreateProject,
        ProjectCreateDialogOpened,
      ),
    ]),
    // Projects list
    view_projects_list(model, model.projects),
    // Create project dialog
    view_projects_create_dialog(model),
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
      icon: opt.Some("\u{1F4C1}"),
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

fn view_projects_list(
  model: Model,
  projects: Remote(List(Project)),
) -> Element(Msg) {
  case projects {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(projects) ->
      case projects {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.MyRole))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(projects, fn(p) {
                #(p.name, tr([], [td([], [text(p.name)]), td([], [text(p.my_role)])]))
              }),
            ),
          ])
      }
  }
}
