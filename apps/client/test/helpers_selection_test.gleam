import domain/project.{Project}
import domain/project_role.{Manager}
import domain/remote.{Loaded}
import domain/task.{WorkSession, WorkSessionsPayload}
import gleam/option as opt
import gleeunit/should
import scrumbringer_client/client_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/metrics as member_metrics
import scrumbringer_client/helpers/selection as helpers_selection

pub fn active_projects_returns_empty_when_not_loaded_test() {
  let model = client_state.default_model()
  helpers_selection.active_projects(model)
  |> should.equal([])
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

  helpers_selection.selected_project(model)
  |> should.equal(opt.Some(project))
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
  helpers_selection.ensure_selected_project(opt.Some(99), [project])
  |> should.equal(opt.Some(10))
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

  helpers_selection.now_working_active_task_id(model)
  |> should.equal(opt.Some(5))
}
