//// Tests for tab badge tooltip (AC21).

import gleam/string
import gleeunit/should
import lustre/element

import scrumbringer_client/ui/tooltips/tab_badge
import scrumbringer_client/ui/tooltips/types.{TabNotesStats}

pub fn shows_total_and_new_count_test() {
  let config =
    tab_badge.Config(
      data: TabNotesStats(total: 5, new_for_user: 2),
      labels: tab_badge.Labels(
        total_suffix: "notas en total",
        new_suffix: "nuevas para ti",
      ),
    )

  let html = tab_badge.view(config) |> element.to_document_string

  string.contains(html, "5") |> should.be_true
  string.contains(html, "notas en total") |> should.be_true
  string.contains(html, "2") |> should.be_true
  string.contains(html, "nuevas para ti") |> should.be_true
}

pub fn hides_new_when_zero_test() {
  let config =
    tab_badge.Config(
      data: TabNotesStats(total: 3, new_for_user: 0),
      labels: tab_badge.Labels(
        total_suffix: "notas en total",
        new_suffix: "nuevas para ti",
      ),
    )

  let html = tab_badge.view(config) |> element.to_document_string

  string.contains(html, "3") |> should.be_true
  string.contains(html, "notas en total") |> should.be_true
  string.contains(html, "nuevas para ti") |> should.be_false
}
