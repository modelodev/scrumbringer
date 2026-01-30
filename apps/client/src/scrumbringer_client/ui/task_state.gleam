import domain/task_status.{
  type TaskStatus, Available, Claimed, Completed, Ongoing, Taken,
}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn label(locale: Locale, status: TaskStatus) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskStateAvailable)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskStateClaimed)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.NowWorking)
    Completed -> i18n.t(locale, i18n_text.TaskStateCompleted)
  }
}
