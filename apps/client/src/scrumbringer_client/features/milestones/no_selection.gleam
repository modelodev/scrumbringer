import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, p, text}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn view(locale: Locale) -> Element(msg) {
  div([attribute.class("milestone-detail-pane milestone-detail-empty")], [
    h3([], [
      text(i18n.t(locale, i18n_text.MilestoneNoSelection)),
    ]),
    p([], [
      text(i18n.t(locale, i18n_text.MilestoneNoSelectionHint)),
    ]),
  ])
}
