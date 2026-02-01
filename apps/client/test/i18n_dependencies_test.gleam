import gleeunit/should

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

pub fn dependencies_labels_es_test() {
  i18n.t(locale.Es, text.Dependencies)
  |> should.equal("Dependencias")

  i18n.t(locale.Es, text.AddDependency)
  |> should.equal("Añadir dependencia")

  i18n.t(locale.Es, text.TaskDependsOn)
  |> should.equal("Esta tarea depende de")

  i18n.t(locale.Es, text.BlockedByTasks(2))
  |> should.equal("Bloqueada por 2 tareas")
}

pub fn dependencies_labels_en_test() {
  i18n.t(locale.En, text.Dependencies)
  |> should.equal("Dependencies")

  i18n.t(locale.En, text.AddDependency)
  |> should.equal("Add dependency")

  i18n.t(locale.En, text.TaskDependsOn)
  |> should.equal("This task depends on")

  i18n.t(locale.En, text.BlockedByTasks(2))
  |> should.equal("Blocked by 2 tasks")
}
