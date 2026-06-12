import gleam/option
import lustre/element.{type Element}

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/empty_state

pub fn loading(locale: Locale) -> Element(msg) {
  empty_state.notice_with_class(
    "clock",
    i18n.t(locale, i18n_text.LoadingEllipsis),
    empty_state.Loading,
    "milestones-state milestones-loading",
  )
}

pub fn error(locale: Locale) -> Element(msg) {
  empty_state.notice_with_class(
    "exclamation-triangle",
    i18n.t(locale, i18n_text.MilestonesLoadError),
    empty_state.Error,
    "milestones-state milestones-error",
  )
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
