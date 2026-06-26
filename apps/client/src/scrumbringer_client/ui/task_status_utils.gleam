////
//// Task status helpers for labels and icons.
////

import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/task_state

import domain/task_status

pub fn label(locale: Locale, status: task_status.TaskPhase) -> String {
  task_state.label(locale, status)
}
