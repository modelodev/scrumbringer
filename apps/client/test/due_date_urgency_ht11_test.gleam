import gleam/option.{None, Some}

import scrumbringer_client/features/pool/urgency

pub fn task_due_urgency_uses_max_of_age_and_due_date_test() {
  let assert "decay-shake-high" =
    urgency.shake_class(
      age_days: 1,
      due_date: Some("2026-06-18"),
      project_today: "2026-06-19",
    )

  let assert "decay-shake-medium" =
    urgency.shake_class(
      age_days: 20,
      due_date: Some("2026-06-22"),
      project_today: "2026-06-19",
    )
}

pub fn due_date_today_is_not_overdue_until_next_project_day_test() {
  let assert urgency.Neutral =
    urgency.due_date_severity(
      due_date: Some("2026-06-19"),
      project_today: "2026-06-19",
    )

  let assert urgency.High =
    urgency.due_date_severity(
      due_date: Some("2026-06-19"),
      project_today: "2026-06-20",
    )
}

pub fn due_date_uses_project_timezone_test() {
  let assert "2026-06-19" =
    urgency.project_today_from_utc(
      now_utc: "2026-06-19T23:30:00Z",
      project_timezone: "America/New_York",
    )

  let assert "2026-06-20" =
    urgency.project_today_from_utc(
      now_utc: "2026-06-19T23:30:00Z",
      project_timezone: "Europe/Madrid",
    )
}

pub fn missing_due_date_has_neutral_urgency_test() {
  let assert urgency.Neutral =
    urgency.due_date_severity(due_date: None, project_today: "2026-06-19")

  let assert "" =
    urgency.shake_class(
      age_days: 1,
      due_date: None,
      project_today: "2026-06-19",
    )
}

pub fn invalid_due_date_has_neutral_urgency_test() {
  let assert urgency.Neutral =
    urgency.due_date_severity(
      due_date: Some("2026-02-31"),
      project_today: "2026-06-19",
    )

  let assert "" =
    urgency.shake_class(
      age_days: 1,
      due_date: Some("not-a-date"),
      project_today: "2026-06-19",
    )
}

pub fn invalid_project_today_has_neutral_due_date_urgency_test() {
  let assert urgency.Neutral =
    urgency.due_date_severity(due_date: Some("2026-06-18"), project_today: "")
}
