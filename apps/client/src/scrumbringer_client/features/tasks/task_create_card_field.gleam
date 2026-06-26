//// Card target field for creating tasks.

import gleam/option as opt

import lustre/element.{type Element}

import domain/card.{type Card}
import scrumbringer_client/features/cards/card_target
import scrumbringer_client/features/cards/card_target_field
import scrumbringer_client/features/cards/card_target_picker
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub type Config(msg) {
  Config(
    locale: Locale,
    cards: List(Card),
    depth_names: List(scope_view.DepthName),
    selected_card_id: opt.Option(Int),
    query: String,
    loading: Bool,
    error: opt.Option(String),
    disabled: Bool,
    on_query_changed: fn(String) -> msg,
    on_selected: fn(String) -> msg,
    on_retry: opt.Option(msg),
  )
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let options = card_target.task_card_targets(config.cards, config.depth_names)
  let filtered_options = card_target.filter_options(options, config.query)
  let presentation =
    card_target_picker.present(
      filtered_options,
      config.query,
      config.selected_card_id,
      card_target_picker.CreateTask,
      i18n.t(config.locale, i18n_text.CardPickerSearchAllCardsHint),
      i18n.t(config.locale, i18n_text.CardPickerRefineSearchHint),
    )

  card_target_field.view(card_target_field.Config(
    label: i18n.t(config.locale, i18n_text.TaskCreateActiveCardLabel),
    placeholder: i18n.t(config.locale, i18n_text.TaskCreateRequiresCard),
    selected_label: card_target.selected_label(options, config.selected_card_id),
    query: config.query,
    options: presentation.options,
    loading: config.loading,
    error: config.error,
    disabled: config.disabled,
    empty_title: i18n.t(config.locale, i18n_text.TaskCreateNoActiveCards),
    empty_body: i18n.t(config.locale, i18n_text.TaskCreateRequiresCard),
    loading_label: i18n.t(config.locale, i18n_text.LoadingEllipsis),
    retry_label: i18n.t(config.locale, i18n_text.Retry),
    hint: presentation.hint,
    show_empty: presentation.show_empty,
    listbox_id: "task-create-card-options",
    testid_prefix: "task-create-card",
    disabled_reason_label: fn(reason) {
      card_target.disabled_reason_label(config.locale, reason)
    },
    on_query_changed: config.on_query_changed,
    on_selected: config.on_selected,
    on_retry: config.on_retry,
  ))
}
