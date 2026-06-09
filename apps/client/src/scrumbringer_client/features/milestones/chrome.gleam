import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, text}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn loading(locale: Locale) -> Element(msg) {
  div([attribute.class("milestones-state milestones-loading")], [
    text(i18n.t(locale, i18n_text.LoadingEllipsis)),
  ])
}

pub fn error(locale: Locale) -> Element(msg) {
  div([attribute.class("milestones-state milestones-error")], [
    text(i18n.t(locale, i18n_text.MilestonesLoadError)),
  ])
}

pub fn header(locale: Locale, actions: Element(msg)) -> Element(msg) {
  div([attribute.class("milestones-header")], [
    div([attribute.class("milestones-header-main")], [
      h3([attribute.class("milestones-title")], [
        text(i18n.t(locale, i18n_text.Milestones)),
      ]),
      div([attribute.class("milestones-toolbar-actions")], [
        actions,
      ]),
    ]),
  ])
}
