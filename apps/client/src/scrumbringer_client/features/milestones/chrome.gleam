import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, text}

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text

pub fn loading(locale: Locale) -> Element(msg) {
  div([attribute.class("milestones-state milestones-loading")], [
    text(i18n.t(locale, i18n_text.LoadingEllipsis)),
  ])
}

pub fn error(locale: Locale) -> Element(msg) {
  div([attribute.class("milestones-state milestones-error")], [
    text(i18n.t(locale, i18n_text.MilestonesLoadError)),
  ])
}

pub fn header(
  locale: Locale,
  action: Element(msg),
  summary: List(work_surface.SummaryChip),
) -> Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(locale, i18n_text.Milestones),
    purpose: i18n.t(locale, i18n_text.MilestonesPurpose),
    summary: summary,
    actions: [action],
    extra_class: option.Some("milestones-header"),
    testid: option.Some("milestones-header"),
  ))
}
