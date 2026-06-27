import gleam/int
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/string

import gleam/dynamic/decode

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, input, label, option, select, text}
import lustre/event

import domain/card.{type Card}
import domain/card/card_codec
import domain/remote.{type Remote, Loaded}

import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/admin_surface
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/color_picker
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

pub type Config(msg) {
  Config(
    locale: Locale,
    project_id: Int,
    project_name: String,
    model: admin_cards.Model,
    detail_modal: Element(msg),
    on_create_opened: msg,
    on_search_changed: fn(String) -> msg,
    on_state_filter_changed: fn(String) -> msg,
    on_show_empty_toggled: msg,
    on_show_closed_toggled: msg,
    on_detail_opened: fn(Int) -> msg,
    on_task_create_opened: fn(Int) -> msg,
    on_edit_opened: fn(Int) -> msg,
    on_delete_opened: fn(Int) -> msg,
    on_dialog_closed: msg,
    on_card_created: fn(Card) -> msg,
    on_card_updated: fn(Card) -> msg,
    on_card_deleted: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  admin_surface.view_with_filters(
    section_header.view_with_action(
      icons.Cards,
      t(config, i18n_text.CardsTitle(config.project_name)),
      dialog.add_button_with_locale(
        config.locale,
        i18n_text.CreateCard,
        config.on_create_opened,
      ),
    ),
    view_filters(config),
    view_list(config, filter_cards(config.model)),
    [
      config.detail_modal,
    ],
  )
}

pub fn view_crud_dialog(config: Config(msg)) -> Element(msg) {
  case config.model.cards_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, card_json, parent_card_attr) = case mode {
        admin_cards.CardDialogCreate(parent_card_id) -> #(
          "create",
          attribute.none(),
          attribute.attribute(
            "parent-card-id",
            parent_card_id_attribute(parent_card_id),
          ),
        )
        admin_cards.CardDialogEdit(card_id) ->
          case find_card(config.model.cards, card_id) {
            opt.Some(card) -> #(
              "edit",
              attribute.property("card", card_to_property_json(card, "edit")),
              attribute.attribute("parent-card-id", "0"),
            )
            opt.None -> #(
              "edit",
              attribute.none(),
              attribute.attribute("parent-card-id", "0"),
            )
          }
        admin_cards.CardDialogDelete(card_id) ->
          case find_card(config.model.cards, card_id) {
            opt.Some(card) -> #(
              "delete",
              attribute.property("card", card_to_property_json(card, "delete")),
              attribute.attribute("parent-card-id", "0"),
            )
            opt.None -> #(
              "delete",
              attribute.none(),
              attribute.attribute("parent-card-id", "0"),
            )
          }
      }

      element.element(
        "card-crud-dialog",
        [
          attribute.attribute("locale", locale.serialize(config.locale)),
          attribute.attribute("project-id", int.to_string(config.project_id)),
          attribute.attribute("mode", mode_str),
          parent_card_attr,
          card_json,
          event.on("card-created", decode_card_created_event(config)),
          event.on("card-updated", decode_card_updated_event(config)),
          event.on("card-deleted", decode_card_deleted_event(config)),
          event.on("close-requested", decode.success(config.on_dialog_closed)),
        ],
        [],
      )
    }
  }
}

fn parent_card_id_attribute(parent_card_id: opt.Option(Int)) -> String {
  case parent_card_id {
    opt.Some(id) -> int.to_string(id)
    opt.None -> "0"
  }
}

fn view_filters(config: Config(msg)) -> Element(msg) {
  div(
    [
      attribute.class("filters-bar filters-inline"),
      attribute.attribute("data-testid", "cards-filters"),
    ],
    [
      div([attribute.class("filter-group filter-search")], [
        input([
          attribute.type_("search"),
          attribute.placeholder(t(config, i18n_text.SearchPlaceholder)),
          attribute.value(config.model.cards_search),
          event.on_input(config.on_search_changed),
        ]),
      ]),
      div([attribute.class("filter-group")], [
        label([], [text(t(config, i18n_text.CardPhase))]),
        select(
          [
            attribute.class("filter-select"),
            attribute.attribute("data-testid", "cards-state-filter"),
            event.on_input(config.on_state_filter_changed),
          ],
          [
            option(
              [
                attribute.value(""),
                attribute.selected(config.model.cards_state_filter == opt.None),
              ],
              t(config, i18n_text.AllOption),
            ),
            option(
              [
                attribute.value(card.state_to_string(card.Draft)),
                attribute.selected(
                  config.model.cards_state_filter == opt.Some(card.Draft),
                ),
              ],
              t(config, i18n_text.CardPhaseDraft),
            ),
            option(
              [
                attribute.value(card.state_to_string(card.Active)),
                attribute.selected(
                  config.model.cards_state_filter == opt.Some(card.Active),
                ),
              ],
              t(config, i18n_text.CardPhaseActive),
            ),
            option(
              [
                attribute.value(card.state_to_string(card.Closed)),
                attribute.selected(
                  config.model.cards_state_filter == opt.Some(card.Closed),
                ),
              ],
              t(config, i18n_text.CardPhaseClosed),
            ),
          ],
        ),
      ]),
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(config.model.cards_show_empty),
            attribute.attribute("data-testid", "show-empty-cards"),
            event.on_check(fn(_) { config.on_show_empty_toggled }),
          ]),
          text(t(config, i18n_text.ShowEmptyCards)),
        ]),
      ]),
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(config.model.cards_show_closed),
            attribute.attribute("data-testid", "show-closed-cards"),
            event.on_check(fn(_) { config.on_show_closed_toggled }),
          ]),
          text(t(config, i18n_text.ShowClosedCards)),
        ]),
      ]),
    ],
  )
}

fn filter_cards(model: admin_cards.Model) -> Remote(List(Card)) {
  case model.cards {
    Loaded(cards) -> {
      let filtered =
        cards
        |> list.filter(fn(c) {
          let state_match = case model.cards_state_filter {
            opt.None -> True
            opt.Some(state) -> c.state == state
          }
          let empty_match = case model.cards_show_empty {
            True -> True
            False -> c.task_count > 0
          }
          let closed_match = case model.cards_show_closed {
            True -> True
            False -> c.state != card.Closed
          }
          let search_match = case string.is_empty(model.cards_search) {
            True -> True
            False ->
              string.contains(
                string.lowercase(c.title),
                string.lowercase(model.cards_search),
              )
          }
          state_match && empty_match && closed_match && search_match
        })
      Loaded(filtered)
    }
    other -> other
  }
}

fn view_list(config: Config(msg), cards: Remote(List(Card))) -> Element(msg) {
  let empty_state =
    div([attribute.class("empty-state")], [
      div([attribute.class("empty-state-icon")], [
        icons.nav_icon(icons.ClipboardDoc, icons.Large),
      ]),
      div([attribute.class("empty-state-title")], [
        text(t(config, i18n_text.NoCardsYet)),
      ]),
      div([attribute.class("empty-state-description")], [
        text(t(config, i18n_text.MemberCardsEmptyHint)),
      ]),
    ])

  data_table.view_remote_with_forbidden(
    cards,
    loading_msg: t(config, i18n_text.LoadingEllipsis),
    empty_msg: "",
    forbidden_msg: t(config, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_empty_state(empty_state)
      |> data_table.with_columns([
        data_table.column_with_class(
          t(config, i18n_text.CardTitle),
          fn(c: Card) {
            let tooltip = t(config, i18n_text.NewNotesTooltip)
            card_title_meta.view_with_class(
              "card-title-with-color",
              button(
                [
                  attribute.class("card-title-button"),
                  attribute.attribute("data-testid", "card-show-open"),
                  event.on_click(config.on_detail_opened(c.id)),
                ],
                [text(c.title)],
              ),
              opt.map(c.color, color_picker.css_var),
              opt.Some("var(--sb-muted)"),
              c.has_new_notes,
              tooltip,
              card_title_meta.ColorTitleNotes,
            )
          },
          "",
          "card-title-cell",
        ),
        data_table.column(t(config, i18n_text.CardPhase), fn(c: Card) {
          card_state_badge.view(
            c.state,
            card_state.label(config.locale, c.state),
            card_state_badge.Table,
          )
        }),
        data_table.column(t(config, i18n_text.CardTasks), fn(c: Card) {
          card_progress.view(
            config.locale,
            c.closed_count,
            c.task_count,
            card_progress.Compact,
          )
        }),
        data_table.column_with_class(
          t(config, i18n_text.Actions),
          fn(c: Card) {
            div([], [
              action_buttons.create_task_in_card_button(
                t(config, i18n_text.NewTaskInCard(c.title)),
                config.on_task_create_opened(c.id),
              ),
              action_buttons.edit_button_with_testid(
                t(config, i18n_text.EditCard),
                config.on_edit_opened(c.id),
                "card-edit-btn",
              ),
              delete_card_action(config, c),
            ])
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(c) { int.to_string(c.id) }),
  )
}

fn delete_card_action(config: Config(msg), card: Card) -> Element(msg) {
  action_buttons.delete_button_with_availability_and_testid(
    t(config, i18n_text.DeleteCard),
    config.on_delete_opened(card.id),
    card_delete_availability(config, card),
    "card-delete-btn",
  )
}

fn card_delete_availability(
  config: Config(msg),
  card: Card,
) -> action_buttons.Availability {
  case card.task_count > 0 {
    True -> action_buttons.Blocked(t(config, i18n_text.CardDeleteBlocked))
    False -> action_buttons.Available
  }
}

fn find_card(cards: Remote(List(Card)), id: Int) -> opt.Option(Card) {
  case cards {
    Loaded(items) ->
      list.find(items, fn(c) { c.id == id })
      |> opt.from_result
    _ -> opt.None
  }
}

fn decode_card_created_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(card_codec.card_decoder(), fn(card) {
    decode.success(config.on_card_created(card))
  })
}

fn decode_card_updated_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(card_codec.card_decoder(), fn(card) {
    decode.success(config.on_card_updated(card))
  })
}

fn decode_card_deleted_event(config: Config(msg)) -> decode.Decoder(msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(config.on_card_deleted(id)) },
  )
}

fn card_to_property_json(c: Card, mode: String) -> json.Json {
  let color_field = case c.color {
    opt.Some(color) -> json.string(card.color_to_string(color))
    opt.None -> json.null()
  }
  json.object([
    #("id", json.int(c.id)),
    #("project_id", json.int(c.project_id)),
    #("parent_card_id", json.null()),
    #("title", json.string(c.title)),
    #("description", json.string(c.description)),
    #("color", color_field),
    #("state", json.string(card.state_to_string(c.state))),
    #("task_count", json.int(c.task_count)),
    #("closed_count", json.int(c.closed_count)),
    #("created_by", json.int(c.created_by)),
    #("created_at", json.string(c.created_at)),
    #("_mode", json.string(mode)),
  ])
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
