import gleam/list
import gleam/string

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

fn assert_equal(actual: String, expected: String) {
  let assert True = actual == expected
}

fn assert_no_claim_word(copy: String) {
  let assert False = string.contains(copy, "claim")
  let assert False = string.contains(copy, "Claim")
}

pub fn spanish_metrics_copy_uses_localized_claim_vocabulary_test() {
  let labels = [
    i18n.t(locale.Es, text.HealthTimeToFirstClaim),
    i18n.t(locale.Es, text.AvgClaimToComplete),
    i18n.t(locale.Es, text.AvgTimeInClaimed),
    i18n.t(locale.Es, text.StaleClaims),
    i18n.t(locale.Es, text.LastClaim),
    i18n.t(locale.Es, text.TimeToFirstClaim),
    i18n.t(locale.Es, text.Claims),
    i18n.t(locale.Es, text.FirstClaim),
    i18n.t(locale.Es, text.MetricsFirstClaimAt),
  ]

  list.each(labels, assert_no_claim_word)
  i18n.t(locale.Es, text.Claims) |> assert_equal("Reclamaciones")
  i18n.t(locale.Es, text.Completes) |> assert_equal("Cierres")
  i18n.t(locale.Es, text.WipCount) |> assert_equal("Trabajo en curso")
  i18n.t(locale.Es, text.Tracking) |> assert_equal("Seguimiento")
}
