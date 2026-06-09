//// Pure member cards list view.

import gleam/list
import gleam/option

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}
import lustre/event

import domain/card.{type Card}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/loading
import scrumbringer_client/ui/task_color

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    pending_count: Int,
    on_card_opened: fn(Int) -> msg,
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  case list.is_empty(config.cards) {
    True ->
      case config.pending_count > 0 {
        True -> loading.loading(t(config, i18n_text.LoadingEllipsis))
        False -> view_empty_state(config)
      }
    False -> view_cards_list(config)
  }
}

fn view_empty_state(config: Config(msg)) -> Element(msg) {
  empty_state.new(
    "clipboard-document-list",
    t(config, i18n_text.MemberFichasEmpty),
    t(config, i18n_text.MemberFichasEmptyHint),
  )
  |> empty_state.view
}

fn view_cards_list(config: Config(msg)) -> Element(msg) {
  div(
    [attribute.class("fichas-list")],
    list.map(config.cards, fn(card) { view_card_item(config, card) }),
  )
}

fn view_card_item(config: Config(msg), card: Card) -> Element(msg) {
  let border_class = task_color.card_border_class(card.color)
  let state_label = card_state.label(config.locale, card.state)

  let header_title_elements =
    card_title_meta.elements(
      span([attribute.class("ficha-title")], [text(card.title)]),
      option.None,
      option.None,
      card.has_new_notes,
      t(config, i18n_text.NewNotesTooltip),
      card_title_meta.TitleNotesColor,
    )

  let header_children =
    list.append(header_title_elements, [
      card_state_badge.view(card.state, state_label, card_state_badge.Ficha),
    ])

  div(
    [
      attribute.class("ficha-card " <> border_class),
      event.on_click(config.on_card_opened(card.id)),
      attribute.attribute("role", "button"),
      attribute.attribute("tabindex", "0"),
    ],
    [
      div([attribute.class("ficha-header")], header_children),
      case card.description {
        "" -> element.none()
        desc -> div([attribute.class("ficha-description")], [text(desc)])
      },
      div([attribute.class("ficha-meta")], [
        card_progress.view(
          card.completed_count,
          card.task_count,
          card_progress.Compact,
        ),
      ]),
    ],
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}
