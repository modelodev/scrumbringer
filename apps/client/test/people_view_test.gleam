import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/effect
import lustre/element

import domain/api_error.{ApiError}
import domain/capability.{type Capability, Capability}
import domain/card
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role
import domain/remote
import domain/task.{
  type Task, type WorkSessionsPayload, Task, WorkSession, WorkSessionsPayload,
}
import domain/task/state as task_state
import domain/task_type.{type TaskType, TaskType, TaskTypeInline}
import domain/user.{User}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/capabilities as admin_capabilities
import scrumbringer_client/client_state/admin/members as admin_members
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

fn project_member(user_id: Int, claimed_count: Int) -> ProjectMember {
  ProjectMember(
    user_id: user_id,
    role: project_role.Member,
    created_at: "",
    claimed_count: claimed_count,
  )
}

fn org_user(user_id: Int, email: String) -> OrgUser {
  OrgUser(id: user_id, email: email, org_role: org_role.Member, created_at: "")
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
    people_roster: model.member.pool.people_roster,
    member_tasks: model.member.pool.member_tasks,
    task_types: model.member.pool.member_task_types,
    capabilities: model.admin.capabilities.capabilities,
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
    org_users: model.admin.members.org_users_cache,
    people_expansions: model.member.pool.people_expansions,
    search_query: model.member.pool.member_people_search_query,
    visibility_filter: model.member.pool.member_people_filter,
    sort: model.member.pool.member_people_sort,
    task_card_color: fn(task) { task.card_color },
    on_scope_kind_change: fn(_value) { 0 },
    on_scope_depth_change: fn(_value) { 0 },
    on_scope_card_change: fn(_value) { 0 },
    on_scope_card_search_change: fn(_value) { 0 },
    on_search_change: fn(_value) { 0 },
    on_visibility_filter_change: fn(_value) { 0 },
    on_sort_change: fn(_value) { 0 },
    on_person_toggle: fn(user_id) { user_id },
    on_task_click: fn(task_id) { task_id },
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

fn with_people_roster(
  model: client_state.Model,
  roster: remote.Remote(List(ProjectMember)),
) -> client_state.Model {
  client_state.update_member(model, fn(member) {
    let pool = member.pool
    member_state.MemberModel(
      ..member,
      pool: member_pool.Model(..pool, people_roster: roster),
    )
  })
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

fn with_tasks(
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

fn with_work_catalog(
  model: client_state.Model,
  task_types: List(TaskType),
  capabilities: List(Capability),
) -> client_state.Model {
  let with_task_types =
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_task_types: remote.Loaded(task_types),
        ),
      )
    })

  client_state.update_admin(with_task_types, fn(admin) {
    let capabilities_model = admin.capabilities
    admin_state.AdminModel(
      ..admin,
      capabilities: admin_capabilities.Model(
        ..capabilities_model,
        capabilities: remote.Loaded(capabilities),
      ),
    )
  })
}

fn with_org_users(
  model: client_state.Model,
  users: List(OrgUser),
) -> client_state.Model {
  client_state.update_admin(model, fn(admin) {
    let members = admin.members
    admin_state.AdminModel(
      ..admin,
      members: admin_members.Model(
        ..members,
        org_users_cache: remote.Loaded(users),
      ),
    )
  })
}

pub fn people_view_loading_state_test() {
  let model = base_model() |> with_people_roster(remote.Loading)
  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Loading people...")
}

pub fn people_view_error_state_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Failed(ApiError(status: 500, code: "E_PEOPLE", message: "boom")),
    )

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Could not load people")
  assert_contains(html, "people-error")
}

pub fn people_view_empty_roster_state_test() {
  let model = base_model() |> with_people_roster(remote.Loaded([]))
  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "No members in this project")
}

pub fn people_view_no_results_state_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 0,
        ),
      ]),
    )
    |> with_tasks([])
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "alice@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
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
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 1,
        ),
        ProjectMember(
          user_id: 11,
          role: project_role.Member,
          created_at: "",
          claimed_count: 1,
        ),
        ProjectMember(
          user_id: 12,
          role: project_role.Member,
          created_at: "",
          claimed_count: 0,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
      OrgUser(
        id: 11,
        email: "bob@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
      OrgUser(
        id: 12,
        email: "cora@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks(tasks)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Working now")
  assert_contains(html, "With claimed work")
  assert_contains(html, "Available")
  assert_contains(html, "Person")
  assert_contains(html, "State")
  assert_not_contains(html, "0 ongoing")
}

pub fn people_view_availability_prefers_canonical_ongoing_state_test() {
  let tasks = [make_task(1, "Active task", 10, task_state.Ongoing)]

  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 1,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks(tasks)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Working now")
  assert_contains(html, "people-roster-row-working")
  assert_not_contains(html, "people-roster-row-claimed")
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
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 2,
        ),
        ProjectMember(
          user_id: 11,
          role: project_role.Member,
          created_at: "",
          claimed_count: 4,
        ),
        ProjectMember(
          user_id: 12,
          role: project_role.Member,
          created_at: "",
          claimed_count: 0,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
      OrgUser(
        id: 11,
        email: "bob@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
      OrgUser(
        id: 12,
        email: "cora@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks(tasks)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(
    html,
    "Operational team state by owned work, blockers, and availability.",
  )
  assert_contains(html, "work-surface-chip success")
  assert_contains(html, ">Available<")
  assert_contains(html, "work-surface-chip claimed")
  assert_contains(html, ">With work<")
  assert_contains(html, "work-surface-chip ongoing")
  assert_contains(html, ">Working now<")
  assert_contains(html, "work-surface-chip blocked")
  assert_contains(html, ">Attention<")
  assert_contains(html, "With claimed work · 1")
  assert_contains(html, "Next: Review logs")
  assert_contains(html, "Checkout")
  assert_contains(html, "Observability")
  assert_contains(html, "High load")
  assert_not_contains(html, "0 ongoing")
}

pub fn people_view_expanded_keeps_card_context_without_card_groups_test() {
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
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 3,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks(tasks)
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Checkout")
  assert_contains(html, "Onboarding")
  assert_contains(html, "Billing")
  assert_contains(html, "Working now")
  assert_contains(html, "Claimed")
  assert_contains(html, "task-card-identity-swatch")
  assert_contains(html, "role=\"img\"")
  assert_contains(html, "aria-label=\"Checkout\"")
  assert_not_contains(html, "people-task-group")
  assert_not_contains(html, "people-task-card-meta")
}

pub fn people_view_expanded_free_person_reads_as_available_capacity_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 0,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks([])
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "No work in progress")
  assert_contains(html, "No claimed work")
  assert_contains(html, "Can pull from Pool")
}

pub fn people_view_reflects_work_session_started_without_reload_test() {
  let model =
    base_model()
    |> with_current_user(1)
    |> with_people_roster(remote.Loaded([project_member(1, 1)]))
    |> with_org_users([org_user(1, "admin@example.com")])
    |> with_tasks([
      make_task(89, "Facilitate rollout sync", 1, task_state.Taken),
    ])
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
  assert_not_contains(html, "Available capacity")
  assert_not_contains(html, "0 ongoing")
}

pub fn people_view_expanded_row_accessibility_and_sections_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 1,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks([make_task(1, "Active task", 10, task_state.Ongoing)])
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "aria-expanded=\"true\"")
  assert_contains(html, "aria-controls=\"person-details-10\"")
  assert_contains(html, "Collapse status for ana@example.com")
  assert_contains(html, "Active")
  assert_contains(html, "Claimed")
  assert_contains(html, "task-item-content")
}

pub fn people_view_uses_list_semantics_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 0,
        ),
      ]),
    )
    |> with_tasks([])

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "<ul")
  assert_contains(html, "<li")
}

pub fn people_view_toggle_is_keyboard_accessible_button_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 0,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks([])

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "<button")
  assert_contains(html, "people-row-toggle")
  assert_contains(html, "aria-expanded=\"false\"")
  assert_contains(html, "aria-label=\"Expand status for ana@example.com\"")
}

pub fn people_view_expanded_separates_active_and_claimed_tasks_test() {
  let tasks = [
    make_task(1, "Ongoing one", 10, task_state.Ongoing),
    make_task(2, "Ongoing via canonical state", 10, task_state.Ongoing),
    make_task(3, "Claimed parked", 10, task_state.Taken),
  ]

  let model =
    base_model()
    |> with_people_roster(
      remote.Loaded([
        ProjectMember(
          user_id: 10,
          role: project_role.Member,
          created_at: "",
          claimed_count: 3,
        ),
      ]),
    )
    |> with_org_users([
      OrgUser(
        id: 10,
        email: "ana@example.com",
        org_role: org_role.Member,
        created_at: "",
      ),
    ])
    |> with_tasks(tasks)
    |> with_people_expanded(10)

  let html =
    people_view.view(people_config(model)) |> element.to_document_string

  assert_contains(html, "Working now")
  assert_contains(html, "Claimed, not started")

  assert_contains(html, "Ongoing one")
  assert_contains(html, "Ongoing via canonical state")
  assert_contains(html, "Claimed parked")
}

pub fn people_view_renders_header_scope_controls_and_body_test() {
  let model =
    base_model()
    |> with_people_roster(remote.Loaded([project_member(10, 0)]))
    |> with_org_users([org_user(10, "ana@example.com")])
    |> with_tasks([])

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
    |> with_people_roster(remote.Loaded([project_member(10, 4)]))
    |> with_org_users([org_user(10, "ana@example.com")])
    |> with_tasks(tasks)
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
  let base =
    base_model()
    |> with_people_roster(remote.Loaded([project_member(10, 1)]))
    |> with_org_users([org_user(10, "ana@example.com")])
    |> with_tasks([task])
    |> with_people_expanded(10)
    |> with_work_catalog(
      [
        TaskType(
          id: 5,
          name: "Bug",
          icon: "bug-ant",
          capability_id: Some(7),
          tasks_count: 1,
        ),
      ],
      [Capability(id: 7, name: "Backend")],
    )

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
    |> with_people_roster(
      remote.Loaded([
        project_member(10, 1),
        project_member(11, 1),
        project_member(12, 0),
      ]),
    )
    |> with_org_users([
      org_user(10, "ana@example.com"),
      org_user(11, "bob@example.com"),
      org_user(12, "cora@example.com"),
    ])
    |> with_tasks(tasks)

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

pub fn people_sort_orders_by_attention_name_and_claimed_test() {
  let tasks = [
    make_task(1, "Blocked task", 20, task_state.Taken) |> blocked,
    make_task(2, "Ongoing task", 30, task_state.Ongoing),
    make_task(3, "Extra task", 30, task_state.Taken),
  ]
  let assert [blocked_task, ongoing_task, extra_task] = tasks
  let people = [
    people_state.derive_status(10, "ana@example.com", []),
    people_state.derive_status(20, "bob@example.com", [blocked_task]),
    people_state.derive_status(30, "cora@example.com", [
      ongoing_task,
      extra_task,
    ]),
  ]

  let assert [
    people_state.PersonStatus(label: "bob@example.com", ..),
    people_state.PersonStatus(label: "cora@example.com", ..),
    people_state.PersonStatus(label: "ana@example.com", ..),
  ] = people_state.sort_people(people, people_state.SortByAttention)

  let assert [
    people_state.PersonStatus(label: "ana@example.com", ..),
    people_state.PersonStatus(label: "bob@example.com", ..),
    people_state.PersonStatus(label: "cora@example.com", ..),
  ] = people_state.sort_people(people, people_state.SortByName)

  let assert [
    people_state.PersonStatus(label: "cora@example.com", ..),
    people_state.PersonStatus(label: "bob@example.com", ..),
    people_state.PersonStatus(label: "ana@example.com", ..),
  ] = people_state.sort_people(people, people_state.SortByClaimedCount)
}

pub fn people_view_does_not_render_command_actions_test() {
  let model =
    base_model()
    |> with_people_roster(remote.Loaded([project_member(10, 2)]))
    |> with_org_users([org_user(10, "ana@example.com")])
    |> with_tasks([
      make_task(1, "Ongoing task", 10, task_state.Ongoing),
      make_task(2, "Claimed task", 10, task_state.Taken),
    ])
    |> with_people_expanded(10)

  let html = render_people(model)

  assert_not_contains(html, "btn-claim-mini")
  assert_not_contains(html, "btn-close")
  assert_not_contains(html, "task-actions")
  assert_not_contains(html, "kanban-card-delete-action")
  assert_not_contains(html, "plan-move")
}

pub fn people_view_card_scope_without_work_uses_empty_state_test() {
  let cards = [make_card(1, None, "Empty Initiative")]
  let model =
    base_model()
    |> with_people_roster(remote.Loaded([project_member(10, 0)]))
    |> with_org_users([org_user(10, "ana@example.com")])
    |> with_tasks([])
    |> with_scope(member_pool.PlanScopeCard, None, Some(1))

  let html = render_people_with_cards(model, cards)

  assert_contains(html, "No claimed work in this card scope")
  assert_contains(html, "people-card-scope-no-work")
  assert_not_contains(html, "data-testid=\"people-view\"")
}
