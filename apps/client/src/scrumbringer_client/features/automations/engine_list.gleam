//// Automation engines list for the unified automations console.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{div, h2, input, p, span, text}
import lustre/element/keyed
import lustre/event

import domain/project.{type Project}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/workflow.{type Workflow}
import domain/workflow/workflow_codec

import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale, serialize}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/filter_bar
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/skeleton

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    selected_project_id: opt.Option(Int),
    selected_rules_view: opt.Option(Element(msg)),
    workflows: Remote(List(Workflow)),
    search_query: String,
    status_filter: String,
    dialog_mode: opt.Option(admin_workflows.WorkflowDialogMode),
    on_create_clicked: msg,
    on_search_changed: fn(String) -> msg,
    on_status_filter_changed: fn(String) -> msg,
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

pub fn view(config: Config(msg)) -> Element(msg) {
  case config.selected_rules_view {
    opt.Some(rules_view) -> rules_view
    opt.None -> view_list(config)
  }
}

fn view_list(config: Config(msg)) -> Element(msg) {
  case config.selected_project {
    opt.None ->
      div([attribute.class("automation-engines-mode")], [
        div([attribute.class("empty")], [
          text(t(config, i18n_text.SelectProjectForWorkflows)),
        ]),
      ])
    opt.Some(project) ->
      div([attribute.class("automation-engines-mode")], [
        div([attribute.class("automation-engines-heading")], [
          h2([], [
            text(t(config, i18n_text.WorkflowsProjectTitle(project.name))),
          ]),
          p([], [text(t(config, i18n_text.AutomationEnginesDescription))]),
        ]),
        view_filters(config),
        view_content(config, config.workflows),
        view_workflow_crud_dialog(config),
      ])
  }
}

fn view_filters(config: Config(msg)) -> Element(msg) {
  filter_bar.new([
    form_field.view(
      t(config, i18n_text.SearchLabel),
      input([
        attribute.type_("search"),
        attribute.value(config.search_query),
        attribute.placeholder(t(
          config,
          i18n_text.AutomationEnginesSearchPlaceholder,
        )),
        attribute.attribute(
          "aria-label",
          t(config, i18n_text.AutomationEnginesSearchPlaceholder),
        ),
        attribute.attribute("data-testid", "automation-engine-search"),
        event.on_input(config.on_search_changed),
      ]),
    ),
    filter_bar.select_field(
      t(config, i18n_text.AutomationEngineStatus),
      config.status_filter,
      [
        filter_bar.SelectOption(
          "all",
          t(config, i18n_text.AutomationEngineStatusAll),
          config.status_filter == "all",
        ),
        filter_bar.SelectOption(
          "active",
          t(config, i18n_text.AutomationEngineStatusActive),
          config.status_filter == "active",
        ),
        filter_bar.SelectOption(
          "paused",
          t(config, i18n_text.AutomationEngineStatusPaused),
          config.status_filter == "paused",
        ),
      ],
      config.on_status_filter_changed,
      "automation-engine-status-filter",
    ),
  ])
  |> filter_bar.with_actions([
    dialog.add_button_with_locale(
      config.locale,
      i18n_text.CreateWorkflow,
      config.on_create_clicked,
    ),
  ])
  |> filter_bar.with_class("automation-engines-filters")
  |> filter_bar.with_testid("automation-engines-filter-bar")
  |> filter_bar.view
}

fn view_content(
  config: Config(msg),
  workflows: Remote(List(Workflow)),
) -> Element(msg) {
  case workflows {
    NotAsked -> skeleton.skeleton_list(3)
    Loading -> skeleton.skeleton_list(3)
    Failed(err) -> error_notice.view(err.message)
    Loaded(items) -> {
      let filtered =
        filter_workflows(items, config.search_query, config.status_filter)

      case filtered {
        [] ->
          empty_state.simple("cog-6-tooth", t(config, i18n_text.NoWorkflowsYet))
        _ ->
          keyed.element(
            "div",
            [attribute.class("automation-engine-list")],
            list.map(filtered, fn(workflow) {
              #(int.to_string(workflow.id), view_engine_row(config, workflow))
            }),
          )
      }
    }
  }
}

fn view_engine_row(config: Config(msg), workflow: Workflow) -> Element(msg) {
  div(
    [
      attribute.class("automation-engine-row"),
      attribute.attribute("data-testid", "automation-engine-row"),
    ],
    [
      div([attribute.class("automation-engine-row__main")], [
        div([attribute.class("automation-engine-row__title")], [
          span([attribute.class("automation-engine-row__name")], [
            text(workflow.name),
          ]),
          workflow_status_badge(config, workflow),
        ]),
        case workflow.description {
          opt.Some(description) ->
            p([attribute.class("automation-engine-row__description")], [
              text(description),
            ])
          opt.None -> element.none()
        },
      ]),
      div([attribute.class("automation-engine-row__meta")], [
        span([], [
          text(
            int.to_string(workflow.rule_count)
            <> " "
            <> t(config, i18n_text.WorkflowRules),
          ),
        ]),
      ]),
      view_actions(config, workflow),
    ],
  )
}

fn workflow_status_badge(
  config: Config(msg),
  workflow: Workflow,
) -> Element(msg) {
  case workflow.active {
    True ->
      badge.new_unchecked(
        t(config, i18n_text.AutomationEngineStatusActive),
        badge.Success,
      )
      |> badge.view
    False ->
      badge.new_unchecked(
        t(config, i18n_text.AutomationEngineStatusPaused),
        badge.Neutral,
      )
      |> badge.view
  }
}

fn view_actions(config: Config(msg), workflow: Workflow) -> Element(msg) {
  div([attribute.class("btn-group")], [
    action_buttons.settings_button_with_testid(
      t(config, i18n_text.WorkflowRules),
      config.on_rules_clicked(workflow.id),
      "workflow-rules-btn",
    ),
    action_buttons.edit_button(
      t(config, i18n_text.EditWorkflow),
      config.on_edit_clicked(workflow),
    ),
    action_buttons.delete_button(
      t(config, i18n_text.DeleteWorkflow),
      config.on_delete_clicked(workflow),
    ),
  ])
}

fn filter_workflows(
  workflows: List(Workflow),
  query: String,
  status_filter: String,
) -> List(Workflow) {
  let needle = string.trim(query) |> string.lowercase

  workflows
  |> list.filter(fn(workflow) {
    workflow_matches_status(workflow, status_filter)
  })
  |> list.filter(fn(workflow) {
    case needle {
      "" -> True
      _ -> workflow_matches_query(workflow, needle)
    }
  })
}

fn workflow_matches_status(workflow: Workflow, status_filter: String) -> Bool {
  case status_filter {
    "active" -> workflow.active
    "paused" -> !workflow.active
    _ -> True
  }
}

fn workflow_matches_query(workflow: Workflow, needle: String) -> Bool {
  string.contains(string.lowercase(workflow.name), needle)
  || case workflow.description {
    opt.Some(description) ->
      string.contains(string.lowercase(description), needle)
    opt.None -> False
  }
}

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
          attribute.attribute("locale", serialize(config.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          workflow_json,
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

fn decode_workflow_created_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(workflow_decoder(), fn(workflow) {
    decode.success(config.on_created(workflow))
  })
}

fn decode_workflow_updated_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(workflow_decoder(), fn(workflow) {
    decode.success(config.on_updated(workflow))
  })
}

fn decode_workflow_deleted_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(config.on_deleted(id)) },
  )
}

fn decode_workflow_close_requested_event(
  config: Config(msg),
) -> decode.Decoder(msg) {
  decode.success(config.on_closed)
}

fn workflow_decoder() -> decode.Decoder(Workflow) {
  workflow_codec.workflow_decoder()
}
