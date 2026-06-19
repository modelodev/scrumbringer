import domain/card.{type CardPhase, Active, Closed, Draft}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn label(locale: Locale, state: CardPhase) -> String {
  case state {
    Draft -> i18n.t(locale, i18n_text.CardPhaseDraft)
    Active -> i18n.t(locale, i18n_text.CardPhaseActive)
    Closed -> i18n.t(locale, i18n_text.CardPhaseClosed)
  }
}
