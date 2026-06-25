import domain/task_status.{
  type TaskPhase, Available, Claimed, Done, Ongoing, Taken,
}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn label(locale: Locale, status: TaskPhase) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskStateAvailable)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskStateClaimed)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.TaskStateOngoing)
    Done -> i18n.t(locale, i18n_text.TaskStateDone)
  }
}

pub fn hint(locale: Locale, status: TaskPhase) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskStateAvailableHint)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskStateClaimedHint)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.TaskStateOngoingHint)
    Done -> i18n.t(locale, i18n_text.TaskStateDoneHint)
  }
}

pub fn next_action(locale: Locale, status: TaskPhase) -> String {
  case status {
    Available -> i18n.t(locale, i18n_text.TaskNextActionClaim)
    Claimed(Taken) -> i18n.t(locale, i18n_text.TaskNextActionStart)
    Claimed(Ongoing) -> i18n.t(locale, i18n_text.TaskNextActionPause)
    Done -> i18n.t(locale, i18n_text.TaskNextActionOpen)
  }
}

pub fn claim_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionClaim)
}

pub fn start_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionStart)
}

pub fn pause_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionPause)
}

pub fn claimed_hint(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskStateClaimedHint)
}

pub fn ongoing_hint(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskStateOngoingHint)
}

pub fn complete_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionComplete)
}

pub fn release_action(locale: Locale) -> String {
  i18n.t(locale, i18n_text.TaskNextActionRelease)
}
