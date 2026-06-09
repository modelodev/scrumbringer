import domain/project.{Project}
import domain/project_role.{Manager}
import domain/remote.{Loaded}
import domain/task.{WorkSession, WorkSessionsPayload}
import gleam/option as opt
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/client_state/selectors as state_selectors

pub fn active_projects_returns_empty_when_not_loaded_test() {
  let model = client_state.default_model()
  let assert [] = state_selectors.active_projects(model)
}

pub fn selected_project_returns_selected_project_test() {
  let project =
    Project(
      id: 1,
      name: "Alpha",
      my_role: Manager,
      created_at: "2026-01-01",
      members_count: 1,
    )
  let model =
    client_state.default_model()
    |> client_state.update_core(fn(core) {
      client_state.CoreModel(
        ..core,
        selected_project_id: opt.Some(1),
        projects: Loaded([project]),
      )
    })

  let assert True = state_selectors.selected_project(model) == opt.Some(project)
}

pub fn ensure_selected_project_picks_first_when_missing_test() {
  let project =
    Project(
      id: 10,
      name: "Alpha",
      my_role: Manager,
      created_at: "2026-01-01",
      members_count: 1,
    )
  let assert opt.Some(10) =
    state_selectors.ensure_selected_project(opt.Some(99), [project])
}

pub fn now_working_active_task_id_from_sessions_test() {
  let session =
    WorkSession(task_id: 5, started_at: "2026-01-01", accumulated_s: 0)
  let payload =
    WorkSessionsPayload(active_sessions: [session], as_of: "2026-01-01")
  let model =
    client_state.default_model()
    |> client_state.update_member(fn(member) {
      let metrics = member.metrics

      member_state.MemberModel(
        ..member,
        metrics: member_metrics.Model(
          ..metrics,
          member_work_sessions: Loaded(payload),
        ),
      )
    })

  let assert opt.Some(5) = state_selectors.now_working_active_task_id(model)
}
