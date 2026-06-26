import gleam/string
import lustre/element

import scrumbringer_client/ui/tone
import scrumbringer_client/ui/workload_breakdown

fn assert_contains(text: String, fragment: String) {
  let assert True = string.contains(text, fragment)
}

pub fn workload_breakdown_renders_operational_metrics_test() {
  let html =
    workload_breakdown.view([
      workload_breakdown.metric("Available", "avail", 3, tone.Available),
      workload_breakdown.metric("Claimed", "claim", 1, tone.Claimed),
      workload_breakdown.metric("Blocked", "block", 0, tone.Blocked),
    ])
    |> element.to_document_string

  assert_contains(html, "data-testid=\"workload-breakdown\"")
  assert_contains(html, "workload-breakdown-item available")
  assert_contains(html, "title=\"Available: 3\"")
  assert_contains(html, ">avail<")
  assert_contains(html, "workload-breakdown-item claimed")
  assert_contains(html, "workload-breakdown-item blocked")
}
