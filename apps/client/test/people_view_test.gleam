import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/effect
import lustre/element

import domain/api_error.{ApiError}
import domain/card
import domain/org_role
import domain/people_workload.{
  type PersonWorkload, type PersonWorkloadTask, PersonWorkload,
  PersonWorkloadSummary, PersonWorkloadTask, WorkloadAttention,
  WorkloadAvailable, WorkloadReserved, WorkloadWorkingNow,
}
import domain/project_role
import domain/remote
import domain/task.{
  type Task, type WorkSessionsPayload, Task, WorkSession, WorkSessionsPayload,
}
import domain/task/state as task_state
import domain/task_type.{TaskTypeInline}
import domain/user.{User}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/people/view as people_view
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_update
import scrumbringer_client/i18n/locale

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

fn assert_not_contains(text: String, fragment: String) {
  let assert False = string.contains(text, fragment)
}

fn make_task(
  id: Int,
  title: String,
  user_id: Int,
  mode: task_state.TaskClaimMode,
) -> Task {
  let state =
    task_state.Claimed(
      claimed_by: user_id,
      claimed_at: "2026-02-01T10:00:00Z",
      mode: mode,
    )

  Task(
    id: id,
    project_id: 1,
    type_id: 1,
    task_type: TaskTypeInline(id: 1, name: "Bug", icon: "bug-ant"),
    ongoing_by: None,
    title: title,
    description: None,
    priority: 3,
    state: state,
    created_by: 1,
    created_at: "2026-02-01T09:00:00Z",
    due_date: None,
    version: 1,
    parent_card_id: None,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
    automation_origin: None,
  )
}

fn task_with_type(task: Task, type_id: Int, type_name: String) -> Task {
  Task(
    ..task,
    type_id: type_id,
    task_type: TaskTypeInline(id: type_id, name: type_name, icon: "bug-ant"),
  )
}

fn blocked(task: Task) -> Task {
  Task(..task, blocked_count: 1)
}

fn task_on_card(
  task: Task,
  card_id: Int,
  title: String,
  color: card.CardColor,
) -> Task {
  Task(
    ..task,
    card_id: Some(card_id),
    card_title: Some(title),
    card_color: Some(color),
  )
}

fn make_card(
  id: Int,
  parent_card_id: option.Option(Int),
  title: String,
) -> card.Card {
  card.Card(
    id: id,
    project_id: 1,
    parent_card_id: parent_card_id,
    title: title,
    description: "",
    color: Some(card.Blue),
    state: card.Active,
    task_count: 0,
    closed_count: 0,
    created_by: 1,
    created_at: "2026-02-01T09:00:00Z",
    due_date: None,
    has_new_notes: False,
  )
}

fn person(user_id: Int) -> PersonWorkload {
  available_person(user_id, "User #" <> int.to_string(user_id))
}

fn workload_email(user_id: Int, email: String) -> #(Int, String) {
  #(user_id, email)
}

fn base_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_ui(fn(ui) { ui_state.UiModel(..ui, locale: locale.En) })
}

fn with_current_user(
  model: client_state.Model,
  user_id: Int,
) -> client_state.Model {
  client_state.update_core(model, fn(core) {
    client_state.CoreModel(
      ..core,
      user: Some(User(
        id: user_id,
        email: "admin@example.com",
        org_id: 1,
        org_role: org_role.Admin,
        created_at: "",
      )),
    )
  })
}

fn people_config(model: client_state.Model) -> people_view.Config(Int) {
  people_config_with_cards(model, [])
}

fn people_config_with_cards(
  model: client_state.Model,
  cards: List(card.Card),
) -> people_view.Config(Int) {
  people_view.Config(
    locale: model.ui.locale,
    people_workload: model.member.pool.people_workload,
    cards: cards,
    depth_names: [
      scope_view.DepthName(1, "Initiative", "Initiatives"),
      scope_view.DepthName(2, "Feature", "Features"),
      scope_view.DepthName(3, "Story", "Stories"),
    ],
    scope_kind: model.member.pool.member_plan_scope_kind,
    selected_depth: model.member.pool.member_card_depth_filter,
    selected_card_id: model.member.pool.member_plan_scope_card_id,
    card_query: model.member.pool.member_plan_scope_card_query,
    people_expansions: model.member.pool.people_expansions,
    search_query: model.member.pool.member_people_search_query,
    visibility_filter: model.member.pool.member_people_filter,
    sort: model.member.pool.member_people_sort,
    current_user_id: model.core.user |> option.map(fn(user) { user.id }),
    on_scope_kind_change: fn(_value) { 0 },
    on_scope_depth_change: fn(_value) { 0 },
    on_scope_card_change: fn(_value) { 0 },
    on_scope_card_search_change: fn(_value) { 0 },
    on_search_change: fn(_value) { 0 },
    on_visibility_filter_change: fn(_value) { 0 },
    on_sort_change: fn(_value) { 0 },
    on_person_toggle: fn(user_id) { user_id },
    on_task_click: fn(task_id) { task_id },
    on_now_working_start: fn(task_id) { task_id + 1000 },
    on_now_working_pause: -1,
    on_task_release: fn(task_id, _version) { task_id + 2000 },
    on_task_close: fn(task_id, _version) { task_id + 3000 },
  )
}

fn render_people(model: client_state.Model) -> String {
  people_view.view(people_config(model)) |> element.to_document_string
}

fn render_people_with_cards(
  model: client_state.Model,
  cards: List(card.Card),
) -> String {
  people_view.view(people_config_with_cards(model, cards))
  |> element.to_document_string
}

fn with_people_workload(
  model: client_state.Model,
  people_workload: remote.Remote(List(PersonWorkload)),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, people_workload: people_workload),
    )
  })
}

fn available_person(user_id: Int, email: String) -> PersonWorkload {
  PersonWorkload(
    user_id: user_id,
    email: email,
    role: project_role.Member,
    state: WorkloadAvailable,
    working_now: [],
    reserved: [],
    attention: [],
    summary: PersonWorkloadSummary(
      working_now_count: 0,
      reserved_count: 0,
      attention_count: 0,
    ),
  )
}

fn with_people_expanded(
  model: client_state.Model,
  user_id: Int,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        people_expansions: dict.insert(
          dict.new(),
          user_id,
          people_state.Expanded,
        ),
      ),
    )
  })
}

fn with_people_search(
  model: client_state.Model,
  search: String,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_people_search_query: search),
    )
  })
}

fn with_people_filter(
  model: client_state.Model,
  filter: people_state.PeopleVisibilityFilter,
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_people_filter: filter),
    )
  })
}

fn with_scope(
  model: client_state.Model,
  scope_kind: member_pool.PlanScopeKind,
  selected_depth: option.Option(Int),
  selected_card_id: option.Option(Int),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        member_plan_scope_kind: scope_kind,
        member_card_depth_filter: selected_depth,
        member_plan_scope_card_id: selected_card_id,
      ),
    )
  })
}

fn with_workload_tasks(
  model: client_state.Model,
  tasks: List(Task),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        people_workload: refresh_test_workload(pool.people_workload, tasks),
      ),
    )
  })
}

fn with_member_tasks(
  model: client_state.Model,
  tasks: List(Task),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, member_tasks: remote.Loaded(tasks)),
    )
  })
}

fn refresh_test_workload(
  people: remote.Remote(List(PersonWorkload)),
  tasks: List(Task),
) -> remote.Remote(List(PersonWorkload)) {
  case people {
    remote.Loaded(existing) ->
      remote.Loaded(
        list.map(existing, fn(person) {
          let owned =
            list.filter(tasks, fn(task) {
              task_owner_id(task) == Some(person.user_id)
            })
          workload_from_tasks(person, owned)
        }),
      )
    other -> other
  }
}

fn workload_from_tasks(
  person: PersonWorkload,
  tasks: List(Task),
) -> PersonWorkload {
  let working_now =
    tasks
    |> list.filter(fn(task) { task_is_ongoing(task) && task.blocked_count == 0 })
    |> list.map(task_to_workload_task)
  let reserved =
    tasks
    |> list.filter(fn(task) {
      !task_is_ongoing(task) && task.blocked_count == 0
    })
    |> list.map(task_to_workload_task)
  let attention =
    tasks
    |> list.filter(fn(task) { task.blocked_count > 0 })
    |> list.map(task_to_workload_task)
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
    summary: PersonWorkloadSummary(
      working_now_count: list.length(working_now),
      reserved_count: list.length(reserved),
      attention_count: list.length(attention),
    ),
  )
}

fn task_to_workload_task(task: Task) -> PersonWorkloadTask {
  PersonWorkloadTask(
    task_id: task.id,
    task_version: task.version,
    owner_user_id: task_owner_id(task) |> option.unwrap(0),
    title: task.title,
    task_type_name: task.task_type.name,
    capability_name: None,
    card_id: task.card_id,
    card_title: task.card_title,
    card_state: None,
    blocked: task.blocked_count > 0,
    ongoing: task_is_ongoing(task),
    outside_active_work_scope: False,
  )
}

fn task_owner_id(task: Task) -> option.Option(Int) {
  case task.state {
    task_state.Claimed(claimed_by: user_id, ..) -> Some(user_id)
    _ -> None
  }
}

fn task_is_ongoing(task: Task) -> Bool {
  case task.state {
    task_state.Claimed(mode: task_state.Ongoing, ..) -> True
    _ -> False
  }
}

fn work_session_payload(task_id: Int) -> WorkSessionsPayload {
  WorkSessionsPayload(
    active_sessions: [
      WorkSession(
        task_id: task_id,
        started_at: "2026-02-01T11:00:00Z",
        accumulated_s: 0,
      ),
    ],
    as_of: "2026-02-01T11:00:00Z",
  )
}

fn no_refresh_context() -> pool_update.Context {
  pool_update.Context(member_refresh: fn(model) { #(model, effect.none()) })
}

fn with_people_emails(
  model: client_state.Model,
  users: List(#(Int, String)),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(
        ..pool,
        people_workload: rename_workload_people(pool.people_workload, users),
      ),
    )
  })
}

fn rename_workload_people(
  people: remote.Remote(List(PersonWorkload)),
  users: List(#(Int, String)),
) -> remote.Remote(List(PersonWorkload)) {
  case people {
    remote.Loaded(existing) ->
      remote.Loaded(
        list.map(existing, fn(person) {
          case
            list.find(users, fn(user) {
              let #(user_id, _) = user
              user_id == person.user_id
            })
          {
            Ok(#(_, email)) -> PersonWorkload(..person, email: email)
            Error(_) -> person
          }
        }),
      )
    other -> other
  }
}

pub fn people_view_loading_state_test() {
  let model = base_model() |> with_people_workload(remote.Loading)
  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Loading people...")
}

pub fn people_view_error_state_test() {
  let model =
    base_model()
    |> with_people_workload(
      remote.Failed(ApiError(status: 500, code: "E_PEOPLE", message: "boom")),
    )

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Could not load people")
  assert_contains(html, "people-error")
}

pub fn people_view_empty_roster_state_test() {
  let model = base_model() |> with_people_workload(remote.Loaded([]))
  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "No members in this project")
}

pub fn people_view_no_results_state_test() {
  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_workload_tasks([])
    |> with_people_emails([
      workload_email(10, "alice@example.com"),
    ])
    |> client_state.update_member(fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(..pool, member_people_search_query: "zzz"),
      )
    })

  let html =
    people_view.view(people_config(model)) |> element.to_document_string
  assert_contains(html, "No people match your search")
}

pub fn people_view_availability_rules_test() {
  let tasks = [
    make_task(1, "Active task", 10, task_state.Ongoing),
    make_task(2, "Claimed task", 11, task_state.Taken),
  ]

  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
        person(11),
        person(12),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
      workload_email(11, "bob@example.com"),
      workload_email(12, "cora@example.com"),
    ])
    |> with_workload_tasks(tasks)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Working now")
  assert_contains(html, "Reserved")
  assert_contains(html, "Available")
  assert_contains(html, "Person")
  assert_contains(html, "State")
  assert_contains(html, "Focus")
  assert_contains(html, "Scope")
  assert_contains(html, "Load")
  assert_not_contains(html, ">Action<")
  assert_not_contains(html, "0 ongoing")
}

pub fn people_view_availability_prefers_canonical_ongoing_state_test() {
  let tasks = [make_task(1, "Active task", 10, task_state.Ongoing)]

  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
    ])
    |> with_workload_tasks(tasks)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Working now")
  assert_contains(html, "people-roster-row-working")
  assert_not_contains(html, "people-roster-row-reserved")
}

pub fn people_view_surface_summary_and_collapsed_balance_test() {
  let tasks = [
    make_task(1, "Build intake", 10, task_state.Ongoing)
      |> task_on_card(101, "Checkout", card.Blue),
    make_task(2, "Draft copy", 10, task_state.Taken)
      |> task_on_card(102, "Onboarding", card.Green),
    make_task(3, "Review logs", 11, task_state.Taken)
      |> task_on_card(103, "Observability", card.Purple),
    make_task(4, "Patch alert", 11, task_state.Taken)
      |> task_on_card(103, "Observability", card.Purple),
    make_task(5, "Check query", 11, task_state.Taken)
      |> task_on_card(103, "Observability", card.Purple),
    make_task(6, "Plan rollout", 11, task_state.Taken)
      |> task_on_card(103, "Observability", card.Purple),
  ]

  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
        person(11),
        person(12),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
      workload_email(11, "bob@example.com"),
      workload_email(12, "cora@example.com"),
    ])
    |> with_workload_tasks(tasks)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(
    html,
    "Operational team state by owned work, blockers, and availability.",
  )
  assert_contains(html, "work-surface-guidance")
  assert_contains(html, "main operating situation")
  assert_contains(html, "task explaining the row")
  assert_contains(html, "dominant card or capability")
  assert_contains(html, "total work volume")
  assert_contains(html, "work-surface-chip success")
  assert_contains(html, ">Available<")
  assert_contains(html, "work-surface-chip claimed")
  assert_contains(html, ">With work<")
  assert_contains(html, "work-surface-chip ongoing")
  assert_contains(html, ">Working now<")
  assert_contains(html, "work-surface-chip blocked")
  assert_contains(html, ">Attention<")
  assert_contains(html, "Reserved · 1")
  assert_contains(html, "Next: Review logs")
  assert_contains(html, "Checkout +1 card")
  assert_contains(html, "Observability")
  assert_contains(html, "1 ongoing · 1 reserved · 2 cards")
  assert_contains(html, "4 reserved")
  assert_contains(html, "High load")
  assert_not_contains(html, "people-roster-action")
  assert_not_contains(html, "people-roster-open")
  assert_not_contains(html, "0 ongoing")
}

pub fn people_view_expanded_keeps_card_context_in_person_tray_test() {
  let tasks = [
    make_task(1, "Build intake", 10, task_state.Ongoing)
      |> task_on_card(101, "Checkout", card.Blue),
    make_task(2, "Draft copy", 10, task_state.Taken)
      |> task_on_card(102, "Onboarding", card.Green),
    make_task(3, "Review copy", 10, task_state.Taken)
      |> task_on_card(103, "Billing", card.Purple),
  ]

  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
    ])
    |> with_workload_tasks(tasks)
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Checkout")
  assert_contains(html, "Onboarding")
  assert_contains(html, "Billing")
  assert_contains(html, "Work tray for ana@example.com")
  assert_contains(html, "Now")
  assert_contains(html, "Reserved")
  assert_contains(html, "In progress · Checkout")
  assert_contains(html, "Reserved · Onboarding")
  assert_not_contains(html, "people-task-group")
  assert_not_contains(html, "people-task-card-meta")
}

pub fn people_view_groups_many_reserved_tasks_by_card_test() {
  let tasks = [
    make_task(1, "Review logs", 10, task_state.Taken)
      |> task_on_card(101, "Observability", card.Purple),
    make_task(2, "Patch alert", 10, task_state.Taken)
      |> task_on_card(101, "Observability", card.Purple),
    make_task(3, "Plan rollout", 10, task_state.Taken)
      |> task_on_card(102, "Release", card.Blue),
  ]

  let model =
    base_model()
    |> with_people_workload(remote.Loaded([person(10)]))
    |> with_people_emails([workload_email(10, "ana@example.com")])
    |> with_workload_tasks(tasks)
    |> with_people_expanded(10)

  let html = render_people(model)

  assert_contains(html, "people-task-groups")
  assert_contains(html, "people-task-group")
  assert_contains(html, "Observability")
  assert_contains(html, "2 tasks")
  assert_contains(html, "Release")
  assert_contains(html, "1 task")
}

pub fn people_view_expanded_free_person_reads_as_available_capacity_test() {
  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
    ])
    |> with_workload_tasks([])
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "No active focus")
  assert_contains(html, "No reserved work")
  assert_contains(html, "Can pull from Pool")
}

pub fn people_view_reflects_work_session_started_when_task_is_loaded_test() {
  let task = make_task(89, "Facilitate rollout sync", 1, task_state.Taken)
  let model =
    base_model()
    |> with_current_user(1)
    |> with_people_workload(remote.Loaded([person(1)]))
    |> with_people_emails([workload_email(1, "admin@example.com")])
    |> with_workload_tasks([task])
    |> with_member_tasks([task])
    |> with_people_expanded(1)

  let #(next, _fx) =
    pool_update.update(
      model,
      pool_messages.MemberWorkSessionStarted(89, Ok(work_session_payload(89))),
      no_refresh_context(),
    )

  let html = render_people(next)

  assert_contains(html, "Working now")
  assert_contains(html, "Facilitate rollout sync")
  assert_not_contains(html, "No active focus")
  assert_not_contains(html, "0 ongoing")
}

pub fn people_view_expanded_row_accessibility_and_sections_test() {
  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
    ])
    |> with_workload_tasks([make_task(1, "Active task", 10, task_state.Ongoing)])
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "aria-controls=\"person-details-10\"")
  assert_contains(html, "Collapse status for ana@example.com")
  assert_contains(html, "Now")
  assert_contains(html, "Reserved")
  assert_contains(html, "task-item-content")
}

pub fn people_view_uses_list_semantics_test() {
  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_workload_tasks([])

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "<ul")
  assert_contains(html, "<li")
}

pub fn people_view_toggle_is_keyboard_accessible_button_test() {
  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
    ])
    |> with_workload_tasks([])

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "<button")
  assert_contains(html, "people-row-toggle")
  assert_contains(html, "aria-expanded=\"false\"")
  assert_contains(html, "aria-label=\"Expand status for ana@example.com\"")
}

pub fn people_view_expanded_separates_active_and_reserved_tasks_test() {
  let tasks = [
    make_task(1, "Ongoing one", 10, task_state.Ongoing),
    make_task(2, "Ongoing via canonical state", 10, task_state.Ongoing),
    make_task(3, "Reserved parked", 10, task_state.Taken),
  ]

  let model =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
    ])
    |> with_workload_tasks(tasks)
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Now")
  assert_contains(html, "Reserved")

  assert_contains(html, "Ongoing one")
  assert_contains(html, "Ongoing via canonical state")
  assert_contains(html, "Reserved parked")
}

pub fn people_view_renders_header_scope_controls_and_body_test() {
  let model =
    base_model()
    |> with_people_workload(remote.Loaded([person(10)]))
    |> with_people_emails([workload_email(10, "ana@example.com")])
    |> with_workload_tasks([])

  let html = render_people(model)

  assert_contains(html, "data-testid=\"people-surface-header\"")
  assert_contains(html, "data-testid=\"plan-scope-bar\"")
  assert_contains(html, "data-testid=\"people-search\"")
  assert_contains(html, "data-testid=\"people-filter\"")
  assert_contains(html, "data-testid=\"people-sort\"")
  assert_contains(html, "data-testid=\"people-view\"")
  assert_not_contains(html, "data-testid=\"plan-closed-toggle\"")
}

pub fn people_view_project_level_and_card_scope_filter_tasks_test() {
  let cards = [
    make_card(1, None, "Root Initiative"),
    make_card(2, Some(1), "Child Feature"),
    make_card(3, None, "Other Initiative"),
    make_card(4, Some(2), "Grand Story"),
  ]
  let tasks = [
    make_task(1, "Root task", 10, task_state.Taken)
      |> task_on_card(1, "Root Initiative", card.Blue),
    make_task(2, "Child task", 10, task_state.Taken)
      |> task_on_card(2, "Child Feature", card.Green),
    make_task(3, "Other task", 10, task_state.Taken)
      |> task_on_card(3, "Other Initiative", card.Purple),
    make_task(4, "Grand task", 10, task_state.Taken)
      |> task_on_card(4, "Grand Story", card.Yellow),
  ]
  let base =
    base_model()
    |> with_people_workload(remote.Loaded([person(10)]))
    |> with_people_emails([workload_email(10, "ana@example.com")])
    |> with_workload_tasks(tasks)
    |> with_people_expanded(10)

  let project_html =
    base
    |> with_scope(member_pool.PlanScopeProject, None, None)
    |> render_people_with_cards(cards)
  assert_contains(project_html, "Root task")
  assert_contains(project_html, "Child task")
  assert_contains(project_html, "Grand task")
  assert_contains(project_html, "Other task")

  let level_html =
    base
    |> with_scope(member_pool.PlanScopeLevel, Some(2), None)
    |> render_people_with_cards(cards)
  assert_not_contains(level_html, "Root task")
  assert_contains(level_html, "Child task")
  assert_contains(level_html, "Grand task")
  assert_not_contains(level_html, "Other task")

  let card_html =
    base
    |> with_scope(member_pool.PlanScopeCard, None, Some(1))
    |> render_people_with_cards(cards)
  assert_contains(card_html, "Root task")
  assert_contains(card_html, "Child task")
  assert_contains(card_html, "Grand task")
  assert_not_contains(card_html, "Other task")
}

pub fn people_view_search_matches_person_task_card_and_capability_test() {
  let cards = [make_card(1, None, "Payments")]
  let task =
    make_task(1, "Retry queue", 10, task_state.Taken)
    |> task_on_card(1, "Payments", card.Blue)
    |> task_with_type(5, "Bug")
  let workload_task =
    PersonWorkloadTask(
      ..task_to_workload_task(task),
      capability_name: Some("Backend"),
    )
  let person =
    PersonWorkload(
      ..available_person(10, "ana@example.com"),
      state: WorkloadReserved,
      reserved: [workload_task],
      summary: PersonWorkloadSummary(
        working_now_count: 0,
        reserved_count: 1,
        attention_count: 0,
      ),
    )
  let base =
    base_model()
    |> with_people_workload(remote.Loaded([person]))
    |> with_people_expanded(10)

  assert_contains(
    base |> with_people_search("ana") |> render_people_with_cards(cards),
    "ana@example.com",
  )
  assert_contains(
    base |> with_people_search("retry") |> render_people_with_cards(cards),
    "Retry queue",
  )
  assert_contains(
    base |> with_people_search("payments") |> render_people_with_cards(cards),
    "Payments",
  )
  assert_contains(
    base |> with_people_search("backend") |> render_people_with_cards(cards),
    "Retry queue",
  )
}

pub fn people_view_visibility_filters_work_attention_and_free_test() {
  let tasks = [
    make_task(1, "Active task", 10, task_state.Ongoing),
    make_task(2, "Blocked task", 11, task_state.Taken) |> blocked,
  ]
  let base =
    base_model()
    |> with_people_workload(
      remote.Loaded([
        person(10),
        person(11),
        person(12),
      ]),
    )
    |> with_people_emails([
      workload_email(10, "ana@example.com"),
      workload_email(11, "bob@example.com"),
      workload_email(12, "cora@example.com"),
    ])
    |> with_workload_tasks(tasks)

  let work_html =
    base
    |> with_people_filter(people_state.ShowWithWork)
    |> render_people
  assert_contains(work_html, "ana@example.com")
  assert_contains(work_html, "bob@example.com")
  assert_not_contains(work_html, "cora@example.com")

  let attention_html =
    base
    |> with_people_filter(people_state.ShowAttention)
    |> render_people
  assert_not_contains(attention_html, "ana@example.com")
  assert_contains(attention_html, "bob@example.com")
  assert_not_contains(attention_html, "cora@example.com")
  assert_contains(attention_html, "Blocked")

  let free_html =
    base
    |> with_people_filter(people_state.ShowFree)
    |> render_people
  assert_not_contains(free_html, "ana@example.com")
  assert_not_contains(free_html, "bob@example.com")
  assert_contains(free_html, "cora@example.com")
}

pub fn people_sort_orders_by_attention_name_and_reserved_test() {
  let people = [
    available_person(10, "ana@example.com"),
    workload_from_tasks(available_person(20, "bob@example.com"), [
      make_task(1, "Blocked task", 20, task_state.Taken) |> blocked,
    ]),
    workload_from_tasks(available_person(30, "cora@example.com"), [
      make_task(2, "Ongoing task", 30, task_state.Ongoing),
      make_task(3, "Extra task", 30, task_state.Taken),
    ]),
  ]

  let assert [
    PersonWorkload(email: "bob@example.com", ..),
    PersonWorkload(email: "cora@example.com", ..),
    PersonWorkload(email: "ana@example.com", ..),
  ] = people_state.sort_people(people, people_state.SortByAttention)

  let assert [
    PersonWorkload(email: "ana@example.com", ..),
    PersonWorkload(email: "bob@example.com", ..),
    PersonWorkload(email: "cora@example.com", ..),
  ] = people_state.sort_people(people, people_state.SortByName)

  let assert [
    PersonWorkload(email: "cora@example.com", ..),
    PersonWorkload(email: "bob@example.com", ..),
    PersonWorkload(email: "ana@example.com", ..),
  ] = people_state.sort_people(people, people_state.SortByReservedCount)
}

pub fn people_view_only_renders_open_action_for_other_people_test() {
  let model =
    base_model()
    |> with_people_workload(remote.Loaded([person(10)]))
    |> with_people_emails([workload_email(10, "ana@example.com")])
    |> with_workload_tasks([
      make_task(1, "Ongoing task", 10, task_state.Ongoing),
      make_task(2, "Reserved task", 10, task_state.Taken),
    ])
    |> with_people_expanded(10)

  let html = render_people(model)

  assert_contains(html, "Open task")
  assert_not_contains(html, "people-task-action-primary")
  assert_not_contains(html, "people-task-action-secondary")
  assert_not_contains(html, "btn-claim-mini")
  assert_not_contains(html, "btn-close")
  assert_not_contains(html, "task-actions")
  assert_not_contains(html, "kanban-card-delete-action")
  assert_not_contains(html, "plan-move")
}

pub fn people_view_renders_contextual_actions_for_current_user_test() {
  let model =
    base_model()
    |> with_current_user(10)
    |> with_people_workload(remote.Loaded([person(10)]))
    |> with_people_emails([workload_email(10, "ana@example.com")])
    |> with_workload_tasks([
      make_task(1, "Ongoing task", 10, task_state.Ongoing),
      make_task(2, "Reserved task", 10, task_state.Taken),
    ])
    |> with_people_expanded(10)

  let html = render_people(model)

  assert_contains(html, "Open task")
  assert_contains(html, ">Pause<")
  assert_contains(html, ">Close<")
  assert_contains(html, ">Start<")
  assert_contains(html, ">Release<")
  assert_contains(html, "people-task-action-primary")
  assert_contains(html, "people-task-action-secondary")
}

pub fn people_view_card_scope_without_work_uses_empty_state_test() {
  let cards = [make_card(1, None, "Empty Initiative")]
  let model =
    base_model()
    |> with_people_workload(remote.Loaded([person(10)]))
    |> with_people_emails([workload_email(10, "ana@example.com")])
    |> with_workload_tasks([])
    |> with_scope(member_pool.PlanScopeCard, None, Some(1))

  let html = render_people_with_cards(model, cards)

  assert_contains(html, "No reserved work in this card scope")
  assert_contains(html, "people-card-scope-no-work")
  assert_not_contains(html, "data-testid=\"people-view\"")
}
