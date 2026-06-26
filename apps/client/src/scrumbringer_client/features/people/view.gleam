//// People view: team availability by project member.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, input, label, li, option as html_option, p, select, span, text,
}
import lustre/element/keyed
import lustre/event

import domain/card.{type Card}
import domain/people_workload.{
  type PersonWorkload, type PersonWorkloadTask, PersonWorkload,
  PersonWorkloadSummary, WorkloadAttention, WorkloadAvailable, WorkloadReserved,
  WorkloadWorkingNow,
}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/tone
import scrumbringer_client/utils/card_queries

type PeopleSummary {
  PeopleSummary(
    attention_count: Int,
    working_count: Int,
    reserved_count: Int,
    available_count: Int,
  )
}

type PersonTaskKind {
  NowTask
  ReservedTask
}

type PeopleCardTaskGroup {
  PeopleCardTaskGroup(
    key: String,
    title: String,
    card_id: Option(Int),
    tasks: List(PersonWorkloadTask),
  )
}

pub type Config(msg) {
  Config(
    locale: Locale,
    people_workload: Remote(List(PersonWorkload)),
    cards: List(Card),
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    selected_depth: Option(Int),
    selected_card_id: Option(Int),
    card_query: String,
    people_expansions: dict.Dict(Int, people_state.RowExpansion),
    search_query: String,
    visibility_filter: people_state.PeopleVisibilityFilter,
    sort: people_state.PeopleSort,
    current_user_id: Option(Int),
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_scope_card_search_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_visibility_filter_change: fn(String) -> msg,
    on_sort_change: fn(String) -> msg,
    on_person_toggle: fn(Int) -> msg,
    on_task_click: fn(Int) -> msg,
    on_card_click: fn(Int) -> msg,
    on_now_working_start: fn(Int) -> msg,
    on_now_working_pause: msg,
    on_task_release: fn(Int, Int) -> msg,
    on_task_close: fn(Int, Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.people_workload {
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

    Loaded(people) -> view_loaded(config, people)
  }
}

fn view_loaded(
  config: Config(msg),
  people: List(PersonWorkload),
) -> Element(msg) {
  case people {
    [] ->
      empty_state.notice_with_class(
        "user-group",
        i18n.t(config.locale, i18n_text.PeopleEmpty),
        empty_state.NeedsSetup,
        "people-state people-empty",
      )

    _ -> {
      let people = scope_people(config, people)

      let searched = filter_people(config, people, config.search_query)
      let filtered =
        people_state.apply_visibility_filter(searched, config.visibility_filter)
        |> people_state.sort_people(config.sort)
      let roster_rows = people_state.build_roster(filtered)

      let header = view_surface_header(config, people)
      let controls = view_people_controls(config)
      let surface =
        work_surface.new_surface(header)
        |> work_surface.with_filters(controls)
        |> work_surface.surface_with_class("people-work-surface")
        |> work_surface.surface_with_testid("people-surface")

      case
        config.scope_kind,
        config.selected_card_id,
        selected_card_scope_has_no_work(config, people),
        filtered
      {
        member_pool.PlanScopeCard, None, _, _ ->
          work_surface.surface(work_surface.with_state(
            surface,
            empty_state.notice_with_class(
              "rectangle-stack",
              i18n.t(config.locale, i18n_text.PlanScopeSelectCard),
              empty_state.NoResults,
              "people-state people-card-scope-empty",
            ),
          ))

        member_pool.PlanScopeCard, Some(_), True, _ ->
          work_surface.surface(work_surface.with_state(
            surface,
            empty_state.notice_with_class(
              "rectangle-stack",
              i18n.t(config.locale, i18n_text.PeopleCardScopeNoWork),
              empty_state.NoResults,
              "people-state people-card-scope-no-work",
            ),
          ))

        _, _, _, [] ->
          work_surface.surface(work_surface.with_state(
            surface,
            empty_state.notice_with_class(
              "magnifying-glass",
              i18n.t(config.locale, i18n_text.PeopleNoResults),
              empty_state.NoResults,
              "people-state people-no-results",
            ),
          ))

        _, _, _, _ ->
          work_surface.surface(work_surface.with_content(
            surface,
            div(
              [
                attribute.class("people-view people-roster"),
                attribute.attribute("data-testid", "people-view"),
              ],
              [view_roster(config, roster_rows)],
            ),
          ))
      }
    }
  }
}

fn selected_card_scope_has_no_work(
  config: Config(msg),
  people: List(PersonWorkload),
) -> Bool {
  case config.scope_kind, config.selected_card_id, config.people_workload {
    member_pool.PlanScopeCard, Some(_), Loaded(_) ->
      !list.any(people, people_state.has_work)
    _, _, _ -> False
  }
}

fn scope_people(
  config: Config(msg),
  people: List(PersonWorkload),
) -> List(PersonWorkload) {
  list.map(people, fn(person) {
    let working_now = scope_tasks(config, person.working_now)
    let reserved = scope_tasks(config, person.reserved)
    let attention = scope_tasks(config, person.attention)
    rebuild_person_workload(person, working_now, reserved, attention)
  })
}

fn scope_tasks(
  config: Config(msg),
  tasks: List(PersonWorkloadTask),
) -> List(PersonWorkloadTask) {
  list.filter(tasks, fn(task) { task_in_scope(config, task) })
}

fn task_in_scope(config: Config(msg), task: PersonWorkloadTask) -> Bool {
  case config.scope_kind {
    member_pool.PlanScopeProject -> True
    member_pool.PlanScopeLevel ->
      case config.selected_depth, task.card_id {
        None, _ -> True
        Some(depth), Some(card_id) ->
          task_is_in_level_subtree(config.cards, card_id, depth)
        Some(_), None -> False
      }
    member_pool.PlanScopeCard ->
      case config.selected_card_id, task.card_id {
        Some(selected_card_id), Some(card_id) ->
          card_queries.card_in_subtree(card_id, selected_card_id, config.cards)
        _, _ -> False
      }
  }
}

fn task_is_in_level_subtree(cards: List(Card), card_id: Int, depth: Int) -> Bool {
  cards
  |> list.filter(fn(card) { card_queries.card_depth(card, cards) == depth })
  |> list.any(fn(level_card) {
    card_queries.card_in_subtree(card_id, level_card.id, cards)
  })
}

fn rebuild_person_workload(
  person: PersonWorkload,
  working_now: List(PersonWorkloadTask),
  reserved: List(PersonWorkloadTask),
  attention: List(PersonWorkloadTask),
) -> PersonWorkload {
  let summary =
    PersonWorkloadSummary(
      working_now_count: list.length(working_now),
      reserved_count: list.length(reserved),
      attention_count: list.length(attention),
    )
  let state = case attention, working_now, reserved {
    [_, ..], _, _ -> WorkloadAttention
    _, [_, ..], _ -> WorkloadWorkingNow
    _, _, [_, ..] -> WorkloadReserved
    _, _, _ -> WorkloadAvailable
  }

  PersonWorkload(
    ..person,
    state: state,
    working_now: working_now,
    reserved: reserved,
    attention: attention,
    summary: summary,
  )
}

fn view_people_controls(config: Config(msg)) -> Element(msg) {
  scope_bar.view(
    scope_bar.Config(
      locale: config.locale,
      cards: config.cards,
      depth_names: config.depth_names,
      scope_kind: config.scope_kind,
      selected_depth: config.selected_depth,
      selected_card_id: config.selected_card_id,
      card_query: config.card_query,
      show_closed: False,
      id_prefix: "people-scope",
      mode_controls: [],
      refinement_controls: [
        view_search_control(config),
        view_filter_control(config),
        view_sort_control(config),
      ],
      show_closed_control: False,
      on_scope_kind_change: config.on_scope_kind_change,
      on_scope_depth_change: config.on_scope_depth_change,
      on_scope_card_change: config.on_scope_card_change,
      on_scope_card_search_change: config.on_scope_card_search_change,
      on_closed_toggled: fn(_value) {
        config.on_visibility_filter_change(people_state.filter_to_string(
          config.visibility_filter,
        ))
      },
    ),
  )
}

fn view_search_control(config: Config(msg)) -> Element(msg) {
  div([attribute.class("people-control people-search-control")], [
    label([], [text(i18n.t(config.locale, i18n_text.SearchLabel))]),
    input([
      attribute.type_("search"),
      attribute.attribute("data-testid", "people-search"),
      attribute.placeholder(i18n.t(
        config.locale,
        i18n_text.PeopleSearchPlaceholder,
      )),
      attribute.value(config.search_query),
      event.on_input(config.on_search_change),
    ]),
  ])
}

fn view_filter_control(config: Config(msg)) -> Element(msg) {
  div([attribute.class("people-control")], [
    label([], [text(i18n.t(config.locale, i18n_text.PeopleShowLabel))]),
    select(
      [
        attribute.attribute("data-testid", "people-filter"),
        attribute.value(people_state.filter_to_string(config.visibility_filter)),
        event.on_input(config.on_visibility_filter_change),
        event.on_change(config.on_visibility_filter_change),
      ],
      [
        html_option(
          [attribute.value("everyone")],
          i18n.t(config.locale, i18n_text.PeopleFilterEveryone),
        ),
        html_option(
          [attribute.value("with-work")],
          i18n.t(config.locale, i18n_text.PeopleFilterWithWork),
        ),
        html_option(
          [attribute.value("attention")],
          i18n.t(config.locale, i18n_text.PeopleFilterAttention),
        ),
        html_option(
          [attribute.value("free")],
          i18n.t(config.locale, i18n_text.PeopleFilterFree),
        ),
      ],
    ),
  ])
}

fn view_sort_control(config: Config(msg)) -> Element(msg) {
  div([attribute.class("people-control")], [
    label([], [text(i18n.t(config.locale, i18n_text.PeopleSortLabel))]),
    select(
      [
        attribute.attribute("data-testid", "people-sort"),
        attribute.value(people_state.sort_to_string(config.sort)),
        event.on_input(config.on_sort_change),
        event.on_change(config.on_sort_change),
      ],
      [
        html_option(
          [attribute.value("attention")],
          i18n.t(config.locale, i18n_text.PeopleSortAttention),
        ),
        html_option(
          [attribute.value("name")],
          i18n.t(config.locale, i18n_text.PeopleSortName),
        ),
        html_option(
          [attribute.value("reserved")],
          i18n.t(config.locale, i18n_text.PeopleSortClaimed),
        ),
      ],
    ),
  ])
}

fn view_roster(
  config: Config(msg),
  rows: List(people_state.PersonRosterRow),
) -> Element(msg) {
  keyed.ul([attribute.class("people-roster-list")], [
    #("roster-head", view_roster_header(config)),
    ..list.flatten([
      view_roster_section(config, rows, people_state.NeedsAttention),
      view_roster_section(config, rows, people_state.RosterWorkingNow),
      view_roster_section(config, rows, people_state.RosterReservedWork),
      view_roster_section(config, rows, people_state.RosterAvailable),
    ])
  ])
}

fn view_roster_header(config: Config(msg)) -> Element(msg) {
  li([attribute.class("people-roster-head")], [
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnPerson))]),
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnWork))]),
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnLoad))]),
  ])
}

fn view_roster_section(
  config: Config(msg),
  rows: List(people_state.PersonRosterRow),
  section: people_state.RosterSection,
) -> List(#(String, Element(msg))) {
  let section_rows = people_state.rows_in_section(rows, section)

  case section_rows {
    [] -> []
    _ -> [
      #(
        "section-" <> section_key(section),
        li([attribute.class("people-roster-section")], [
          text(
            section_label(config, section)
            <> " · "
            <> int.to_string(list.length(section_rows)),
          ),
        ]),
      ),
      ..list.map(section_rows, fn(row) {
        #(
          "person-" <> int.to_string(row.person.user_id),
          view_roster_row(config, row),
        )
      })
    ]
  }
}

fn view_roster_row(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Element(msg) {
  let person = row.person
  let PersonWorkload(
    user_id: user_id,
    email: label,
    working_now: active_tasks,
    reserved: reserved_tasks,
    attention: attention_tasks,
    ..,
  ) = person

  let expanded = is_expanded(config.people_expansions, user_id)
  let details_id = "person-details-" <> int.to_string(user_id)
  let toggle_label = case expanded {
    True -> i18n.t(config.locale, i18n_text.CollapsePerson(name: label))
    False -> i18n.t(config.locale, i18n_text.ExpandPerson(name: label))
  }

  li([attribute.class("people-roster-row " <> section_row_class(row.section))], [
    div(
      roster_cell_attrs(
        config,
        "people-roster-person",
        i18n_text.PeopleColumnPerson,
      ),
      [
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
      ],
    ),
    div(
      roster_cell_attrs(
        config,
        "people-roster-work",
        i18n_text.PeopleColumnWork,
      ),
      [
        view_work(config, row),
      ],
    ),
    div(
      roster_cell_attrs(
        config,
        "people-roster-load",
        i18n_text.PeopleColumnLoad,
      ),
      [
        view_load(config, row),
      ],
    ),
    case expanded {
      True ->
        div(
          [
            attribute.class("people-row-details"),
            attribute.attribute("id", details_id),
          ],
          [
            view_person_tray(
              config,
              label,
              list.append(
                active_tasks,
                attention_tasks
                  |> list.filter(fn(t) { t.ongoing }),
              ),
              list.append(
                reserved_tasks,
                attention_tasks
                  |> list.filter(fn(t) { !t.ongoing }),
              ),
            ),
          ],
        )
      False -> element.none()
    },
  ])
}

fn roster_cell_attrs(
  config: Config(msg),
  class_name: String,
  label: i18n_text.Text,
) -> List(attribute.Attribute(msg)) {
  [
    attribute.class("people-roster-cell " <> class_name),
    attribute.attribute("data-label", i18n.t(config.locale, label)),
  ]
}

fn view_surface_header(
  config: Config(msg),
  people: List(PersonWorkload),
) -> Element(msg) {
  let summary = summarize_people(people)

  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(config.locale, i18n_text.People),
    purpose: i18n.t(config.locale, i18n_text.PeoplePurpose),
    summary: [
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleAttentionLabel),
        int.to_string(summary.attention_count),
        tone.Blocked,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleWorkingLabel),
        int.to_string(summary.working_count),
        tone.Ongoing,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleBusyLabel),
        int.to_string(summary.reserved_count),
        tone.Claimed,
      ),
      work_surface.summary_chip(
        i18n.t(config.locale, i18n_text.PeopleFreeLabel),
        int.to_string(summary.available_count),
        tone.Success,
      ),
    ],
    actions: [],
    extra_class: Some("people-surface-header"),
    testid: Some("people-surface-header"),
  ))
}

fn summarize_people(people: List(PersonWorkload)) -> PeopleSummary {
  let roster_summary =
    people
    |> people_state.build_roster
    |> people_state.roster_summary

  PeopleSummary(
    attention_count: roster_summary.attention_count,
    working_count: roster_summary.working_count,
    reserved_count: roster_summary.reserved_count,
    available_count: roster_summary.available_count,
  )
}

fn section_key(section: people_state.RosterSection) -> String {
  case section {
    people_state.NeedsAttention -> "attention"
    people_state.RosterWorkingNow -> "working"
    people_state.RosterReservedWork -> "reserved"
    people_state.RosterAvailable -> "available"
  }
}

fn section_label(
  config: Config(msg),
  section: people_state.RosterSection,
) -> String {
  case section {
    people_state.NeedsAttention ->
      i18n.t(config.locale, i18n_text.PeopleSectionNeedsAttention)
    people_state.RosterWorkingNow ->
      i18n.t(config.locale, i18n_text.PeopleSectionWorkingNow)
    people_state.RosterReservedWork ->
      i18n.t(config.locale, i18n_text.PeopleSectionReservedWork)
    people_state.RosterAvailable ->
      i18n.t(config.locale, i18n_text.PeopleSectionAvailable)
  }
}

fn section_row_class(section: people_state.RosterSection) -> String {
  "people-roster-row-" <> section_key(section)
}

fn load_detail(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Option(String) {
  case row.secondary_signal {
    Some(people_state.HighReservedLoadSignal(_)) ->
      Some(i18n.t(config.locale, i18n_text.PeopleLoadWarning))
    None -> None
  }
}

fn view_optional_detail(detail: Option(String)) -> Element(msg) {
  case detail {
    Some(value) ->
      span([attribute.class("people-roster-detail")], [text(value)])
    None -> element.none()
  }
}

fn view_work(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Element(msg) {
  case row.primary_task {
    Some(task) ->
      div([attribute.class("people-roster-work-stack")], [
        view_work_links(config, row, task),
        view_blocker_line(config, task),
      ])
    None ->
      span([attribute.class("people-roster-muted")], [
        text(i18n.t(config.locale, i18n_text.PeopleNoOwnedWork)),
      ])
  }
}

fn view_work_links(
  config: Config(msg),
  row: people_state.PersonRosterRow,
  task: PersonWorkloadTask,
) -> Element(msg) {
  div([attribute.class("people-roster-work-links")], [
    button(
      [
        attribute.class("people-roster-task-link"),
        event.on_click(config.on_task_click(task.task_id)),
      ],
      [text(focus_label(config, row, task))],
    ),
    view_work_card_link(config, task),
  ])
}

fn view_work_card_link(
  config: Config(msg),
  task: PersonWorkloadTask,
) -> Element(msg) {
  case task.card_id, task.card_title {
    Some(card_id), Some(title) ->
      button(
        [
          attribute.class("people-roster-card-link"),
          event.on_click(config.on_card_click(card_id)),
        ],
        [text(title)],
      )
    Some(card_id), None ->
      button(
        [
          attribute.class("people-roster-card-link"),
          event.on_click(config.on_card_click(card_id)),
        ],
        [text(i18n.t(config.locale, i18n_text.PeopleNoCardContext))],
      )
    None, Some(title) ->
      span([attribute.class("people-roster-card-muted")], [text(title)])
    None, None ->
      span([attribute.class("people-roster-card-muted")], [
        text(i18n.t(config.locale, i18n_text.PeopleNoCardContext)),
      ])
  }
}

fn focus_label(
  config: Config(msg),
  row: people_state.PersonRosterRow,
  task: PersonWorkloadTask,
) -> String {
  case row.section {
    people_state.RosterReservedWork ->
      i18n.t(config.locale, i18n_text.PeopleNextWork(task.title))
    people_state.NeedsAttention
    | people_state.RosterWorkingNow
    | people_state.RosterAvailable -> task.title
  }
}

fn view_blocker_line(
  config: Config(msg),
  task: PersonWorkloadTask,
) -> Element(msg) {
  case task.blocked {
    True ->
      span([attribute.class("people-roster-blocker")], [
        text(i18n.t(
          config.locale,
          i18n_text.PeopleBlockedBy(blocker_label(config, task)),
        )),
      ])
    False -> element.none()
  }
}

fn blocker_label(config: Config(msg), _task: PersonWorkloadTask) -> String {
  i18n.t(config.locale, i18n_text.PeopleOpenDependencies)
}

fn task_scope_label(config: Config(msg), task: PersonWorkloadTask) -> String {
  case task.card_title, task.capability_name {
    Some(card_title), Some(capability) -> card_title <> " - " <> capability
    Some(card_title), None -> card_title
    None, Some(capability) -> capability
    None, None -> i18n.t(config.locale, i18n_text.PeopleNoCardContext)
  }
}

fn view_load(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Element(msg) {
  div([attribute.class("people-roster-load-stack")], [
    span([attribute.class("people-roster-load-text")], [
      text(load_label(config, row)),
    ]),
    view_optional_detail(load_detail(config, row)),
  ])
}

fn load_label(config: Config(msg), row: people_state.PersonRosterRow) -> String {
  let active_count = list.length(row.person.working_now)
  let reserved_count = list.length(row.person.reserved)
  let blocked_count = blocked_task_count(person_tasks(row.person))
  let cards_count = distinct_card_count(person_tasks(row.person))

  []
  |> append_load_part(
    active_count > 0,
    i18n.t(config.locale, i18n_text.PeopleOngoingCount(active_count)),
  )
  |> append_load_part(
    reserved_count > 0,
    i18n.t(config.locale, i18n_text.PeopleReservedCount(reserved_count)),
  )
  |> append_load_part(
    blocked_count > 0,
    i18n.t(config.locale, i18n_text.PeopleBlockedCount(blocked_count)),
  )
  |> append_load_part(
    cards_count > 1,
    i18n.t(config.locale, i18n_text.PeopleCardsCount(cards_count)),
  )
  |> load_parts_to_label(config)
}

fn append_load_part(
  parts: List(String),
  should_include: Bool,
  part: String,
) -> List(String) {
  case should_include {
    True -> list.append(parts, [part])
    False -> parts
  }
}

fn load_parts_to_label(parts: List(String), config: Config(msg)) -> String {
  case parts {
    [] -> i18n.t(config.locale, i18n_text.PeopleAvailableState)
    _ -> string.join(parts, " · ")
  }
}

fn blocked_task_count(tasks: List(PersonWorkloadTask)) -> Int {
  tasks
  |> list.filter(fn(task) { task.blocked })
  |> list.length
}

fn distinct_card_count(tasks: List(PersonWorkloadTask)) -> Int {
  count_distinct_card_keys(tasks, [])
}

fn count_distinct_card_keys(
  tasks: List(PersonWorkloadTask),
  seen: List(String),
) -> Int {
  case tasks {
    [] -> list.length(seen)
    [task, ..rest] ->
      case task_card_key(task) {
        Some(key) ->
          case list.contains(seen, key) {
            True -> count_distinct_card_keys(rest, seen)
            False -> count_distinct_card_keys(rest, [key, ..seen])
          }
        None -> count_distinct_card_keys(rest, seen)
      }
  }
}

fn task_card_key(task: PersonWorkloadTask) -> Option(String) {
  case task.card_id, task.card_title {
    Some(id), _ -> Some("card:" <> int.to_string(id))
    None, Some(title) -> Some("title:" <> title)
    None, None -> None
  }
}

fn view_person_tray(
  config: Config(msg),
  person_label: String,
  active_tasks: List(PersonWorkloadTask),
  reserved_tasks: List(PersonWorkloadTask),
) -> Element(msg) {
  div([attribute.class("people-person-tray")], [
    div([attribute.class("people-person-tray-header")], [
      span([attribute.class("people-person-tray-title")], [
        text(i18n.t(config.locale, i18n_text.PeopleTrayTitle(person_label))),
      ]),
      span([attribute.class("people-person-tray-summary")], [
        text(person_tray_summary(config, active_tasks, reserved_tasks)),
      ]),
    ]),
    view_focus_summary(config, active_tasks, reserved_tasks),
    case active_tasks {
      [] -> element.none()
      _ -> view_now_section(config, active_tasks)
    },
    view_reserved_section(config, reserved_tasks),
  ])
}

fn person_tray_summary(
  config: Config(msg),
  active_tasks: List(PersonWorkloadTask),
  reserved_tasks: List(PersonWorkloadTask),
) -> String {
  let active_count = list.length(active_tasks)
  let reserved_count = list.length(reserved_tasks)
  let card_count = distinct_card_count(reserved_tasks)

  []
  |> append_load_part(
    active_tasks != [],
    i18n.t(config.locale, i18n_text.PeopleOngoingCount(active_count)),
  )
  |> append_load_part(
    reserved_tasks != [],
    i18n.t(config.locale, i18n_text.PeopleReservedCount(reserved_count)),
  )
  |> append_load_part(
    card_count > 0,
    i18n.t(config.locale, i18n_text.PeopleCardsCount(card_count)),
  )
  |> load_parts_to_label(config)
}

fn view_focus_summary(
  config: Config(msg),
  active_tasks: List(PersonWorkloadTask),
  reserved_tasks: List(PersonWorkloadTask),
) -> Element(msg) {
  let focus = case active_tasks {
    [] -> i18n.t(config.locale, i18n_text.PeopleNoActiveFocus)
    _ -> i18n.t(config.locale, i18n_text.PeopleWorkingNowState)
  }
  let reserved = case reserved_tasks {
    [] -> i18n.t(config.locale, i18n_text.PeopleNoReservedWork)
    _ ->
      i18n.t(
        config.locale,
        i18n_text.PeopleReservedCount(list.length(reserved_tasks)),
      )
  }

  p([attribute.class("people-person-focus-summary")], [
    text(focus <> " · " <> reserved),
  ])
}

fn view_now_section(
  config: Config(msg),
  active_tasks: List(PersonWorkloadTask),
) -> Element(msg) {
  view_tray_section(
    "people-tray-now",
    i18n.t(config.locale, i18n_text.PeopleNowSection),
    i18n.t(config.locale, i18n_text.PeopleNowDescription),
    view_task_list(config, active_tasks, NowTask, True),
  )
}

fn view_reserved_section(
  config: Config(msg),
  reserved_tasks: List(PersonWorkloadTask),
) -> Element(msg) {
  view_tray_section(
    "people-tray-reserved",
    i18n.t(config.locale, i18n_text.PeopleReservedSection),
    i18n.t(config.locale, i18n_text.PeopleReservedDescription),
    case reserved_tasks {
      [] -> view_tray_empty(config, i18n_text.PeopleNoReservedWork)
      _ -> view_reserved_tasks(config, reserved_tasks)
    },
  )
}

fn view_tray_section(
  class_name: String,
  title: String,
  description: String,
  body: Element(msg),
) -> Element(msg) {
  div([attribute.class("people-tray-section " <> class_name)], [
    div([attribute.class("people-tray-section-header")], [
      span([attribute.class("people-tray-section-title")], [text(title)]),
      span([attribute.class("people-tray-section-description")], [
        text(description),
      ]),
    ]),
    body,
  ])
}

fn view_tray_empty(config: Config(msg), message: i18n_text.Text) -> Element(msg) {
  p([attribute.class("section-empty-hint people-task-empty")], [
    text(i18n.t(config.locale, message)),
  ])
}

fn view_reserved_tasks(
  config: Config(msg),
  reserved_tasks: List(PersonWorkloadTask),
) -> Element(msg) {
  view_reserved_groups(config, reserved_tasks)
}

fn view_reserved_groups(
  config: Config(msg),
  reserved_tasks: List(PersonWorkloadTask),
) -> Element(msg) {
  keyed.ul(
    [attribute.class("people-task-groups")],
    list.map(group_reserved_tasks(config, reserved_tasks), fn(group) {
      #(
        group.key,
        li([attribute.class("people-task-group")], [
          view_reserved_group_header(config, group),
          view_task_list(config, group.tasks, ReservedTask, False),
        ]),
      )
    }),
  )
}

fn view_reserved_group_header(
  config: Config(msg),
  group: PeopleCardTaskGroup,
) -> Element(msg) {
  div([attribute.class("people-task-group-header")], [
    div([attribute.class("people-task-group-heading")], [
      span([attribute.class("people-task-group-title")], [
        text(group.title),
      ]),
    ]),
    div([attribute.class("people-task-group-actions")], [
      span([attribute.class("people-task-group-count")], [
        text(i18n.t(
          config.locale,
          i18n_text.PeopleReservedGroupCount(list.length(group.tasks)),
        )),
      ]),
      case group.card_id {
        Some(card_id) ->
          action_button(
            "people-task-action people-task-action-secondary people-card-action-open",
            i18n.t(config.locale, i18n_text.OpenCard),
            config.on_card_click(card_id),
          )
        None -> element.none()
      },
    ]),
  ])
}

fn group_reserved_tasks(
  config: Config(msg),
  tasks: List(PersonWorkloadTask),
) -> List(PeopleCardTaskGroup) {
  group_reserved_tasks_loop(config, tasks, [])
}

fn group_reserved_tasks_loop(
  config: Config(msg),
  tasks: List(PersonWorkloadTask),
  groups: List(PeopleCardTaskGroup),
) -> List(PeopleCardTaskGroup) {
  case tasks {
    [] -> groups
    [task, ..rest] ->
      group_reserved_tasks_loop(
        config,
        rest,
        add_task_to_reserved_groups(config, groups, task),
      )
  }
}

fn add_task_to_reserved_groups(
  config: Config(msg),
  groups: List(PeopleCardTaskGroup),
  task: PersonWorkloadTask,
) -> List(PeopleCardTaskGroup) {
  let key = reserved_group_key(task)
  case groups {
    [] -> [new_reserved_group(config, key, task)]
    [group, ..rest] ->
      case group.key == key {
        True -> [
          PeopleCardTaskGroup(..group, tasks: list.append(group.tasks, [task])),
          ..rest
        ]
        False -> [group, ..add_task_to_reserved_groups(config, rest, task)]
      }
  }
}

fn new_reserved_group(
  config: Config(msg),
  key: String,
  task: PersonWorkloadTask,
) -> PeopleCardTaskGroup {
  PeopleCardTaskGroup(
    key: key,
    title: reserved_group_title(config, task),
    card_id: task.card_id,
    tasks: [task],
  )
}

fn reserved_group_key(task: PersonWorkloadTask) -> String {
  case task.card_id, task.card_title {
    Some(id), _ -> "card:" <> int.to_string(id)
    None, Some(title) -> "title:" <> title
    None, None -> "none"
  }
}

fn reserved_group_title(config: Config(msg), task: PersonWorkloadTask) -> String {
  case task.card_title {
    Some(title) -> title
    None -> i18n.t(config.locale, i18n_text.PeopleNoCardContext)
  }
}

fn view_task_list(
  config: Config(msg),
  tasks: List(PersonWorkloadTask),
  kind: PersonTaskKind,
  include_scope: Bool,
) -> Element(msg) {
  keyed.ul(
    [attribute.class("people-task-list")],
    list.map(tasks, fn(task) {
      #(
        int.to_string(task.task_id),
        li([attribute.class("people-task-item")], [
          view_task_item(config, task, kind, include_scope),
        ]),
      )
    }),
  )
}

fn view_task_item(
  config: Config(msg),
  task: PersonWorkloadTask,
  kind: PersonTaskKind,
  include_scope: Bool,
) -> Element(msg) {
  task_item.view(
    task_item.Config(
      container_class: "task-item",
      content_class: "task-item-content",
      leading: None,
      on_click: None,
      content_title: None,
      content_label: None,
      icon: None,
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: view_task_secondary(config, task, kind, include_scope),
      actions: view_task_actions(config, task, kind),
      reserve_actions_slot: False,
      action_slot_class: None,
      content_testid: None,
      testid: None,
    ),
    task_item.Div,
  )
}

fn view_task_secondary(
  config: Config(msg),
  task: PersonWorkloadTask,
  kind: PersonTaskKind,
  include_scope: Bool,
) -> Element(msg) {
  let context = task_line_context(config, task, include_scope)
  let label = case task.blocked, kind {
    True, _ ->
      task_meta_label(
        config,
        i18n_text.PeopleTaskBlockedMeta,
        i18n_text.PeopleNeedsAttentionState,
        context,
      )
    False, NowTask ->
      task_meta_label(
        config,
        i18n_text.PeopleTaskNowMeta,
        i18n_text.PeopleWorkingNowState,
        context,
      )
    False, ReservedTask ->
      task_meta_label(
        config,
        i18n_text.PeopleTaskReservedMeta,
        i18n_text.PeopleReservedSection,
        context,
      )
  }

  div([attribute.class("task-item-meta people-task-meta")], [
    span(
      [
        attribute.class("people-task-status-meta"),
        attribute.attribute("title", label),
      ],
      [text(label)],
    ),
  ])
}

fn task_line_context(
  config: Config(msg),
  task: PersonWorkloadTask,
  include_scope: Bool,
) -> Option(String) {
  case include_scope, task.capability_name {
    False, Some(capability) -> Some(capability)
    False, None -> None
    True, _ -> {
      let base = task_scope_label(config, task)
      Some(base)
    }
  }
}

fn task_meta_label(
  config: Config(msg),
  label: fn(String) -> i18n_text.Text,
  fallback: i18n_text.Text,
  context: Option(String),
) -> String {
  case context {
    Some(value) -> i18n.t(config.locale, label(value))
    None -> i18n.t(config.locale, fallback)
  }
}

fn view_task_actions(
  config: Config(msg),
  task: PersonWorkloadTask,
  kind: PersonTaskKind,
) -> List(Element(msg)) {
  let open =
    action_button(
      "people-task-action people-task-action-open",
      i18n.t(config.locale, i18n_text.OpenTask),
      config.on_task_click(task.task_id),
    )

  case task_is_owned_by_current_user(config, task), kind {
    True, NowTask -> [
      open,
      action_button(
        "people-task-action people-task-action-secondary",
        i18n.t(config.locale, i18n_text.Pause),
        config.on_now_working_pause,
      ),
      action_button(
        "people-task-action people-task-action-secondary",
        i18n.t(config.locale, i18n_text.Close),
        config.on_task_close(task.task_id, task.task_version),
      ),
    ]
    True, ReservedTask -> [
      open,
      action_button(
        "people-task-action people-task-action-primary",
        i18n.t(config.locale, i18n_text.Start),
        config.on_now_working_start(task.task_id),
      ),
      action_button(
        "people-task-action people-task-action-secondary",
        i18n.t(config.locale, i18n_text.Release),
        config.on_task_release(task.task_id, task.task_version),
      ),
    ]
    False, _ -> [open]
  }
}

fn action_button(class_name: String, label: String, msg: msg) -> Element(msg) {
  button(
    [
      attribute.class(class_name),
      attribute.type_("button"),
      event.on_click(msg),
    ],
    [text(label)],
  )
}

fn task_is_owned_by_current_user(
  config: Config(msg),
  task: PersonWorkloadTask,
) -> Bool {
  case config.current_user_id {
    Some(current_user_id) -> current_user_id == task.owner_user_id
    None -> False
  }
}

fn filter_people(
  config: Config(msg),
  people: List(PersonWorkload),
  search_query: String,
) -> List(PersonWorkload) {
  let query = string.trim(search_query) |> string.lowercase
  case query {
    "" -> people
    _ ->
      list.filter(people, fn(person) {
        person_matches_query(config, person, query)
      })
  }
}

fn person_matches_query(
  config: Config(msg),
  person: PersonWorkload,
  query: String,
) -> Bool {
  string.contains(string.lowercase(person.email), query)
  || list.any(person_tasks(person), fn(task) {
    task_matches_query(config, task, query)
  })
}

fn person_tasks(person: PersonWorkload) -> List(PersonWorkloadTask) {
  list.append(
    person.working_now,
    list.append(person.reserved, person.attention),
  )
}

fn task_matches_query(
  _config: Config(msg),
  task: PersonWorkloadTask,
  query: String,
) -> Bool {
  string.contains(string.lowercase(task.title), query)
  || string.contains(string.lowercase(option_string(task.card_title)), query)
  || string.contains(string.lowercase(task.task_type_name), query)
  || string.contains(
    string.lowercase(option_string(task.capability_name)),
    query,
  )
}

fn option_string(value: Option(String)) -> String {
  case value {
    Some(text) -> text
    None -> ""
  }
}

fn is_expanded(
  expansions: dict.Dict(Int, people_state.RowExpansion),
  user_id: Int,
) -> Bool {
  case dict.get(expansions, user_id) {
    Ok(people_state.Expanded) -> True
    _ -> False
  }
}
