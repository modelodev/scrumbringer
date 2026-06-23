//// Automation engines list for the unified automations console.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, h2, input, p, span, text}
import lustre/element/keyed
import lustre/event

import domain/project.{type Project}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/workflow.{type Workflow}

import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/filter_bar
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/skeleton

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    selected_project_id: opt.Option(Int),
    selected_rules_view: opt.Option(Element(msg)),
    workflows: Remote(List(Workflow)),
    selected_engine_id: opt.Option(Int),
    selected_rule_id: opt.Option(Int),
    search_query: String,
    status_filter: String,
    dialog_mode: opt.Option(admin_workflows.WorkflowDialogMode),
    form_name: String,
    form_description: String,
    form_active: Bool,
    form_submitting: Bool,
    form_error: opt.Option(String),
    on_create_clicked: msg,
    on_search_changed: fn(String) -> msg,
    on_status_filter_changed: fn(String) -> msg,
    on_rules_clicked: fn(Int) -> msg,
    on_edit_clicked: fn(Workflow) -> msg,
    on_delete_clicked: fn(Workflow) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_active_changed: fn(Bool) -> msg,
    on_submitted: fn(opt.Option(Int)) -> msg,
    on_delete_confirmed: msg,
    on_closed: msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.selected_rules_view {
    opt.Some(rules_view) -> rules_view
    opt.None -> view_list(config)
  }
}

fn view_list(config: Config(msg)) -> Element(msg) {
  case config.selected_project {
    opt.None ->
      div([attribute.class("automation-engines-mode")], [
        div([attribute.class("empty")], [
          text(t(config, i18n_text.SelectProjectForWorkflows)),
        ]),
      ])
    opt.Some(project) ->
      div([attribute.class("automation-engines-mode")], [
        div([attribute.class("automation-engines-heading")], [
          h2([], [
            text(t(config, i18n_text.WorkflowsProjectTitle(project.name))),
          ]),
          p([], [text(t(config, i18n_text.AutomationEnginesDescription))]),
        ]),
        view_filters(config),
        view_content(config, config.workflows),
        view_engine_panel(config),
      ])
  }
}

fn view_filters(config: Config(msg)) -> Element(msg) {
  filter_bar.new([
    form_field.view(
      t(config, i18n_text.SearchLabel),
      input([
        attribute.type_("search"),
        attribute.value(config.search_query),
        attribute.placeholder(t(
          config,
          i18n_text.AutomationEnginesSearchPlaceholder,
        )),
        attribute.attribute(
          "aria-label",
          t(config, i18n_text.AutomationEnginesSearchPlaceholder),
        ),
        attribute.attribute("data-testid", "automation-engine-search"),
        event.on_input(config.on_search_changed),
      ]),
    ),
    filter_bar.select_field(
      t(config, i18n_text.AutomationEngineStatus),
      config.status_filter,
      [
        filter_bar.SelectOption(
          "all",
          t(config, i18n_text.AutomationEngineStatusAll),
          config.status_filter == "all",
        ),
        filter_bar.SelectOption(
          "active",
          t(config, i18n_text.AutomationEngineStatusActive),
          config.status_filter == "active",
        ),
        filter_bar.SelectOption(
          "paused",
          t(config, i18n_text.AutomationEngineStatusPaused),
          config.status_filter == "paused",
        ),
      ],
      config.on_status_filter_changed,
      "automation-engine-status-filter",
    ),
  ])
  |> filter_bar.with_actions([
    dialog.add_button_with_locale(
      config.locale,
      i18n_text.CreateWorkflow,
      config.on_create_clicked,
    ),
  ])
  |> filter_bar.with_class("automation-engines-filters")
  |> filter_bar.with_testid("automation-engines-filter-bar")
  |> filter_bar.view
}

fn view_content(
  config: Config(msg),
  workflows: Remote(List(Workflow)),
) -> Element(msg) {
  case workflows {
    NotAsked -> skeleton.skeleton_list(3)
    Loading -> skeleton.skeleton_list(3)
    Failed(err) -> error_notice.view(err.message)
    Loaded(items) -> {
      let filtered =
        filter_workflows(items, config.search_query, config.status_filter)

      case filtered {
        [] ->
          empty_state.simple("cog-6-tooth", t(config, i18n_text.NoWorkflowsYet))
        _ ->
          keyed.element(
            "div",
            [attribute.class("automation-engine-list")],
            list.map(filtered, fn(workflow) {
              #(int.to_string(workflow.id), view_engine_row(config, workflow))
            }),
          )
      }
    }
  }
}

fn view_engine_row(config: Config(msg), workflow: Workflow) -> Element(msg) {
  let is_selected = config.selected_engine_id == opt.Some(workflow.id)
  div(
    [
      attribute.class(row_class("automation-engine-row", is_selected)),
      attribute.attribute("data-testid", "automation-engine-row"),
      attribute.attribute("data-selected", bool_to_string(is_selected)),
    ],
    [
      div([attribute.class("automation-engine-row__main")], [
        div([attribute.class("automation-engine-row__title")], [
          span([attribute.class("automation-engine-row__name")], [
            text(workflow.name),
          ]),
          workflow_status_badge(config, workflow),
        ]),
        case workflow.description {
          opt.Some(description) ->
            p([attribute.class("automation-engine-row__description")], [
              text(description),
            ])
          opt.None -> element.none()
        },
      ]),
      div([attribute.class("automation-engine-row__meta")], [
        span([], [
          text(
            int.to_string(workflow.rule_count)
            <> " "
            <> t(config, i18n_text.WorkflowRules),
          ),
        ]),
      ]),
      view_actions(config, workflow),
    ],
  )
}

fn row_class(base: String, is_selected: Bool) -> String {
  case is_selected {
    True -> base <> " is-selected"
    False -> base
  }
}

fn workflow_status_badge(
  config: Config(msg),
  workflow: Workflow,
) -> Element(msg) {
  case workflow.active {
    True ->
      badge.new_unchecked(
        t(config, i18n_text.AutomationEngineStatusActive),
        badge.Success,
      )
      |> badge.view
    False ->
      badge.new_unchecked(
        t(config, i18n_text.AutomationEngineStatusPaused),
        badge.Neutral,
      )
      |> badge.view
  }
}

fn view_actions(config: Config(msg), workflow: Workflow) -> Element(msg) {
  div([attribute.class("btn-group")], [
    action_buttons.settings_button_with_testid(
      t(config, i18n_text.WorkflowRules),
      config.on_rules_clicked(workflow.id),
      "workflow-rules-btn",
    ),
    action_buttons.edit_button(
      t(config, i18n_text.EditWorkflow),
      config.on_edit_clicked(workflow),
    ),
    action_buttons.delete_button(
      t(config, i18n_text.DeleteWorkflow),
      config.on_delete_clicked(workflow),
    ),
  ])
}

fn filter_workflows(
  workflows: List(Workflow),
  query: String,
  status_filter: String,
) -> List(Workflow) {
  let needle = string.trim(query) |> string.lowercase

  workflows
  |> list.filter(fn(workflow) {
    workflow_matches_status(workflow, status_filter)
  })
  |> list.filter(fn(workflow) {
    case needle {
      "" -> True
      _ -> workflow_matches_query(workflow, needle)
    }
  })
}

fn workflow_matches_status(workflow: Workflow, status_filter: String) -> Bool {
  case status_filter {
    "active" -> workflow.active
    "paused" -> !workflow.active
    _ -> True
  }
}

fn workflow_matches_query(workflow: Workflow, needle: String) -> Bool {
  string.contains(string.lowercase(workflow.name), needle)
  || case workflow.description {
    opt.Some(description) ->
      string.contains(string.lowercase(description), needle)
    opt.None -> False
  }
}

fn view_engine_panel(config: Config(msg)) -> Element(msg) {
  case config.dialog_mode {
    opt.None -> element.none()
    opt.Some(admin_workflows.WorkflowDialogDelete(workflow)) ->
      view_delete_panel(config, workflow)
    opt.Some(mode) -> view_form_panel(config, mode)
  }
}

fn view_form_panel(
  config: Config(msg),
  mode: admin_workflows.WorkflowDialogMode,
) -> Element(msg) {
  let title = case mode {
    admin_workflows.WorkflowDialogCreate -> t(config, i18n_text.CreateWorkflow)
    admin_workflows.WorkflowDialogEdit(_) -> t(config, i18n_text.EditWorkflow)
    admin_workflows.WorkflowDialogDelete(_) -> t(config, i18n_text.EditWorkflow)
  }
  let submit_label = case mode {
    admin_workflows.WorkflowDialogCreate -> t(config, i18n_text.CreateWorkflow)
    admin_workflows.WorkflowDialogEdit(_) -> t(config, i18n_text.Save)
    admin_workflows.WorkflowDialogDelete(_) -> t(config, i18n_text.Save)
  }

  div(
    [
      attribute.class("automation-engine-panel"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-label", title),
    ],
    [
      panel_header(title, config.on_closed, t(config, i18n_text.Close)),
      view_form_error(config),
      form(
        [
          attribute.id("automation-engine-form"),
          event.on_submit(fn(_) {
            config.on_submitted(config.selected_project_id)
          }),
        ],
        [
          form_field.view(
            t(config, i18n_text.WorkflowName),
            input([
              attribute.type_("text"),
              attribute.required(True),
              attribute.value(config.form_name),
              attribute.attribute("data-testid", "automation-engine-name"),
              event.on_input(config.on_name_changed),
            ]),
          ),
          form_field.view(
            t(config, i18n_text.WorkflowDescription),
            input([
              attribute.type_("text"),
              attribute.value(config.form_description),
              attribute.attribute(
                "data-testid",
                "automation-engine-description",
              ),
              event.on_input(config.on_description_changed),
            ]),
          ),
          form_field.view_checkbox(
            t(config, i18n_text.WorkflowActive),
            input([
              attribute.type_("checkbox"),
              attribute.checked(config.form_active),
              attribute.attribute("data-testid", "automation-engine-active"),
              event.on_check(config.on_active_changed),
            ]),
          ),
        ],
      ),
      panel_actions(
        cancel: config.on_closed,
        submit: config.on_submitted(config.selected_project_id),
        submit_label: submit_label,
        submitting: config.form_submitting,
        cancel_label: t(config, i18n_text.Cancel),
        submitting_label: t(config, i18n_text.Saving),
      ),
    ],
  )
}

fn view_delete_panel(config: Config(msg), workflow: Workflow) -> Element(msg) {
  div(
    [
      attribute.class("automation-engine-panel"),
      attribute.attribute("role", "dialog"),
      attribute.attribute("aria-label", t(config, i18n_text.DeleteWorkflow)),
    ],
    [
      panel_header(
        t(config, i18n_text.DeleteWorkflow),
        config.on_closed,
        t(config, i18n_text.Close),
      ),
      view_form_error(config),
      p([], [text(t(config, i18n_text.WorkflowDeleteConfirm(workflow.name)))]),
      panel_actions(
        cancel: config.on_closed,
        submit: config.on_delete_confirmed,
        submit_label: t(config, i18n_text.DeleteWorkflow),
        submitting: config.form_submitting,
        cancel_label: t(config, i18n_text.Cancel),
        submitting_label: t(config, i18n_text.Saving),
      ),
    ],
  )
}

fn panel_header(
  title: String,
  on_closed: msg,
  close_label: String,
) -> Element(msg) {
  div([attribute.class("automation-engine-panel__header")], [
    h2([], [text(title)]),
    button(
      [
        attribute.type_("button"),
        attribute.class("icon-btn"),
        attribute.attribute("aria-label", close_label),
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
        [text(message)],
      )
  }
}

fn panel_actions(
  cancel cancel: msg,
  submit submit: msg,
  submit_label submit_label: String,
  submitting submitting: Bool,
  cancel_label cancel_label: String,
  submitting_label submitting_label: String,
) -> Element(msg) {
  div([attribute.class("automation-engine-panel__actions")], [
    button(
      [
        attribute.type_("button"),
        attribute.class("btn secondary"),
        event.on_click(cancel),
      ],
      [text(cancel_label)],
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
          True -> submitting_label
          False -> submit_label
        }),
      ],
    ),
  ])
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
