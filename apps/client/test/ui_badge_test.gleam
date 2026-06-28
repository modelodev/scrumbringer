import scrumbringer_client/ui/badge
import support/render_assertions

pub fn new_truncated_truncates_valid_text_test() {
  let assert Ok(result) = badge.new_truncated("Long status", badge.Neutral, 4)
  let html = result |> badge.view |> render_assertions.html

  render_assertions.contains(html, "Long…")
  render_assertions.contains(html, "badge-neutral")
}

pub fn new_truncated_rejects_empty_text_test() {
  let assert Error("Badge text cannot be empty") =
    badge.new_truncated("   ", badge.Warning, 8)
}

pub fn status_maps_closed_to_success_test() {
  badge.status("Closed") |> render_assertions.view_contains("badge-success")
}

pub fn status_does_not_treat_completed_as_closed_test() {
  badge.status("Completed") |> render_assertions.view_contains("badge-neutral")
}
