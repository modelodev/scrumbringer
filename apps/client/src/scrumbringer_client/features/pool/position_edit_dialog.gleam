//// Manual task position edit dialog.

import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{input}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field

pub type Config(msg) {
  Config(
    locale: Locale,
    x: String,
    y: String,
    error: opt.Option(String),
    in_flight: Bool,
    on_close: msg,
    on_x_changed: fn(String) -> msg,
    on_y_changed: fn(String) -> msg,
    on_submit: msg,
  )
}

fn t(config: Config(msg), key: i18n_text.Text) -> String {
  i18n.t(config.locale, key)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  dialog.view_with_close_label(
    dialog.DialogConfig(
      title: t(config, i18n_text.EditPosition),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: config.on_close,
    ),
    t(config, i18n_text.Close),
    True,
    config.error,
    [
      form_field.view(
        t(config, i18n_text.XLabel),
        input([
          attribute.type_("number"),
          attribute.value(config.x),
          event.on_input(config.on_x_changed),
        ]),
      ),
      form_field.view(
        t(config, i18n_text.YLabel),
        input([
          attribute.type_("number"),
          attribute.value(config.y),
          event.on_input(config.on_y_changed),
        ]),
      ),
    ],
    [
      dialog.cancel_button_with_locale(config.locale, config.on_close),
      dialog.submit_button_with_locale_click(
        config.locale,
        config.on_submit,
        config.in_flight,
        False,
        i18n_text.Save,
        i18n_text.Saving,
      ),
    ],
  )
}
