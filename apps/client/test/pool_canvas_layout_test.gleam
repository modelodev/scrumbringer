import gleam/list
import gleam/option.{None, Some}

import domain/card
import domain/task.{type Task, Task}
import domain/task_type.{TaskTypeInline}
import scrumbringer_client/features/pool/canvas_layout
import scrumbringer_client/features/pool/task_card
import scrumbringer_client/i18n/locale
import scrumbringer_client/theme
import support/domain_fixtures

pub fn overflow_task_moves_to_first_free_visible_slot_test() {
  let fitted =
    canvas_layout.fit_overflow_cards([
      config(1, 12, 12),
      config(2, 900, 12),
    ])

  let assert [first, second] = fitted
  let assert 12 = first.x
  let assert 12 = first.y
  let assert 172 = second.x
  let assert 12 = second.y
}

pub fn visible_tasks_are_not_repositioned_test() {
  let fitted =
    canvas_layout.fit_overflow_cards([
      config(1, 492, 332),
      config(2, 652, 652),
    ])

  let assert [first, second] = fitted
  let assert 492 = first.x
  let assert 332 = first.y
  let assert 652 = second.x
  let assert 652 = second.y
}

pub fn canvas_adds_rows_for_additional_overflow_tasks_test() {
  let visible_cards =
    list.range(0, 24)
    |> list.map(fn(index) {
      let column = index % 5
      let row = index / 5
      config(index + 1, 12 + column * 160, 12 + row * 160)
    })

  let fitted =
    canvas_layout.fit_overflow_cards(
      list.append(visible_cards, [config(99, 1200, 12)]),
    )

  let assert Ok(last) = list.last(fitted)
  let assert 12 = last.x
  let assert 812 = last.y
}

fn config(id: Int, x: Int, y: Int) -> task_card.Config(String) {
  task_card.Config(
    locale: locale.En,
    theme: theme.Default,
    task: sample_task(id),
    current_user_id: Some(7),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
    x: x,
    y: y,
    age_days: 1,
    project_today: "2026-06-19",
    highlight_class: "",
    touch_preview: False,
    disable_actions: False,
    hidden_blocked_count: None,
    notes: [],
    on_claim: "claim",
    on_release: "release",
    on_close: "close",
    on_open: "open",
    on_hover_opened: "hover-opened",
    on_hover_closed: "hover-closed",
    on_focused: "focused",
    on_blurred: "blurred",
    on_drag_started: fn(_, _) { "drag" },
    on_touch_started: fn(_, _) { "touch-start" },
    on_touch_ended: "touch-end",
  )
}

fn sample_task(id: Int) -> Task {
  Task(
    ..domain_fixtures.task(id, "Task", 1),
    task_type: TaskTypeInline(id: 1, name: "Feature", icon: "sparkles"),
    card_id: Some(10),
    card_title: Some("Release card"),
    card_color: Some(card.Blue),
    description: None,
  )
}
