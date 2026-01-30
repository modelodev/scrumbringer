import domain/card.{type CardState, Cerrada, EnCurso, Pendiente}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn label(locale: Locale, state: CardState) -> String {
  case state {
    Pendiente -> i18n.t(locale, i18n_text.CardStatePendiente)
    EnCurso -> i18n.t(locale, i18n_text.CardStateEnCurso)
    Cerrada -> i18n.t(locale, i18n_text.CardStateCerrada)
  }
}
