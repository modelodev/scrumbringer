import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should
import lustre/element

import domain/api_error.{ApiError}
import domain/org.{type OrgUser, OrgUser}
import domain/org_role
import domain/project.{type ProjectMember, ProjectMember}
import domain/project_role
import domain/remote
import domain/task.{type Task, Task}
import domain/task_state
import domain/task_status
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/people/state as people_state
import scrumbringer_client/features/people/view as people_view
import scrumbringer_client/i18n/locale

fn make_task(
  id: Int,
  title: String,
  user_id: Int,
  mode: task_status.ClaimedState,
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
    status: task_state.to_status(state),
    work_state: task_state.to_work_state(state),
    created_by: 1,
    created_at: "2026-02-01T09:00:00Z",
    version: 1,
    card_id: None,
    card_title: None,
    card_color: None,
    has_new_notes: False,
    blocked_count: 0,
    dependencies: [],
  )
}

fn make_taken_task_with_ongoing_by(id: Int, title: String, user_id: Int) -> Task {
  let task = make_task(id, title, user_id, task_status.Taken)
  Task(..task, ongoing_by: Some(task_status.OngoingBy(user_id: user_id)))
}

fn base_model() -> client_state.Model {
  client_state.default_model()
  |> client_state.update_ui(fn(ui) { ui_state.UiModel(..ui, locale: locale.En) })
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

fn count_occurrences(haystack: String, needle: String) -> Int {
  case needle == "" {
    True -> 0
    False -> list.length(string.split(haystack, needle)) - 1
  }
}

pub fn people_view_loading_state_test() {
  let model = base_model() |> with_people_roster(remote.Loading)
  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "Loading people...") |> should.be_true
}

pub fn people_view_error_state_test() {
  let model =
    base_model()
    |> with_people_roster(
      remote.Failed(ApiError(status: 500, code: "E_PEOPLE", message: "boom")),
    )

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "Could not load people") |> should.be_true
  string.contains(html, "people-error") |> should.be_true
}

pub fn people_view_empty_roster_state_test() {
  let model = base_model() |> with_people_roster(remote.Loaded([]))
  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "No members in this project") |> should.be_true
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
        pool: member_pool.Model(..pool, member_filters_q: "zzz"),
      )
    })

  let html = people_view.view(model) |> element.to_document_string
  string.contains(html, "No people match your search") |> should.be_true
}

pub fn people_view_availability_rules_test() {
  let tasks = [
    make_task(1, "Active task", 10, task_status.Ongoing),
    make_task(2, "Claimed task", 11, task_status.Taken),
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

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "Working") |> should.be_true
  string.contains(html, "Busy") |> should.be_true
  string.contains(html, "Free") |> should.be_true
}

pub fn people_view_availability_prefers_ongoing_by_test() {
  let tasks = [make_taken_task_with_ongoing_by(1, "Active task", 10)]

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

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "Working") |> should.be_true
  string.contains(html, "Busy") |> should.be_false
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
    |> with_tasks([make_task(1, "Active task", 10, task_status.Ongoing)])
    |> with_people_expanded(10)

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "aria-expanded=\"true\"") |> should.be_true
  string.contains(html, "aria-controls=\"person-details-10\"") |> should.be_true
  string.contains(html, "Collapse status for ana@example.com") |> should.be_true
  string.contains(html, "Active") |> should.be_true
  string.contains(html, "Claimed") |> should.be_true
  string.contains(html, "task-item-content") |> should.be_true
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

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "<ul") |> should.be_true
  string.contains(html, "<li") |> should.be_true
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

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "<button") |> should.be_true
  string.contains(html, "people-row-toggle") |> should.be_true
  string.contains(html, "aria-expanded=\"false\"") |> should.be_true
  string.contains(html, "aria-label=\"Expand status for ana@example.com\"")
  |> should.be_true
}

pub fn people_view_expanded_separates_active_and_claimed_tasks_test() {
  let tasks = [
    make_task(1, "Ongoing one", 10, task_status.Ongoing),
    make_taken_task_with_ongoing_by(2, "Ongoing via session", 10),
    make_task(3, "Claimed parked", 10, task_status.Taken),
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

  let html = people_view.view(model) |> element.to_document_string

  string.contains(html, "Active") |> should.be_true
  string.contains(html, "Claimed") |> should.be_true

  count_occurrences(html, "Ongoing one") |> should.equal(1)
  count_occurrences(html, "Ongoing via session") |> should.equal(1)
  count_occurrences(html, "Claimed parked") |> should.equal(1)
}
