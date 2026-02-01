import gleeunit/should

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

pub fn release_all_labels_es_test() {
  i18n.t(locale.Es, text.ReleaseAll)
  |> should.equal("Liberar todas")

  i18n.t(locale.Es, text.ClaimedTasks(3))
  |> should.equal("3 reclamadas")

  i18n.t(locale.Es, text.ReleaseAllConfirmTitle)
  |> should.equal("Confirmar liberación")

  i18n.t(locale.Es, text.ReleaseAllConfirmBody(3, "Ana"))
  |> should.equal("Vas a liberar 3 tareas de Ana. Las tareas volverán al pool.")

  i18n.t(locale.Es, text.ReleaseAllSelfError)
  |> should.equal("No puedes liberar tus propias tareas")
}

pub fn release_all_labels_en_test() {
  i18n.t(locale.En, text.ReleaseAll)
  |> should.equal("Release all")

  i18n.t(locale.En, text.ClaimedTasks(3))
  |> should.equal("3 claimed")

  i18n.t(locale.En, text.ReleaseAllConfirmTitle)
  |> should.equal("Confirm release")

  i18n.t(locale.En, text.ReleaseAllConfirmBody(3, "Ana"))
  |> should.equal(
    "You are about to release 3 tasks from Ana. The tasks will return to the pool.",
  )

  i18n.t(locale.En, text.ReleaseAllSelfError)
  |> should.equal("You cannot release your own tasks")
}
