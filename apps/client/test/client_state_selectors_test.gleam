import domain/org_role
import domain/project.{type Project, Project}
import domain/project_role
import domain/remote.{Loaded}
import domain/user.{type User, User}
import gleam/option as opt
import scrumbringer_client/client_state.{
  type Model, CoreModel, Model, default_model, update_core,
}
import scrumbringer_client/client_state/selectors
import scrumbringer_client/permissions

fn current_user() -> User {
  User(
    id: 1,
    email: "lead@example.com",
    org_id: 1,
    org_role: org_role.Member,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn managed_project() -> Project {
  Project(
    id: 7,
    name: "Roadmap",
    my_role: project_role.Manager,
    created_at: "2026-01-01T00:00:00Z",
    members_count: 3,
    card_depth_names: [],
    healthy_pool_limit: 20,
  )
}

fn admin_model(section: permissions.AdminSection) -> Model {
  update_core(default_model(), fn(core) {
    CoreModel(
      ..core,
      user: opt.Some(current_user()),
      projects: Loaded([managed_project()]),
      selected_project_id: opt.Some(7),
      active_section: section,
    )
  })
}

pub fn ensure_default_section_keeps_internal_template_mode_test() {
  let next =
    selectors.ensure_default_section(admin_model(permissions.TaskTemplates))

  let Model(core: core, ..) = next
  let CoreModel(active_section: active_section, ..) = core

  let assert permissions.TaskTemplates = active_section
}

pub fn ensure_default_section_keeps_internal_execution_mode_test() {
  let next =
    selectors.ensure_default_section(admin_model(permissions.RuleMetrics))

  let Model(core: core, ..) = next
  let CoreModel(active_section: active_section, ..) = core

  let assert permissions.RuleMetrics = active_section
}
