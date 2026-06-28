import domain/card
import gleam/option.{None, Some}
import scrumbringer_client/ui/task_color
import support/assertions.{assert_equal}

pub fn task_color_returns_empty_for_none_test() {
  task_color.card_border_class(None) |> assert_equal("")
}

pub fn task_color_returns_border_class_for_valid_color_test() {
  task_color.card_border_class(Some(card.Blue))
  |> assert_equal("card-border-blue")
}
