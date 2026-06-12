//// Shared compact chip for numeric and textual UI signals.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import scrumbringer_client/ui/tone

pub opaque type SignalChip {
  SignalChip(
    label: String,
    value: Option(String),
    tone: tone.Tone,
    base_class: String,
    extra_class: Option(String),
    value_class: String,
    label_class: String,
    testid: Option(String),
    title: Option(String),
  )
}

/// Create a label-only signal chip.
pub fn text(label: String, tone_value: tone.Tone) -> SignalChip {
  SignalChip(
    label: label,
    value: None,
    tone: tone_value,
    base_class: "signal-chip",
    extra_class: None,
    value_class: "signal-chip-value",
    label_class: "signal-chip-label",
    testid: None,
    title: None,
  )
}

/// Create a signal chip with a metric value and label.
pub fn metric(label: String, value: String, tone_value: tone.Tone) -> SignalChip {
  SignalChip(..text(label, tone_value), value: Some(value))
}

/// Create a signal chip with an integer metric value.
pub fn metric_int(
  label: String,
  value: Int,
  tone_value: tone.Tone,
) -> SignalChip {
  metric(label, int.to_string(value), tone_value)
}

/// Create a metric chip only when the value is greater than zero.
pub fn metric_if_positive(
  label: String,
  value: Int,
  tone_value: tone.Tone,
) -> Option(SignalChip) {
  case value > 0 {
    True -> Some(metric_int(label, value, tone_value))
    False -> None
  }
}

/// Override the root CSS class while preserving the semantic tone class.
pub fn with_class(chip: SignalChip, base_class: String) -> SignalChip {
  SignalChip(..chip, base_class: base_class)
}

/// Add a business-specific modifier class.
pub fn with_extra_class(chip: SignalChip, extra_class: String) -> SignalChip {
  SignalChip(..chip, extra_class: Some(extra_class))
}

/// Override metric value and label classes for compatibility with existing CSS.
pub fn with_parts(
  chip: SignalChip,
  value_class: String,
  label_class: String,
) -> SignalChip {
  SignalChip(..chip, value_class: value_class, label_class: label_class)
}

/// Add a `data-testid` attribute.
pub fn with_testid(chip: SignalChip, testid: String) -> SignalChip {
  SignalChip(..chip, testid: Some(testid))
}

/// Add a title tooltip.
pub fn with_title(chip: SignalChip, title: String) -> SignalChip {
  SignalChip(..chip, title: Some(title))
}

/// Render the signal chip.
pub fn view(chip: SignalChip) -> Element(msg) {
  html.span(attrs(chip), children(chip))
}

fn attrs(chip: SignalChip) -> List(attribute.Attribute(msg)) {
  list.append(
    [attribute.class(class_name(chip))],
    list.append(
      optional_attr("data-testid", chip.testid),
      optional_attr("title", chip.title),
    ),
  )
}

fn optional_attr(
  name: String,
  value: Option(String),
) -> List(attribute.Attribute(msg)) {
  case value {
    Some(attr_value) -> [attribute.attribute(name, attr_value)]
    None -> []
  }
}

fn class_name(chip: SignalChip) -> String {
  let base = chip.base_class <> " " <> tone.class_name(chip.tone)

  case chip.extra_class {
    Some(extra) -> base <> " " <> extra
    None -> base
  }
}

fn children(chip: SignalChip) -> List(Element(msg)) {
  case chip.value {
    Some(value) -> [
      html.span([attribute.class(chip.value_class)], [html.text(value)]),
      html.span([attribute.class(chip.label_class)], [html.text(chip.label)]),
    ]
    None -> [html.text(chip.label)]
  }
}
