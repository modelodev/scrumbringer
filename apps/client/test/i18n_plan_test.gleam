import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text

fn assert_equal(actual: String, expected: String) {
  let assert True = actual == expected
}

pub fn plan_labels_es_test() {
  i18n.t(locale.Es, text.PlanScope) |> assert_equal("Scope")
  i18n.t(locale.Es, text.PlanScopeProject) |> assert_equal("Proyecto")
  i18n.t(locale.Es, text.PlanScopeLevel) |> assert_equal("Nivel")
  i18n.t(locale.Es, text.PlanScopeCard) |> assert_equal("Card")
  i18n.t(locale.Es, text.PlanScopeSelectCard)
  |> assert_equal("Selecciona una card activa")
  i18n.t(locale.Es, text.PlanScopeNoActiveCards)
  |> assert_equal("Sin cards activas")
  i18n.t(locale.Es, text.PlanMode) |> assert_equal("Modo")
  i18n.t(locale.Es, text.PlanModeStructure) |> assert_equal("Estructura")
  i18n.t(locale.Es, text.PlanModeKanban) |> assert_equal("Kanban")
  i18n.t(locale.Es, text.PlanClosed) |> assert_equal("Cerradas")
  i18n.t(locale.Es, text.PlanEmptyCardScopeBody)
  |> assert_equal(
    "Busca una card para ver su subarbol, capacidades, tasks y riesgo.",
  )
  i18n.t(locale.Es, text.PlanEmptyScopeTitle)
  |> assert_equal("No hay cards en este scope.")
  i18n.t(locale.Es, text.PlanEmptyScopeBody)
  |> assert_equal(
    "Crea una card o cambia el scope para revisar otra parte del plan.",
  )
}

pub fn plan_labels_en_test() {
  i18n.t(locale.En, text.PlanScope) |> assert_equal("Scope")
  i18n.t(locale.En, text.PlanScopeProject) |> assert_equal("Project")
  i18n.t(locale.En, text.PlanScopeLevel) |> assert_equal("Level")
  i18n.t(locale.En, text.PlanScopeCard) |> assert_equal("Card")
  i18n.t(locale.En, text.PlanScopeSelectCard)
  |> assert_equal("Select an active card")
  i18n.t(locale.En, text.PlanScopeNoActiveCards)
  |> assert_equal("No active cards")
  i18n.t(locale.En, text.PlanMode) |> assert_equal("Mode")
  i18n.t(locale.En, text.PlanModeStructure) |> assert_equal("Structure")
  i18n.t(locale.En, text.PlanModeKanban) |> assert_equal("Kanban")
  i18n.t(locale.En, text.PlanClosed) |> assert_equal("Closed")
  i18n.t(locale.En, text.PlanEmptyCardScopeBody)
  |> assert_equal(
    "Search for a card to review its subtree, capabilities, tasks, and risk.",
  )
  i18n.t(locale.En, text.PlanEmptyScopeTitle)
  |> assert_equal("No cards in this scope.")
  i18n.t(locale.En, text.PlanEmptyScopeBody)
  |> assert_equal(
    "Create a card or change the scope to review another part of the plan.",
  )
}
