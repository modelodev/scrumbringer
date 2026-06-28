import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

pub fn release_all_labels_es_test() {
  let assert "Liberar todas" = i18n.t(locale.Es, text.ReleaseAll)

  let assert "Confirmar liberación" =
    i18n.t(locale.Es, text.ReleaseAllConfirmTitle)

  let assert "Vas a liberar 3 tareas de Ana. Las tareas volverán al pool." =
    i18n.t(locale.Es, text.ReleaseAllConfirmBody(3, "Ana"))

  let assert "No puedes liberar tus propias tareas" =
    i18n.t(locale.Es, text.ReleaseAllSelfError)
}

pub fn release_all_labels_en_test() {
  let assert "Release all" = i18n.t(locale.En, text.ReleaseAll)

  let assert "Confirm release" = i18n.t(locale.En, text.ReleaseAllConfirmTitle)

  let expected =
    "You are about to release 3 tasks from Ana. The tasks will return to the pool."
  let assert True =
    i18n.t(locale.En, text.ReleaseAllConfirmBody(3, "Ana")) == expected

  let assert "You cannot release your own tasks" =
    i18n.t(locale.En, text.ReleaseAllSelfError)
}
