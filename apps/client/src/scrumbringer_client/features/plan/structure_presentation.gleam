//// Pure presentation helpers for Plan structure rows.

import gleam/int

import domain/card.{type Card, Active, Closed, Draft}

import scrumbringer_client/features/plan/types
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/card_state as card_state_ui
import scrumbringer_client/ui/tone

pub fn card_state_label(locale: Locale, card: Card) -> String {
  card_state_ui.label(locale, card.state)
}

pub fn card_state_tone(card: Card) -> tone.Tone {
  case card.state {
    Draft -> tone.Warning
    Active -> tone.Available
    Closed -> tone.Neutral
  }
}

pub fn pool_impact_label(card: Card, rollup: types.CardRollup) -> String {
  case card.state {
    Draft ->
      case rollup.pool_impact {
        0 -> "0"
        impact -> "+" <> int.to_string(impact) <> " tareas"
      }
    Active -> "ya activo"
    Closed -> "-"
  }
}

pub fn pool_impact_tone(card: Card) -> tone.Tone {
  case card.state {
    Draft -> tone.Warning
    Active -> tone.Available
    Closed -> tone.Neutral
  }
}
