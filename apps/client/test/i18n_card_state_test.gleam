import domain/card.{Active, Closed, Draft}
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale
import scrumbringer_client/i18n/text
import scrumbringer_client/ui/card_state

pub fn spanish_card_phase_labels_are_localized_test() {
  let assert "Por iniciar" = card_state.label(locale.Es, Draft)
  let assert "En curso" = card_state.label(locale.Es, Active)
  let assert "Cerrada" = card_state.label(locale.Es, Closed)
}

pub fn spanish_kanban_summary_uses_tarjetas_test() {
  let assert "Tarjetas" = i18n.t(locale.Es, text.KanbanSummaryCards)
}

pub fn spanish_card_action_blockers_are_localized_test() {
  let assert "Las tarjetas cerradas no pueden recibir tarjetas hijas ni tareas nuevas." =
    i18n.t(locale.Es, text.CardClosedCannotReceiveChildren)
  let assert "Esta tarjeta tiene historial operativo. Ciérrala en lugar de eliminarla." =
    i18n.t(locale.Es, text.CardHasOperationalHistory)
  let assert "Solo los managers del proyecto pueden activar una jerarquía de tarjetas." =
    i18n.t(locale.Es, text.ActivateHierarchyManagerOnly)
}
