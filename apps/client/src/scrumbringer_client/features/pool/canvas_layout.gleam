//// Pool canvas layout helpers.
////
//// Keeps the pool canvas free of native horizontal scrollbars by relocating only
//// task cards whose saved coordinates fall outside the normal visible canvas.

import gleam/int
import gleam/list

import scrumbringer_client/features/pool/task_card

const card_size = 128

const gap = 32

const padding = 12

const visible_columns = 5

const min_visible_rows = 5

pub fn visible_width() -> Int {
  padding * 2 + visible_columns * card_size + { visible_columns - 1 } * gap
}

pub fn visible_height(card_count: Int) -> Int {
  let rows = visible_rows(card_count)
  padding * 2 + rows * card_size + { rows - 1 } * gap
}

pub fn fit_overflow_cards(
  cards: List(task_card.Config(msg)),
) -> List(task_card.Config(msg)) {
  let card_count = list.length(cards)
  let slots = visible_slots(card_count)
  let visible_rects =
    cards
    |> list.filter(fn(card) { is_inside_visible_canvas(card, card_count) })
    |> list.map(card_rect)

  let #(fitted, _) =
    list.fold(cards, #([], visible_rects), fn(acc, card_config) {
      let #(result, occupied) = acc
      case is_inside_visible_canvas(card_config, card_count) {
        True -> #([card_config, ..result], occupied)
        False -> {
          case first_free_slot(slots, occupied) {
            Ok(slot) -> {
              let #(x, y, _, _) = slot
              let next_card = task_card.Config(..card_config, x: x, y: y)
              #([next_card, ..result], [slot, ..occupied])
            }
            Error(_) -> #([card_config, ..result], occupied)
          }
        }
      }
    })

  list.reverse(fitted)
}

fn is_inside_visible_canvas(
  card_config: task_card.Config(msg),
  card_count: Int,
) -> Bool {
  card_config.x >= 0
  && card_config.y >= 0
  && card_config.x + card_size <= visible_width()
  && card_config.y + card_size <= visible_height(card_count)
}

fn first_free_slot(
  slots: List(#(Int, Int, Int, Int)),
  occupied: List(#(Int, Int, Int, Int)),
) -> Result(#(Int, Int, Int, Int), Nil) {
  list.find(slots, fn(slot) {
    !list.any(occupied, fn(rect) { rects_overlap(slot, rect) })
  })
}

fn visible_slots(card_count: Int) -> List(#(Int, Int, Int, Int)) {
  list.range(0, visible_rows(card_count) - 1)
  |> list.flat_map(fn(row) {
    list.range(0, visible_columns - 1)
    |> list.map(fn(column) {
      let x = padding + column * { card_size + gap }
      let y = padding + row * { card_size + gap }
      #(x, y, card_size, card_size)
    })
  })
}

fn card_rect(card_config: task_card.Config(msg)) -> #(Int, Int, Int, Int) {
  #(card_config.x, card_config.y, card_size, card_size)
}

fn visible_rows(card_count: Int) -> Int {
  int.max(min_visible_rows, ceil_div(int.max(card_count, 1), visible_columns))
}

fn ceil_div(value: Int, divisor: Int) -> Int {
  { value + divisor - 1 } / divisor
}

fn rects_overlap(a: #(Int, Int, Int, Int), b: #(Int, Int, Int, Int)) -> Bool {
  let #(ax, ay, aw, ah) = a
  let #(bx, by, bw, bh) = b

  ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by
}
