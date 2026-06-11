import domain/milestone.{
  type MilestoneProgress, type MilestoneState, Active, Completed, Ready,
}
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element, none}
import lustre/element/html.{button, div, h4, input, label, p, span, text}
import lustre/element/keyed
import lustre/event

import scrumbringer_client/features/milestones/queries as milestone_queries
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/badge

pub type Config(msg) {
  Config(
    locale: Locale,
    items: List(MilestoneProgress),
    selected_id: option.Option(Int),
    search_query: String,
    show_completed: Bool,
    show_empty: Bool,
    on_search_change: fn(String) -> msg,
    on_toggle_completed: msg,
    on_toggle_empty: msg,
    on_select: fn(Int) -> msg,
    loose_tasks_count: fn(Int) -> Int,
    empty_cards_count: fn(Int) -> Int,
    milestone_state_label: fn(MilestoneState) -> String,
    milestone_state_variant: fn(MilestoneState) -> badge.BadgeVariant,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let ready_items = by_state(config.items, Ready)
  let active_items = by_state(config.items, Active)
  let completed_items = by_state(config.items, Completed)

  div([attribute.class("milestones-list-pane")], [
    view_filters(config),
    view_section(config, i18n_text.MilestonesActive, active_items),
    view_section(config, i18n_text.MilestonesReady, ready_items),
    case config.show_completed {
      True ->
        view_section(config, i18n_text.MilestonesCompleted, completed_items)
      False -> none()
    },
  ])
}

fn view_filters(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("milestones-filters"),
      attribute.attribute("data-testid", "milestones-filters"),
    ],
    [
      input([
        attribute.type_("search"),
        attribute.class("milestones-search"),
        attribute.attribute("data-testid", "milestones-search"),
        attribute.placeholder(i18n.t(
          config.locale,
          i18n_text.MilestoneSearchPlaceholder,
        )),
        attribute.value(config.search_query),
        event.on_input(config.on_search_change),
      ]),
      div([attribute.class("milestones-filter-row")], [
        label([attribute.class("milestones-filter-chip")], [
          input([
            attribute.type_("checkbox"),
            attribute.class("milestones-filter-checkbox"),
            attribute.attribute("data-testid", "milestones-filter-completed"),
            attribute.checked(config.show_completed),
            event.on_check(fn(_) { config.on_toggle_completed }),
          ]),
          text(" " <> i18n.t(config.locale, i18n_text.ShowCompletedMilestones)),
        ]),
        label([attribute.class("milestones-filter-chip")], [
          input([
            attribute.type_("checkbox"),
            attribute.class("milestones-filter-checkbox"),
            attribute.attribute("data-testid", "milestones-filter-empty"),
            attribute.checked(config.show_empty),
            event.on_check(fn(_) { config.on_toggle_empty }),
          ]),
          text(" " <> i18n.t(config.locale, i18n_text.ShowEmptyMilestones)),
        ]),
      ]),
    ],
  )
}

fn view_section(
  config: Config(msg),
  title: i18n_text.Text,
  items: List(MilestoneProgress),
) -> Element(msg) {
  case items {
    [] -> none()
    _ ->
      div([attribute.class("milestones-list-section")], [
        h4([attribute.class("milestones-section-title")], [
          text(i18n.t(config.locale, title)),
        ]),
        keyed.div(
          [attribute.class("milestones-items")],
          list.map(items, fn(item) {
            #(
              int.to_string(item.milestone.id),
              view_item(
                config,
                item,
                config.selected_id == option.Some(item.milestone.id),
              ),
            )
          }),
        ),
      ])
  }
}

fn view_item(
  config: Config(msg),
  progress: MilestoneProgress,
  selected: Bool,
) -> Element(msg) {
  let milestone_id = progress.milestone.id
  let css = case selected {
    True -> "milestone-item milestone-item-selected"
    False -> "milestone-item"
  }

  button(
    [
      attribute.class(css),
      attribute.attribute("type", "button"),
      attribute.attribute(
        "data-testid",
        "milestone-row:" <> int.to_string(milestone_id),
      ),
      attribute.attribute("aria-pressed", attribute_value.boolean(selected)),
      event.on_click(config.on_select(milestone_id)),
    ],
    [
      div([attribute.class("milestone-item-header")], [
        div([attribute.class("milestone-row-header-main")], [
          span([attribute.class("milestone-row-title-link")], [
            text(progress.milestone.name),
          ]),
        ]),
        div([attribute.class("milestone-item-meta")], [
          badge.quick(
            config.milestone_state_label(progress.milestone.state),
            config.milestone_state_variant(progress.milestone.state),
          ),
          span([attribute.class("milestone-progress-percent")], [
            text(
              int.to_string(milestone_queries.progress_percentage(progress))
              <> "%",
            ),
          ]),
        ]),
      ]),
      div(
        [attribute.class("milestone-item-stats")],
        list.append(
          [
            pill(
              config.locale,
              i18n_text.MilestoneCardsCount(progress.cards_total),
            ),
          ],
          optional_loose_tasks_pill(
            config.locale,
            config.loose_tasks_count(milestone_id),
          ),
        ),
      ),
      p([attribute.class("milestone-item-description milestone-health-hint")], [
        text(health_hint(config, progress)),
      ]),
    ],
  )
}

fn health_hint(config: Config(msg), progress: MilestoneProgress) -> String {
  let loose_tasks = config.loose_tasks_count(progress.milestone.id)
  let empty_cards = config.empty_cards_count(progress.milestone.id)

  case
    progress.milestone.state,
    progress.cards_total,
    loose_tasks,
    empty_cards
  {
    Ready, 0, 0, _ -> i18n.t(config.locale, i18n_text.MilestoneEmptyHint)
    _, _, loose_count, _ if loose_count > 0 ->
      i18n.t(config.locale, i18n_text.MilestoneLooseTasksHint)
    _, _, _, empty_count if empty_count > 0 ->
      i18n.t(config.locale, i18n_text.MilestoneEmptyCardsCount(empty_count))
    Active, _, _, _ -> i18n.t(config.locale, i18n_text.MilestoneStateActive)
    Completed, _, _, _ -> i18n.t(config.locale, i18n_text.MetricsTasksCompleted)
    _, _, _, _ -> i18n.t(config.locale, i18n_text.MilestoneStructureSummary)
  }
}

fn by_state(
  items: List(MilestoneProgress),
  state: MilestoneState,
) -> List(MilestoneProgress) {
  list.filter(items, fn(progress) { progress.milestone.state == state })
}

fn pill(locale: Locale, label: i18n_text.Text) -> Element(msg) {
  span([attribute.class("milestone-stat-pill")], [
    text(i18n.t(locale, label)),
  ])
}

fn optional_loose_tasks_pill(
  locale: Locale,
  loose_tasks: Int,
) -> List(Element(msg)) {
  case loose_tasks > 0 {
    True -> [pill(locale, i18n_text.MilestoneLooseTasksCount(loose_tasks))]
    False -> []
  }
}
