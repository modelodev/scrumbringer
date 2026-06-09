import domain/milestone.{type MilestoneState, Active, Completed, Ready}
import domain/task_status

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/badge

pub fn task_status_to_short(
  locale: Locale,
  status: task_status.TaskStatus,
) -> String {
  case status {
    task_status.Available ->
      i18n.t(locale, i18n_text.MilestoneTaskStatusAvailable)
    task_status.Claimed(_) ->
      i18n.t(locale, i18n_text.MilestoneTaskStatusClaimed)
    task_status.Completed ->
      i18n.t(locale, i18n_text.MilestoneTaskStatusCompleted)
  }
}

pub fn milestone_state_label(locale: Locale, state: MilestoneState) -> String {
  i18n.t(locale, case state {
    Ready -> i18n_text.MilestoneStateReady
    Active -> i18n_text.MilestoneStateActive
    Completed -> i18n_text.MilestoneStateCompleted
  })
}

pub fn milestone_state_variant(state: MilestoneState) -> badge.BadgeVariant {
  case state {
    Ready -> badge.Warning
    Active -> badge.Primary
    Completed -> badge.Success
  }
}
