import lustre/element.{type Element}

import domain/card.{type Card}

import scrumbringer_client/client_state/member/pool as pool_state
import scrumbringer_client/features/pool/create_dialog
import scrumbringer_client/i18n/locale.{type Locale}

pub fn view(
  locale: Locale,
  pool: pool_state.Model,
  cards: List(Card),
  on_close: msg,
  on_submit: msg,
  on_title_changed: fn(String) -> msg,
  on_description_changed: fn(String) -> msg,
  on_priority_changed: fn(String) -> msg,
  on_type_id_changed: fn(String) -> msg,
  on_type_options_retry_clicked: msg,
  on_card_id_changed: fn(String) -> msg,
) -> Element(msg) {
  create_dialog.view(from_state(
    locale,
    pool,
    cards,
    on_close,
    on_submit,
    on_title_changed,
    on_description_changed,
    on_priority_changed,
    on_type_id_changed,
    on_type_options_retry_clicked,
    on_card_id_changed,
  ))
}

pub fn from_state(
  locale: Locale,
  pool: pool_state.Model,
  cards: List(Card),
  on_close: msg,
  on_submit: msg,
  on_title_changed: fn(String) -> msg,
  on_description_changed: fn(String) -> msg,
  on_priority_changed: fn(String) -> msg,
  on_type_id_changed: fn(String) -> msg,
  on_type_options_retry_clicked: msg,
  on_card_id_changed: fn(String) -> msg,
) -> create_dialog.Config(msg) {
  create_dialog.Config(
    locale: locale,
    error: pool.member_create_error,
    title: pool.member_create_title,
    description: pool.member_create_description,
    priority: pool.member_create_priority,
    type_id: pool.member_create_type_id,
    card_id: pool.member_create_card_id,
    milestone_id: pool.member_create_milestone_id,
    in_flight: pool.member_create_in_flight,
    task_types: pool.member_task_types,
    milestones: pool.member_milestones,
    cards: cards,
    on_close: on_close,
    on_submit: on_submit,
    on_title_changed: on_title_changed,
    on_description_changed: on_description_changed,
    on_priority_changed: on_priority_changed,
    on_type_id_changed: on_type_id_changed,
    on_type_options_retry_clicked: on_type_options_retry_clicked,
    on_card_id_changed: on_card_id_changed,
  )
}
