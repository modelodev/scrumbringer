//// Automation template library view.
////
//// ## Mission
////
//// Render project-scoped templates as an internal automations mode.

import gleam/int
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html.{div, h2, input, p, span, text}
import lustre/event

import gleam/dynamic/decode

import domain/project.{type Project}
import domain/remote as remote_state
import domain/task_type.{type TaskType}
import domain/workflow.{type TaskTemplate}
import domain/workflow/workflow_codec

import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/filter_bar
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/info_callout

// =============================================================================
// Template Library Views
// =============================================================================

pub type Config(msg) {
  Config(
    locale: Locale,
    selected_project: opt.Option(Project),
    selected_project_id: opt.Option(Int),
    templates: remote_state.Remote(List(TaskTemplate)),
    dialog_mode: opt.Option(admin_task_templates.TaskTemplateDialogMode),
    task_types: remote_state.Remote(List(TaskType)),
    search_query: String,
    on_create_clicked: msg,
    on_edit_clicked: fn(TaskTemplate) -> msg,
    on_delete_clicked: fn(TaskTemplate) -> msg,
    on_search_changed: fn(String) -> msg,
    on_created: fn(TaskTemplate) -> msg,
    on_updated: fn(TaskTemplate) -> msg,
    on_deleted: fn(Int) -> msg,
    on_closed: msg,
  )
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

/// Automation template library view (project-scoped only).
pub fn view_task_templates(config: Config(msg)) -> Element(msg) {
  let title = case config.selected_project {
    opt.Some(project) ->
      i18n.t(config.locale, i18n_text.TaskTemplatesProjectTitle(project.name))
    opt.None -> i18n.t(config.locale, i18n_text.TaskTemplatesTitle)
  }

  div([attribute.class("automation-templates-mode")], [
    div([attribute.class("automation-templates-heading")], [
      h2([], [text(title)]),
      p([], [
        text(i18n.t(config.locale, i18n_text.AutomationTemplatesDescription)),
      ]),
    ]),
    view_template_filters(config),
    view_templates_hint(config),
    view_task_templates_table(config),
    view_task_template_crud_dialog(config),
  ])
}

fn view_template_filters(config: Config(msg)) -> Element(msg) {
  filter_bar.new([
    form_field.view(
      i18n.t(config.locale, i18n_text.SearchLabel),
      input([
        attribute.type_("search"),
        attribute.value(config.search_query),
        attribute.placeholder(i18n.t(
          config.locale,
          i18n_text.AutomationTemplatesSearchPlaceholder,
        )),
        attribute.attribute(
          "aria-label",
          i18n.t(config.locale, i18n_text.AutomationTemplatesSearchPlaceholder),
        ),
        attribute.attribute("data-testid", "automation-template-search"),
        event.on_input(config.on_search_changed),
      ]),
    ),
  ])
  |> filter_bar.with_actions([
    dialog.add_button_with_locale(
      config.locale,
      i18n_text.CreateTaskTemplate,
      config.on_create_clicked,
    ),
  ])
  |> filter_bar.with_class("automation-templates-filters")
  |> filter_bar.with_testid("automation-template-picker")
  |> filter_bar.view
}

/// Unified hint with variables documentation for the template library.
fn view_templates_hint(config: Config(msg)) -> Element(msg) {
  info_callout.view_with_content(
    opt.None,
    div([], [
      span([], [
        text(i18n.t(config.locale, i18n_text.TemplatesHintRules)),
      ]),
      div([attribute.class("info-callout-variables")], [
        text(i18n.t(config.locale, i18n_text.TaskTemplateVariablesHelp)),
      ]),
    ]),
  )
}

/// Render the task-template-crud-dialog Lustre component.
fn view_task_template_crud_dialog(config: Config(msg)) -> Element(msg) {
  case config.dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, template_json, project_id_attr) = case mode {
        admin_task_templates.TaskTemplateDialogCreate ->
          create_dialog_parts(config.selected_project_id)
        admin_task_templates.TaskTemplateDialogEdit(template) ->
          entity_dialog_parts(
            "edit",
            "template",
            task_template_to_property_json(template, "edit"),
            template.project_id,
          )
        admin_task_templates.TaskTemplateDialogDelete(template) ->
          entity_dialog_parts(
            "delete",
            "template",
            task_template_to_property_json(template, "delete"),
            template.project_id,
          )
      }

      element.element(
        "task-template-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(config.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          // Property for template data (edit/delete modes)
          template_json,
          // Property for task types list
          attribute.property(
            "task-types",
            task_types_to_property_json(config.task_types),
          ),
          // Event listeners for component events
          event.on(
            "task-template-created",
            decode_task_template_created_event(config),
          ),
          event.on(
            "task-template-updated",
            decode_task_template_updated_event(config),
          ),
          event.on(
            "task-template-deleted",
            decode_task_template_deleted_event(config),
          ),
          event.on(
            "close-requested",
            decode_task_template_close_requested_event(config),
          ),
        ],
        [],
      )
    }
  }
}

/// Convert task template to JSON for property passing to component.
fn task_template_to_property_json(
  template: TaskTemplate,
  mode: String,
) -> json.Json {
  json.object([
    #("id", json.int(template.id)),
    #("org_id", json.int(template.org_id)),
    #("project_id", case template.project_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("name", json.string(template.name)),
    #("description", case template.description {
      opt.Some(desc) -> json.string(desc)
      opt.None -> json.null()
    }),
    #("type_id", json.int(template.type_id)),
    #("type_name", json.string(template.type_name)),
    #("priority", json.int(template.priority)),
    #("created_by", json.int(template.created_by)),
    #("created_at", json.string(template.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Convert task types to JSON for property passing to component.
fn task_types_to_property_json(
  task_types: remote_state.Remote(List(TaskType)),
) -> json.Json {
  case task_types {
    remote_state.Loaded(types) ->
      json.array(types, fn(tt: TaskType) {
        json.object([
          #("id", json.int(tt.id)),
          #("name", json.string(tt.name)),
          #("icon", json.string(tt.icon)),
        ])
      })
    _ -> json.array([], fn(_) { json.null() })
  }
}

/// Decoder for task-template-created event.
fn decode_task_template_created_event(
  config: Config(msg),
) -> decode.Decoder(msg) {
  event_decoders.custom_detail(task_template_decoder(), fn(template) {
    decode.success(config.on_created(template))
  })
}

/// Decoder for task-template-updated event.
fn decode_task_template_updated_event(
  config: Config(msg),
) -> decode.Decoder(msg) {
  event_decoders.custom_detail(task_template_decoder(), fn(template) {
    decode.success(config.on_updated(template))
  })
}

/// Decoder for task-template-deleted event.
fn decode_task_template_deleted_event(
  config: Config(msg),
) -> decode.Decoder(msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(config.on_deleted(id)) },
  )
}

/// Decoder for close-requested event from task template component.
fn decode_task_template_close_requested_event(
  config: Config(msg),
) -> decode.Decoder(msg) {
  decode.success(config.on_closed)
}

/// Decoder for TaskTemplate from JSON (used in custom events).
/// Story 4.9 AC20: Added rules_count field.
fn task_template_decoder() -> decode.Decoder(TaskTemplate) {
  workflow_codec.task_template_decoder()
}

fn view_task_templates_table(config: Config(msg)) -> Element(msg) {
  let t = fn(key) { i18n.t(config.locale, key) }
  let templates =
    config.templates
    |> remote_state.map(fn(items) {
      filter_templates(items, config.search_query)
    })

  data_table.view_remote_with_forbidden(
    templates,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoTaskTemplatesYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name column
        data_table.column(t(i18n_text.TaskTemplateName), fn(tmpl: TaskTemplate) {
          text(tmpl.name)
        }),
        // Type column (task type)
        data_table.column(t(i18n_text.TaskTemplateType), fn(tmpl: TaskTemplate) {
          text(tmpl.type_name)
        }),
        // Priority column
        data_table.column_with_class(
          t(i18n_text.TaskTemplatePriority),
          fn(tmpl: TaskTemplate) {
            badge.new_unchecked(int.to_string(tmpl.priority), badge.Neutral)
            |> badge.view_with_class("priority-badge")
          },
          "col-number",
          "cell-number",
        ),
        // Actions column with icon buttons
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(tmpl: TaskTemplate) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: t(i18n_text.EditTaskTemplate),
              edit_click: config.on_edit_clicked(tmpl),
              edit_testid: "template-edit-btn",
              delete_title: t(i18n_text.Delete),
              delete_click: config.on_delete_clicked(tmpl),
              delete_testid: "template-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(tmpl) { int.to_string(tmpl.id) })
      |> data_table.with_row_attrs(fn(_tmpl) {
        [attribute.attribute("data-testid", "automation-template-row")]
      }),
  )
}

fn filter_templates(
  templates: List(TaskTemplate),
  query: String,
) -> List(TaskTemplate) {
  let needle = string.trim(query) |> string.lowercase
  case needle {
    "" -> templates
    _ ->
      list.filter(templates, fn(template) {
        template_matches_query(template, needle)
      })
  }
}

fn template_matches_query(template: TaskTemplate, needle: String) -> Bool {
  string.contains(string.lowercase(template.name), needle)
  || string.contains(string.lowercase(template.type_name), needle)
  || case template.description {
    opt.Some(description) ->
      string.contains(string.lowercase(description), needle)
    opt.None -> False
  }
}
