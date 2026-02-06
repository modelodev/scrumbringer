//// People view: team availability by project member.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some, from_result}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h3, li, p, section, span, text, ul}
import lustre/event

import domain/org.{type OrgUser}
import domain/project.{type ProjectMember}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import domain/task.{type Task}
import domain/task_state
import scrumbringer_client/client_state.{type Model, type Msg, pool_msg}
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/utils/card_queries

pub fn view(model: Model) -> Element(Msg) {
  case model.member.pool.people_roster {
    NotAsked | Loading ->
      div([attribute.class("people-state people-loading")], [
        text(helpers_i18n.i18n_t(model, i18n_text.PeopleLoading)),
      ])

    Failed(_err) ->
      div([attribute.class("people-state people-error")], [
        text(helpers_i18n.i18n_t(model, i18n_text.PeopleLoadError)),
      ])

    Loaded(members) -> view_loaded(model, members)
  }
}

fn view_loaded(model: Model, members: List(ProjectMember)) -> Element(Msg) {
  case members {
    [] ->
      div([attribute.class("people-state people-empty")], [
        text(helpers_i18n.i18n_t(model, i18n_text.PeopleEmpty)),
      ])

    _ -> {
      let people =
        list.map(members, fn(member) {
          people_state.derive_status(
            member.user_id,
            resolve_user_label(model, member.user_id),
            tasks_for_member(model, member.user_id),
          )
        })

      let filtered = filter_people(people, model.member.pool.member_filters_q)

      case filtered {
        [] ->
          div([attribute.class("people-state people-no-results")], [
            text(helpers_i18n.i18n_t(model, i18n_text.PeopleNoResults)),
          ])

        _ ->
          section(
            [
              attribute.class("people-view people-list"),
              attribute.attribute("data-testid", "people-view"),
            ],
            [
              h3([attribute.class("people-title")], [
                text(helpers_i18n.i18n_t(model, i18n_text.People)),
              ]),
              ul(
                [attribute.class("people-items")],
                list.map(filtered, fn(person) { view_person_row(model, person) }),
              ),
            ],
          )
      }
    }
  }
}

fn view_person_row(
  model: Model,
  person: people_state.PersonStatus,
) -> Element(Msg) {
  let people_state.PersonStatus(
    user_id: user_id,
    label: label,
    availability: availability,
    active_tasks: active_tasks,
    claimed_tasks: claimed_tasks,
  ) = person

  let expanded = is_expanded(model.member.pool.people_expansions, user_id)
  let details_id = "person-details-" <> int.to_string(user_id)
  let toggle_label = case expanded {
    True -> helpers_i18n.i18n_t(model, i18n_text.CollapsePerson(name: label))
    False -> helpers_i18n.i18n_t(model, i18n_text.ExpandPerson(name: label))
  }

  let badge_text = availability_label(model, availability)
  let badge_variant = people_state.badge_variant(availability)
  let availability_chip =
    badge.new_unchecked(badge_text, badge_variant)
    |> badge.view_with_class("people-status-chip")

  li([attribute.class("people-row")], [
    div([attribute.class("people-row-header")], [
      button(
        [
          attribute.class("people-row-toggle"),
          attribute.attribute("aria-expanded", bool_to_string(expanded)),
          attribute.attribute("aria-controls", details_id),
          attribute.attribute("aria-label", toggle_label),
          event.on_click(
            pool_msg(pool_messages.MemberPeopleRowToggled(user_id)),
          ),
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
    case expanded {
      True ->
        div(
          [
            attribute.class("people-row-details"),
            attribute.attribute("id", details_id),
          ],
          [
            view_active_section(model, active_tasks),
            view_claimed_section(model, claimed_tasks),
          ],
        )
      False -> element.none()
    },
  ])
}

fn view_active_section(model: Model, active_tasks: List(Task)) -> Element(Msg) {
  div([attribute.class("people-subsection")], [
    p([attribute.class("people-subsection-title")], [
      text(helpers_i18n.i18n_t(model, i18n_text.PeopleActiveSection)),
    ]),
    case active_tasks {
      [] -> p([attribute.class("section-empty-hint")], [text("-")])
      [task] -> view_task_item(model, task)
      _ ->
        ul(
          [attribute.class("people-claimed-list")],
          list.map(active_tasks, fn(task) {
            li([attribute.class("people-task-item")], [
              view_task_item(model, task),
            ])
          }),
        )
    },
  ])
}

fn view_claimed_section(model: Model, claimed_tasks: List(Task)) -> Element(Msg) {
  div([attribute.class("people-subsection")], [
    p([attribute.class("people-subsection-title")], [
      text(helpers_i18n.i18n_t(model, i18n_text.PeopleClaimedSection)),
    ]),
    case claimed_tasks {
      [] -> p([attribute.class("section-empty-hint")], [text("-")])
      _ ->
        ul(
          [attribute.class("people-claimed-list")],
          list.map(claimed_tasks, fn(task) {
            li([attribute.class("people-task-item")], [
              view_task_item(model, task),
            ])
          }),
        )
    },
  ])
}

fn view_task_item(model: Model, task: Task) -> Element(Msg) {
  let #(_card_title_opt, resolved_color) =
    card_queries.resolve_task_card_info(model, task)

  let border_class = task_color.card_border_class(resolved_color)

  task_item.view(
    task_item.Config(
      container_class: "task-item " <> border_class,
      content_class: "task-item-content",
      on_click: Some(pool_msg(pool_messages.MemberTaskDetailsOpened(task.id))),
      icon: None,
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: task_item.empty_secondary(),
      actions: task_item.no_actions(),
      testid: None,
    ),
    task_item.Div,
  )
}

fn tasks_for_member(model: Model, user_id: Int) -> List(Task) {
  case model.member.pool.member_tasks {
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

fn resolve_user_label(model: Model, user_id: Int) -> String {
  case find_org_user(model, user_id) {
    Some(user) -> user.email
    None -> helpers_i18n.i18n_t(model, i18n_text.UserNumber(user_id))
  }
}

fn find_org_user(model: Model, user_id: Int) -> Option(OrgUser) {
  case model.admin.members.org_users_cache {
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
  model: Model,
  availability: people_state.Availability,
) -> String {
  case availability {
    people_state.Working -> helpers_i18n.i18n_t(model, i18n_text.Working)
    people_state.Busy -> helpers_i18n.i18n_t(model, i18n_text.Busy)
    people_state.Free -> helpers_i18n.i18n_t(model, i18n_text.Free)
  }
}

fn bool_to_string(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
