import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, h3, p, text}
import lustre/event

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/empty_state

pub fn no_projects(locale: Locale) -> Element(msg) {
  div([attribute.class("empty")], [
    h2([], [text(i18n.t(locale, i18n_text.NoProjectsYet))]),
    p([], [text(i18n.t(locale, i18n_text.NoProjectsBody))]),
  ])
}

pub fn header(locale: Locale, on_new_task: msg) -> Element(msg) {
  div([attribute.class("pool-header")], [
    div([attribute.class("pool-header-main")], [
      h3([attribute.class("pool-title")], [
        text(i18n.t(locale, i18n_text.Pool)),
      ]),
    ]),
    button(
      [
        attribute.class("btn-sm btn-primary pool-header-action"),
        attribute.attribute("data-testid", "btn-new-task-pool-header"),
        event.on_click(on_new_task),
      ],
      [
        text("+ "),
        text(i18n.t(locale, i18n_text.NewTask)),
      ],
    ),
  ])
}

pub fn tasks_loading(locale: Locale) -> Element(msg) {
  div([attribute.class("empty")], [
    text(i18n.t(locale, i18n_text.LoadingEllipsis)),
  ])
}

pub fn tasks_no_matches(locale: Locale) -> Element(msg) {
  empty_state.simple(
    "magnifying-glass",
    i18n.t(locale, i18n_text.NoTasksMatchYourFilters),
  )
}

pub fn tasks_onboarding(locale: Locale, on_new_task: msg) -> Element(msg) {
  empty_state.new(
    "star",
    i18n.t(locale, i18n_text.NoAvailableTasksRightNow),
    i18n.t(locale, i18n_text.CreateFirstTaskToStartUsingPool),
  )
  |> empty_state.with_action(i18n.t(locale, i18n_text.NewTask), on_new_task)
  |> empty_state.view
}

pub fn my_tasks_heading(locale: Locale) -> Element(msg) {
  h3([], [text(i18n.t(locale, i18n_text.MyTasks))])
}

pub fn my_tasks_dropzone_hint(locale: Locale) -> Element(msg) {
  div([attribute.class("dropzone-hint")], [
    text(
      i18n.t(locale, i18n_text.Claim)
      <> ": "
      <> i18n.t(locale, i18n_text.MyTasks),
    ),
  ])
}

pub fn no_claimed_tasks(locale: Locale) -> Element(msg) {
  empty_state.simple("hand-raised", i18n.t(locale, i18n_text.NoClaimedTasks))
}
