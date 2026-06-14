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

import lustre
import lustre/attribute
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{div, form, input, span, text}
import lustre/event

import domain/api_error.{type ApiError, type ApiResult}
import domain/card.{type Card, all_colors, color_to_string, state_to_string}
import domain/card/codec as card_codec
import scrumbringer_client/ui/attribute_value

import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/components/crud_dialog_base
import scrumbringer_client/i18n/en as i18n_en
import scrumbringer_client/i18n/es as i18n_es
import scrumbringer_client/i18n/locale.{type Locale, En, Es}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/modal_header

// =============================================================================
// Internal Types
// =============================================================================

/// Dialog mode determines which view to show.
pub type DialogMode =
  crud_dialog_base.DialogLifecycle(Card)

/// Internal component model - encapsulates all 17 CRUD fields.
pub type Model {
  Model(
    // Attributes from parent
    locale: Locale,
    project_id: Option(Int),
    create_milestone_id: Option(Int),
    create_milestone_name: Option(String),
    mode: DialogMode,
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

/// Internal messages - not exposed to parent.
pub type Msg {
  // Attribute/property changes
  LocaleReceived(Locale)
  ProjectIdReceived(Int)
  MilestoneIdReceived(Int)
  MilestoneIdCleared
  MilestoneNameReceived(String)
  MilestoneNameCleared
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
    component.on_attribute_change("milestone-id", decode_milestone_id),
    component.on_attribute_change("milestone-name", decode_milestone_name),
    component.on_attribute_change("mode", decode_mode),
    component.on_attribute_change("card-id", decode_card_id),
    component.on_property_change("card", card_property_decoder()),
    component.adopt_styles(True),
  ]
}

fn decode_locale(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_locale(value, LocaleReceived)
}

fn decode_project_id(value: String) -> Result(Msg, Nil) {
  crud_dialog_base.decode_int_attribute(value, ProjectIdReceived)
}

fn decode_milestone_id(value: String) -> Result(Msg, Nil) {
  case int.parse(value) {
    Ok(id) -> Ok(MilestoneIdReceived(id))
    Error(_) -> Ok(MilestoneIdCleared)
  }
}

fn decode_milestone_name(value: String) -> Result(Msg, Nil) {
  case value {
    "" -> Ok(MilestoneNameCleared)
    name -> Ok(MilestoneNameReceived(name))
  }
}

fn decode_mode(value: String) -> Result(Msg, Nil) {
  // edit and delete modes need card data from property
  crud_dialog_base.decode_create_mode(
    value,
    crud_dialog_base.Creating,
    ModeReceived,
  )
}

fn decode_card_id(_value: String) -> Result(Msg, Nil) {
  // Card ID is used with the card property, so we don't process it here
  Error(Nil)
}

fn card_property_decoder() -> Decoder(Msg) {
  use card <- decode.then(card_codec.card_decoder())
  use mode <- decode.field("_mode", decode.string)

  crud_dialog_base.decode_entity_mode(
    mode,
    card,
    crud_dialog_base.Editing,
    crud_dialog_base.Deleting,
    ModeReceived,
  )
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
    create_milestone_id: option.None,
    create_milestone_name: option.None,
    mode: crud_dialog_base.Closed,
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
    LocaleReceived(loc) -> #(Model(..model, locale: loc), effect.none())

    ProjectIdReceived(id) -> #(
      Model(..model, project_id: option.Some(id)),
      effect.none(),
    )

    MilestoneIdReceived(id) -> #(
      Model(..model, create_milestone_id: option.Some(id)),
      effect.none(),
    )

    MilestoneIdCleared -> #(
      Model(..model, create_milestone_id: option.None),
      effect.none(),
    )

    MilestoneNameReceived(name) -> #(
      Model(..model, create_milestone_name: option.Some(name)),
      effect.none(),
    )

    MilestoneNameCleared -> #(
      Model(..model, create_milestone_name: option.None),
      effect.none(),
    )

    ModeReceived(mode) -> handle_mode_received(model, mode)

    // Create form handlers
    CreateTitleChanged(title) -> #(
      Model(..model, create_title: title),
      effect.none(),
    )

    CreateDescriptionChanged(desc) -> #(
      Model(..model, create_description: desc),
      effect.none(),
    )

    CreateColorToggle -> #(
      Model(..model, create_color_open: !model.create_color_open),
      effect.none(),
    )

    CreateColorChanged(color) -> #(
      Model(..model, create_color: color, create_color_open: False),
      effect.none(),
    )

    CreateSubmitted -> handle_create_submitted(model)

    CreateResult(Ok(card)) -> handle_create_success(model, card)

    CreateResult(Error(err)) -> #(
      Model(
        ..model,
        create_in_flight: False,
        create_error: option.Some(err.message),
      ),
      effect.none(),
    )

    // Edit form handlers
    EditTitleChanged(title) -> #(
      Model(..model, edit_title: title),
      effect.none(),
    )

    EditDescriptionChanged(desc) -> #(
      Model(..model, edit_description: desc),
      effect.none(),
    )

    EditColorToggle -> #(
      Model(..model, edit_color_open: !model.edit_color_open),
      effect.none(),
    )

    EditColorChanged(color) -> #(
      Model(..model, edit_color: color, edit_color_open: False),
      effect.none(),
    )

    EditSubmitted -> handle_edit_submitted(model)

    EditResult(Ok(card)) -> handle_edit_success(model, card)

    EditResult(Error(err)) -> #(
      Model(
        ..model,
        edit_in_flight: False,
        edit_error: option.Some(err.message),
      ),
      effect.none(),
    )

    EditCancelled -> #(reset_edit_fields(model), emit_close_requested())

    // Delete handlers
    DeleteConfirmed -> handle_delete_confirmed(model)

    DeleteResult(Ok(_)) -> handle_delete_success(model)

    DeleteResult(Error(err)) -> handle_delete_error(model, err)

    DeleteCancelled -> #(reset_delete_fields(model), emit_close_requested())

    CloseRequested -> #(model, emit_close_requested())
  }
}

/// Test helper: exposes update transitions for deterministic unit tests.
pub fn update_for_test(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  update(model, msg)
}

fn handle_mode_received(model: Model, mode: DialogMode) -> #(Model, Effect(Msg)) {
  case mode {
    crud_dialog_base.Closed -> #(
      Model(..model, mode: crud_dialog_base.Closed),
      effect.none(),
    )

    crud_dialog_base.Creating -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Creating,
        create_title: "",
        create_description: "",
        create_color: option.None,
        create_color_open: False,
        create_in_flight: False,
        create_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Editing(card) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Editing(card),
        edit_title: card.title,
        edit_description: card.description,
        edit_color: option.map(card.color, color_to_string),
        edit_color_open: False,
        edit_in_flight: False,
        edit_error: option.None,
      ),
      effect.none(),
    )

    crud_dialog_base.Deleting(card) -> #(
      Model(
        ..model,
        mode: crud_dialog_base.Deleting(card),
        delete_in_flight: False,
        delete_error: option.None,
      ),
      effect.none(),
    )
  }
}

fn handle_create_submitted(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(
    model,
    model.create_in_flight,
    submit_create_title,
  )
}

fn submit_create_title(model: Model) -> #(Model, Effect(Msg)) {
  case crud_dialog_base.required_text(model.create_title) {
    Error(_) -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.TitleRequired)),
      ),
      effect.none(),
    )
    Ok(title) -> submit_create_with_title(model, title)
  }
}

fn submit_create_with_title(
  model: Model,
  title: String,
) -> #(Model, Effect(Msg)) {
  case model.project_id {
    option.Some(project_id) -> #(
      Model(..model, create_in_flight: True, create_error: option.None),
      api_cards.create_card(
        project_id,
        title,
        model.create_description,
        form_color_to_domain(model.create_color),
        model.create_milestone_id,
        CreateResult,
      ),
    )
    option.None -> #(
      Model(
        ..model,
        create_error: option.Some(t(model.locale, i18n_text.SelectProjectFirst)),
      ),
      effect.none(),
    )
  }
}

fn handle_create_success(model: Model, card: Card) -> #(Model, Effect(Msg)) {
  #(
    Model(
      ..model,
      mode: crud_dialog_base.Closed,
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
  crud_dialog_base.submit_if_idle(model, model.edit_in_flight, submit_edit)
}

fn submit_edit(model: Model) -> #(Model, Effect(Msg)) {
  case crud_dialog_base.required_text(model.edit_title) {
    Error(_) -> #(
      Model(
        ..model,
        edit_error: option.Some(t(model.locale, i18n_text.TitleRequired)),
      ),
      effect.none(),
    )
    Ok(title) -> submit_edit_with_title(model, title)
  }
}

fn submit_edit_with_title(model: Model, title: String) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Editing(card) -> #(
      Model(..model, edit_in_flight: True, edit_error: option.None),
      api_cards.update_card(
        card.id,
        title,
        model.edit_description,
        form_color_to_domain(model.edit_color),
        option.None,
        EditResult,
      ),
    )
    _ -> #(model, effect.none())
  }
}

fn form_color_to_domain(color: Option(String)) -> Option(color_picker.CardColor) {
  case color {
    option.None -> option.None
    option.Some(value) -> color_picker.string_to_color(value)
  }
}

fn handle_edit_success(model: Model, card: Card) -> #(Model, Effect(Msg)) {
  #(reset_edit_fields(model), emit_card_updated(card))
}

fn handle_delete_confirmed(model: Model) -> #(Model, Effect(Msg)) {
  crud_dialog_base.submit_if_idle(model, model.delete_in_flight, submit_delete)
}

fn submit_delete(model: Model) -> #(Model, Effect(Msg)) {
  case model.mode {
    crud_dialog_base.Deleting(card) -> #(
      Model(..model, delete_in_flight: True, delete_error: option.None),
      api_cards.delete_card(card.id, DeleteResult),
    )
    _ -> #(model, effect.none())
  }
}

fn handle_delete_success(model: Model) -> #(Model, Effect(Msg)) {
  let card_id = case model.mode {
    crud_dialog_base.Deleting(card) -> card.id
    _ -> 0
  }
  #(reset_delete_fields(model), emit_card_deleted(card_id))
}

fn handle_delete_error(model: Model, err: ApiError) -> #(Model, Effect(Msg)) {
  let error_msg = case err.status {
    409 -> t(model.locale, i18n_text.CardDeleteBlocked)
    _ -> err.message
  }
  #(
    Model(
      ..model,
      delete_in_flight: False,
      delete_error: option.Some(error_msg),
    ),
    effect.none(),
  )
}

fn reset_edit_fields(model: Model) -> Model {
  Model(
    ..model,
    mode: crud_dialog_base.Closed,
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
    mode: crud_dialog_base.Closed,
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
  let state_str = state_to_string(card.state)
  let color_fields = case card.color {
    option.Some(c) -> [#("color", json.string(color_to_string(c)))]
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
    crud_dialog_base.Closed -> element.none()
    crud_dialog_base.Creating -> view_create_dialog(model)
    crud_dialog_base.Editing(_card) -> view_edit_dialog(model)
    crud_dialog_base.Deleting(card) -> view_delete_dialog(model, card)
  }
}

fn view_card_fields(
  model: Model,
  title: String,
  description: String,
  color: Option(String),
  color_open: Bool,
  on_title_changed: fn(String) -> Msg,
  on_description_changed: fn(String) -> Msg,
  on_color_toggle: Msg,
  on_color_changed: fn(Option(String)) -> Msg,
  title_aria_label: Option(String),
  description_aria_label: Option(String),
  autofocus_title: Bool,
) -> List(Element(Msg)) {
  [
    form_field.view_required(
      t(model.locale, i18n_text.CardTitle),
      input(
        [
          attribute.type_("text"),
          attribute.value(title),
          event.on_input(on_title_changed),
          attribute.required(True),
        ]
        |> maybe_add_aria_label(title_aria_label)
        |> maybe_add_autofocus(autofocus_title),
      ),
    ),
    form_field.view(
      t(model.locale, i18n_text.CardDescription),
      input(
        [
          attribute.type_("text"),
          attribute.value(description),
          event.on_input(on_description_changed),
        ]
        |> maybe_add_aria_label(description_aria_label),
      ),
    ),
    form_field.view(
      t(model.locale, i18n_text.ColorLabel),
      view_color_picker(
        model.locale,
        color,
        color_open,
        on_color_toggle,
        on_color_changed,
      ),
    ),
  ]
}

fn maybe_add_aria_label(
  attrs: List(attribute.Attribute(Msg)),
  label: Option(String),
) -> List(attribute.Attribute(Msg)) {
  case label {
    option.Some(value) -> [attribute.attribute("aria-label", value), ..attrs]
    option.None -> attrs
  }
}

fn maybe_add_autofocus(
  attrs: List(attribute.Attribute(Msg)),
  should_autofocus: Bool,
) -> List(attribute.Attribute(Msg)) {
  case should_autofocus {
    True -> [attribute.autofocus(True), ..attrs]
    False -> attrs
  }
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  let dialog_class = case model.create_color_open {
    True -> "dialog dialog-md dialog-color-picker-open"
    False -> "dialog dialog-md"
  }

  crud_dialog_base.view_dialog_shell(
    dialog_class,
    modal_header.view_dialog_with_icon_and_close_label(
      t(model.locale, i18n_text.CreateCard),
      icons.nav_icon(icons.Cards, icons.Medium),
      CloseRequested,
      t(model.locale, i18n_text.Close),
    ),
    model.create_error,
    [
      form(
        [
          event.on_submit(fn(_) { CreateSubmitted }),
          attribute.id("card-create-form"),
        ],
        [
          view_create_milestone_context(model),
          ..view_card_fields(
            model,
            model.create_title,
            model.create_description,
            model.create_color,
            model.create_color_open,
            CreateTitleChanged,
            CreateDescriptionChanged,
            CreateColorToggle,
            CreateColorChanged,
            option.Some("Card title"),
            option.Some("Card description"),
            True,
          )
        ],
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, CloseRequested),
      crud_dialog_base.view_submit_button(
        "card-create-form",
        model.create_in_flight,
        t(model.locale, i18n_text.Create),
        t(model.locale, i18n_text.Creating),
      ),
    ],
  )
}

fn view_create_milestone_context(model: Model) -> Element(Msg) {
  case model.create_milestone_id {
    option.Some(milestone_id) ->
      form_field.view(
        t(model.locale, i18n_text.MilestoneTarget),
        div(
          [
            attribute.class("task-create-milestone-target"),
            attribute.attribute("data-testid", "card-create-milestone-context"),
            attribute.attribute(
              "aria-label",
              t(model.locale, i18n_text.MilestoneTarget),
            ),
          ],
          [text(milestone_target_text(model, milestone_id))],
        ),
      )
    option.None -> element.none()
  }
}

fn milestone_target_text(model: Model, milestone_id: Int) -> String {
  case model.create_milestone_name {
    option.Some(name) -> name
    option.None -> "#" <> int.to_string(milestone_id)
  }
}

fn view_edit_dialog(model: Model) -> Element(Msg) {
  let dialog_class = case model.edit_color_open {
    True -> "dialog dialog-md dialog-color-picker-open"
    False -> "dialog dialog-md"
  }

  crud_dialog_base.view_dialog_shell(
    dialog_class,
    modal_header.view_dialog_with_icon_and_close_label(
      t(model.locale, i18n_text.EditCard),
      icons.nav_icon(icons.Pencil, icons.Medium),
      EditCancelled,
      t(model.locale, i18n_text.Close),
    ),
    model.edit_error,
    [
      form(
        [
          event.on_submit(fn(_) { EditSubmitted }),
          attribute.id("card-edit-form"),
        ],
        view_card_fields(
          model,
          model.edit_title,
          model.edit_description,
          model.edit_color,
          model.edit_color_open,
          EditTitleChanged,
          EditDescriptionChanged,
          EditColorToggle,
          EditColorChanged,
          option.None,
          option.None,
          False,
        ),
      ),
    ],
    [
      crud_dialog_base.view_cancel_button(model.locale, EditCancelled),
      crud_dialog_base.view_submit_button(
        "card-edit-form",
        model.edit_in_flight,
        t(model.locale, i18n_text.Save),
        t(model.locale, i18n_text.Working),
      ),
    ],
  )
}

fn view_delete_dialog(model: Model, card: Card) -> Element(Msg) {
  crud_dialog_base.view_delete_dialog_shell(
    model.locale,
    t(model.locale, i18n_text.DeleteCard),
    icons.nav_icon(icons.Trash, icons.Medium),
    t(model.locale, i18n_text.CardDeleteConfirm(card.title)),
    model.delete_error,
    model.delete_in_flight,
    DeleteCancelled,
    DeleteConfirmed,
    t(model.locale, i18n_text.Removing),
  )
}

pub fn view_create_dialog_for_test(
  locale: Locale,
  milestone_id: Option(Int),
  milestone_name: Option(String),
) -> Element(Msg) {
  let model =
    Model(
      ..default_model(),
      locale: locale,
      mode: crud_dialog_base.Creating,
      create_milestone_id: milestone_id,
      create_milestone_name: milestone_name,
    )
  view_create_dialog(model)
}

pub fn view_edit_dialog_for_test(locale: Locale, card: Card) -> Element(Msg) {
  let model =
    Model(
      ..default_model(),
      locale: locale,
      mode: crud_dialog_base.Editing(card),
      edit_title: card.title,
      edit_description: card.description,
      edit_color: option.map(card.color, color_to_string),
    )
  view_edit_dialog(model)
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
    option.Some(c) -> color_picker.string_to_color(c)
  }

  let selected_label = case selected_color {
    option.None -> t(locale, i18n_text.ColorNone)
    option.Some(c) -> t(locale, color_picker.color_i18n_key(c))
  }

  div([attribute.class("color-picker" <> open_class)], [
    // Trigger button
    div(
      [
        attribute.class("color-picker-trigger"),
        attribute.attribute("role", "combobox"),
        attribute.attribute("aria-expanded", attribute_value.boolean(is_open)),
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
  ])
}

fn view_color_option(
  locale: Locale,
  color: Option(color_picker.CardColor),
  selected: Option(color_picker.CardColor),
  on_select: fn(Option(String)) -> Msg,
) -> Element(Msg) {
  let is_selected = color == selected

  let label_text = case color {
    option.None -> t(locale, i18n_text.ColorNone)
    option.Some(c) -> t(locale, color_picker.color_i18n_key(c))
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
      attribute.attribute("aria-selected", attribute_value.boolean(is_selected)),
      event.on_click(on_click_msg),
    ],
    [view_swatch(color), span([], [text(label_text)])],
  )
}

fn view_swatch(color: Option(color_picker.CardColor)) -> Element(Msg) {
  case color {
    option.None ->
      span(
        [attribute.class("color-picker-swatch color-picker-swatch-none")],
        [],
      )
    option.Some(c) ->
      span(
        [
          attribute.class("color-picker-swatch"),
          attribute.attribute(
            "style",
            "background: " <> color_picker.css_var(c),
          ),
        ],
        [],
      )
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
