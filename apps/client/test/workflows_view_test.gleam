import gleam/int
import gleam/option as opt
import gleam/string
import lustre/element

import domain/project.{type Project, Project}
import domain/project_role
import domain/remote.{Loaded}
import domain/workflow.{type Workflow, Workflow}
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/admin/views/workflows
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
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
  )
}

fn config() -> workflows.Config(String) {
  workflows.Config(
    locale: locale.En,
    selected_project: opt.Some(selected_project()),
    selected_project_id: opt.Some(7),
    selected_rules_view: opt.None,
    workflows: Loaded([workflow(3, "Release automation", True)]),
    dialog_mode: opt.None,
    on_create_clicked: "create",
    on_rules_clicked: fn(id) { "rules-" <> int.to_string(id) },
    on_edit_clicked: fn(workflow) { "edit-" <> workflow.name },
    on_delete_clicked: fn(workflow) { "delete-" <> workflow.name },
    on_created: fn(workflow) { "created-" <> workflow.name },
    on_updated: fn(workflow) { "updated-" <> workflow.name },
    on_deleted: fn(id) { "deleted-" <> int.to_string(id) },
    on_closed: "closed",
  )
}

pub fn workflows_view_renders_list_from_config_without_root_model_test() {
  let html =
    workflows.view_workflows(config())
    |> element.to_document_string

  assert_contains(html, "Workflows - Roadmap")
  assert_contains(html, "Create Workflow")
  assert_contains(html, "Release automation")
  assert_contains(html, "workflow-rules-btn")
}

pub fn workflows_view_renders_empty_project_state_without_root_model_test() {
  let html =
    workflows.view_workflows(
      workflows.Config(..config(), selected_project: opt.None),
    )
    |> element.to_document_string

  assert_contains(html, "Select a project to manage workflows")
}

pub fn workflows_view_renders_crud_dialog_from_config_without_root_model_test() {
  let html =
    workflows.view_workflows(
      workflows.Config(
        ..config(),
        dialog_mode: opt.Some(state_types.WorkflowDialogCreate),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "workflow-crud-dialog")
  assert_contains(html, "locale=\"en\"")
  assert_contains(html, "project-id=\"7\"")
  assert_contains(html, "mode=\"create\"")
}
