import gleam/list
import scrumbringer_client/ui/icon_catalog
import scrumbringer_client/ui/icon_picker.{
  InvalidIconCategory, active_category_or_default, category_to_string,
  parse_category,
}

pub fn parse_category_accepts_known_ids_test() {
  let assert Ok(icon_catalog.All) = parse_category("all")
  let assert Ok(icon_catalog.Tasks) = parse_category("tasks")
  let assert Ok(icon_catalog.Status) = parse_category("status")
  let assert Ok(icon_catalog.Priority) = parse_category("priority")
  let assert Ok(icon_catalog.Objects) = parse_category("objects")
  let assert Ok(icon_catalog.Actions) = parse_category("actions")
}

pub fn parse_category_rejects_unknown_ids_test() {
  let assert Error(InvalidIconCategory("everything")) =
    parse_category("everything")
}

pub fn category_ids_round_trip_test() {
  let categories = [
    icon_catalog.All,
    icon_catalog.Tasks,
    icon_catalog.Status,
    icon_catalog.Priority,
    icon_catalog.Objects,
    icon_catalog.Actions,
  ]

  categories
  |> list.each(fn(category) {
    let assert Ok(parsed) = parse_category(category_to_string(category))
    let assert True = parsed == category
  })
}

pub fn active_category_or_default_recovers_invalid_category_test() {
  let assert icon_catalog.All = active_category_or_default("everything")
}
