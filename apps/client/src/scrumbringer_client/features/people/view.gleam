//// People view: team availability by project member.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some, from_result}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, input, label, li, option as html_option, p, select, span, text,
}
import lustre/element/keyed
import lustre/event

import domain/capability.{type Capability}
import domain/card.{type Card, type CardColor}
import domain/org.{type OrgUser}
import domain/project.{type ProjectMember}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task as domain_task
import domain/task/state as task_state
import domain/task_type.{type TaskType}
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/plan/scope_bar
import scrumbringer_client/features/work_filters
import scrumbringer_client/features/work_scope/queries as work_scope_queries
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attribute_value
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/task_color
import scrumbringer_client/ui/task_item
import scrumbringer_client/ui/task_state as task_state_ui
import scrumbringer_client/ui/tone

type PeopleSummary {
  PeopleSummary(
    attention_count: Int,
    working_count: Int,
    claimed_count: Int,
    available_count: Int,
  )
}

pub type Config(msg) {
  Config(
    locale: Locale,
    people_roster: Remote(List(ProjectMember)),
    member_tasks: Remote(List(domain_task.Task)),
    task_types: Remote(List(TaskType)),
    capabilities: Remote(List(Capability)),
    cards: List(Card),
    depth_names: List(scope_view.DepthName),
    scope_kind: member_pool.PlanScopeKind,
    selected_depth: Option(Int),
    selected_card_id: Option(Int),
    card_query: String,
    org_users: Remote(List(OrgUser)),
    people_expansions: dict.Dict(Int, people_state.RowExpansion),
    search_query: String,
    visibility_filter: people_state.PeopleVisibilityFilter,
    sort: people_state.PeopleSort,
    task_card_color: fn(domain_task.Task) -> Option(CardColor),
    on_scope_kind_change: fn(String) -> msg,
    on_scope_depth_change: fn(String) -> msg,
    on_scope_card_change: fn(String) -> msg,
    on_scope_card_search_change: fn(String) -> msg,
    on_search_change: fn(String) -> msg,
    on_visibility_filter_change: fn(String) -> msg,
    on_sort_change: fn(String) -> msg,
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
      let scoped_tasks = scoped_member_tasks(config)
      let people =
        list.map(members, fn(member) {
          people_state.derive_status(
            member.user_id,
            resolve_user_label(config, member.user_id),
            tasks_for_member(scoped_tasks, member.user_id),
          )
        })

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
        selected_card_scope_has_no_work(config, scoped_tasks),
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
  scoped_tasks: List(domain_task.Task),
) -> Bool {
  case config.scope_kind, config.selected_card_id, config.member_tasks {
    member_pool.PlanScopeCard, Some(_), Loaded(_) -> scoped_tasks == []
    _, _, _ -> False
  }
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
          [attribute.value("claimed")],
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
      view_roster_section(config, rows, people_state.RosterClaimedWork),
      view_roster_section(config, rows, people_state.RosterAvailable),
    ])
  ])
}

fn view_roster_header(config: Config(msg)) -> Element(msg) {
  li([attribute.class("people-roster-head")], [
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnPerson))]),
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnState))]),
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnWork))]),
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnContext))]),
    span([], [text(i18n.t(config.locale, i18n_text.PeopleColumnAction))]),
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
  let people_state.PersonStatus(
    user_id: user_id,
    label: label,
    active_tasks: active_tasks,
    claimed_tasks: claimed_tasks,
    ..,
  ) = person

  let expanded = is_expanded(config.people_expansions, user_id)
  let details_id = "person-details-" <> int.to_string(user_id)
  let toggle_label = case expanded {
    True -> i18n.t(config.locale, i18n_text.CollapsePerson(name: label))
    False -> i18n.t(config.locale, i18n_text.ExpandPerson(name: label))
  }

  li([attribute.class("people-roster-row " <> section_row_class(row.section))], [
    div([attribute.class("people-roster-cell people-roster-person")], [
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
    ]),
    div([attribute.class("people-roster-cell people-roster-state")], [
      span([attribute.class("people-roster-state-label")], [
        text(row_state_label(config, row)),
      ]),
      view_optional_detail(row_state_detail(config, row)),
    ]),
    div([attribute.class("people-roster-cell people-roster-work")], [
      view_primary_work(config, row),
    ]),
    div([attribute.class("people-roster-cell people-roster-context")], [
      view_context(config, row),
    ]),
    div([attribute.class("people-roster-cell people-roster-action")], [
      view_row_action(config, row),
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
        int.to_string(summary.claimed_count),
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

fn summarize_people(people: List(people_state.PersonStatus)) -> PeopleSummary {
  let roster_summary =
    people
    |> people_state.build_roster
    |> people_state.roster_summary

  PeopleSummary(
    attention_count: roster_summary.attention_count,
    working_count: roster_summary.working_count,
    claimed_count: roster_summary.claimed_count,
    available_count: roster_summary.available_count,
  )
}

fn section_key(section: people_state.RosterSection) -> String {
  case section {
    people_state.NeedsAttention -> "attention"
    people_state.RosterWorkingNow -> "working"
    people_state.RosterClaimedWork -> "claimed"
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
    people_state.RosterClaimedWork ->
      i18n.t(config.locale, i18n_text.PeopleSectionClaimedWork)
    people_state.RosterAvailable ->
      i18n.t(config.locale, i18n_text.PeopleSectionAvailable)
  }
}

fn section_row_class(section: people_state.RosterSection) -> String {
  "people-roster-row-" <> section_key(section)
}

fn row_state_label(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> String {
  case row.attention_reason, row.section {
    Some(people_state.OngoingWorkBlocked), _ ->
      i18n.t(config.locale, i18n_text.PeopleOngoingWorkBlocked)
    Some(people_state.ClaimedWorkBlocked), _ ->
      i18n.t(config.locale, i18n_text.PeopleClaimedWorkBlocked)
    None, people_state.RosterWorkingNow ->
      i18n.t(config.locale, i18n_text.PeopleWorkingNowState)
    None, people_state.RosterClaimedWork ->
      i18n.t(
        config.locale,
        i18n_text.PeopleClaimedCount(list.length(row.person.claimed_tasks)),
      )
    None, people_state.RosterAvailable ->
      i18n.t(config.locale, i18n_text.PeopleAvailableState)
    None, people_state.NeedsAttention ->
      i18n.t(config.locale, i18n_text.PeopleNeedsAttentionState)
  }
}

fn row_state_detail(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Option(String) {
  case row.attention_reason {
    Some(_) -> Some(i18n.t(config.locale, i18n_text.PeopleBlockedDetail))
    None ->
      case row.secondary_signal {
        Some(people_state.HighClaimedLoadSignal(_)) ->
          Some(i18n.t(config.locale, i18n_text.PeopleLoadWarning))
        None -> None
      }
  }
}

fn view_optional_detail(detail: Option(String)) -> Element(msg) {
  case detail {
    Some(value) ->
      span([attribute.class("people-roster-detail")], [text(value)])
    None -> element.none()
  }
}

fn view_primary_work(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Element(msg) {
  case row.primary_task {
    Some(task) ->
      div([attribute.class("people-roster-work-stack")], [
        button(
          [
            attribute.class("people-roster-task-link"),
            event.on_click(config.on_task_click(task.id)),
          ],
          [text(primary_work_label(config, row, task))],
        ),
        view_blocker_line(config, task),
      ])
    None ->
      span([attribute.class("people-roster-muted")], [
        text(i18n.t(config.locale, i18n_text.PeopleNoOwnedWork)),
      ])
  }
}

fn primary_work_label(
  config: Config(msg),
  row: people_state.PersonRosterRow,
  task: domain_task.Task,
) -> String {
  case row.section {
    people_state.RosterClaimedWork ->
      i18n.t(config.locale, i18n_text.PeopleNextWork(task.title))
    people_state.NeedsAttention
    | people_state.RosterWorkingNow
    | people_state.RosterAvailable -> task.title
  }
}

fn view_blocker_line(
  config: Config(msg),
  task: domain_task.Task,
) -> Element(msg) {
  case task.blocked_count > 0 {
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

fn blocker_label(config: Config(msg), task: domain_task.Task) -> String {
  case first_open_dependency_title(task) {
    Some(title) -> title
    None -> i18n.t(config.locale, i18n_text.PeopleOpenDependencies)
  }
}

fn first_open_dependency_title(task: domain_task.Task) -> Option(String) {
  task.dependencies
  |> list.find_map(fn(dep) {
    let domain_task.TaskDependency(title: title, state: state, ..) = dep
    case state {
      task_state.Closed(..) -> Error(Nil)
      task_state.Available | task_state.Claimed(..) -> Ok(title)
    }
  })
  |> from_result
}

fn view_context(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Element(msg) {
  case row.primary_task {
    Some(task) ->
      span([attribute.class("people-roster-context-text")], [
        text(task_context_label(config, task)),
      ])
    None ->
      span([attribute.class("people-roster-muted")], [
        text(i18n.t(config.locale, i18n_text.PeopleCanPullFromPool)),
      ])
  }
}

fn task_context_label(config: Config(msg), task: domain_task.Task) -> String {
  case task.card_title, task_capability_name(config, task) {
    Some(card_title), "" -> card_title
    Some(card_title), capability -> card_title <> " - " <> capability
    None, "" -> i18n.t(config.locale, i18n_text.PeopleNoCardContext)
    None, capability -> capability
  }
}

fn view_row_action(
  config: Config(msg),
  row: people_state.PersonRosterRow,
) -> Element(msg) {
  case row.primary_task {
    Some(task) ->
      button(
        [
          attribute.class("btn btn-xs people-roster-open"),
          event.on_click(config.on_task_click(task.id)),
        ],
        [text(i18n.t(config.locale, i18n_text.PeopleOpenTaskAction))],
      )
    None ->
      span([attribute.class("people-roster-muted")], [
        text(i18n.t(config.locale, i18n_text.Pool)),
      ])
  }
}

fn view_active_section(
  config: Config(msg),
  active_tasks: List(domain_task.Task),
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
  claimed_tasks: List(domain_task.Task),
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

fn view_task_list(
  config: Config(msg),
  tasks: List(domain_task.Task),
) -> Element(msg) {
  keyed.ul(
    [attribute.class("people-claimed-list")],
    list.map(tasks, fn(task) {
      #(
        int.to_string(task.id),
        li([attribute.class("people-task-item")], [
          view_task_item(config, task),
        ]),
      )
    }),
  )
}

fn view_task_item(config: Config(msg), task: domain_task.Task) -> Element(msg) {
  let resolved_color = config.task_card_color(task)
  let border_class = task_color.card_border_class(resolved_color)

  task_item.view(
    task_item.Config(
      container_class: "task-item " <> border_class,
      content_class: "task-item-content",
      leading: view_task_leading_swatch(config, task, resolved_color),
      on_click: Some(config.on_task_click(task.id)),
      content_title: None,
      content_label: None,
      icon: None,
      icon_class: None,
      title: task.title,
      title_class: None,
      secondary: view_task_secondary(config, task),
      actions: task_item.no_actions(),
      reserve_actions_slot: True,
      action_slot_class: None,
      content_testid: None,
      testid: None,
    ),
    task_item.Div,
  )
}

fn view_task_leading_swatch(
  config: Config(msg),
  task: domain_task.Task,
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

fn view_task_secondary(
  config: Config(msg),
  task: domain_task.Task,
) -> Element(msg) {
  div([attribute.class("task-item-meta people-task-meta")], [
    span(
      [
        attribute.class("task-status-muted"),
        attribute.attribute(
          "title",
          task_state_ui.hint(config.locale, task_state.to_status(task.state)),
        ),
      ],
      [
        text(task_state_ui.label(
          config.locale,
          task_state.to_status(task.state),
        )),
      ],
    ),
  ])
}

fn task_card_accessibility_label(
  config: Config(msg),
  task: domain_task.Task,
) -> String {
  case task.card_title {
    Some(title) -> title
    None -> i18n.t(config.locale, i18n_text.PeopleNoCardContext)
  }
}

fn scoped_member_tasks(config: Config(msg)) -> List(domain_task.Task) {
  case config.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(task) { task_is_claimed(task) })
      |> work_scope_queries.tasks_in_scope(
        config.cards,
        config.scope_kind,
        config.selected_depth,
        config.selected_card_id,
      )
    _ -> []
  }
}

fn task_is_claimed(task: domain_task.Task) -> Bool {
  case task.state {
    task_state.Claimed(..) -> True
    _ -> False
  }
}

fn tasks_for_member(
  tasks: List(domain_task.Task),
  user_id: Int,
) -> List(domain_task.Task) {
  list.filter(tasks, fn(task) {
    case task.state {
      task_state.Claimed(claimed_by: claimed_by, ..) -> claimed_by == user_id
      _ -> False
    }
  })
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
  config: Config(msg),
  people: List(people_state.PersonStatus),
  search_query: String,
) -> List(people_state.PersonStatus) {
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
  person: people_state.PersonStatus,
  query: String,
) -> Bool {
  string.contains(string.lowercase(person.label), query)
  || list.any(person_tasks(person), fn(task) {
    task_matches_query(config, task, query)
  })
}

fn person_tasks(person: people_state.PersonStatus) -> List(domain_task.Task) {
  list.append(person.active_tasks, person.claimed_tasks)
}

fn task_matches_query(
  config: Config(msg),
  task: domain_task.Task,
  query: String,
) -> Bool {
  string.contains(string.lowercase(task.title), query)
  || string.contains(string.lowercase(option_string(task.card_title)), query)
  || string.contains(string.lowercase(task.task_type.name), query)
  || string.contains(
    string.lowercase(task_capability_name(config, task)),
    query,
  )
}

fn task_capability_name(config: Config(msg), task: domain_task.Task) -> String {
  case config.task_types, config.capabilities {
    Loaded(task_types), Loaded(capabilities) ->
      case work_filters.task_capability_id(task, task_types) {
        Some(capability_id) ->
          case
            list.find(capabilities, fn(capability) {
              capability.id == capability_id
            })
          {
            Ok(capability) -> capability.name
            Error(_) -> ""
          }
        None -> ""
      }
    _, _ -> ""
  }
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
  case dict.get(expansions, user_id) |> from_result {
    Some(people_state.Expanded) -> True
    _ -> False
  }
}
