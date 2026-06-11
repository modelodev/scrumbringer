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
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.TaskStateOngoing)
    Completed -> i18n.t(locale, i18n_text.TaskStateCompleted)
  }
}

pub fn hint(locale: Locale, status: TaskStatus) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskStateAvailableHint)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskStateClaimedHint)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.TaskStateOngoingHint)
    Completed -> i18n.t(locale, i18n_text.TaskStateCompletedHint)
  }
}

pub fn next_action(locale: Locale, status: TaskStatus) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskNextActionClaim)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskNextActionStart)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.TaskNextActionPause)
    Completed -> i18n.t(locale, i18n_text.TaskNextActionOpen)
  }
}

pub fn complete_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionComplete)
}

pub fn release_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionRelease)
}
