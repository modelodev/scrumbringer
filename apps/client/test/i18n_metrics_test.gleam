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

fn assert_no_complete_word(copy: String) {
  let assert False = string.contains(copy, "complete")
  let assert False = string.contains(copy, "Complete")
}

pub fn english_metrics_copy_uses_close_vocabulary_test() {
  let labels = [
    i18n.t(locale.En, text.AvgClaimToClose),
    i18n.t(locale.En, text.Closures),
  ]

  list.each(labels, assert_no_complete_word)
  i18n.t(locale.En, text.AvgClaimToClose)
  |> assert_equal("Avg claim → close")
  i18n.t(locale.En, text.Closures) |> assert_equal("Closures")
}

pub fn spanish_metrics_copy_uses_localized_claim_vocabulary_test() {
  let labels = [
    i18n.t(locale.Es, text.HealthTimeToFirstClaim),
    i18n.t(locale.Es, text.AvgClaimToClose),
    i18n.t(locale.Es, text.AvgTimeInClaimed),
    i18n.t(locale.Es, text.StaleClaims),
    i18n.t(locale.Es, text.LastClaim),
    i18n.t(locale.Es, text.TimeToFirstClaim),
    i18n.t(locale.Es, text.Claims),
    i18n.t(locale.Es, text.FirstClaim),
  ]

  list.each(labels, assert_no_claim_word)
  i18n.t(locale.Es, text.Claims) |> assert_equal("Reclamaciones")
  i18n.t(locale.Es, text.Closures) |> assert_equal("Cierres")
  i18n.t(locale.Es, text.WipCount) |> assert_equal("Trabajo en curso")
}
