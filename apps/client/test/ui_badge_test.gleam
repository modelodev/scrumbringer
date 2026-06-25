import gleam/string
import lustre/element

import scrumbringer_client/ui/badge

pub fn new_truncated_truncates_valid_text_test() {
  let assert Ok(result) = badge.new_truncated("Long status", badge.Neutral, 4)

  let assert "Long…" = badge.get_text(result)
  let assert badge.Neutral = badge.get_variant(result)
}

pub fn new_truncated_rejects_empty_text_test() {
  let assert Error("Badge text cannot be empty") =
    badge.new_truncated("   ", badge.Warning, 8)
}

pub fn status_maps_closed_to_success_test() {
  let html = badge.status("Closed") |> element.to_document_string

  let assert True = string.contains(html, "badge-success")
}

pub fn status_keeps_obsolete_completed_alias_neutral_test() {
  let html = badge.status("Completed") |> element.to_document_string

  let assert True = string.contains(html, "badge-neutral")
}
