//// Admin workflows view.
////
//// ## Mission
////
//// Render the workflow admin entry view and workflow dialog component.
////
//// ## Responsibilities
////
//// - Workflows list
//// - Selected-workflow dispatch to rules view
//// - Workflow CRUD custom element wiring
////
//// ## Relations
////
//// - **features/admin/view.gleam**: Delegates to this module
//// - **features/admin/update.gleam**: Handles workflow-related messages

import gleam/int
import gleam/json
import gleam/option as opt

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{a, div, span, text}
import lustre/event

import gleam/dynamic/decode

import domain/project.{type Project}
import domain/remote.{type Remote}
import domain/workflow.{type Workflow}
import domain/workflow/workflow_codec

import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale, serialize}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/info_callout
import scrumbringer_client/ui/section_header

// =============================================================================
// Workflows Views
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    selected_project_id: opt.Option(Int),
    selected_rules_view: opt.Option(Element(msg)),
    workflows: Remote(List(Workflow)),
    dialog_mode: opt.Option(admin_workflows.WorkflowDialogMode),
    on_create_clicked: msg,
    on_rules_clicked: fn(Int) -> msg,
    on_edit_clicked: fn(Workflow) -> msg,
    on_delete_clicked: fn(Workflow) -> msg,
    on_created: fn(Workflow) -> msg,
    on_updated: fn(Workflow) -> msg,
    on_deleted: fn(Int) -> msg,
    on_closed: msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

/// Workflows management view.
pub fn view_workflows(config: Config(msg)) -> Element(msg) {
  // If we're viewing rules for a specific workflow, show rules view
  case config.selected_rules_view {
    opt.Some(rules_view) -> rules_view
    opt.None -> view_workflows_list(config)
  }
}

fn view_workflows_list(config: Config(msg)) -> Element(msg) {
  // Workflows are project-scoped, so require a project to be selected (AC22)
  case config.selected_project {
    opt.None ->
      div([attribute.class("section")], [
        div([attribute.class("empty")], [
          text(t(config, i18n_text.SelectProjectForWorkflows)),
        ]),
      ])
    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.Workflows,
          t(config, i18n_text.WorkflowsProjectTitle(project.name)),
          dialog.add_button_with_locale(
            config.locale,
            i18n_text.CreateWorkflow,
            config.on_create_clicked,
          ),
        ),
        // Story 4.9 AC21: Contextual hint with link to Templates
        view_rules_hint(config),
        // Project workflows table (AC23)
        view_workflows_table(config, config.workflows),
        // Workflow CRUD dialog component (handles create, edit, delete)
        view_workflow_crud_dialog(config),
      ])
  }
}

/// Story 4.9 AC21: Contextual hint linking Rules to Templates.
fn view_rules_hint(config: Config(msg)) -> Element(msg) {
  info_callout.view_with_content(
    opt.None,
    span([], [
      text(t(config, i18n_text.RulesHintTemplates)),
      a(
        [
          attribute.href("/config/templates"),
          attribute.class("info-callout-link"),
        ],
        [
          text(t(config, i18n_text.RulesHintTemplatesLink) <> " \u{2192}"),
        ],
      ),
    ]),
  )
}

// Justification: nested case keeps dialog mode and project scoping logic colocated.

/// Render the workflow-crud-dialog Lustre component.
fn view_workflow_crud_dialog(config: Config(msg)) -> Element(msg) {
  case config.dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, workflow_json, project_id_attr) = case mode {
        admin_workflows.WorkflowDialogCreate ->
          create_dialog_parts(config.selected_project_id)
        admin_workflows.WorkflowDialogEdit(workflow) ->
          entity_dialog_parts(
            "edit",
            "workflow",
            workflow_to_property_json(workflow, "edit"),
            workflow.project_id,
          )
        admin_workflows.WorkflowDialogDelete(workflow) ->
          entity_dialog_parts(
            "delete",
            "workflow",
            workflow_to_property_json(workflow, "delete"),
            workflow.project_id,
          )
      }

      element.element(
        "workflow-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", serialize(config.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          // Property for workflow data (edit/delete modes)
          workflow_json,
          // Event listeners for component events
          event.on("workflow-created", decode_workflow_created_event(config)),
          event.on("workflow-updated", decode_workflow_updated_event(config)),
          event.on("workflow-deleted", decode_workflow_deleted_event(config)),
          event.on(
            "close-requested",
            decode_workflow_close_requested_event(config),
          ),
        ],
        [],
      )
    }
  }
}

/// Convert workflow to JSON for property passing to component.
fn workflow_to_property_json(workflow: Workflow, mode: String) -> json.Json {
  json.object([
    #("id", json.int(workflow.id)),
    #("org_id", json.int(workflow.org_id)),
    #("project_id", case workflow.project_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("name", json.string(workflow.name)),
    #("description", case workflow.description {
      opt.Some(desc) -> json.string(desc)
      opt.None -> json.null()
    }),
    #("active", json.bool(workflow.active)),
    #("rule_count", json.int(workflow.rule_count)),
    #("created_by", json.int(workflow.created_by)),
    #("created_at", json.string(workflow.created_at)),
    #("_mode", json.string(mode)),
  ])
}

fn create_dialog_parts(
  selected_project_id: opt.Option(Int),
) -> #(String, Attribute(msg), Attribute(msg)) {
  #("create", attribute.none(), project_id_attribute(selected_project_id))
}

fn entity_dialog_parts(
  mode: String,
  property_name: String,
  property_json: json.Json,
  project_id: opt.Option(Int),
) -> #(String, Attribute(msg), Attribute(msg)) {
  #(
    mode,
    attribute.property(property_name, property_json),
    project_id_attribute(project_id),
  )
}

fn project_id_attribute(project_id: opt.Option(Int)) -> Attribute(msg) {
  case project_id {
    opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
    opt.None -> attribute.none()
  }
}

/// Decoder for workflow-created event.
fn decode_workflow_created_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(workflow_decoder(), fn(workflow) {
    decode.success(config.on_created(workflow))
  })
}

/// Decoder for workflow-updated event.
fn decode_workflow_updated_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(workflow_decoder(), fn(workflow) {
    decode.success(config.on_updated(workflow))
  })
}

/// Decoder for workflow-deleted event.
fn decode_workflow_deleted_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(config.on_deleted(id)) },
  )
}

/// Decoder for Workflow from JSON (used in custom events).
fn workflow_decoder() -> decode.Decoder(Workflow) {
  workflow_codec.workflow_decoder()
}

/// Decoder for close-requested event from workflow dialog.
fn decode_workflow_close_requested_event(
  config: Config(msg),
) -> decode.Decoder(msg) {
  decode.success(config.on_closed)
}

fn view_workflows_table(
  config: Config(msg),
  workflows: Remote(List(Workflow)),
) -> Element(msg) {
  data_table.view_remote_with_forbidden(
    workflows,
    loading_msg: t(config, i18n_text.LoadingEllipsis),
    empty_msg: t(config, i18n_text.NoWorkflowsYet),
    forbidden_msg: t(config, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(t(config, i18n_text.WorkflowName), fn(w: Workflow) {
          text(w.name)
        }),
        // Active status
        data_table.column(t(config, i18n_text.WorkflowActive), fn(w: Workflow) {
          text(case w.active {
            True -> "✓"
            False -> "✗"
          })
        }),
        // Rules count
        data_table.column(t(config, i18n_text.WorkflowRules), fn(w: Workflow) {
          text(int.to_string(w.rule_count))
        }),
        // Actions
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(w: Workflow) { view_workflow_actions(config, w) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(w: Workflow) { int.to_string(w.id) })
      |> data_table.with_empty_state(empty_state.simple(
        "cog-6-tooth",
        t(config, i18n_text.NoWorkflowsYet),
      )),
  )
}

fn view_workflow_actions(config: Config(msg), w: Workflow) -> Element(msg) {
  div([attribute.class("btn-group")], [
    // Rules button - navigate to rules view
    action_buttons.settings_button_with_testid(
      t(config, i18n_text.WorkflowRules),
      config.on_rules_clicked(w.id),
      "workflow-rules-btn",
    ),
    // Edit button
    action_buttons.edit_button(
      t(config, i18n_text.EditWorkflow),
      config.on_edit_clicked(w),
    ),
    // Delete button
    action_buttons.delete_button(
      t(config, i18n_text.DeleteWorkflow),
      config.on_delete_clicked(w),
    ),
  ])
}
