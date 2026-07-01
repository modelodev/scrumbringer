//// Shared metadata primitives for detail inspectors.

import gleam/option.{type Option, None, Some}

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/icons
import scrumbringer_client/utils/format_date

pub fn container(groups: List(Element(msg))) -> Option(Element(msg)) {
  case groups {
    [] -> None
    _ -> Some(container_required(groups))
  }
}

pub fn container_required(groups: List(Element(msg))) -> Element(msg) {
  div([attribute.class("detail-meta")], groups)
}

pub fn group(children: List(Element(msg))) -> Option(Element(msg)) {
  case children {
    [] -> None
    _ -> Some(group_required(children))
  }
}

pub fn group_required(children: List(Element(msg))) -> Element(msg) {
  div([attribute.class("detail-meta-group")], children)
}

pub fn created_at(
  locale: Locale,
  created_at: String,
  testid: String,
) -> Element(msg) {
  span(
    [
      attribute.class("inspector-meta-chip inspector-meta-created"),
      attribute.attribute("data-testid", testid),
      attribute.attribute(
        "title",
        format_date.full_date_for_locale(locale, created_at),
      ),
    ],
    [
      icons.nav_icon(icons.Calendar, icons.Small),
      text(
        i18n.t(locale, i18n_text.CreatedAt)
        <> " "
        <> format_date.short_date_for_locale(locale, created_at),
      ),
    ],
  )
}
