//// Automation template library view.
////
//// ## Mission
////
//// Render project-scoped templates as an internal automations mode.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h2, input, option, p, select, span, text, textarea,
}
import lustre/event

import domain/project.{type Project}
import domain/remote as remote_state
import domain/task_type.{type TaskType}
import domain/workflow.{type TaskTemplate}

import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/filter_bar
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/info_callout

// =============================================================================
// Template Library Views
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    selected_project_id: opt.Option(Int),
    templates: remote_state.Remote(List(TaskTemplate)),
    dialog_mode: opt.Option(admin_task_templates.TaskTemplateDialogMode),
    task_types: remote_state.Remote(List(TaskType)),
    search_query: String,
    form_name: String,
    form_description: String,
    form_type_id: String,
    form_priority: String,
    form_submitting: Bool,
    form_error: opt.Option(String),
    on_create_clicked: msg,
    on_edit_clicked: fn(TaskTemplate) -> msg,
    on_delete_clicked: fn(TaskTemplate) -> msg,
    on_search_changed: fn(String) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_type_changed: fn(String) -> msg,
    on_priority_changed: fn(String) -> msg,
    on_submitted: fn(opt.Option(Int)) -> msg,
    on_delete_confirmed: msg,
    on_closed: msg,
  )
}

/// Automation template library view (project-scoped only).
pub fn view(config: Config(msg)) -> Element(msg) {
  let title = case config.selected_project {
    opt.Some(project) ->
      i18n.t(config.locale, i18n_text.TaskTemplatesProjectTitle(project.name))
    opt.None -> i18n.t(config.locale, i18n_text.TaskTemplatesTitle)
  }

  div([attribute.class("automation-templates-mode")], [
    div([attribute.class("automation-templates-heading")], [
      h2([], [text(title)]),
      p([], [
        text(i18n.t(config.locale, i18n_text.AutomationTemplatesDescription)),
      ]),
    ]),
    view_template_filters(config),
    view_templates_hint(config),
    view_task_templates_table(config),
    view_template_panel(config),
  ])
}

fn view_template_filters(config: Config(msg)) -> Element(msg) {
  filter_bar.new([
    form_field.view(
      i18n.t(config.locale, i18n_text.SearchLabel),
      input([
        attribute.type_("search"),
        attribute.value(config.search_query),
        attribute.placeholder(i18n.t(
          config.locale,
          i18n_text.AutomationTemplatesSearchPlaceholder,
        )),
        attribute.attribute(
          "aria-label",
          i18n.t(config.locale, i18n_text.AutomationTemplatesSearchPlaceholder),
        ),
        attribute.attribute("data-testid", "automation-template-search"),
        event.on_input(config.on_search_changed),
      ]),
    ),
  ])
  |> filter_bar.with_actions([
    dialog.add_button_with_locale(
      config.locale,
      i18n_text.CreateTaskTemplate,
      config.on_create_clicked,
    ),
  ])
  |> filter_bar.with_class("automation-templates-filters")
  |> filter_bar.with_testid("automation-template-picker")
  |> filter_bar.view
}

/// Unified hint with variables documentation for the template library.
fn view_templates_hint(config: Config(msg)) -> Element(msg) {
  info_callout.view_with_content(
    opt.None,
    div([], [
      span([], [
        text(i18n.t(config.locale, i18n_text.TemplatesHintRules)),
      ]),
      div([attribute.class("info-callout-variables")], [
        text(i18n.t(config.locale, i18n_text.TaskTemplateVariablesHelp)),
      ]),
    ]),
  )
}

fn view_template_panel(config: Config(msg)) -> Element(msg) {
  case config.dialog_mode {
    opt.None -> element.none()
    opt.Some(admin_task_templates.TaskTemplateDialogDelete(template)) ->
      view_delete_panel(config, template)
    opt.Some(mode) -> view_form_panel(config, mode)
  }
}

fn view_form_panel(
  config: Config(msg),
  mode: admin_task_templates.TaskTemplateDialogMode,
) -> Element(msg) {
  let title = case mode {
    admin_task_templates.TaskTemplateDialogCreate -> "New template"
    admin_task_templates.TaskTemplateDialogEdit(_) -> "Edit template"
    admin_task_templates.TaskTemplateDialogDelete(_) -> "Template"
  }
  let action = case mode {
    admin_task_templates.TaskTemplateDialogCreate -> "Create template"
    admin_task_templates.TaskTemplateDialogEdit(_) -> "Save changes"
    admin_task_templates.TaskTemplateDialogDelete(_) -> "Save"
  }

  div(
    [
      attribute.class("automation-template-panel"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-label", title),
    ],
    [
      panel_header(title, config.on_closed),
      view_form_error(config),
      form_field.view(
        "Template name",
        input([
          attribute.value(config.form_name),
          attribute.attribute("data-testid", "automation-template-name"),
          event.on_input(config.on_name_changed),
        ]),
      ),
      form_field.view(
        "Template description",
        textarea(
          [
            attribute.value(config.form_description),
            attribute.attribute(
              "data-testid",
              "automation-template-description",
            ),
            event.on_input(config.on_description_changed),
          ],
          "",
        ),
      ),
      form_field.view(
        "Task type",
        select(
          [
            attribute.value(config.form_type_id),
            attribute.attribute("data-testid", "automation-template-type"),
            event.on_input(config.on_type_changed),
          ],
          task_type_options(config),
        ),
      ),
      form_field.view(
        "Priority",
        select(
          [
            attribute.value(config.form_priority),
            attribute.attribute("data-testid", "automation-template-priority"),
            event.on_input(config.on_priority_changed),
          ],
          priority_options(config.form_priority),
        ),
      ),
      div([attribute.class("automation-template-panel__hint")], [
        text(
          "Available variables: {{origin}}, {{trigger}}, {{project}}, {{user}}",
        ),
      ]),
      panel_actions(
        cancel: config.on_closed,
        submit: config.on_submitted(config.selected_project_id),
        submit_label: action,
        submitting: config.form_submitting,
      ),
    ],
  )
}

fn view_delete_panel(
  config: Config(msg),
  template: TaskTemplate,
) -> Element(msg) {
  div(
    [
      attribute.class("automation-template-panel"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-label", "Delete template"),
    ],
    [
      panel_header("Delete template", config.on_closed),
      view_form_error(config),
      p([], [
        text("Delete "),
        span([attribute.class("strong")], [text(template.name)]),
        text("? Rules using this template should be paused or updated first."),
      ]),
      panel_actions(
        cancel: config.on_closed,
        submit: config.on_delete_confirmed,
        submit_label: "Delete template",
        submitting: config.form_submitting,
      ),
    ],
  )
}

fn panel_header(title: String, on_closed: msg) -> Element(msg) {
  div([attribute.class("automation-template-panel__header")], [
    h2([], [text(title)]),
    button(
      [
        attribute.type_("button"),
        attribute.class("icon-btn"),
        attribute.attribute("aria-label", "Close"),
        event.on_click(on_closed),
      ],
      [text("x")],
    ),
  ])
}

fn view_form_error(config: Config(msg)) -> Element(msg) {
  case config.form_error {
    opt.None -> element.none()
    opt.Some(message) ->
      div(
        [attribute.class("form-error"), attribute.attribute("role", "alert")],
        [
          text(message),
        ],
      )
  }
}

fn panel_actions(
  cancel cancel: msg,
  submit submit: msg,
  submit_label submit_label: String,
  submitting submitting: Bool,
) -> Element(msg) {
  div([attribute.class("automation-template-panel__actions")], [
    button(
      [
        attribute.type_("button"),
        attribute.class("btn secondary"),
        event.on_click(cancel),
      ],
      [text("Cancel")],
    ),
    button(
      [
        attribute.type_("button"),
        attribute.class("btn primary"),
        attribute.disabled(submitting),
        event.on_click(submit),
      ],
      [
        text(case submitting {
          True -> "Saving..."
          False -> submit_label
        }),
      ],
    ),
  ])
}

fn task_type_options(config: Config(msg)) -> List(Element(msg)) {
  let empty = option([attribute.value("")], "Select task type")
  case config.task_types {
    remote_state.Loaded(types) -> [
      empty,
      ..list.map(types, fn(task_type) {
        option(
          [
            attribute.value(int.to_string(task_type.id)),
            attribute.selected(
              config.form_type_id == int.to_string(task_type.id),
            ),
          ],
          task_type.name,
        )
      })
    ]
    _ -> [empty]
  }
}

fn priority_options(selected: String) -> List(Element(msg)) {
  [1, 2, 3, 4, 5]
  |> list.map(fn(priority) {
    let value = int.to_string(priority)
    option(
      [attribute.value(value), attribute.selected(selected == value)],
      value,
    )
  })
}

fn view_task_templates_table(config: Config(msg)) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let templates =
    config.templates
    |> remote_state.map(fn(items) {
      filter_templates(items, config.search_query)
    })

  data_table.view_remote_with_forbidden(
    templates,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoTaskTemplatesYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name column
        data_table.column(t(i18n_text.TaskTemplateName), fn(tmpl: TaskTemplate) {
          text(tmpl.name)
        }),
        // Type column (task type)
        data_table.column(t(i18n_text.TaskTemplateType), fn(tmpl: TaskTemplate) {
          text(tmpl.type_name)
        }),
        // Priority column
        data_table.column_with_class(
          t(i18n_text.TaskTemplatePriority),
          fn(tmpl: TaskTemplate) {
            badge.new_unchecked(int.to_string(tmpl.priority), badge.Neutral)
            |> badge.view_with_class("priority-badge")
          },
          "col-number",
          "cell-number",
        ),
        // Actions column with icon buttons
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(tmpl: TaskTemplate) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: t(i18n_text.EditTaskTemplate),
              edit_click: config.on_edit_clicked(tmpl),
              edit_testid: "template-edit-btn",
              delete_title: t(i18n_text.Delete),
              delete_click: config.on_delete_clicked(tmpl),
              delete_testid: "template-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(tmpl) { int.to_string(tmpl.id) })
      |> data_table.with_row_attrs(fn(_tmpl) {
        [attribute.attribute("data-testid", "automation-template-row")]
      }),
  )
}

fn filter_templates(
  templates: List(TaskTemplate),
  query: String,
) -> List(TaskTemplate) {
  let needle = string.trim(query) |> string.lowercase
  case needle {
    "" -> templates
    _ ->
      list.filter(templates, fn(template) {
        template_matches_query(template, needle)
      })
  }
}

fn template_matches_query(template: TaskTemplate, needle: String) -> Bool {
  string.contains(string.lowercase(template.name), needle)
  || string.contains(string.lowercase(template.type_name), needle)
  || case template.description {
    opt.Some(description) ->
      string.contains(string.lowercase(description), needle)
    opt.None -> False
  }
}
