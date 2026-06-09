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
import domain/card/codec as card_codec
import domain/milestone.{type MilestoneProgress}
import domain/remote.{type Remote, Loaded}

import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
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
    milestones: Remote(List(MilestoneProgress)),
    detail_modal: Element(msg),
    on_create_opened: msg,
    on_search_changed: fn(String) -> msg,
    on_state_filter_changed: fn(String) -> msg,
    on_show_empty_toggled: msg,
    on_show_completed_toggled: msg,
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
  div([attribute.class("section")], [
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
    view_crud_dialog(config),
    config.detail_modal,
  ])
}

pub fn view_crud_dialog(config: Config(msg)) -> Element(msg) {
  case config.model.cards_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let milestone_name =
        resolve_create_milestone_name(config)
        |> milestone_name_or_empty

      let #(mode_str, card_json) = case mode {
        state_types.CardDialogCreate -> #("create", attribute.none())
        state_types.CardDialogEdit(card_id) ->
          case find_card(config.model.cards, card_id) {
            opt.Some(card) -> #(
              "edit",
              attribute.property("card", card_to_property_json(card, "edit")),
            )
            opt.None -> #("edit", attribute.none())
          }
        state_types.CardDialogDelete(card_id) ->
          case find_card(config.model.cards, card_id) {
            opt.Some(card) -> #(
              "delete",
              attribute.property("card", card_to_property_json(card, "delete")),
            )
            opt.None -> #("delete", attribute.none())
          }
      }

      element.element(
        "card-crud-dialog",
        [
          attribute.attribute("locale", locale.serialize(config.locale)),
          attribute.attribute("project-id", int.to_string(config.project_id)),
          attribute.attribute(
            "milestone-id",
            case config.model.cards_create_milestone_id {
              opt.Some(id) -> int.to_string(id)
              opt.None -> ""
            },
          ),
          attribute.attribute("milestone-name", milestone_name),
          attribute.attribute("mode", mode_str),
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
        label([], [text(t(config, i18n_text.CardState))]),
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
                attribute.value(card.state_to_string(card.Pendiente)),
                attribute.selected(
                  config.model.cards_state_filter == opt.Some(card.Pendiente),
                ),
              ],
              t(config, i18n_text.CardStatePendiente),
            ),
            option(
              [
                attribute.value(card.state_to_string(card.EnCurso)),
                attribute.selected(
                  config.model.cards_state_filter == opt.Some(card.EnCurso),
                ),
              ],
              t(config, i18n_text.CardStateEnCurso),
            ),
            option(
              [
                attribute.value(card.state_to_string(card.Cerrada)),
                attribute.selected(
                  config.model.cards_state_filter == opt.Some(card.Cerrada),
                ),
              ],
              t(config, i18n_text.CardStateCerrada),
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
            attribute.checked(config.model.cards_show_completed),
            attribute.attribute("data-testid", "show-completed-cards"),
            event.on_check(fn(_) { config.on_show_completed_toggled }),
          ]),
          text(t(config, i18n_text.ShowCompletedCards)),
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
          let completed_match = case model.cards_show_completed {
            True -> True
            False -> c.state != card.Cerrada
          }
          let search_match = case string.is_empty(model.cards_search) {
            True -> True
            False ->
              string.contains(
                string.lowercase(c.title),
                string.lowercase(model.cards_search),
              )
          }
          state_match && empty_match && completed_match && search_match
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
        text(t(config, i18n_text.MemberFichasEmptyHint)),
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
                  attribute.attribute("data-testid", "card-detail-open"),
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
        data_table.column(t(config, i18n_text.CardState), fn(c: Card) {
          card_state_badge.view(
            c.state,
            card_state.label(config.locale, c.state),
            card_state_badge.Table,
          )
        }),
        data_table.column(t(config, i18n_text.CardTasks), fn(c: Card) {
          card_progress.view(
            c.completed_count,
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
              action_buttons.delete_button_with_testid(
                t(config, i18n_text.DeleteCard),
                config.on_delete_opened(c.id),
                "card-delete-btn",
              ),
            ])
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(c) { int.to_string(c.id) }),
  )
}

fn resolve_create_milestone_name(config: Config(msg)) -> opt.Option(String) {
  case config.model.cards_create_milestone_id, config.milestones {
    opt.Some(milestone_id), Loaded(items) ->
      list.find_map(items, fn(progress) {
        case progress.milestone.id == milestone_id {
          True -> Ok(progress.milestone.name)
          False -> Error(Nil)
        }
      })
      |> opt.from_result
    _, _ -> opt.None
  }
}

fn milestone_name_or_empty(name: opt.Option(String)) -> String {
  case name {
    opt.None -> ""
    opt.Some(value) -> value
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
  let milestone_field = case c.milestone_id {
    opt.Some(id) -> json.int(id)
    opt.None -> json.null()
  }
  json.object([
    #("id", json.int(c.id)),
    #("project_id", json.int(c.project_id)),
    #("milestone_id", milestone_field),
    #("title", json.string(c.title)),
    #("description", json.string(c.description)),
    #("color", color_field),
    #("state", json.string(card.state_to_string(c.state))),
    #("task_count", json.int(c.task_count)),
    #("completed_count", json.int(c.completed_count)),
    #("created_by", json.int(c.created_by)),
    #("created_at", json.string(c.created_at)),
    #("_mode", json.string(mode)),
  ])
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
