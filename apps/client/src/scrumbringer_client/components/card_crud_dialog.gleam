//// Card CRUD Dialog Component.
////
//// ## Mission
////
//// Encapsulated Lustre Component for card create, edit, and delete dialogs.
////
//// ## Responsibilities
////
//// - Handle create dialog: title, description, color fields
//// - Handle edit dialog: prefill from card, submit updates
//// - Handle delete confirmation dialog
//// - Emit events to parent for card-created, card-updated, card-deleted
////
//// ## Relations
////
//// - Parent: features/admin/view.gleam renders this component
//// - API: api/cards.gleam for CRUD operations

import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, form, h3, input, label, p, span, text}
import lustre/event

import domain/api_error.{type ApiError}
import domain/card.{type Card, type CardState, Card, Cerrada, EnCurso, Pendiente}

import scrumbringer_client/api/core.{type ApiResult}
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons

// =============================================================================
// Internal Types
// =============================================================================

/// Dialog mode determines which view to show.
pub type DialogMode {
  ModeCreate
  ModeEdit(Card)
  ModeDelete(Card)
}

/// Internal component model - encapsulates all 17 CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    mode: Option(DialogMode),
    // Create dialog fields
    create_title: String,
    create_description: String,
    create_color: Option(String),
    create_color_open: Bool,
    create_in_flight: Bool,
    create_error: Option(String),
    // Edit dialog fields
    edit_title: String,
    edit_description: String,
    edit_color: Option(String),
    edit_color_open: Bool,
    edit_in_flight: Bool,
    edit_error: Option(String),
    // Delete dialog fields
    delete_in_flight: Bool,
    delete_error: Option(String),
  )
}

/// Color option for color picker.
pub type CardColor {
  Gray
  Red
  Orange
  Yellow
  Green
  Blue
  Purple
  Pink
}

/// All available colors.
const all_colors = [Gray, Red, Orange, Yellow, Green, Blue, Purple, Pink]

/// Internal messages - not exposed to parent.
pub type Msg {
  // Attribute/property changes
  LocaleReceived(Locale)
  ProjectIdReceived(Int)
  ModeReceived(DialogMode)
  // Create form
  CreateTitleChanged(String)
  CreateDescriptionChanged(String)
  CreateColorToggle
  CreateColorChanged(Option(String))
  CreateSubmitted
  CreateResult(ApiResult(Card))
  // Edit form
  EditTitleChanged(String)
  EditDescriptionChanged(String)
  EditColorToggle
  EditColorChanged(Option(String))
  EditSubmitted
  EditResult(ApiResult(Card))
  EditCancelled
  // Delete confirmation
  DeleteConfirmed
  DeleteResult(ApiResult(Nil))
  DeleteCancelled
  // Close dialog
  CloseRequested
}

// =============================================================================
// Component Registration
// =============================================================================

/// Register the card-crud-dialog as a custom element.
/// Call this once at app init. Returns Result to handle registration errors.
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, on_attribute_change())
  |> lustre.register("card-crud-dialog")
}

/// Build attribute/property change handlers.
fn on_attribute_change() -> List(component.Option(Msg)) {
  [
    component.on_attribute_change("locale", decode_locale),
    component.on_attribute_change("project-id", decode_project_id),
    component.on_attribute_change("mode", decode_mode),
    component.on_attribute_change("card-id", decode_card_id),
    component.on_property_change("card", card_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  Ok(LocaleReceived(locale.deserialize(value)))
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  int.parse(value)
  |> result.map(ProjectIdReceived)
  |> result.replace_error(Nil)
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  case value {
    "create" -> Ok(ModeReceived(ModeCreate))
    // edit and delete modes need card data from property
    _ -> Error(Nil)
  }
}

fn decode_card_id(_value: String) -> Result(Msg, Nil) {
  // Card ID is used with the card property, so we don't process it here
  Error(Nil)
}

fn card_property_decoder() -> Decoder(Msg) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", decode.optional(decode.string))
  use state <- decode.field("state", card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use mode <- decode.field("_mode", decode.string)
  let card =
    Card(
      id: id,
      project_id: project_id,
      title: title,
      description: description,
      color: color,
      state: state,
      task_count: task_count,
      completed_count: completed_count,
      created_by: created_by,
      created_at: created_at,
    )
  case mode {
    "edit" -> decode.success(ModeReceived(ModeEdit(card)))
    "delete" -> decode.success(ModeReceived(ModeDelete(card)))
    _ -> decode.success(ModeReceived(ModeEdit(card)))
  }
}

fn card_state_decoder() -> Decoder(CardState) {
  use state_str <- decode.then(decode.string)
  case state_str {
    "en_curso" -> decode.success(EnCurso)
    "cerrada" -> decode.success(Cerrada)
    _ -> decode.success(Pendiente)
  }
}

// =============================================================================
// Init
// =============================================================================

fn init(_: Nil) -> #(Model, Effect(Msg)) {
  #(default_model(), effect.none())
}

fn default_model() -> Model {
  Model(
    locale: En,
    project_id: option.None,
    mode: option.None,
    create_title: "",
    create_description: "",
    create_color: option.None,
    create_color_open: False,
    create_in_flight: False,
    create_error: option.None,
    edit_title: "",
    edit_description: "",
    edit_color: option.None,
    edit_color_open: False,
    edit_in_flight: False,
    edit_error: option.None,
    delete_in_flight: False,
    delete_error: option.None,
  )
}

// =============================================================================
// Update
// =============================================================================

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LocaleReceived(loc) ->
      #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) ->
      #(Model(..model, project_id: option.Some(id)), effect.none())

    ModeReceived(mode) ->
      handle_mode_received(model, mode)

    // Create form handlers
    CreateTitleChanged(title) ->
      #(Model(..model, create_title: title), effect.none())

    CreateDescriptionChanged(desc) ->
      #(Model(..model, create_description: desc), effect.none())

    CreateColorToggle ->
      #(Model(..model, create_color_open: !model.create_color_open), effect.none())

    CreateColorChanged(color) ->
      #(Model(..model, create_color: color, create_color_open: False), effect.none())

    CreateSubmitted ->
      handle_create_submitted(model)

    CreateResult(Ok(card)) ->
      handle_create_success(model, card)

    CreateResult(Error(err)) ->
      #(
        Model(..model, create_in_flight: False, create_error: option.Some(err.message)),
        effect.none(),
      )

    // Edit form handlers
    EditTitleChanged(title) ->
      #(Model(..model, edit_title: title), effect.none())

    EditDescriptionChanged(desc) ->
      #(Model(..model, edit_description: desc), effect.none())

    EditColorToggle ->
      #(Model(..model, edit_color_open: !model.edit_color_open), effect.none())

    EditColorChanged(color) ->
      #(Model(..model, edit_color: color, edit_color_open: False), effect.none())

    EditSubmitted ->
      handle_edit_submitted(model)

    EditResult(Ok(card)) ->
      handle_edit_success(model, card)

    EditResult(Error(err)) ->
      #(
        Model(..model, edit_in_flight: False, edit_error: option.Some(err.message)),
        effect.none(),
      )

    EditCancelled ->
      #(reset_edit_fields(model), emit_close_requested())

    // Delete handlers
    DeleteConfirmed ->
      handle_delete_confirmed(model)

    DeleteResult(Ok(_)) ->
      handle_delete_success(model)

    DeleteResult(Error(err)) ->
      handle_delete_error(model, err)

    DeleteCancelled ->
      #(reset_delete_fields(model), emit_close_requested())

    CloseRequested ->
      #(model, emit_close_requested())
  }
}

fn handle_mode_received(model: Model, mode: DialogMode) -> #(Model, Effect(Msg)) {
  case mode {
    ModeCreate ->
      #(
        Model(
          ..model,
          mode: option.Some(ModeCreate),
          create_title: "",
          create_description: "",
          create_color: option.None,
          create_color_open: False,
          create_in_flight: False,
          create_error: option.None,
        ),
        effect.none(),
      )

    ModeEdit(card) ->
      #(
        Model(
          ..model,
          mode: option.Some(ModeEdit(card)),
          edit_title: card.title,
          edit_description: card.description,
          edit_color: card.color,
          edit_color_open: False,
          edit_in_flight: False,
          edit_error: option.None,
        ),
        effect.none(),
      )

    ModeDelete(card) ->
      #(
        Model(
          ..model,
          mode: option.Some(ModeDelete(card)),
          delete_in_flight: False,
          delete_error: option.None,
        ),
        effect.none(),
      )
  }
}

fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.create_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.create_title {
        "" ->
          #(
            Model(..model, create_error: option.Some(t(model.locale, i18n_text.TitleRequired))),
            effect.none(),
          )
        title ->
          case model.project_id {
            option.Some(project_id) ->
              #(
                Model(..model, create_in_flight: True, create_error: option.None),
                api_cards.create_card(
                  project_id,
                  title,
                  model.create_description,
                  model.create_color,
                  CreateResult,
                ),
              )
            option.None ->
              #(
                Model(..model, create_error: option.Some(t(model.locale, i18n_text.SelectProjectFirst))),
                effect.none(),
              )
          }
      }
  }
}

fn handle_create_success(model: Model, card: Card) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: option.None,
      create_title: "",
      create_description: "",
      create_color: option.None,
      create_color_open: False,
      create_in_flight: False,
      create_error: option.None,
    ),
    emit_card_created(card),
  )
}

fn handle_edit_submitted(model: Model) -> #(Model, Effect(Msg)) {
  case model.edit_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.edit_title {
        "" ->
          #(
            Model(..model, edit_error: option.Some(t(model.locale, i18n_text.TitleRequired))),
            effect.none(),
          )
        title ->
          case model.mode {
            option.Some(ModeEdit(card)) ->
              #(
                Model(..model, edit_in_flight: True, edit_error: option.None),
                api_cards.update_card(
                  card.id,
                  title,
                  model.edit_description,
                  model.edit_color,
                  EditResult,
                ),
              )
            _ ->
              #(model, effect.none())
          }
      }
  }
}

fn handle_edit_success(model: Model, card: Card) -> #(Model, Effect(Msg)) {
  #(
    reset_edit_fields(model),
    emit_card_updated(card),
  )
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  case model.delete_in_flight {
    True -> #(model, effect.none())
    False ->
      case model.mode {
        option.Some(ModeDelete(card)) ->
          #(
            Model(..model, delete_in_flight: True, delete_error: option.None),
            api_cards.delete_card(card.id, DeleteResult),
          )
        _ ->
          #(model, effect.none())
      }
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let card_id = case model.mode {
    option.Some(ModeDelete(card)) -> card.id
    _ -> 0
  }
  #(
    reset_delete_fields(model),
    emit_card_deleted(card_id),
  )
}

fn handle_delete_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  let error_msg = case err.status {
    409 -> t(model.locale, i18n_text.CardDeleteBlocked)
    _ -> err.message
  }
  #(
    Model(..model, delete_in_flight: False, delete_error: option.Some(error_msg)),
    effect.none(),
  )
}

fn reset_edit_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: option.None,
    edit_title: "",
    edit_description: "",
    edit_color: option.None,
    edit_color_open: False,
    edit_in_flight: False,
    edit_error: option.None,
  )
}

fn reset_delete_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: option.None,
    delete_in_flight: False,
    delete_error: option.None,
  )
}

// =============================================================================
// Effects - Custom Events
// =============================================================================

fn emit_card_created(card: Card) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("card-created", card_to_json(card))
  })
}

fn emit_card_updated(card: Card) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("card-updated", card_to_json(card))
  })
}

fn emit_card_deleted(card_id: Int) -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("card-deleted", json.object([#("id", json.int(card_id))]))
  })
}

fn emit_close_requested() -> Effect(Msg) {
  effect.from(fn(_dispatch) {
    emit_custom_event("close-requested", json.null())
  })
}

@external(javascript, "../component.ffi.mjs", "emit_custom_event")
fn emit_custom_event(_name: String, _detail: json.Json) -> Nil {
  Nil
}

fn card_to_json(card: Card) -> json.Json {
  let state_str = case card.state {
    Pendiente -> "pendiente"
    EnCurso -> "en_curso"
    Cerrada -> "cerrada"
  }
  let color_fields = case card.color {
    option.Some(c) -> [#("color", json.string(c))]
    option.None -> [#("color", json.null())]
  }
  json.object(
    list.flatten([
      [
        #("id", json.int(card.id)),
        #("project_id", json.int(card.project_id)),
        #("title", json.string(card.title)),
        #("description", json.string(card.description)),
        #("state", json.string(state_str)),
        #("task_count", json.int(card.task_count)),
        #("completed_count", json.int(card.completed_count)),
        #("created_by", json.int(card.created_by)),
        #("created_at", json.string(card.created_at)),
      ],
      color_fields,
    ]),
  )
}

// =============================================================================
// View
// =============================================================================

fn view(model: Model) -> Element(Msg) {
  case model.mode {
    option.None -> element.none()
    option.Some(ModeCreate) -> view_create_dialog(model)
    option.Some(ModeEdit(_card)) -> view_edit_dialog(model)
    option.Some(ModeDelete(card)) -> view_delete_dialog(model, card)
  }
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-md"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header (Story 4.8 UX: Heroicon instead of emoji)
        view_header(model, i18n_text.CreateCard, icons.Cards),
        // Error
        view_error(model.create_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { CreateSubmitted }),
              attribute.id("card-create-form"),
            ],
            [
              // Title field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.CardTitle))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_title),
                  event.on_input(CreateTitleChanged),
                  attribute.required(True),
                  attribute.attribute("aria-label", "Card title"),
                ]),
              ]),
              // Description field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.CardDescription))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.create_description),
                  event.on_input(CreateDescriptionChanged),
                  attribute.attribute("aria-label", "Card description"),
                ]),
              ]),
              // Color picker
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.ColorLabel))]),
                view_color_picker(
                  model.locale,
                  model.create_color,
                  model.create_color_open,
                  CreateColorToggle,
                  CreateColorChanged,
                ),
              ]),
            ],
          ),
        ]),
        // Footer
        div([attribute.class("dialog-footer")], [
          view_cancel_button(model.locale, CloseRequested),
          button(
            [
              attribute.type_("submit"),
              attribute.form("card-create-form"),
              attribute.disabled(model.create_in_flight),
              attribute.class(case model.create_in_flight {
                True -> "btn-loading"
                False -> ""
              }),
            ],
            [
              text(case model.create_in_flight {
                True -> t(model.locale, i18n_text.Creating)
                False -> t(model.locale, i18n_text.Create)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-md"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header (Story 4.8 UX: Heroicon instead of emoji)
        view_header(model, i18n_text.EditCard, icons.Pencil),
        // Error
        view_error(model.edit_error),
        // Body
        div([attribute.class("dialog-body")], [
          form(
            [
              event.on_submit(fn(_) { EditSubmitted }),
              attribute.id("card-edit-form"),
            ],
            [
              // Title field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.CardTitle))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_title),
                  event.on_input(EditTitleChanged),
                  attribute.required(True),
                ]),
              ]),
              // Description field
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.CardDescription))]),
                input([
                  attribute.type_("text"),
                  attribute.value(model.edit_description),
                  event.on_input(EditDescriptionChanged),
                ]),
              ]),
              // Color picker
              div([attribute.class("field")], [
                label([], [text(t(model.locale, i18n_text.ColorLabel))]),
                view_color_picker(
                  model.locale,
                  model.edit_color,
                  model.edit_color_open,
                  EditColorToggle,
                  EditColorChanged,
                ),
              ]),
            ],
          ),
        ]),
        // Footer
        div([attribute.class("dialog-footer")], [
          view_cancel_button(model.locale, EditCancelled),
          button(
            [
              attribute.type_("submit"),
              attribute.form("card-edit-form"),
              attribute.disabled(model.edit_in_flight),
              attribute.class(case model.edit_in_flight {
                True -> "btn-loading"
                False -> ""
              }),
            ],
            [
              text(case model.edit_in_flight {
                True -> t(model.locale, i18n_text.Working)
                False -> t(model.locale, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_delete_dialog(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("dialog-overlay")], [
    div(
      [
        attribute.class("dialog dialog-sm"),
        attribute.attribute("role", "dialog"),
        attribute.attribute("aria-modal", "true"),
      ],
      [
        // Header (Story 4.8 UX: Heroicon instead of emoji)
        view_header(model, i18n_text.DeleteCard, icons.Trash),
        // Error
        view_error(model.delete_error),
        // Body
        div([attribute.class("dialog-body")], [
          p([], [
            text(t(model.locale, i18n_text.CardDeleteConfirm(card.title))),
          ]),
        ]),
        // Footer
        div([attribute.class("dialog-footer")], [
          view_cancel_button(model.locale, DeleteCancelled),
          button(
            [
              event.on_click(DeleteConfirmed),
              attribute.disabled(model.delete_in_flight),
              attribute.class("btn-danger"),
            ],
            [
              text(case model.delete_in_flight {
                True -> t(model.locale, i18n_text.Removing)
                False -> t(model.locale, i18n_text.DeleteCard)
              }),
            ],
          ),
        ]),
      ],
    ),
  ])
}

fn view_header(model: Model, title_key: i18n_text.Text, icon: icons.NavIcon) -> Element(Msg) {
  div([attribute.class("dialog-header")], [
    div([attribute.class("dialog-title")], [
      span([attribute.class("dialog-icon")], [
        icons.nav_icon(icon, icons.Medium),
      ]),
      h3([], [text(t(model.locale, title_key))]),
    ]),
    button(
      [
        attribute.class("btn-icon dialog-close"),
        attribute.type_("button"),
        event.on_click(CloseRequested),
        attribute.attribute("aria-label", "Close"),
      ],
      [text("\u{2715}")],
    ),
  ])
}

fn view_error(error: Option(String)) -> Element(Msg) {
  case error {
    option.Some(msg) ->
      div([attribute.class("dialog-error")], [
        span([], [text("\u{26A0}")]),
        text(" " <> msg),
      ])
    option.None -> element.none()
  }
}

fn view_cancel_button(locale: Locale, on_click_msg: Msg) -> Element(Msg) {
  button(
    [attribute.type_("button"), event.on_click(on_click_msg)],
    [text(t(locale, i18n_text.Cancel))],
  )
}

// =============================================================================
// Internal Color Picker
// =============================================================================

fn view_color_picker(
  locale: Locale,
  selected: Option(String),
  is_open: Bool,
  on_toggle: Msg,
  on_select: fn(Option(String)) -> Msg,
) -> Element(Msg) {
  let open_class = case is_open {
    True -> " open"
    False -> ""
  }

  let selected_color = case selected {
    option.None -> option.None
    option.Some(c) -> string_to_color(c)
  }

  let selected_label = case selected_color {
    option.None -> t(locale, i18n_text.ColorNone)
    option.Some(c) -> t(locale, color_i18n_key(c))
  }

  div(
    [attribute.class("color-picker" <> open_class)],
    [
      // Trigger button
      div(
        [
          attribute.class("color-picker-trigger"),
          attribute.attribute("role", "combobox"),
          attribute.attribute("aria-expanded", case is_open {
            True -> "true"
            False -> "false"
          }),
          attribute.attribute("aria-label", t(locale, i18n_text.ColorLabel)),
          event.on_click(on_toggle),
        ],
        [
          view_swatch(selected_color),
          span([attribute.class("color-picker-label")], [text(selected_label)]),
          span([attribute.class("color-picker-arrow")], [text("\u{25BC}")]),
        ],
      ),
      // Dropdown menu
      div(
        [
          attribute.class("color-picker-dropdown"),
          attribute.attribute("role", "listbox"),
        ],
        [
          // "None" option
          view_color_option(locale, option.None, selected_color, on_select),
          // Color options
          ..list.map(all_colors, fn(c) {
            view_color_option(locale, option.Some(c), selected_color, on_select)
          })
        ],
      ),
    ],
  )
}

fn view_color_option(
  locale: Locale,
  color: Option(CardColor),
  selected: Option(CardColor),
  on_select: fn(Option(String)) -> Msg,
) -> Element(Msg) {
  let is_selected = color == selected

  let label_text = case color {
    option.None -> t(locale, i18n_text.ColorNone)
    option.Some(c) -> t(locale, color_i18n_key(c))
  }

  let selected_class = case is_selected {
    True -> " selected"
    False -> ""
  }

  let on_click_msg = case color {
    option.None -> on_select(option.None)
    option.Some(c) -> on_select(option.Some(color_to_string(c)))
  }

  div(
    [
      attribute.class("color-picker-option" <> selected_class),
      attribute.attribute("role", "option"),
      attribute.attribute("aria-selected", case is_selected {
        True -> "true"
        False -> "false"
      }),
      event.on_click(on_click_msg),
    ],
    [view_swatch(color), span([], [text(label_text)])],
  )
}

fn view_swatch(color: Option(CardColor)) -> Element(Msg) {
  case color {
    option.None ->
      span([attribute.class("color-picker-swatch color-picker-swatch-none")], [])
    option.Some(c) ->
      span(
        [
          attribute.class("color-picker-swatch"),
          attribute.attribute("style", "background: " <> css_var(c)),
        ],
        [],
      )
  }
}

fn color_to_string(color: CardColor) -> String {
  case color {
    Gray -> "gray"
    Red -> "red"
    Orange -> "orange"
    Yellow -> "yellow"
    Green -> "green"
    Blue -> "blue"
    Purple -> "purple"
    Pink -> "pink"
  }
}

fn string_to_color(s: String) -> Option(CardColor) {
  case s {
    "gray" -> option.Some(Gray)
    "red" -> option.Some(Red)
    "orange" -> option.Some(Orange)
    "yellow" -> option.Some(Yellow)
    "green" -> option.Some(Green)
    "blue" -> option.Some(Blue)
    "purple" -> option.Some(Purple)
    "pink" -> option.Some(Pink)
    _ -> option.None
  }
}

fn css_var(color: CardColor) -> String {
  "var(--sb-card-" <> color_to_string(color) <> ")"
}

fn color_i18n_key(color: CardColor) -> i18n_text.Text {
  case color {
    Gray -> i18n_text.ColorGray
    Red -> i18n_text.ColorRed
    Orange -> i18n_text.ColorOrange
    Yellow -> i18n_text.ColorYellow
    Green -> i18n_text.ColorGreen
    Blue -> i18n_text.ColorBlue
    Purple -> i18n_text.ColorPurple
    Pink -> i18n_text.ColorPink
  }
}

// =============================================================================
// i18n Helper
// =============================================================================

fn t(loc: Locale, key: i18n_text.Text) -> String {
  case loc {
    En -> i18n_en.translate(key)
    Es -> i18n_es.translate(key)
  }
}
