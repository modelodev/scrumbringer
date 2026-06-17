import domain/card as card_domain
import domain/milestone.{type MilestoneProgress, Active, Completed, Ready}
import domain/org.{type OrgUser}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked, unwrap}
import domain/task as task_domain
import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div}

import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/milestones/actions as milestone_actions
import scrumbringer_client/features/milestones/card_actions as milestone_card_actions
import scrumbringer_client/features/milestones/chrome as milestone_chrome
import scrumbringer_client/features/milestones/content_pane
import scrumbringer_client/features/milestones/dialogs as milestone_dialogs
import scrumbringer_client/features/milestones/empty_state as milestone_empty_state
import scrumbringer_client/features/milestones/filters as milestone_filters
import scrumbringer_client/features/milestones/labels as milestone_labels
import scrumbringer_client/features/milestones/list_pane
import scrumbringer_client/features/milestones/no_selection as milestone_no_selection
import scrumbringer_client/features/milestones/queries as milestone_queries
import scrumbringer_client/features/milestones/selection as milestone_selection
import scrumbringer_client/features/milestones/work_items
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/tone

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    milestones: Remote(List(MilestoneProgress)),
    selected_project_id: option.Option(Int),
    search_query: String,
    show_completed: Bool,
    show_empty: Bool,
    selected_milestone_id: option.Option(Int),
    summary_expanded: Bool,
    expanded_cards: dict.Dict(Int, Bool),
    dialog: member_pool.MilestoneDialog,
    dialog_in_flight: Bool,
    dialog_error: option.Option(String),
    activation_in_flight_id: option.Option(Int),
    cards: List(card_domain.Card),
    tasks: List(task_domain.Task),
    org_users: List(OrgUser),
    can_manage: Bool,
    on_create_milestone: msg,
    on_dialog_close: msg,
    on_activate_clicked: fn(Int) -> msg,
    on_create_submitted: msg,
    on_edit_submitted: fn(Int) -> msg,
    on_delete_submitted: fn(Int) -> msg,
    on_name_changed: fn(String) -> msg,
    on_description_changed: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_toggle_completed: msg,
    on_toggle_empty: msg,
    on_view_kanban: msg,
    on_select: fn(Int) -> msg,
    on_summary_toggle: msg,
    on_card_toggle: fn(Int) -> msg,
    on_quick_create_card: fn(Int) -> msg,
    on_quick_create_task: fn(Int) -> msg,
    on_activate_prompt: fn(Int) -> msg,
    on_edit: fn(Int) -> msg,
    on_delete: fn(Int) -> msg,
    on_task_open: fn(Int) -> msg,
    on_task_claim: fn(Int, Int) -> msg,
    on_card_drag_started: fn(Int, Int) -> msg,
    on_task_drag_started: fn(Int, Int) -> msg,
    on_drag_ended: msg,
    on_card_move: fn(Int, Int, Int) -> msg,
    on_task_move: fn(Int, Int, Int) -> msg,
    on_card_create_task: fn(Int) -> msg,
    on_card_edit: fn(Int) -> msg,
    on_card_delete: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let content = case config.milestones {
    NotAsked | Loading -> milestone_chrome.loading(config.locale)

    Failed(_) -> milestone_chrome.error(config.locale)

    Loaded(items) ->
      view_loaded(
        config,
        milestone_filters.by_project(items, config.selected_project_id),
      )
  }

  div([], [
    content,
    milestone_dialogs.view(dialogs_config(config)),
  ])
}

fn dialogs_config(config: Config(msg)) -> milestone_dialogs.Config(msg) {
  milestone_dialogs.Config(
    locale: config.locale,
    milestones: config.milestones,
    dialog: config.dialog,
    in_flight: config.dialog_in_flight,
    error: config.dialog_error,
    on_close: config.on_dialog_close,
    on_activate_clicked: config.on_activate_clicked,
    on_create_submitted: config.on_create_submitted,
    on_edit_submitted: config.on_edit_submitted,
    on_delete_submitted: config.on_delete_submitted,
    on_name_changed: config.on_name_changed,
    on_description_changed: config.on_description_changed,
  )
}

fn view_loaded(
  config: Config(msg),
  items: List(MilestoneProgress),
) -> Element(msg) {
  let filtered =
    milestone_filters.apply(
      items,
      milestone_filters.Config(
        search_query: config.search_query,
        show_completed: config.show_completed,
        show_empty: config.show_empty,
      ),
    )

  case items, filtered {
    [], _ -> view_empty_state(config, i18n_text.MilestonesEmpty)
    _, [] -> view_empty_state(config, i18n_text.MilestonesNoResults)
    _, _ -> view_master_detail(config, filtered)
  }
}

fn view_master_detail(
  config: Config(msg),
  items: List(MilestoneProgress),
) -> Element(msg) {
  let selected =
    milestone_selection.selected_progress(items, config.selected_milestone_id)

  div(
    [
      attribute.class("milestones-view milestones-master-detail"),
      attribute.attribute("data-testid", "milestones-view"),
    ],
    [
      milestone_chrome.header(
        config.locale,
        view_create_button(config),
        milestone_summary(config.locale, items),
      ),
      div([attribute.class("milestones-shell")], [
        view_milestone_list_pane(config, items, selected),
        view_milestone_detail_pane(config, selected),
      ]),
    ],
  )
}

fn milestone_summary(
  locale: Locale,
  items: List(MilestoneProgress),
) -> List(work_surface.SummaryChip) {
  [
    work_surface.summary_chip(
      i18n.t(locale, i18n_text.MilestonesActive),
      int.to_string(
        list.count(items, fn(progress) { progress.milestone.state == Active }),
      ),
      tone.Primary,
    ),
    work_surface.summary_chip(
      i18n.t(locale, i18n_text.MilestonesReady),
      int.to_string(
        list.count(items, fn(progress) { progress.milestone.state == Ready }),
      ),
      tone.Neutral,
    ),
    work_surface.summary_chip(
      i18n.t(locale, i18n_text.MilestonesCompleted),
      int.to_string(
        list.count(items, fn(progress) { progress.milestone.state == Completed }),
      ),
      tone.Success,
    ),
  ]
}

fn view_milestone_list_pane(
  config: Config(msg),
  items: List(MilestoneProgress),
  selected: option.Option(MilestoneProgress),
) -> Element(msg) {
  list_pane.view(list_pane.Config(
    locale: config.locale,
    items: items,
    selected_id: selected |> option.map(fn(progress) { progress.milestone.id }),
    search_query: config.search_query,
    show_completed: config.show_completed,
    show_empty: config.show_empty,
    on_search_change: config.on_search_change,
    on_toggle_completed: config.on_toggle_completed,
    on_toggle_empty: config.on_toggle_empty,
    on_select: config.on_select,
    loose_tasks_count: fn(milestone_id) {
      loose_tasks_count(config, milestone_id)
    },
    empty_cards_count: fn(milestone_id) {
      empty_cards_count(config, milestone_id)
    },
    milestone_state_label: fn(state) {
      milestone_labels.milestone_state_label(config.locale, state)
    },
    milestone_state_variant: milestone_labels.milestone_state_variant,
  ))
}

fn view_milestone_detail_pane(
  config: Config(msg),
  selected: option.Option(MilestoneProgress),
) -> Element(msg) {
  case selected {
    option.Some(progress) -> view_selected_milestone_detail(config, progress)
    option.None -> milestone_no_selection.view(config.locale)
  }
}

fn view_selected_milestone_detail(
  config: Config(msg),
  progress: MilestoneProgress,
) -> Element(msg) {
  let milestone_id = progress.milestone.id
  let loose_tasks = loose_tasks_count(config, milestone_id)
  let blocked_tasks = blocked_tasks_count(config, milestone_id)
  let empty_cards = empty_cards_count(config, milestone_id)
  let cards_without_progress =
    cards_without_progress_count(config, milestone_id)

  div(
    [
      attribute.class("milestone-detail-pane"),
      attribute.attribute("data-testid", "milestone-detail-pane"),
    ],
    [
      content_pane.view(content_pane.Config(
        locale: config.locale,
        progress: progress,
        loose_tasks: loose_tasks,
        blocked_tasks: blocked_tasks,
        empty_cards: empty_cards,
        cards_without_progress: cards_without_progress,
        cards_section: view_cards_section(config, milestone_id),
        loose_tasks_panel: view_loose_tasks_panel(config, milestone_id),
        actions: detail_header_actions(config, progress, milestone_id),
        summary_expanded: config.summary_expanded,
        on_summary_toggle: config.on_summary_toggle,
        milestone_state_label: fn(state) {
          milestone_labels.milestone_state_label(config.locale, state)
        },
        milestone_state_variant: milestone_labels.milestone_state_variant,
        progress_percentage: milestone_queries.progress_percentage,
      )),
    ],
  )
}

fn view_empty_state(
  config: Config(msg),
  message: i18n_text.Text,
) -> Element(msg) {
  milestone_empty_state.view(milestone_empty_state.EmptyConfig(
    locale: config.locale,
    message: message,
    can_manage: config.can_manage,
    on_create: config.on_create_milestone,
  ))
}

fn view_create_button(config: Config(msg)) -> Element(msg) {
  milestone_empty_state.create_button(milestone_empty_state.CreateButtonConfig(
    locale: config.locale,
    can_manage: config.can_manage,
    on_create: config.on_create_milestone,
  ))
}

fn detail_header_actions(
  config: Config(msg),
  progress: MilestoneProgress,
  milestone_id: Int,
) -> List(Element(msg)) {
  [
    view_kanban_button(config),
    ..milestone_actions.view(milestone_actions.Config(
      locale: config.locale,
      progress: progress,
      can_manage: config.can_manage,
      activation_in_flight: config.activation_in_flight_id
        == option.Some(milestone_id),
      has_other_active: has_other_active_milestone(config, milestone_id),
      on_quick_create_card: config.on_quick_create_card,
      on_quick_create_task: config.on_quick_create_task,
      on_activate_prompt: config.on_activate_prompt,
      on_edit: config.on_edit,
      on_delete: config.on_delete,
    ))
  ]
}

fn view_kanban_button(config: Config(msg)) -> Element(msg) {
  button.icon_text(
    i18n.t(config.locale, i18n_text.ViewInKanban),
    config.on_view_kanban,
    icons.Cards,
    button.Secondary,
    button.ViewAction,
  )
  |> button.with_class("milestone-view-kanban")
  |> button.view
}

fn view_cards_section(config: Config(msg), milestone_id: Int) -> Element(msg) {
  work_items.view_cards_section(work_items_config(config, milestone_id))
}

fn work_items_config(
  config: Config(msg),
  milestone_id: Int,
) -> work_items.Config(msg) {
  let destinations = ready_destination_milestones(config, milestone_id)
  let can_move = config.can_manage && is_ready_milestone(config, milestone_id)

  work_items.Config(
    locale: config.locale,
    theme: config.theme,
    milestone_id: milestone_id,
    cards: cards_for_milestone(config, milestone_id),
    loose_tasks: loose_tasks_for_milestone(config, milestone_id),
    org_users: config.org_users,
    tasks_for_card: fn(card_id) { tasks_for_card(config, card_id) },
    destinations: destinations,
    can_move: can_move,
    can_drag: can_move && destinations != [],
    is_card_expanded: fn(card_id) {
      dict.get(config.expanded_cards, card_id)
      |> option.from_result
      |> bool_or_false
    },
    on_card_toggle: config.on_card_toggle,
    on_view_kanban: config.on_view_kanban,
    card_header_actions: fn(card) { card_header_actions(config, card) },
    on_task_open: config.on_task_open,
    on_task_claim: config.on_task_claim,
    on_card_drag_started: fn(card_id) {
      config.on_card_drag_started(card_id, milestone_id)
    },
    on_task_drag_started: fn(task_id) {
      config.on_task_drag_started(task_id, milestone_id)
    },
    on_drag_ended: config.on_drag_ended,
    on_card_move: fn(card_id, destination_id) {
      config.on_card_move(card_id, milestone_id, destination_id)
    },
    on_task_move: fn(task_id, destination_id) {
      config.on_task_move(task_id, milestone_id, destination_id)
    },
    task_status_label: fn(status) {
      milestone_labels.task_status_to_short(config.locale, status)
    },
  )
}

fn bool_or_false(value: option.Option(Bool)) -> Bool {
  case value {
    option.None -> False
    option.Some(is_true) -> is_true
  }
}

fn member_milestones(config: Config(msg)) -> List(MilestoneProgress) {
  unwrap(config.milestones, [])
}

fn cards_for_milestone(
  config: Config(msg),
  milestone_id: Int,
) -> List(card_domain.Card) {
  milestone_queries.cards_for_milestone(config.cards, milestone_id)
}

fn tasks_for_card(config: Config(msg), card_id: Int) -> List(task_domain.Task) {
  milestone_queries.tasks_for_card(config.tasks, card_id)
}

fn view_loose_tasks_panel(
  config: Config(msg),
  milestone_id: Int,
) -> Element(msg) {
  work_items.view_loose_tasks_panel(work_items_config(config, milestone_id))
}

fn loose_tasks_for_milestone(
  config: Config(msg),
  milestone_id: Int,
) -> List(task_domain.Task) {
  milestone_queries.loose_tasks_for_milestone(config.tasks, milestone_id)
}

fn loose_tasks_count(config: Config(msg), milestone_id: Int) -> Int {
  milestone_queries.loose_tasks_count(config.tasks, milestone_id)
}

fn blocked_tasks_count(config: Config(msg), milestone_id: Int) -> Int {
  milestone_queries.blocked_tasks_count(
    config.tasks,
    config.cards,
    milestone_id,
  )
}

fn empty_cards_count(config: Config(msg), milestone_id: Int) -> Int {
  milestone_queries.empty_cards_count(config.cards, milestone_id)
}

fn cards_without_progress_count(config: Config(msg), milestone_id: Int) -> Int {
  milestone_queries.cards_without_progress_count(config.cards, milestone_id)
}

fn ready_destination_milestones(
  config: Config(msg),
  current_milestone_id: Int,
) -> List(milestone.Milestone) {
  milestone_queries.ready_destination_milestones(
    member_milestones(config),
    current_milestone_id,
  )
}

fn is_ready_milestone(config: Config(msg), milestone_id: Int) -> Bool {
  milestone_queries.is_ready_milestone(member_milestones(config), milestone_id)
}

fn card_header_actions(
  config: Config(msg),
  card: card_domain.Card,
) -> List(Element(msg)) {
  milestone_card_actions.view(milestone_card_actions.Config(
    locale: config.locale,
    card_id: card.id,
    card_title: card.title,
    task_count: card.task_count,
    can_manage: config.can_manage,
    on_create_task: config.on_card_create_task(card.id),
    on_edit: config.on_card_edit(card.id),
    on_delete: config.on_card_delete(card.id),
  ))
}

fn has_other_active_milestone(config: Config(msg), milestone_id: Int) -> Bool {
  milestone_queries.has_other_active_milestone(
    member_milestones(config),
    milestone_id,
  )
}
