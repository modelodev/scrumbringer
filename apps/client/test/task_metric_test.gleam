import scrumbringer_client/i18n/locale
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_metric
import scrumbringer_client/ui/tone

pub fn task_metric_maps_available_semantics_test() {
  let assert "Available" = task_metric.label(locale.En, task_metric.Available)
  let assert icons.InboxEmpty = task_metric.icon(task_metric.Available)
  let assert tone.Available = task_metric.tone(task_metric.Available)
  let assert "task-metric-available" = task_metric.testid(task_metric.Available)
}

pub fn task_metric_maps_all_canonical_kinds_test() {
  let cases = [
    #(task_metric.Total, icons.List, tone.Neutral, "task-metric-total"),
    #(
      task_metric.Claimed,
      icons.ClipboardDoc,
      tone.Claimed,
      "task-metric-claimed",
    ),
    #(task_metric.Ongoing, icons.Play, tone.Ongoing, "task-metric-ongoing"),
    #(task_metric.Closed, icons.CheckCircle, tone.Success, "task-metric-closed"),
    #(task_metric.Blocked, icons.Warning, tone.Blocked, "task-metric-blocked"),
  ]

  list_each(cases, fn(item) {
    let #(kind, expected_icon, expected_tone, expected_testid) = item
    let assert True = task_metric.icon(kind) == expected_icon
    let assert True = task_metric.tone(kind) == expected_tone
    let assert True = task_metric.testid(kind) == expected_testid
    Nil
  })
}

pub fn task_metric_title_uses_localized_label_and_value_test() {
  let metric = task_metric.metric(task_metric.Blocked, 2)

  let assert "Blocked: 2" = task_metric.title(locale.En, metric)
  let assert "Bloqueadas: 2" = task_metric.title(locale.Es, metric)
}

fn list_each(items: List(a), fun: fn(a) -> Nil) -> Nil {
  case items {
    [] -> Nil
    [first, ..rest] -> {
      fun(first)
      list_each(rest, fun)
    }
  }
}
