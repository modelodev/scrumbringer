import gleam/string

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

fn assert_non_empty(value: String) {
  let assert True =
    value
    |> string.trim
    |> string.length
    |> fn(length) { length > 0 }
}

pub fn i18n_smoke_selected_texts_en_test() {
  assert_non_empty(i18n.t(locale.En, text.AppName))
  let assert "Sign in" = i18n.t(locale.En, text.LoginTitle)
  assert_non_empty(i18n.t(locale.En, text.AcceptInviteTitle))
  assert_non_empty(i18n.t(locale.En, text.ResetPasswordTitle))
  assert_non_empty(i18n.t(locale.En, text.NowWorking))
  assert_non_empty(i18n.t(locale.En, text.PopoverType))
  assert_non_empty(i18n.t(locale.En, text.CreatedAgoDays(1)))
  let assert "Capabilities saved" = i18n.t(locale.En, text.SkillsSaved)
  let assert "My capabilities" = i18n.t(locale.En, text.MySkills)
  let assert "Could not close task" = i18n.t(locale.En, text.TaskCloseFailed)
}

pub fn i18n_smoke_selected_texts_es_test() {
  assert_non_empty(i18n.t(locale.Es, text.AppName))
  assert_non_empty(i18n.t(locale.Es, text.LoginTitle))
  assert_non_empty(i18n.t(locale.Es, text.AcceptInviteTitle))
  assert_non_empty(i18n.t(locale.Es, text.ResetPasswordTitle))
  assert_non_empty(i18n.t(locale.Es, text.NowWorking))
  assert_non_empty(i18n.t(locale.Es, text.PopoverType))
  assert_non_empty(i18n.t(locale.Es, text.CreatedAgoDays(2)))
  let assert "Capacidades guardadas" = i18n.t(locale.Es, text.SkillsSaved)
  let assert "Mis capacidades" = i18n.t(locale.Es, text.MySkills)
  let assert "Tarea cerrada" = i18n.t(locale.Es, text.TaskDone)
  let assert "en curso" = i18n.t(locale.Es, text.InProgress)
  let assert "No se pudo cerrar la tarea" =
    i18n.t(locale.Es, text.TaskCloseFailed)
}
