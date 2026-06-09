import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn claim(locale: Locale) -> String {
  i18n.t(locale, i18n_text.Claim)
}

pub fn release(locale: Locale) -> String {
  i18n.t(locale, i18n_text.Release)
}

pub fn drag(locale: Locale) -> String {
  i18n.t(locale, i18n_text.Drag)
}

pub fn complete(locale: Locale) -> String {
  i18n.t(locale, i18n_text.Complete)
}

pub fn parent_card(locale: Locale) -> String {
  i18n.t(locale, i18n_text.ParentCardLabel)
}

pub fn age(locale: Locale) -> String {
  i18n.t(locale, i18n_text.AgeLabel)
}

pub fn created_ago_days(locale: Locale, days: Int) -> String {
  i18n.t(locale, i18n_text.CreatedAgoDays(days))
}

pub fn description(locale: Locale) -> String {
  i18n.t(locale, i18n_text.Description)
}

pub fn open_task(locale: Locale) -> String {
  i18n.t(locale, i18n_text.OpenTask)
}

pub fn blocked_by_tasks(locale: Locale, count: Int) -> String {
  i18n.t(locale, i18n_text.BlockedByTasks(count))
}

pub fn hidden_blocked_by_filters(locale: Locale, count: Int) -> String {
  i18n.t(locale, i18n_text.HiddenBlockedByFilters(count))
}

pub fn recent_notes(locale: Locale) -> String {
  i18n.t(locale, i18n_text.RecentNotes)
}

pub fn current_user(locale: Locale) -> String {
  i18n.t(locale, i18n_text.You)
}

pub fn user_number(locale: Locale, user_id: Int) -> String {
  i18n.t(locale, i18n_text.UserNumber(user_id))
}
