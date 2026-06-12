//// People view: team availability by project member.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some, from_result}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, li, p, section, span, text, ul}
import lustre/event

import domain/card.{type CardColor}
import domain/org.{type OrgUser}
import domain/project.{type ProjectMember}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task}
import domain/task_state
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/tone

const load_warning_claimed_threshold = 4

type PeopleSummary {
  PeopleSummary(
    free_count: Int,
    busy_count: Int,
    working_count: Int,
    claimed_total: Int,
  )
}

type TaskGroup {
  TaskGroup(card_id: Option(Int), card_title: Option(String), tasks: List(Task))
}

pub type Config(msg) {
  Config(
    locale: Locale,
    people_roster: Remote(List(ProjectMember)),
    member_tasks: Remote(List(Task)),
    org_users: Remote(List(OrgUser)),
    people_expansions: dict.Dict(Int, people_state.RowExpansion),
    search_query: String,
    task_card_color: fn(Task) -> Option(CardColor),
    on_person_toggle: fn(Int) -> msg,
    on_task_click: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.people_roster {
    NotAsked | Loading ->
      empty_state.notice_with_class(
        "clock",
        i18n.t(config.locale, i18n_text.PeopleLoading),
        empty_state.Loading,
        "people-state people-loading",
      )

    Failed(_err) ->
      empty_state.notice_with_class(
        "exclamation-triangle",
        i18n.t(config.locale, i18n_text.PeopleLoadError),
        empty_state.Error,
        "people-state people-error",
      )

    Loaded(members) -> view_loaded(config, members)
  }
}

fn view_loaded(
  config: Config(msg),
  members: List(ProjectMember),
) -> Element(msg) {
  case members {
    [] ->
      empty_state.notice_with_class(
        "user-group",
        i18n.t(config.locale, i18n_text.PeopleEmpty),
        empty_state.NeedsSetup,
        "people-state people-empty",
      )

    _ -> {
      let people =
        list.map(members, fn(member) {
          people_state.derive_status(
            member.user_id,
            resolve_user_label(config, member.user_id),
            tasks_for_member(config, member.user_id),
          )
        })

      let filtered = filter_people(people, config.search_query)

      case filtered {
        [] ->
          empty_state.notice_with_class(
            "magnifying-glass",
            i18n.t(config.locale, i18n_text.PeopleNoResults),
            empty_state.NoResults,
            "people-state people-no-results",
          )

        _ ->
          section(
            [
              attribute.class("people-view people-list"),
              attribute.attribute("data-testid", "people-view"),
            ],
            [
              view_surface_header(config, filtered),
              ul(
                [attribute.class("people-items")],
                list.map(filtered, fn(person) {
                  view_person_row(config, person)
                }),
              ),
            ],
          )
      }
    }
  }
}

fn view_person_row(
  config: Config(msg),
  person: people_state.PersonStatus,
) -> Element(msg) {
  let people_state.PersonStatus(
    user_id: user_id,
    label: label,
    availability: availability,
    active_tasks: active_tasks,
    claimed_tasks: claimed_tasks,
  ) = person

  let expanded = is_expanded(config.people_expansions, user_id)
  let details_id = "person-details-" <> int.to_string(user_id)
  let toggle_label = case expanded {
    True -> i18n.t(config.locale, i18n_text.CollapsePerson(name: label))
    False -> i18n.t(config.locale, i18n_text.ExpandPerson(name: label))
  }

  let badge_text = availability_label(config, availability)
  let badge_variant = people_state.badge_variant(availability)
  let availability_chip =
    badge.new_unchecked(badge_text, badge_variant)
    |> badge.view_with_class("people-status-chip")
  let person_tasks = list.append(active_tasks, claimed_tasks)

  li([attribute.class("people-row")], [
    div([attribute.class("people-row-header")], [
      div([attribute.class("people-row-main")], [
        button(
          [
            attribute.class("people-row-toggle"),
            attribute.attribute(
              "aria-expanded",
              attribute_value.boolean(expanded),
            ),
            attribute.attribute("aria-controls", details_id),
            attribute.attribute("aria-label", toggle_label),
            event.on_click(config.on_person_toggle(user_id)),
          ],
          [
            span([attribute.class("people-row-caret")], [
              text(case expanded {
                True -> "▾"
                False -> "▸"
              }),
            ]),
            span([attribute.class("people-row-name")], [text(label)]),
          ],
        ),
        availability_chip,
      ]),
      div([attribute.class("people-row-balance")], [
        view_row_metric(
          i18n.t(
            config.locale,
            i18n_text.PeopleOngoingCount(list.length(active_tasks)),
          ),
          badge.Primary,
        ),
        view_row_metric(
          i18n.t(
            config.locale,
            i18n_text.PeopleClaimedCount(list.length(claimed_tasks)),
          ),
          badge.Neutral,
        ),
        view_person_cards(config, person_tasks),
        view_load_warning(config, claimed_tasks),
      ]),
    ]),
    case expanded {
      True ->
        div(
          [
            attribute.class("people-row-details"),
            attribute.attribute("id", details_id),
          ],
          [
            view_active_section(config, active_tasks),
            view_claimed_section(config, claimed_tasks),
          ],
        )
      False -> element.none()
    },
  ])
}

fn view_surface_header(
  config: Config(msg),
  people: List(people_state.PersonStatus),
) -> Element(msg) {
  let summary = summarize_people(people)

  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(config.locale, i18n_text.People),
    purpose: i18n.t(config.locale, i18n_text.PeoplePurpose),
    summary: [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleFreeLabel),
        int.to_string(summary.free_count),
        tone.Success,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleBusyLabel),
        int.to_string(summary.busy_count),
        tone.Warning,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleWorkingLabel),
        int.to_string(summary.working_count),
        tone.Ongoing,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleClaimedLabel),
        int.to_string(summary.claimed_total),
        tone.Claimed,
      ),
    ],
    actions: [],
    extra_class: Some("people-surface-header"),
    testid: Some("people-surface-header"),
  ))
}

fn summarize_people(people: List(people_state.PersonStatus)) -> PeopleSummary {
  list.fold(
    people,
    PeopleSummary(
      free_count: 0,
      busy_count: 0,
      working_count: 0,
      claimed_total: 0,
    ),
    fn(summary, person) {
      let with_claimed =
        PeopleSummary(
          ..summary,
          claimed_total: summary.claimed_total
            + list.length(person.claimed_tasks),
        )

      case person.availability {
        people_state.Free ->
          PeopleSummary(..with_claimed, free_count: with_claimed.free_count + 1)
        people_state.Busy ->
          PeopleSummary(..with_claimed, busy_count: with_claimed.busy_count + 1)
        people_state.Working ->
          PeopleSummary(
            ..with_claimed,
            working_count: with_claimed.working_count + 1,
          )
      }
    },
  )
}

fn view_row_metric(label: String, variant: badge.BadgeVariant) -> Element(msg) {
  badge.new_unchecked(label, variant)
  |> badge.view_with_class("people-metric-chip")
}

fn view_person_cards(config: Config(msg), tasks: List(Task)) -> Element(msg) {
  let titles = task_groups(tasks) |> card_titles_from_groups

  case titles {
    [] ->
      span([attribute.class("people-card-empty")], [
        text(i18n.t(config.locale, i18n_text.PeopleNoCardContext)),
      ])
    _ ->
      div([attribute.class("people-card-set")], [
        view_row_metric(
          i18n.t(config.locale, i18n_text.PeopleCardsCount(list.length(titles))),
          badge.Neutral,
        ),
        ..list.map(titles, fn(title) {
          span([attribute.class("people-card-chip")], [text(title)])
        })
      ])
  }
}

fn view_load_warning(
  config: Config(msg),
  claimed_tasks: List(Task),
) -> Element(msg) {
  case list.length(claimed_tasks) >= load_warning_claimed_threshold {
    True ->
      badge.new_unchecked(
        i18n.t(config.locale, i18n_text.PeopleLoadWarning),
        badge.Warning,
      )
      |> badge.view_with_class("people-load-chip")
    False -> element.none()
  }
}

fn view_active_section(
  config: Config(msg),
  active_tasks: List(Task),
) -> Element(msg) {
  div([attribute.class("people-subsection")], [
    p([attribute.class("people-subsection-title")], [
      text(i18n.t(config.locale, i18n_text.PeopleActiveSection)),
    ]),
    case active_tasks {
      [] ->
        p([attribute.class("section-empty-hint people-task-empty")], [
          text(i18n.t(config.locale, i18n_text.PeopleAvailableCapacity)),
        ])
      _ -> view_task_list(config, active_tasks)
    },
  ])
}

fn view_claimed_section(
  config: Config(msg),
  claimed_tasks: List(Task),
) -> Element(msg) {
  div([attribute.class("people-subsection")], [
    p([attribute.class("people-subsection-title")], [
      text(i18n.t(config.locale, i18n_text.PeopleClaimedSection)),
    ]),
    case claimed_tasks {
      [] ->
        p([attribute.class("section-empty-hint people-task-empty")], [
          text(i18n.t(config.locale, i18n_text.PeopleNoClaimedTasks)),
        ])
      _ -> view_task_list(config, claimed_tasks)
    },
  ])
}

fn view_task_list(config: Config(msg), tasks: List(Task)) -> Element(msg) {
  ul(
    [attribute.class("people-claimed-list")],
    list.map(tasks, fn(task) {
      li([attribute.class("people-task-item")], [
        view_task_item(config, task),
      ])
    }),
  )
}

fn view_task_item(config: Config(msg), task: Task) -> Element(msg) {
  let resolved_color = config.task_card_color(task)
  let border_class = task_color.card_border_class(resolved_color)

  task_item.view(
    task_item.Config(
      container_class: "task-item " <> border_class,
      content_class: "task-item-content",
      leading: view_task_leading_swatch(config, task, resolved_color),
      on_click: Some(config.on_task_click(task.id)),
      icon: None,
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: view_task_secondary(config, task),
      actions: task_item.no_actions(),
      reserve_actions_slot: True,
      action_slot_class: None,
      testid: None,
    ),
    task_item.Div,
  )
}

fn view_task_leading_swatch(
  config: Config(msg),
  task: Task,
  card_color: Option(CardColor),
) -> Option(Element(msg)) {
  case card_color {
    Some(_) ->
      Some(view_card_identity_swatch(
        card_color,
        task_card_accessibility_label(config, task),
      ))
    None -> None
  }
}

fn view_card_identity_swatch(
  card_color: Option(CardColor),
  label: String,
) -> Element(msg) {
  case card_color {
    Some(_) ->
      span(
        [
          attribute.class("task-card-identity-swatch"),
          attribute.attribute("role", "img"),
          attribute.attribute("aria-label", label),
          attribute.attribute("title", label),
        ],
        [],
      )
    None -> element.none()
  }
}

fn view_task_secondary(config: Config(msg), task: Task) -> Element(msg) {
  div([attribute.class("task-item-meta people-task-meta")], [
    span(
      [
        attribute.class("task-status-muted"),
        attribute.attribute(
          "title",
          task_state_ui.hint(config.locale, task.status),
        ),
      ],
      [text(task_state_ui.label(config.locale, task.status))],
    ),
  ])
}

fn task_card_accessibility_label(config: Config(msg), task: Task) -> String {
  case task.card_title {
    Some(title) -> title
    None -> i18n.t(config.locale, i18n_text.PeopleNoCardContext)
  }
}

fn task_groups(tasks: List(Task)) -> List(TaskGroup) {
  tasks
  |> list.fold([], fn(groups, task) { upsert_task_group(groups, task) })
  |> list.reverse
  |> list.map(fn(group) { TaskGroup(..group, tasks: list.reverse(group.tasks)) })
}

fn upsert_task_group(groups: List(TaskGroup), task: Task) -> List(TaskGroup) {
  case groups {
    [] -> [new_task_group(task)]
    [group, ..rest] -> {
      case same_task_card(group, task) {
        True -> [TaskGroup(..group, tasks: [task, ..group.tasks]), ..rest]
        False -> [group, ..upsert_task_group(rest, task)]
      }
    }
  }
}

fn new_task_group(task: Task) -> TaskGroup {
  TaskGroup(card_id: task.card_id, card_title: task.card_title, tasks: [task])
}

fn same_task_card(group: TaskGroup, task: Task) -> Bool {
  group.card_id == task.card_id && group.card_title == task.card_title
}

fn card_titles_from_groups(groups: List(TaskGroup)) -> List(String) {
  groups
  |> list.fold([], fn(titles, group) {
    case group.card_title {
      Some(title) -> [title, ..titles]
      None -> titles
    }
  })
  |> list.reverse
}

fn tasks_for_member(config: Config(msg), user_id: Int) -> List(Task) {
  case config.member_tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(task) {
        case task.state {
          task_state.Claimed(claimed_by: claimed_by, ..) ->
            claimed_by == user_id
          _ -> False
        }
      })
    _ -> []
  }
}

fn resolve_user_label(config: Config(msg), user_id: Int) -> String {
  case find_org_user(config, user_id) {
    Some(user) -> user.email
    None -> i18n.t(config.locale, i18n_text.UserNumber(user_id))
  }
}

fn find_org_user(config: Config(msg), user_id: Int) -> Option(OrgUser) {
  case config.org_users {
    Loaded(users) ->
      list.find(users, fn(user) { user.id == user_id }) |> from_result
    _ -> None
  }
}

fn filter_people(
  people: List(people_state.PersonStatus),
  search_query: String,
) -> List(people_state.PersonStatus) {
  let query = string.trim(search_query) |> string.lowercase
  case query {
    "" -> people
    _ ->
      list.filter(people, fn(person) {
        string.contains(string.lowercase(person.label), query)
      })
  }
}

fn is_expanded(
  expansions: dict.Dict(Int, people_state.RowExpansion),
  user_id: Int,
) -> Bool {
  case dict.get(expansions, user_id) |> from_result {
    Some(people_state.Expanded) -> True
    _ -> False
  }
}

fn availability_label(
  config: Config(msg),
  availability: people_state.Availability,
) -> String {
  case availability {
    people_state.Working -> i18n.t(config.locale, i18n_text.Working)
    people_state.Busy -> i18n.t(config.locale, i18n_text.Busy)
    people_state.Free -> i18n.t(config.locale, i18n_text.Free)
  }
}
