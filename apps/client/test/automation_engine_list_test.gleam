import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/project.{type Project, Project}
import domain/project_role
import domain/remote.{Loaded}
import domain/workflow.{type Workflow, Workflow}
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/features/automations/engine_list
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn workflow(id: Int, name: String, active: Bool) -> Workflow {
  Workflow(
    id: id,
    org_id: 1,
    project_id: opt.Some(7),
    name: name,
    description: opt.None,
    active: active,
    rule_count: 2,
    created_by: 1,
    created_at: "2026-01-01T00:00:00Z",
  )
}

fn selected_project() -> Project {
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

fn config() -> engine_list.Config(String) {
  engine_list.Config(
    locale: locale.En,
    selected_project: opt.Some(selected_project()),
    selected_project_id: opt.Some(7),
    selected_rules_view: opt.None,
    workflows: Loaded([workflow(3, "Release automation", True)]),
    search_query: "",
    status_filter: "all",
    dialog_mode: opt.None,
    on_create_clicked: "create",
    on_search_changed: fn(value) { "search-" <> value },
    on_status_filter_changed: fn(value) { "status-" <> value },
    on_rules_clicked: fn(id) { "rules-" <> int.to_string(id) },
    on_edit_clicked: fn(workflow) { "edit-" <> workflow.name },
    on_delete_clicked: fn(workflow) { "delete-" <> workflow.name },
    on_created: fn(workflow) { "created-" <> workflow.name },
    on_updated: fn(workflow) { "updated-" <> workflow.name },
    on_deleted: fn(id) { "deleted-" <> int.to_string(id) },
    on_closed: "closed",
  )
}

pub fn automation_engine_list_renders_operational_rows_test() {
  let html =
    engine_list.view(config())
    |> element.to_document_string

  assert_contains(html, "Engines - Roadmap")
  assert_contains(html, "Create engine")
  assert_contains(html, "filter-bar automation-engines-filters")
  assert_contains(html, "data-testid=\"automation-engines-filter-bar\"")
  assert_contains(html, "data-testid=\"automation-engine-search\"")
  assert_contains(html, "data-testid=\"automation-engine-status-filter\"")
  assert_contains(html, "data-testid=\"automation-engine-row\"")
  assert_contains(html, "Release automation")
  assert_contains(html, "workflow-rules-btn")
  assert_not_contains(html, "section-header")
  assert_not_contains(html, "info-callout-link")
}

pub fn automation_engine_list_filters_by_status_test() {
  let html =
    engine_list.view(
      engine_list.Config(
        ..config(),
        workflows: Loaded([
          workflow(3, "Release automation", True),
          workflow(4, "Paused intake", False),
        ]),
        status_filter: "paused",
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Paused intake")
  assert_contains(html, "Paused")
  assert_not_contains(html, "Release automation")
}

pub fn automation_engine_list_renders_crud_dialog_test() {
  let html =
    engine_list.view(
      engine_list.Config(
        ..config(),
        dialog_mode: opt.Some(admin_workflows.WorkflowDialogCreate),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "workflow-crud-dialog")
  assert_contains(html, "locale=\"en\"")
  assert_contains(html, "project-id=\"7\"")
  assert_contains(html, "mode=\"create\"")
}
