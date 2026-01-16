import gleam/string
import gleeunit/should

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

fn assert_non_empty(value: String) {
  value
  |> string.trim
  |> string.length
  |> should.not_equal(0)
}

pub fn i18n_smoke_selected_texts_en_test() {
  assert_non_empty(i18n.t(locale.En, text.AppName))
  assert_non_empty(i18n.t(locale.En, text.LoginTitle))
  assert_non_empty(i18n.t(locale.En, text.AcceptInviteTitle))
  assert_non_empty(i18n.t(locale.En, text.ResetPasswordTitle))
  assert_non_empty(i18n.t(locale.En, text.NowWorking))
  assert_non_empty(i18n.t(locale.En, text.PopoverType))
  assert_non_empty(i18n.t(locale.En, text.CreatedAgoDays(1)))
}

pub fn i18n_smoke_selected_texts_es_test() {
  assert_non_empty(i18n.t(locale.Es, text.AppName))
  assert_non_empty(i18n.t(locale.Es, text.LoginTitle))
  assert_non_empty(i18n.t(locale.Es, text.AcceptInviteTitle))
  assert_non_empty(i18n.t(locale.Es, text.ResetPasswordTitle))
  assert_non_empty(i18n.t(locale.Es, text.NowWorking))
  assert_non_empty(i18n.t(locale.Es, text.PopoverType))
  assert_non_empty(i18n.t(locale.Es, text.CreatedAgoDays(2)))
}
