import lustre/element.{type Element}

import domain/card.{type Card}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import gleam/option as opt

import scrumbringer_client/client_state/member/pool as pool_state
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/pool/create_dialog
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn view(
  locale: Locale,
  pool: pool_state.Model,
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
  on_close: msg,
  on_submit: msg,
  on_title_changed: fn(String) -> msg,
  on_description_changed: fn(String) -> msg,
  on_priority_changed: fn(String) -> msg,
  on_type_id_changed: fn(String) -> msg,
  on_card_id_changed: fn(String) -> msg,
  on_card_query_changed: fn(String) -> msg,
  on_type_options_retry_clicked: msg,
  on_card_options_retry_clicked: msg,
) -> Element(msg) {
  create_dialog.view(from_state(
    locale,
    pool,
    cards,
    depth_names,
    on_close,
    on_submit,
    on_title_changed,
    on_description_changed,
    on_priority_changed,
    on_type_id_changed,
    on_card_id_changed,
    on_card_query_changed,
    on_type_options_retry_clicked,
    on_card_options_retry_clicked,
  ))
}

pub fn from_state(
  locale: Locale,
  pool: pool_state.Model,
  cards: List(Card),
  depth_names: List(scope_view.DepthName),
  on_close: msg,
  on_submit: msg,
  on_title_changed: fn(String) -> msg,
  on_description_changed: fn(String) -> msg,
  on_priority_changed: fn(String) -> msg,
  on_type_id_changed: fn(String) -> msg,
  on_card_id_changed: fn(String) -> msg,
  on_card_query_changed: fn(String) -> msg,
  on_type_options_retry_clicked: msg,
  on_card_options_retry_clicked: msg,
) -> create_dialog.Config(msg) {
  create_dialog.Config(
    locale: locale,
    error: pool.member_create_error,
    title: pool.member_create_title,
    description: pool.member_create_description,
    priority: pool.member_create_priority,
    type_id: pool.member_create_type_id,
    card_id: pool.member_create_card_id,
    card_query: pool.member_create_card_query,
    in_flight: pool.member_create_in_flight,
    task_types: pool.member_task_types,
    cards: cards,
    cards_loading: cards_loading(pool),
    cards_error: cards_error(locale, pool),
    depth_names: depth_names,
    on_close: on_close,
    on_submit: on_submit,
    on_title_changed: on_title_changed,
    on_description_changed: on_description_changed,
    on_priority_changed: on_priority_changed,
    on_type_id_changed: on_type_id_changed,
    on_card_id_changed: on_card_id_changed,
    on_card_query_changed: on_card_query_changed,
    on_type_options_retry_clicked: on_type_options_retry_clicked,
    on_card_options_retry_clicked: on_card_options_retry_clicked,
  )
}

fn cards_loading(pool: pool_state.Model) -> Bool {
  case pool.member_cards {
    NotAsked | Loading -> True
    Loaded(_) | Failed(_) -> False
  }
}

fn cards_error(locale: Locale, pool: pool_state.Model) -> opt.Option(String) {
  case pool.member_cards {
    Failed(_) -> opt.Some(i18n.t(locale, i18n_text.TaskCreateCardsLoadFailed))
    NotAsked | Loading | Loaded(_) -> opt.None
  }
}
