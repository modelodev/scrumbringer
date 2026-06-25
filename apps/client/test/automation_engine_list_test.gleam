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
import scrumbringer_client/features/automations/focus_target as automation_focus
import scrumbringer_client/i18n/locale

fn assert_contains(html: String, fragment: String) {
  let assert True = string.contains(html, fragment)
}

fn assert_not_contains(html: String, fragment: String) {
  let assert False = string.contains(html, fragment)
}

fn engine(id: Int, name: String, active: Bool) -> Workflow {
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
    engines: Loaded([engine(3, "Release automation", True)]),
    selected_engine_id: opt.None,
    selected_rule_id: opt.None,
    search_query: "",
    status_filter: "all",
    dialog_mode: opt.None,
    form_name: "",
    form_description: "",
    form_active: True,
    form_submitting: False,
    form_error: opt.None,
    on_create_clicked: "create",
    on_search_changed: fn(value) { "search-" <> value },
    on_status_filter_changed: fn(value) { "status-" <> value },
    on_rules_clicked: fn(id) { "rules-" <> int.to_string(id) },
    on_edit_clicked: fn(engine) { "edit-" <> engine.name },
    on_delete_clicked: fn(engine) { "delete-" <> engine.name },
    on_name_changed: fn(value) { "name-" <> value },
    on_description_changed: fn(value) { "description-" <> value },
    on_active_changed: fn(value) {
      case value {
        True -> "active-true"
        False -> "active-false"
      }
    },
    on_submitted: fn(project_id) {
      case project_id {
        opt.Some(id) -> "submit-" <> int.to_string(id)
        opt.None -> "submit-none"
      }
    },
    on_delete_confirmed: "delete-confirmed",
    on_closed: "closed",
  )
}

pub fn automation_engine_list_renders_operational_rows_test() {
  let html =
    engine_list.view(config())
    |> element.to_document_string

  assert_contains(html, "Engines - Roadmap")
  assert_contains(html, "filter-bar automation-engines-filters")
  assert_contains(html, "data-testid=\"automation-engines-filter-bar\"")
  assert_contains(html, "data-testid=\"automation-engine-search\"")
  assert_contains(html, "data-testid=\"automation-engine-status-filter\"")
  assert_contains(html, "data-testid=\"automation-engine-row\"")
  assert_contains(html, "Release automation")
  assert_contains(html, "workflow-rules-btn")
  assert_contains(html, automation_focus.engine_edit_trigger_id(3))
  assert_contains(html, automation_focus.engine_delete_trigger_id(3))
  assert_not_contains(html, "inert")
  assert_not_contains(html, "section-header")
  assert_not_contains(html, "info-callout-link")
}

pub fn automation_engine_list_filters_by_status_test() {
  let html =
    engine_list.view(
      engine_list.Config(
        ..config(),
        engines: Loaded([
          engine(3, "Release automation", True),
          engine(4, "Paused intake", False),
        ]),
        status_filter: "paused",
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Paused intake")
  assert_contains(html, "Paused")
  assert_not_contains(html, "Release automation")
}

pub fn automation_engine_list_marks_selected_engine_test() {
  let html =
    engine_list.view(
      engine_list.Config(..config(), selected_engine_id: opt.Some(3)),
    )
    |> element.to_document_string

  assert_contains(html, "data-testid=\"automation-engine-row\"")
  assert_contains(html, "data-selected=\"true\"")
  assert_contains(html, "automation-engine-row is-selected")
}

pub fn automation_engine_list_renders_feature_local_create_panel_test() {
  let html =
    engine_list.view(
      engine_list.Config(
        ..config(),
        dialog_mode: opt.Some(admin_workflows.EngineDialogCreate),
        form_name: "Release automation",
        form_description: "Creates follow-up work",
      ),
    )
    |> element.to_document_string

  assert_contains(html, "automation-engine-panel")
  assert_contains(html, "inert")
  assert_contains(html, "aria-hidden=\"true\"")
  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"automation-engine-panel-title\"")
  assert_contains(html, "id=\"automation-engine-panel-title\"")
  assert_contains(html, "data-testid=\"automation-engine-name\"")
  assert_contains(html, "autofocus")
  assert_not_contains(
    html,
    "id=\"automation-engine-panel-title\" tabindex=\"-1\"",
  )
  assert_contains(html, "aria-keyshortcuts=\"Escape\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "Create engine")
  assert_contains(html, "data-testid=\"automation-engine-name\"")
  assert_contains(html, "aria-label=\"Name\"")
  assert_contains(html, "Release automation")
  assert_contains(html, "data-testid=\"automation-engine-description\"")
  assert_contains(html, "aria-label=\"Description\"")
  assert_contains(html, "Creates follow-up work")
  assert_contains(html, "data-testid=\"automation-engine-active\"")
  assert_not_contains(html, "workflow-crud-dialog")
}

pub fn automation_engine_list_localizes_panel_actions_test() {
  let html =
    engine_list.view(
      engine_list.Config(
        ..config(),
        locale: locale.Es,
        dialog_mode: opt.Some(
          admin_workflows.EngineDialogEdit(engine(3, "Release automation", True)),
        ),
        form_name: "Release automation",
        form_description: "Creates follow-up work",
        form_submitting: True,
      ),
    )
    |> element.to_document_string

  assert_contains(html, "Editar motor")
  assert_contains(html, "aria-label=\"Cerrar\"")
  assert_contains(html, ">Cancelar<")
  assert_contains(html, "Guardando")
  assert_not_contains(html, "aria-label=\"Close\"")
  assert_not_contains(html, ">Cancel<")
  assert_not_contains(html, "Saving...")
}

pub fn automation_engine_list_renders_feature_local_delete_panel_test() {
  let html =
    engine_list.view(
      engine_list.Config(
        ..config(),
        dialog_mode: opt.Some(
          admin_workflows.EngineDialogDelete(engine(
            3,
            "Release automation",
            True,
          )),
        ),
      ),
    )
    |> element.to_document_string

  assert_contains(html, "automation-engine-panel")
  assert_contains(html, "inert")
  assert_contains(html, "aria-hidden=\"true\"")
  assert_contains(html, "role=\"dialog\"")
  assert_contains(html, "aria-modal=\"true\"")
  assert_contains(html, "aria-labelledby=\"automation-engine-panel-title\"")
  assert_contains(html, "id=\"automation-engine-panel-title\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "autofocus")
  assert_contains(html, "aria-keyshortcuts=\"Escape\"")
  assert_contains(html, "tabindex=\"-1\"")
  assert_contains(html, "Delete engine")
  assert_contains(html, "Delete engine &quot;Release automation&quot;?")
  assert_not_contains(html, "workflow-crud-dialog")
}
