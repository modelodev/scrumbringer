//// Date-only due date value.
////
//// Due dates are product dates, not instants. The canonical wire and database
//// representation is `YYYY-MM-DD`; timezone conversion happens before callers
//// compare a due date with the project-local today.

import gleam/int
import gleam/order.{type Order}
import gleam/regexp
import gleam/string

pub opaque type DueDate {
  DueDate(value: String)
}

pub type ParseError {
  InvalidDueDate
}

pub fn parse(value: String) -> Result(DueDate, ParseError) {
  case regexp.check(date_pattern(), value) && valid_calendar_parts(value) {
    True -> Ok(DueDate(value))
    False -> Error(InvalidDueDate)
  }
}

pub fn to_string(due_date: DueDate) -> String {
  let DueDate(value) = due_date
  value
}

pub fn compare(left: DueDate, right: DueDate) -> Order {
  string.compare(to_string(left), to_string(right))
}

fn date_pattern() -> regexp.Regexp {
  let assert Ok(pattern) = regexp.from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
  pattern
}

fn valid_calendar_parts(value: String) -> Bool {
  let assert Ok(year) = int.parse(string.slice(value, 0, 4))
  let assert Ok(month) = int.parse(string.slice(value, 5, 2))
  let assert Ok(day) = int.parse(string.slice(value, 8, 2))

  year >= 1
  && month >= 1
  && month <= 12
  && day >= 1
  && day <= days_in_month(year, month)
}

fn days_in_month(year: Int, month: Int) -> Int {
  case month {
    2 ->
      case leap_year(year) {
        True -> 29
        False -> 28
      }
    4 | 6 | 9 | 11 -> 30
    _ -> 31
  }
}

fn leap_year(year: Int) -> Bool {
  year % 400 == 0 || { year % 4 == 0 && year % 100 != 0 }
}
