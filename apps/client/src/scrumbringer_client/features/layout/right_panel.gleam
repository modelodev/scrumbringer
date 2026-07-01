//// Right Panel - Activity and profile panel
////
//// Mission: Render the right panel with user activity (my tasks, my cards),
//// active task timer, preferences, and profile/logout controls.
////
//// Responsibilities:
//// - "My Tasks" section with claimed tasks
//// - "My Cards" section with user's card progress
//// - "My Metrics" section with personal stats
//// - Active task timer with controls
//// - Preferences section (theme, language)
//// - Profile info and logout button (always at bottom)
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
import lustre/element/html.{
  button, div, h3, h4, label, option, select, span, text,
}
import lustre/element/keyed
import lustre/event

import domain/card
import domain/task.{type Task}
import domain/user.{type User}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/button as ui_button
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_type_icon

/// Active task info for timer display
pub type ActiveTaskInfo {
  ActiveTaskInfo(
    task_id: Int,
    task_title: String,
    task_type_icon: String,
    card_color: Option(card.CardColor),
    elapsed_display: String,
    is_paused: Bool,
  )
}

/// Card with progress for my cards section
pub type MyCardProgress {
  MyCardProgress(
    card_id: Int,
    card_title: String,
    card_color: Option(card.CardColor),
    closed: Int,
    total: Int,
  )
}

/// Configuration for the right panel
pub type RightPanelConfig(msg) {
  RightPanelConfig(
    locale: Locale,
    user: Option(User),
    my_tasks: List(Task),
    my_cards: List(MyCardProgress),
    active_tasks: List(ActiveTaskInfo),
    task_card_color: fn(Task) -> Option(card.CardColor),
    on_task_start: fn(Int) -> msg,
    on_task_pause: fn(Int) -> msg,
    on_task_close: fn(Int) -> msg,
    on_task_release: fn(Int) -> msg,
    on_task_click: fn(Int) -> msg,
    on_card_click: fn(Int) -> msg,
    on_logout: msg,
    drag_armed: Bool,
    drag_over_my_tasks: Bool,
    preferences_popup_open: Bool,
    on_preferences_toggle: msg,
    current_theme: Theme,
    on_theme_change: fn(String) -> msg,
    on_locale_change: fn(String) -> msg,
    disable_actions: Bool,
  )
}

/// Renders the right panel with all sections
pub fn view(config: RightPanelConfig(msg)) -> Element(msg) {
  div(
    [
      attribute.class("right-panel-content"),
      attribute.attribute("aria-live", "polite"),
    ],
    [
      div([attribute.class("right-panel-activity")], [
        view_active_tasks_section(config),
        view_my_tasks(config),
        view_my_cards(config),
      ]),
      div([attribute.class("right-panel-footer")], [
        view_profile(config),
      ]),
      view_preferences_popup(config),
    ],
  )
}

fn view_active_tasks_section(config: RightPanelConfig(msg)) -> Element(msg) {
  let is_empty = list.is_empty(config.active_tasks)
  let task_count = list.length(config.active_tasks)

  let header_text = case is_empty {
    True -> i18n.t(config.locale, i18n_text.InProgress) <> " (0)"
    False ->
      case task_count {
        1 -> i18n.t(config.locale, i18n_text.InProgress)
        n ->
          i18n.t(config.locale, i18n_text.InProgress)
          <> " ("
          <> int.to_string(n)
          <> ")"
      }
  }

  let section_class = case is_empty {
    True -> "active-task-section section-collapsed"
    False -> "active-task-section"
  }

  div(
    [
      attribute.class(section_class),
      attribute.attribute("data-testid", "active-task"),
    ],
    [
      h3([attribute.class("section-title section-title-with-icon")], [
        icons.nav_icon(icons.Play, icons.Small),
        text(header_text),
      ]),
      case config.active_tasks {
        [] ->
          div([attribute.class("section-empty-hint")], [
            text(i18n.t(config.locale, i18n_text.NoTasksInProgressHint)),
          ])
        tasks ->
          keyed.div(
            [attribute.class("active-tasks-list")],
            list.map(tasks, fn(active) {
              #(
                int.to_string(active.task_id),
                view_active_task_card(config, active),
              )
            }),
          )
      },
    ],
  )
}

fn view_active_task_card(
  config: RightPanelConfig(msg),
  active: ActiveTaskInfo,
) -> Element(msg) {
  let border_class = task_color.card_border_class(active.card_color)

  div(
    [
      attribute.class("active-task-card " <> border_class),
      attribute.attribute("title", active.task_title),
    ],
    [
      div([attribute.class("task-title-row")], [
        span([attribute.class("task-type-icon")], [
          task_type_icon.view(active.task_type_icon, 14, config.current_theme),
        ]),
        span([attribute.class("task-title")], [text(active.task_title)]),
      ]),
      div(
        [
          attribute.class("task-timer"),
          attribute.attribute("data-testid", "task-timer"),
        ],
        [text(active.elapsed_display)],
      ),
      div([attribute.class("task-actions")], [
        case active.is_paused {
          True ->
            action_buttons.task_icon_button(
              i18n.t(config.locale, i18n_text.Resume),
              config.on_task_start(active.task_id),
              icons.Play,
              action_buttons.SizeXs,
              config.disable_actions,
              "",
              None,
              Some("my-task-start-btn"),
            )
          False ->
            task_actions.pause_icon(
              i18n.t(config.locale, i18n_text.Pause),
              config.on_task_pause(active.task_id),
              action_buttons.SizeXs,
              config.disable_actions,
              "",
              None,
              Some("task-pause-btn"),
            )
        },
        task_actions.close_icon(
          i18n.t(config.locale, i18n_text.TaskNextActionClose),
          config.on_task_close(active.task_id),
          action_buttons.SizeXs,
          config.disable_actions,
          "",
          None,
          Some("task-close-btn"),
        ),
      ]),
    ],
  )
}

fn view_my_tasks(config: RightPanelConfig(msg)) -> Element(msg) {
  let active_task_ids = list.map(config.active_tasks, fn(a) { a.task_id })
  let filtered_tasks =
    list.filter(config.my_tasks, fn(task) {
      !list.contains(active_task_ids, task.id)
    })

  let dropzone_class = case config.drag_armed, config.drag_over_my_tasks {
    True, True -> "my-tasks-section pool-my-tasks-dropzone drop-over"
    True, False -> "my-tasks-section pool-my-tasks-dropzone drag-active"
    False, _ -> "my-tasks-section pool-my-tasks-dropzone"
  }

  let is_empty = list.is_empty(filtered_tasks)
  let section_class = case is_empty {
    True -> dropzone_class <> " section-collapsed"
    False -> dropzone_class
  }

  div(
    [
      attribute.attribute("id", "pool-my-tasks"),
      attribute.class(section_class),
      attribute.attribute("data-testid", "my-tasks"),
    ],
    [
      case config.drag_armed {
        True ->
          div([attribute.class("dropzone-hint")], [
            text(
              i18n.t(config.locale, i18n_text.Claim)
              <> ": "
              <> i18n.t(config.locale, i18n_text.MyTasks),
            ),
          ])
        False -> element.none()
      },
      h3([attribute.class("section-title section-title-with-icon")], [
        icons.nav_icon(icons.ClipboardDoc, icons.Small),
        text(i18n.t(config.locale, i18n_text.MyTasks)),
        case is_empty {
          True ->
            span([attribute.class("section-empty-indicator")], [
              text(" (0)"),
            ])
          False ->
            span([attribute.class("section-count")], [
              text(" (" <> int.to_string(list.length(filtered_tasks)) <> ")"),
            ])
        },
      ]),
      case filtered_tasks {
        [] ->
          div([attribute.class("section-empty-hint")], [
            text(i18n.t(config.locale, i18n_text.NoTasksClaimedHint)),
          ])
        tasks ->
          keyed.div(
            [attribute.class("task-list")],
            list.map(tasks, fn(task) {
              #(int.to_string(task.id), view_my_task_item(config, task))
            }),
          )
      },
    ],
  )
}

fn view_my_task_item(config: RightPanelConfig(msg), task: Task) -> Element(msg) {
  let resolved_color = config.task_card_color(task)
  let border_class = task_color.card_border_class(resolved_color)
  let open_label =
    i18n.t(config.locale, i18n_text.OpenTask) <> ": " <> task.title

  task_item.view(
    task_item.Config(
      container_class: "right-panel-task-row " <> border_class,
      content_class: "right-panel-task-button",
      leading: Some(view_task_card_swatch()),
      on_click: Some(config.on_task_click(task.id)),
      content_title: Some(task.title),
      content_label: Some(open_label),
      icon: Some(task_type_icon.view(
        task.task_type.icon,
        14,
        config.current_theme,
      )),
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: task_item.empty_secondary(),
      actions: [
        div([attribute.class("task-actions")], [
          action_buttons.task_icon_button(
            i18n.t(config.locale, i18n_text.Start),
            config.on_task_start(task.id),
            icons.Play,
            action_buttons.SizeXs,
            config.disable_actions,
            "",
            None,
            Some("my-task-start-btn"),
          ),
          task_actions.release_icon(
            i18n.t(config.locale, i18n_text.Release),
            config.on_task_release(task.id),
            action_buttons.SizeXs,
            config.disable_actions,
            "",
            None,
            Some("my-task-release-btn"),
          ),
        ]),
      ],
      reserve_actions_slot: False,
      action_slot_class: None,
      content_testid: Some("mobile-task-open"),
      testid: None,
    ),
    task_item.Div,
  )
}

fn view_task_card_swatch() -> Element(msg) {
  span(
    [
      attribute.class("task-card-identity-swatch"),
      attribute.attribute("aria-hidden", "true"),
    ],
    [],
  )
}

fn view_my_cards(config: RightPanelConfig(msg)) -> Element(msg) {
  let is_empty = list.is_empty(config.my_cards)
  let section_class = case is_empty {
    True -> "my-cards-section section-collapsed"
    False -> "my-cards-section"
  }

  div(
    [
      attribute.class(section_class),
      attribute.attribute("data-testid", "my-cards"),
    ],
    [
      h3([attribute.class("section-title section-title-with-icon")], [
        icons.nav_icon(icons.Cards, icons.Small),
        text(i18n.t(config.locale, i18n_text.MyCards)),
        case is_empty {
          True ->
            span([attribute.class("section-empty-indicator")], [
              text(" (0)"),
            ])
          False ->
            span([attribute.class("section-count")], [
              text(" (" <> int.to_string(list.length(config.my_cards)) <> ")"),
            ])
        },
      ]),
      case config.my_cards {
        [] ->
          div([attribute.class("section-empty-hint")], [
            text(i18n.t(config.locale, i18n_text.NoCardsAssignedHint)),
          ])
        cards ->
          keyed.div(
            [attribute.class("my-cards-list")],
            list.map(cards, fn(card) {
              #(int.to_string(card.card_id), view_my_card_item(config, card))
            }),
          )
      },
    ],
  )
}

fn view_my_card_item(
  config: RightPanelConfig(msg),
  card: MyCardProgress,
) -> Element(msg) {
  let border_class = task_color.card_border_class(card.card_color)
  let open_label =
    i18n.t(config.locale, i18n_text.MyCards) <> ": " <> card.card_title

  button(
    [
      attribute.class("my-card-item " <> border_class),
      attribute.attribute("data-testid", "my-card-item"),
      attribute.type_("button"),
      attribute.attribute("title", card.card_title),
      attribute.attribute("aria-label", open_label),
      event.on_click(config.on_card_click(card.card_id)),
    ],
    [
      span([attribute.class("card-title")], [text(card.card_title)]),
      card_progress.view(
        config.locale,
        card.closed,
        card.total,
        card_progress.Compact,
      ),
    ],
  )
}

fn view_preferences_popup(config: RightPanelConfig(msg)) -> Element(msg) {
  case config.preferences_popup_open {
    False -> element.none()
    True -> {
      let current_theme = theme.serialize(config.current_theme)
      let current_locale = locale.serialize(config.locale)

      div([attribute.class("preferences-popup-overlay")], [
        div(
          [
            attribute.class("preferences-popup"),
            attribute.attribute("data-testid", "preferences-popup"),
            attribute.attribute("role", "dialog"),
            attribute.attribute("aria-modal", "true"),
            attribute.attribute("aria-labelledby", "preferences-popup-title"),
          ],
          [
            div([attribute.class("popup-header")], [
              h4(
                [
                  attribute.class("popup-title"),
                  attribute.attribute("id", "preferences-popup-title"),
                ],
                [
                  icons.nav_icon(icons.Cog, icons.Small),
                  text(i18n.t(config.locale, i18n_text.Preferences)),
                ],
              ),
              profile_icon_button(
                i18n.t(config.locale, i18n_text.Close),
                icons.Close,
                config.on_preferences_toggle,
              ),
            ]),
            div([attribute.class("preferences-popup-content")], [
              label([attribute.class("preference-item")], [
                span([attribute.class("preference-icon")], [
                  case config.current_theme {
                    theme.Dark -> icons.nav_icon(icons.Moon, icons.Small)
                    theme.Default -> icons.nav_icon(icons.Sun, icons.Small)
                  },
                ]),
                span([attribute.class("sr-only")], [
                  text(i18n.t(config.locale, i18n_text.ThemeLabel)),
                ]),
                select(
                  [
                    attribute.class("preference-select"),
                    attribute.value(current_theme),
                    attribute.attribute("data-testid", "theme-selector"),
                    event.on_input(config.on_theme_change),
                  ],
                  [
                    option(
                      [attribute.value("default")],
                      i18n.t(config.locale, i18n_text.ThemeDefault),
                    ),
                    option(
                      [attribute.value("dark")],
                      i18n.t(config.locale, i18n_text.ThemeDark),
                    ),
                  ],
                ),
              ]),
              label([attribute.class("preference-item")], [
                span([attribute.class("preference-icon")], [
                  icons.nav_icon(icons.Globe, icons.Small),
                ]),
                span([attribute.class("sr-only")], [
                  text(i18n.t(config.locale, i18n_text.LanguageLabel)),
                ]),
                select(
                  [
                    attribute.class("preference-select"),
                    attribute.value(current_locale),
                    attribute.attribute("data-testid", "locale-selector"),
                    event.on_input(config.on_locale_change),
                  ],
                  [
                    option([attribute.value("es")], "Español"),
                    option([attribute.value("en")], "English"),
                  ],
                ),
              ]),
            ]),
          ],
        ),
      ])
    }
  }
}

fn view_profile(config: RightPanelConfig(msg)) -> Element(msg) {
  div([attribute.class("profile-section")], [
    case config.user {
      Some(user) ->
        div(
          [
            attribute.class("user-info"),
            attribute.attribute("title", user.email),
          ],
          [
            icons.nav_icon(icons.UserCircle, icons.Small),
            span([attribute.class("user-email")], [text(user.email)]),
          ],
        )
      None -> element.none()
    },
    div([attribute.class("profile-actions")], [
      profile_icon_button_config(
        i18n.t(config.locale, i18n_text.Preferences),
        icons.Cog,
        config.on_preferences_toggle,
      )
        |> ui_button.with_testid("preferences-btn")
        |> ui_button.with_attribute(attribute.attribute(
          "aria-haspopup",
          "dialog",
        ))
        |> ui_button.with_attribute(
          attribute.attribute(
            "aria-expanded",
            case config.preferences_popup_open {
              True -> "true"
              False -> "false"
            },
          ),
        )
        |> ui_button.view,
      profile_icon_button_config(
        i18n.t(config.locale, i18n_text.Logout),
        icons.Logout,
        config.on_logout,
      )
        |> ui_button.with_class("btn-logout")
        |> ui_button.with_testid("logout-btn")
        |> ui_button.view,
    ]),
  ])
}

fn profile_icon_button(
  label: String,
  icon: icons.NavIcon,
  on_click: msg,
) -> Element(msg) {
  profile_icon_button_config(label, icon, on_click)
  |> ui_button.view
}

fn profile_icon_button_config(
  label: String,
  icon: icons.NavIcon,
  on_click: msg,
) -> ui_button.Config(msg) {
  ui_button.icon(
    label,
    on_click,
    icon,
    ui_button.Neutral,
    ui_button.GlobalAction,
  )
  |> ui_button.with_class("btn-icon-only")
}
