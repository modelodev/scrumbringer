//// Right Panel - Activity and profile panel
////
//// Mission: Render the right panel with user activity (my tasks, my cards),
//// active task timer, and profile/logout controls.
////
//// Responsibilities:
//// - "My Tasks" section with claimed tasks
//// - "My Cards" section with user's card progress
//// - Active task timer with controls
//// - Profile info and logout button
////
//// Non-responsibilities:
//// - Layout structure (handled by ThreePanelLayout)
//// - Timer logic (handled by parent)
//// - API calls (handled by parent)

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h4, span, text}
import lustre/event

import domain/task.{type Task}
import domain/user.{type User}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

// =============================================================================
// Types
// =============================================================================

/// Active task info for timer display
pub type ActiveTaskInfo {
  ActiveTaskInfo(
    task_id: Int,
    task_title: String,
    elapsed_display: String,
    is_paused: Bool,
  )
}

/// Card with progress for my cards section
pub type MyCardProgress {
  MyCardProgress(card_id: Int, card_title: String, completed: Int, total: Int)
}

/// Configuration for the right panel
pub type RightPanelConfig(msg) {
  RightPanelConfig(
    locale: Locale,
    user: Option(User),
    my_tasks: List(Task),
    my_cards: List(MyCardProgress),
    active_task: Option(ActiveTaskInfo),
    on_task_start: fn(Int) -> msg,
    on_task_pause: msg,
    on_task_complete: msg,
    on_task_release: fn(Int) -> msg,
    on_card_click: fn(Int) -> msg,
    on_logout: msg,
  )
}

// =============================================================================
// View
// =============================================================================

/// Renders the right panel with all sections
pub fn view(config: RightPanelConfig(msg)) -> Element(msg) {
  div(
    [attribute.class("right-panel-content")],
    [
      // Active task timer (if any)
      case config.active_task {
        Some(active) -> view_active_task(config, active)
        None -> element.none()
      },
      // My Tasks section
      view_my_tasks(config),
      // My Cards section (placeholder for now)
      view_my_cards(config),
      // Profile and logout
      view_profile(config),
    ],
  )
}

// =============================================================================
// Active Task Timer
// =============================================================================

fn view_active_task(
  config: RightPanelConfig(msg),
  active: ActiveTaskInfo,
) -> Element(msg) {
  div(
    [
      attribute.class("active-task-section"),
      attribute.attribute("data-testid", "active-task"),
    ],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.InProgress)),
      ]),
      div(
        [attribute.class("active-task-card")],
        [
          div([attribute.class("task-title")], [text(active.task_title)]),
          div(
            [
              attribute.class("task-timer"),
              attribute.attribute("data-testid", "task-timer"),
            ],
            [text(active.elapsed_display)],
          ),
          div(
            [attribute.class("task-actions")],
            [
              case active.is_paused {
                True ->
                  button(
                    [
                      attribute.class("btn-xs"),
                      attribute.attribute("data-testid", "my-task-start-btn"),
                      event.on_click(config.on_task_start(active.task_id)),
                    ],
                    [text(i18n.t(config.locale, i18n_text.Resume))],
                  )
                False ->
                  button(
                    [
                      attribute.class("btn-xs"),
                      attribute.attribute("data-testid", "task-pause-btn"),
                      event.on_click(config.on_task_pause),
                    ],
                    [text(i18n.t(config.locale, i18n_text.Pause))],
                  )
              },
              button(
                [
                  attribute.class("btn-xs"),
                  attribute.attribute("data-testid", "task-complete-btn"),
                  event.on_click(config.on_task_complete),
                ],
                [text(i18n.t(config.locale, i18n_text.Complete))],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}

// =============================================================================
// My Tasks Section
// =============================================================================

fn view_my_tasks(config: RightPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("my-tasks-section"),
      attribute.attribute("data-testid", "my-tasks"),
    ],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.MyTasks)),
      ]),
      case config.my_tasks {
        [] ->
          div([attribute.class("empty-state")], [
            text(i18n.t(config.locale, i18n_text.NoTasksClaimed)),
          ])
        tasks ->
          div(
            [attribute.class("task-list")],
            list.map(tasks, fn(task) { view_my_task_item(config, task) }),
          )
      },
    ],
  )
}

fn view_my_task_item(config: RightPanelConfig(msg), task: Task) -> Element(msg) {
  div(
    [attribute.class("task-item")],
    [
      span([attribute.class("task-title")], [text(task.title)]),
      div(
        [attribute.class("task-actions")],
        [
          button(
            [
              attribute.class("btn-xs"),
              attribute.attribute("data-testid", "my-task-start-btn"),
              event.on_click(config.on_task_start(task.id)),
            ],
            [text(i18n.t(config.locale, i18n_text.Start))],
          ),
          button(
            [
              attribute.class("btn-xs"),
              attribute.attribute("data-testid", "my-task-release-btn"),
              event.on_click(config.on_task_release(task.id)),
            ],
            [text(i18n.t(config.locale, i18n_text.Release))],
          ),
        ],
      ),
    ],
  )
}

// =============================================================================
// My Cards Section
// =============================================================================

fn view_my_cards(config: RightPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("my-cards-section"),
      attribute.attribute("data-testid", "my-cards"),
    ],
    [
      h4([attribute.class("section-title")], [
        text(i18n.t(config.locale, i18n_text.MyCards)),
      ]),
      case config.my_cards {
        [] ->
          div([attribute.class("empty-state")], [
            text(i18n.t(config.locale, i18n_text.NoCardsAssigned)),
          ])
        cards ->
          div(
            [attribute.class("my-cards-list")],
            list.map(cards, fn(card) { view_my_card_item(config, card) }),
          )
      },
    ],
  )
}

fn view_my_card_item(
  config: RightPanelConfig(msg),
  card: MyCardProgress,
) -> Element(msg) {
  let progress_text =
    int.to_string(card.completed) <> "/" <> int.to_string(card.total)

  button(
    [
      attribute.class("my-card-item"),
      attribute.attribute("data-testid", "my-card-item"),
      event.on_click(config.on_card_click(card.card_id)),
    ],
    [
      span([attribute.class("card-title")], [text(card.card_title)]),
      span([attribute.class("card-progress")], [text(progress_text)]),
    ],
  )
}

// =============================================================================
// Profile Section
// =============================================================================

fn view_profile(config: RightPanelConfig(msg)) -> Element(msg) {
  div(
    [attribute.class("profile-section")],
    [
      case config.user {
        Some(user) ->
          div(
            [attribute.class("user-info")],
            [
              span([attribute.class("user-email")], [text(user.email)]),
            ],
          )
        None -> element.none()
      },
      button(
        [
          attribute.class("btn-logout"),
          attribute.attribute("data-testid", "logout-btn"),
          event.on_click(config.on_logout),
        ],
        [text(i18n.t(config.locale, i18n_text.Logout))],
      ),
    ],
  )
}
