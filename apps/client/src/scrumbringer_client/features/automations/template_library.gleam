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

import domain/automation
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
import scrumbringer_client/ui/modal_close_button

// =============================================================================
// Template Library Views
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    selected_project_id: opt.Option(Int),
    templates: remote_state.Remote(List(TaskTemplate)),
    selected_template_id: opt.Option(Int),
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
  let t = fn(key) { i18n.t(config.locale, key) }
  let title = case mode {
    admin_task_templates.TaskTemplateDialogCreate ->
      t(i18n_text.CreateTaskTemplate)
    admin_task_templates.TaskTemplateDialogEdit(_) ->
      t(i18n_text.EditTaskTemplate)
    admin_task_templates.TaskTemplateDialogDelete(_) ->
      t(i18n_text.AdminTaskTemplates)
  }
  let action = case mode {
    admin_task_templates.TaskTemplateDialogCreate ->
      t(i18n_text.CreateTaskTemplate)
    admin_task_templates.TaskTemplateDialogEdit(_) -> t(i18n_text.Save)
    admin_task_templates.TaskTemplateDialogDelete(_) -> t(i18n_text.Save)
  }

  div(
    [
      attribute.class("automation-template-panel"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-label", title),
    ],
    [
      panel_header(title, config.locale, config.on_closed),
      view_form_error(config),
      form_field.view(
        t(i18n_text.TaskTemplateName),
        input([
          attribute.value(config.form_name),
          attribute.attribute("aria-label", t(i18n_text.TaskTemplateName)),
          attribute.attribute("data-testid", "automation-template-name"),
          event.on_input(config.on_name_changed),
        ]),
      ),
      form_field.view(
        t(i18n_text.TaskTemplateDescription),
        textarea(
          [
            attribute.value(config.form_description),
            attribute.attribute(
              "aria-label",
              t(i18n_text.TaskTemplateDescription),
            ),
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
        t(i18n_text.TaskTemplateType),
        select(
          [
            attribute.value(config.form_type_id),
            attribute.attribute("aria-label", t(i18n_text.TaskTemplateType)),
            attribute.attribute("data-testid", "automation-template-type"),
            event.on_input(config.on_type_changed),
          ],
          task_type_options(config),
        ),
      ),
      form_field.view(
        t(i18n_text.TaskTemplatePriority),
        select(
          [
            attribute.value(config.form_priority),
            attribute.attribute("aria-label", t(i18n_text.TaskTemplatePriority)),
            attribute.attribute("data-testid", "automation-template-priority"),
            event.on_input(config.on_priority_changed),
          ],
          priority_options(config.form_priority),
        ),
      ),
      div([attribute.class("automation-template-panel__hint")], [
        span([], [text(t(i18n_text.AvailableVariables) <> ":")]),
        div(
          [attribute.class("automation-template-variable-chips")],
          template_variable_names()
            |> list.map(fn(variable) { view_variable_chip(config, variable) }),
        ),
        p([], [text(t(i18n_text.TaskTemplateDescriptionHint))]),
      ]),
      panel_actions(
        locale: config.locale,
        cancel: config.on_closed,
        submit: config.on_submitted(config.selected_project_id),
        submit_label: action,
        submitting: config.form_submitting,
      ),
    ],
  )
}

fn view_variable_chip(config: Config(msg), variable: String) -> Element(msg) {
  let token = variable_token(variable)
  button(
    [
      attribute.type_("button"),
      attribute.class("automation-template-variable-chip"),
      attribute.attribute("data-testid", "automation-template-variable-chip"),
      attribute.attribute("data-variable", token),
      attribute.attribute(
        "aria-label",
        i18n.t(config.locale, i18n_text.TaskTemplateInsertVariable(variable)),
      ),
      event.on_click(
        config.on_description_changed(description_with_inserted_variable(
          config.form_description,
          variable,
        )),
      ),
    ],
    [text(token)],
  )
}

fn description_with_inserted_variable(
  description: String,
  variable: String,
) -> String {
  let token = variable_token(variable)
  case string.trim(description) {
    "" -> token
    _ -> description <> " " <> token
  }
}

fn variable_token(variable: String) -> String {
  "{{" <> variable <> "}}"
}

fn template_variable_names() -> List(String) {
  automation.available_template_variables(automation.TaskCompleted(opt.None))
  |> list.append(
    automation.available_template_variables(automation.CardActivated(
      automation.AnyCard,
    )),
  )
  |> unique_strings([])
}

fn unique_strings(items: List(String), seen: List(String)) -> List(String) {
  case items {
    [] -> list.reverse(seen)
    [item, ..rest] ->
      case list.contains(seen, item) {
        True -> unique_strings(rest, seen)
        False -> unique_strings(rest, [item, ..seen])
      }
  }
}

fn view_delete_panel(
  config: Config(msg),
  template: TaskTemplate,
) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  div(
    [
      attribute.class("automation-template-panel"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-label", t(i18n_text.DeleteTaskTemplate)),
    ],
    [
      panel_header(
        t(i18n_text.DeleteTaskTemplate),
        config.locale,
        config.on_closed,
      ),
      view_form_error(config),
      p([], [
        text(t(i18n_text.TaskTemplateDeleteConfirm(template.name))),
      ]),
      p([], [
        text(t(i18n_text.TaskTemplateDeleteRulesWarning)),
      ]),
      panel_actions(
        locale: config.locale,
        cancel: config.on_closed,
        submit: config.on_delete_confirmed,
        submit_label: t(i18n_text.DeleteTaskTemplate),
        submitting: config.form_submitting,
      ),
    ],
  )
}

fn panel_header(title: String, locale: Locale, on_closed: msg) -> Element(msg) {
  div([attribute.class("automation-template-panel__header")], [
    h2([], [text(title)]),
    modal_close_button.view_with_label_and_class(
      i18n.t(locale, i18n_text.Close),
      "icon-btn",
      on_closed,
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
  locale locale: Locale,
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
      [text(i18n.t(locale, i18n_text.Cancel))],
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
          True -> i18n.t(locale, i18n_text.Saving)
          False -> submit_label
        }),
      ],
    ),
  ])
}

fn task_type_options(config: Config(msg)) -> List(Element(msg)) {
  let empty =
    option(
      [attribute.value("")],
      i18n.t(config.locale, i18n_text.SelectTaskType),
    )
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
        data_table.column_with_class(
          t(i18n_text.TaskTemplateUsages),
          fn(tmpl: TaskTemplate) { view_template_usage(config, tmpl) },
          "col-number",
          "cell-number",
        ),
        data_table.column_with_class(
          t(i18n_text.TaskTemplateCreatedTasks),
          fn(tmpl: TaskTemplate) {
            text(int.to_string(tmpl.created_tasks_count))
          },
          "col-number",
          "cell-number",
        ),
        data_table.column(
          t(i18n_text.TaskTemplateLastExecution),
          fn(tmpl: TaskTemplate) { view_last_execution(config, tmpl) },
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
      |> data_table.with_row_attrs(fn(tmpl) {
        let is_selected = config.selected_template_id == opt.Some(tmpl.id)
        [
          attribute.attribute("data-testid", "automation-template-row"),
          attribute.attribute("data-selected", bool_to_string(is_selected)),
          attribute.class(row_class("automation-template-row", is_selected)),
        ]
      }),
  )
}

fn view_template_usage(
  config: Config(msg),
  template: TaskTemplate,
) -> Element(msg) {
  div([attribute.class("automation-template-usage")], [
    span([attribute.class("automation-template-usage__count")], [
      text(int.to_string(template.rules_count)),
    ]),
    case template.rules_count {
      0 ->
        badge.new_unchecked(
          i18n.t(config.locale, i18n_text.TaskTemplateUnused),
          badge.Warning,
        )
        |> badge.view_with_class("automation-template-unused-badge")
      _ -> element.none()
    },
  ])
}

fn view_last_execution(
  config: Config(msg),
  template: TaskTemplate,
) -> Element(msg) {
  case template.last_execution_at {
    opt.Some(value) -> text(value)
    opt.None -> text(i18n.t(config.locale, i18n_text.TaskTemplateNeverExecuted))
  }
}

fn row_class(base: String, is_selected: Bool) -> String {
  case is_selected {
    True -> base <> " is-selected"
    False -> base
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
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
