import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text
import support/assertions.{assert_equal}

pub fn dependencies_labels_es_test() {
  i18n.t(locale.Es, text.Dependencies)
  |> assert_equal("Dependencias")

  i18n.t(locale.Es, text.AddDependency)
  |> assert_equal("Añadir dependencia")

  i18n.t(locale.Es, text.TaskDependsOn)
  |> assert_equal("Esta tarea depende de")

  i18n.t(locale.Es, text.BlockedByTasks(2))
  |> assert_equal("Bloqueada por 2 tareas")
}

pub fn dependencies_labels_en_test() {
  i18n.t(locale.En, text.Dependencies)
  |> assert_equal("Dependencies")

  i18n.t(locale.En, text.AddDependency)
  |> assert_equal("Add dependency")

  i18n.t(locale.En, text.TaskDependsOn)
  |> assert_equal("This task depends on")

  i18n.t(locale.En, text.BlockedByTasks(2))
  |> assert_equal("Blocked by 2 tasks")
}
