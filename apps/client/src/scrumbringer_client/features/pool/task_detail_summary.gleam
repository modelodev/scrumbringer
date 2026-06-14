//// Operational summary for a task detail view.

import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import domain/milestone.{type MilestoneProgress}
import domain/remote.{type Remote, Loaded}
import domain/task.{type Task, type TaskDependency, claimed_by}

import scrumbringer_client/features/pool/blocking
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/task_state

pub type Config {
  Config(
    locale: Locale,
    task: Task,
    dependencies: Remote(List(TaskDependency)),
    milestones: Remote(List(MilestoneProgress)),
    parent_card_title: opt.Option(String),
  )
}

pub fn view(config: Config) -> Element(msg) {
  let is_owner_empty = owner_is_empty(config)
  let blocker_count = blocking_count(config)

  div([attribute.class("task-detail-summary")], [
    div([attribute.class("task-detail-summary-title")], [
      text(t(config.locale, i18n_text.TaskOperationalSummary)),
    ]),
    div([attribute.class("task-detail-summary-grid")], [
      summary_item(
        t(config.locale, i18n_text.Status),
        task_state.label(config.locale, config.task.status),
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
        t(config.locale, i18n_text.MilestoneLabel),
        milestone_label(config),
        milestone_is_empty(config),
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
    ]),
  ])
}

fn summary_item(label: String, value: String, muted: Bool) -> Element(msg) {
  div([attribute.class("task-detail-summary-item")], [
    div([attribute.class("task-detail-summary-label")], [text(label)]),
    div(
      [
        attribute.class(case muted {
          True -> "task-detail-summary-value muted"
          False -> "task-detail-summary-value"
        }),
      ],
      [text(value)],
    ),
  ])
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

fn milestone_label(config: Config) -> String {
  case config.task.milestone_id, config.milestones {
    opt.Some(milestone_id), Loaded(milestones) ->
      case
        list.find(milestones, fn(progress) {
          progress.milestone.id == milestone_id
        })
      {
        Ok(progress) -> progress.milestone.name
        Error(_) -> t(config.locale, i18n_text.NoMilestone)
      }
    opt.Some(_), _ -> t(config.locale, i18n_text.LoadingEllipsis)
    opt.None, _ -> t(config.locale, i18n_text.NoMilestone)
  }
}

fn milestone_is_empty(config: Config) -> Bool {
  config.task.milestone_id == opt.None
}

fn owner_label(config: Config) -> String {
  case claimed_by(config.task) {
    opt.Some(_) -> t(config.locale, i18n_text.Assigned)
    opt.None -> t(config.locale, i18n_text.Unassigned)
  }
}

fn owner_is_empty(config: Config) -> Bool {
  claimed_by(config.task) == opt.None
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
