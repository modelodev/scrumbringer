import gleam/option.{None, Some}
import gleeunit/should
import scrumbringer_client/ui/task_color

pub fn task_color_returns_empty_for_none_test() {
  task_color.card_border_class(None) |> should.equal("")
}

pub fn task_color_returns_empty_for_invalid_color_test() {
  task_color.card_border_class(Some("not-a-color")) |> should.equal("")
}

pub fn task_color_returns_border_class_for_valid_color_test() {
  task_color.card_border_class(Some("blue")) |> should.equal("card-border-blue")
}
