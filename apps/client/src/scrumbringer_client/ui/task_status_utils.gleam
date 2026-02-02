////
//// Task status helpers for labels and icons.
////

import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_state

import domain/task_status

pub fn label(locale: Locale, status: task_status.TaskStatus) -> String {
  task_state.label(locale, status)
}

pub fn claimed_icon(status: task_status.TaskStatus) -> icons.NavIcon {
  case status {
    task_status.Claimed(task_status.Ongoing) -> icons.Play
    task_status.Claimed(task_status.Taken) -> icons.Pause
    _ -> icons.Pause
  }
}
