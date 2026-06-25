import domain/due_date
import gleam/order

pub fn parse_accepts_iso_date_only_values_test() {
  let assert Ok(parsed) = due_date.parse("2026-06-19")

  let assert "2026-06-19" = due_date.to_string(parsed)
}

pub fn parse_rejects_non_date_values_test() {
  let assert Error(due_date.InvalidDueDate) = due_date.parse("")
  let assert Error(due_date.InvalidDueDate) = due_date.parse("2026-6-19")
  let assert Error(due_date.InvalidDueDate) =
    due_date.parse("2026-06-19T00:00:00Z")
}

pub fn parse_rejects_impossible_calendar_dates_test() {
  let assert Error(due_date.InvalidDueDate) = due_date.parse("0000-01-01")
  let assert Error(due_date.InvalidDueDate) = due_date.parse("2026-02-29")
  let assert Error(due_date.InvalidDueDate) = due_date.parse("2026-04-31")
  let assert Error(due_date.InvalidDueDate) = due_date.parse("2026-13-01")
}

pub fn parse_accepts_leap_day_test() {
  let assert Ok(parsed) = due_date.parse("2028-02-29")

  let assert "2028-02-29" = due_date.to_string(parsed)
}

pub fn compare_orders_date_only_values_test() {
  let assert Ok(earlier) = due_date.parse("2026-06-18")
  let assert Ok(today) = due_date.parse("2026-06-19")
  let assert Ok(later) = due_date.parse("2026-06-20")

  let assert order.Lt = due_date.compare(earlier, today)
  let assert order.Eq = due_date.compare(today, today)
  let assert order.Gt = due_date.compare(later, today)
}
