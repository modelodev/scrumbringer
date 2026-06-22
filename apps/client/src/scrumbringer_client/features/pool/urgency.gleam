import gleam/int
import gleam/option.{type Option}
import gleam/order
import gleam/string

pub type Severity {
  Neutral
  Low
  Medium
  High
}

@external(javascript, "./urgency.ffi.mjs", "projectTodayFromUtc")
fn project_today_from_utc_external(
  _now_utc: String,
  _project_timezone: String,
) -> String {
  ""
}

pub fn project_today_from_utc(
  now_utc now_utc: String,
  project_timezone project_timezone: String,
) -> String {
  project_today_from_utc_external(now_utc, project_timezone)
}

pub fn shake_class(
  age_days age_days: Int,
  due_date due_date: Option(String),
  project_today project_today: String,
) -> String {
  severity_to_shake_class(max_severity(
    age_severity(age_days),
    due_date_severity(due_date:, project_today:),
  ))
}

pub fn age_severity(age_days: Int) -> Severity {
  case age_days {
    d if d < 9 -> Neutral
    d if d < 18 -> Low
    d if d < 27 -> Medium
    _ -> High
  }
}

pub fn due_date_severity(
  due_date due_date: Option(String),
  project_today project_today: String,
) -> Severity {
  case due_date {
    option.Some(date) ->
      case string.compare(date, project_today) {
        order.Lt -> High
        _ -> Neutral
      }
    _ -> Neutral
  }
}

pub fn max_severity(a: Severity, b: Severity) -> Severity {
  case int.compare(rank(a), rank(b)) {
    order.Lt -> b
    _ -> a
  }
}

fn rank(severity: Severity) -> Int {
  case severity {
    Neutral -> 0
    Low -> 1
    Medium -> 2
    High -> 3
  }
}

fn severity_to_shake_class(severity: Severity) -> String {
  case severity {
    Neutral -> ""
    Low -> "decay-shake-low"
    Medium -> "decay-shake-medium"
    High -> "decay-shake-high"
  }
}
