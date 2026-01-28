//// Tab badge tooltip for notes count on tab (AC21).

import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import scrumbringer_client/ui/tooltips/types.{type TabNotesStats}

pub type Labels {
  Labels(total_suffix: String, new_suffix: String)
}

pub type Config(msg) {
  Config(data: TabNotesStats, labels: Labels)
}

pub fn view(config: Config(msg)) -> Element(msg) {
  let Config(data: data, labels: labels) = config
  let types.TabNotesStats(total: total, new_for_user: new_for_user) = data

  div([attribute.class("tab-badge-tooltip"), attribute.role("tooltip")], [
    div([attribute.class("tab-badge-total")], [
      text(int.to_string(total) <> " " <> labels.total_suffix),
    ]),
    case new_for_user > 0 {
      True ->
        div([attribute.class("tab-badge-new")], [
          text(int.to_string(new_for_user) <> " " <> labels.new_suffix),
        ])
      False -> element.none()
    },
  ])
}
