//// Operational summary for a Task Show view.

import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{a, div, text}

import domain/remote.{type Remote, Loaded}
import domain/task as domain_task
import domain/task/state as task_execution_state

import scrumbringer_client/automation_deep_link
import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/task_state

pub type Config {
  Config(
    locale: Locale,
    task: domain_task.Task,
    dependencies: Remote(List(domain_task.TaskDependency)),
    parent_card_title: opt.Option(String),
  )
}

pub fn view(config: Config) -> Element(msg) {
  let is_owner_empty = owner_is_empty(config)
  let blocker_count = blocking_count(config)

  div([attribute.class("task-show-summary")], [
    div([attribute.class("task-show-summary-title")], [
      text(t(config.locale, i18n_text.TaskOperationalSummary)),
    ]),
    div(
      [attribute.class("task-show-summary-grid")],
      [
        summary_item(
          t(config.locale, i18n_text.Status),
          task_state.label(
            config.locale,
            task_execution_state.to_status(config.task.state),
          ),
          False,
        ),
        summary_item(
          t(config.locale, i18n_text.Priority),
          t(config.locale, i18n_text.PriorityShort(config.task.priority)),
          False,
        ),
        summary_item(
          t(config.locale, i18n_text.TaskType),
          config.task.task_type.name,
          False,
        ),
        summary_item(
          t(config.locale, i18n_text.ParentCardLabel),
          card_label(config),
          card_is_empty(config),
        ),
        summary_item(
          t(config.locale, i18n_text.TaskOwner),
          owner_label(config),
          is_owner_empty,
        ),
        summary_item(
          t(config.locale, i18n_text.Blocked),
          blocking_label(config, blocker_count),
          blocker_count == 0,
        ),
      ]
        |> list.append(automation_origin_items(config)),
    ),
  ])
}

fn summary_item(label: String, value: String, muted: Bool) -> Element(msg) {
  div([attribute.class("task-show-summary-item")], [
    div([attribute.class("task-show-summary-label")], [text(label)]),
    div(
      [
        attribute.class(case muted {
          True -> "task-show-summary-value muted"
          False -> "task-show-summary-value"
        }),
      ],
      [text(value)],
    ),
  ])
}

fn automation_origin_items(config: Config) -> List(Element(msg)) {
  case config.task.automation_origin {
    opt.Some(origin) -> [automation_origin_item(config, origin)]
    opt.None -> []
  }
}

fn automation_origin_item(
  config: Config,
  origin: domain_task.AutomationOrigin,
) -> Element(msg) {
  div([attribute.class("task-show-summary-item")], [
    div([attribute.class("task-show-summary-label")], [
      text(t(config.locale, i18n_text.TaskAutomationOrigin)),
    ]),
    div([attribute.class("task-show-summary-value")], [
      div([attribute.class("task-show-summary-origin-kind")], [
        text(t(config.locale, i18n_text.TaskAutomationCreatedBy)),
      ]),
      a(
        [
          attribute.href(automation_execution_href(config, origin)),
          attribute.attribute("data-testid", "automation-created-task-origin"),
        ],
        [text(automation_origin_label(config.locale, origin))],
      ),
      div(
        [attribute.class("task-show-summary-actions")],
        automation_origin_links(config, origin),
      ),
    ]),
  ])
}

fn automation_origin_links(
  config: Config,
  origin: domain_task.AutomationOrigin,
) -> List(Element(msg)) {
  let engine_link = case origin.workflow_id {
    opt.Some(id) -> [
      automation_link(
        config.locale,
        automation_route(
          config.task.project_id,
          permissions.Workflows,
          automation_deep_link.SelectedEngine(id),
        ),
        i18n_text.TaskAutomationViewEngine,
        "automation-origin-engine-link",
      ),
    ]
    opt.None -> []
  }

  let rule_link = [
    automation_link(
      config.locale,
      automation_route(
        config.task.project_id,
        permissions.Workflows,
        automation_deep_link.SelectedRule(origin.rule_id, origin.workflow_id),
      ),
      i18n_text.TaskAutomationViewRule,
      "automation-origin-rule-link",
    ),
  ]

  let template_link = case origin.template_id {
    opt.Some(id) -> [
      automation_link(
        config.locale,
        automation_route(
          config.task.project_id,
          permissions.TaskTemplates,
          automation_deep_link.SelectedTemplate(id),
        ),
        i18n_text.TaskAutomationViewTemplate,
        "automation-origin-template-link",
      ),
    ]
    opt.None -> []
  }

  engine_link
  |> list.append(rule_link)
  |> list.append(template_link)
}

fn automation_link(
  locale: Locale,
  href: String,
  label: i18n_text.Text,
  testid: String,
) -> Element(msg) {
  a(
    [
      attribute.href(href),
      attribute.class("task-show-summary-action"),
      attribute.attribute("data-testid", testid),
    ],
    [text(t(locale, label))],
  )
}

fn automation_execution_href(
  config: Config,
  origin: domain_task.AutomationOrigin,
) -> String {
  case origin.execution_id {
    opt.Some(id) ->
      automation_route(
        config.task.project_id,
        permissions.RuleMetrics,
        automation_deep_link.SelectedExecution(id),
      )
    opt.None ->
      router.format(router.Config(
        permissions.RuleMetrics,
        opt.Some(config.task.project_id),
      ))
  }
}

fn automation_route(
  project_id: Int,
  section: permissions.AdminSection,
  selection: automation_deep_link.Selection,
) -> String {
  router.format(router.ConfigAutomation(
    section,
    opt.Some(project_id),
    selection,
  ))
}

fn automation_origin_label(
  locale: Locale,
  origin: domain_task.AutomationOrigin,
) -> String {
  [
    workflow_label(locale, origin),
    rule_label(locale, origin),
    template_label(locale, origin),
  ]
  |> string.join(" -> ")
}

fn workflow_label(
  locale: Locale,
  origin: domain_task.AutomationOrigin,
) -> String {
  case origin.workflow_name, origin.workflow_id {
    opt.Some(name), _ -> name
    _, opt.Some(id) -> t(locale, i18n_text.TaskAutomationEngineLabel(id))
    _, _ -> t(locale, i18n_text.TaskAutomationCreatedBy)
  }
}

fn rule_label(locale: Locale, origin: domain_task.AutomationOrigin) -> String {
  case origin.rule_name {
    opt.Some(name) -> name
    opt.None -> t(locale, i18n_text.TaskAutomationRuleLabel(origin.rule_id))
  }
}

fn template_label(
  locale: Locale,
  origin: domain_task.AutomationOrigin,
) -> String {
  let base = case origin.template_name, origin.template_id {
    opt.Some(name), _ -> name
    _, opt.Some(id) -> t(locale, i18n_text.TaskAutomationTemplateLabel(id))
    _, _ -> t(locale, i18n_text.TaskAutomationTemplateFallback)
  }

  case origin.template_version {
    opt.Some(version) -> base <> " v" <> int.to_string(version)
    opt.None -> base
  }
}

fn card_label(config: Config) -> String {
  case config.parent_card_title {
    opt.Some(title) -> title
    opt.None -> t(config.locale, i18n_text.NoCard)
  }
}

fn card_is_empty(config: Config) -> Bool {
  config.parent_card_title == opt.None
}

fn owner_label(config: Config) -> String {
  case task_execution_state.claimed_by(config.task.state) {
    opt.Some(_) -> t(config.locale, i18n_text.Assigned)
    opt.None -> t(config.locale, i18n_text.Unassigned)
  }
}

fn owner_is_empty(config: Config) -> Bool {
  task_execution_state.claimed_by(config.task.state) == opt.None
}

fn blocking_label(config: Config, count: Int) -> String {
  case count {
    0 -> t(config.locale, i18n_text.TaskBlockingClear)
    count -> t(config.locale, i18n_text.BlockedByTasks(count))
  }
}

fn blocking_count(config: Config) -> Int {
  case config.dependencies {
    Loaded(dependencies) -> blocking.incomplete_dependency_count(dependencies)
    _ -> config.task.blocked_count
  }
}

fn t(locale: Locale, key: i18n_text.Text) -> String {
  i18n.t(locale, key)
}
