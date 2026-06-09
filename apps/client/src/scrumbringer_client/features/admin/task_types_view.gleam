import gleam/int
import gleam/json
import gleam/list
import gleam/option as opt

import gleam/dynamic/decode

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h2, p, text}
import lustre/event

import domain/capability.{type Capability}
import domain/remote.{type Remote, Loaded}
import domain/task/codec as task_codec
import domain/task_type.{type TaskType}

import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme.{type Theme}
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    theme: Theme,
    project_id: Int,
    project_name: String,
    model: admin_task_types.Model,
    capabilities: Remote(List(Capability)),
    on_create_opened: msg,
    on_edit_opened: fn(TaskType) -> msg,
    on_delete_opened: fn(TaskType) -> msg,
    on_dialog_closed: msg,
    on_crud_created: fn(TaskType) -> msg,
    on_crud_updated: fn(TaskType) -> msg,
    on_crud_deleted: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  div([attribute.class("section")], [
    section_header.view_with_action(
      icons.TaskTypes,
      t(config, i18n_text.TaskTypesTitle(config.project_name)),
      dialog.add_button_with_locale(
        config.locale,
        i18n_text.CreateTaskType,
        config.on_create_opened,
      ),
    ),
    view_list(config),
    view_crud_dialog(config),
  ])
}

fn view_crud_dialog(config: Config(msg)) -> Element(msg) {
  case config.model.task_types_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, type_json) = case mode {
        state_types.TaskTypeDialogCreate -> #("create", attribute.none())
        state_types.TaskTypeDialogEdit(task_type) -> #(
          "edit",
          attribute.property(
            "task-type",
            task_type_to_property_json(task_type, "edit"),
          ),
        )
        state_types.TaskTypeDialogDelete(task_type) -> #(
          "delete",
          attribute.property(
            "task-type",
            task_type_to_property_json(task_type, "delete"),
          ),
        )
      }

      let capabilities_json = case config.capabilities {
        Loaded(caps) ->
          attribute.property(
            "capabilities",
            json.array(caps, capability_to_json),
          )
        _ -> attribute.none()
      }

      element.element(
        "task-type-crud-dialog",
        [
          attribute.attribute("locale", locale.serialize(config.locale)),
          attribute.attribute("project-id", int.to_string(config.project_id)),
          attribute.attribute("mode", mode_str),
          type_json,
          capabilities_json,
          event.on("type-created", decode_task_type_created_event(config)),
          event.on("type-updated", decode_task_type_updated_event(config)),
          event.on("type-deleted", decode_task_type_deleted_event(config)),
          event.on("close-requested", decode.success(config.on_dialog_closed)),
        ],
        [],
      )
    }
  }
}

fn view_list(config: Config(msg)) -> Element(msg) {
  let empty_state =
    div([attribute.class("empty")], [
      h2([], [text(t(config, i18n_text.NoTaskTypesYet))]),
      p([], [text(t(config, i18n_text.TaskTypesExplain))]),
      p([], [text(t(config, i18n_text.CreateFirstTaskTypeHint))]),
    ])

  data_table.view_remote_with_forbidden(
    config.model.task_types,
    loading_msg: t(config, i18n_text.LoadingEllipsis),
    empty_msg: "",
    forbidden_msg: t(config, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_empty_state(empty_state)
      |> data_table.with_columns([
        data_table.column(t(config, i18n_text.Name), fn(tt: TaskType) {
          text(tt.name)
        }),
        data_table.column(t(config, i18n_text.Icon), fn(tt: TaskType) {
          icons.view_task_type_icon_inline(tt.icon, 20, config.theme)
        }),
        data_table.column(
          t(config, i18n_text.CapabilityLabel),
          fn(tt: TaskType) {
            case tt.capability_id {
              opt.Some(id) ->
                case resolve_capability_name(config.capabilities, id) {
                  opt.Some(name) -> text(name)
                  opt.None -> text("-")
                }
              opt.None -> text(t(config, i18n_text.NoneOption))
            }
          },
        ),
        data_table.column_with_class(
          t(config, i18n_text.CardTasks),
          fn(tt: TaskType) { text(int.to_string(tt.tasks_count)) },
          "col-number",
          "cell-number",
        ),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(tt: TaskType) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: t(config, i18n_text.EditTaskType),
              edit_click: config.on_edit_opened(tt),
              edit_testid: "task-type-edit-btn",
              delete_title: t(config, i18n_text.DeleteTaskType),
              delete_click: config.on_delete_opened(tt),
              delete_testid: "task-type-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(tt) { int.to_string(tt.id) }),
  )
}

fn task_type_to_property_json(task_type: TaskType, mode: String) -> json.Json {
  json.object([
    #("id", json.int(task_type.id)),
    #("name", json.string(task_type.name)),
    #("icon", json.string(task_type.icon)),
    #("capability_id", case task_type.capability_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("tasks_count", json.int(task_type.tasks_count)),
    #("_mode", json.string(mode)),
  ])
}

fn capability_to_json(cap: Capability) -> json.Json {
  json.object([#("id", json.int(cap.id)), #("name", json.string(cap.name))])
}

fn decode_task_type_created_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(task_codec.task_type_decoder(), fn(task_type) {
    decode.success(config.on_crud_created(task_type))
  })
}

fn decode_task_type_updated_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(task_codec.task_type_decoder(), fn(task_type) {
    decode.success(config.on_crud_updated(task_type))
  })
}

fn decode_task_type_deleted_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(config.on_crud_deleted(id)) },
  )
}

fn resolve_capability_name(
  capabilities: Remote(List(Capability)),
  capability_id: Int,
) -> opt.Option(String) {
  case capabilities {
    Loaded(caps) ->
      list.find(caps, fn(cap: Capability) { cap.id == capability_id })
      |> opt.from_result
      |> opt.map(fn(cap) { cap.name })

    _ -> opt.None
  }
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
