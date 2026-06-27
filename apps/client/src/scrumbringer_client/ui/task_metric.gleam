//// Semantic task metric definitions.

import gleam/int

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/tone

pub type TaskMetricKind {
  Total
  Available
  Claimed
  Ongoing
  Closed
  Blocked
}

pub type TaskMetric {
  TaskMetric(kind: TaskMetricKind, value: Int)
}

pub fn metric(kind: TaskMetricKind, value: Int) -> TaskMetric {
  TaskMetric(kind: kind, value: value)
}

pub fn label(locale: Locale, kind: TaskMetricKind) -> String {
  case kind {
    Total -> i18n.t(locale, i18n_text.CapabilityBoardTotal)
    Available -> i18n.t(locale, i18n_text.MetricsAvailable)
    Claimed -> i18n.t(locale, i18n_text.MetricsClaimed)
    Ongoing -> i18n.t(locale, i18n_text.MetricsOngoing)
    Closed -> i18n.t(locale, i18n_text.Closed)
    Blocked -> i18n.t(locale, i18n_text.PoolVisibilityBlocked)
  }
}

pub fn icon(kind: TaskMetricKind) -> icons.NavIcon {
  case kind {
    Total -> icons.List
    Available -> icons.InboxEmpty
    Claimed -> icons.ClipboardDoc
    Ongoing -> icons.Play
    Closed -> icons.CheckCircle
    Blocked -> icons.Warning
  }
}

pub fn tone(kind: TaskMetricKind) -> tone.Tone {
  case kind {
    Total -> tone.Neutral
    Available -> tone.Available
    Claimed -> tone.Claimed
    Ongoing -> tone.Ongoing
    Closed -> tone.Success
    Blocked -> tone.Blocked
  }
}

pub fn title(locale: Locale, metric: TaskMetric) -> String {
  label(locale, metric.kind) <> ": " <> int.to_string(metric.value)
}

pub fn testid(kind: TaskMetricKind) -> String {
  "task-metric-" <> kind_key(kind)
}

pub fn kind_key(kind: TaskMetricKind) -> String {
  case kind {
    Total -> "total"
    Available -> "available"
    Claimed -> "claimed"
    Ongoing -> "ongoing"
    Closed -> "closed"
    Blocked -> "blocked"
  }
}
