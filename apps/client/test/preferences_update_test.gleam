import lustre/effect

import scrumbringer_client/client_state
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/client_update
import scrumbringer_client/features/i18n/msg as i18n_messages
import scrumbringer_client/features/i18n/update as i18n_update
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme

pub fn invalid_theme_selection_is_noop_test() {
  let model =
    client_state.default_model()
    |> client_state.update_ui(fn(ui) {
      ui_state.UiModel(..ui, theme: theme.Dark)
    })

  let #(next_model, fx) =
    client_update.update(model, client_state.ThemeSelected("nope"))

  let assert theme.Dark = next_model.ui.theme
  let assert True = fx == effect.none()
}

pub fn invalid_locale_selection_is_noop_test() {
  let #(next_locale, fx) = i18n_update.update_locale(locale.Es, "fr-FR")

  let assert locale.Es = next_locale
  let assert True = fx == effect.none()
}

pub fn valid_locale_selection_updates_root_model_test() {
  let model =
    client_state.default_model()
    |> client_state.update_ui(fn(ui) {
      ui_state.UiModel(..ui, locale: locale.Es)
    })

  let #(next_model, _) =
    client_update.update(
      model,
      client_state.I18nMsg(i18n_messages.LocaleSelected("en")),
    )

  let assert locale.En = next_model.ui.locale
}
