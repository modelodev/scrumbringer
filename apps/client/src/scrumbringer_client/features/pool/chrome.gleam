import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, h3, text}

import scrumbringer_client/features/layout/work_surface
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/locale.{type Locale}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/button
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons

pub fn no_projects(locale: Locale) -> Element(msg) {
  empty_state.no_projects(
    i18n.t(locale, i18n_text.NoProjectsYet),
    i18n.t(locale, i18n_text.NoProjectsBody),
  )
  |> empty_state.with_class("empty")
  |> empty_state.view
}

pub fn header(
  locale: Locale,
  on_new_task: msg,
  summary: List(work_surface.SummaryChip),
) -> Element(msg) {
  work_surface.header(work_surface.HeaderConfig(
    title: i18n.t(locale, i18n_text.Pool),
    purpose: i18n.t(locale, i18n_text.PoolPurpose),
    summary: summary,
    actions: [
      button.icon_text(
        i18n.t(locale, i18n_text.NewTask),
        on_new_task,
        icons.Plus,
        button.Primary,
        button.GlobalAction,
      )
      |> button.with_class("pool-header-action")
      |> button.with_testid("btn-new-task-pool-header")
      |> button.view,
    ],
    extra_class: option.Some("pool-header"),
    testid: option.Some("pool-surface-header"),
  ))
}

pub fn tasks_loading(locale: Locale) -> Element(msg) {
  empty_state.notice_with_class(
    "clock",
    i18n.t(locale, i18n_text.LoadingEllipsis),
    empty_state.Loading,
    "empty",
  )
}

pub fn tasks_no_matches(locale: Locale) -> Element(msg) {
  empty_state.notice(
    "magnifying-glass",
    i18n.t(locale, i18n_text.NoTasksMatchYourFilters),
    empty_state.NoResults,
  )
}

pub fn tasks_no_open(locale: Locale, on_new_task: msg) -> Element(msg) {
  empty_state.new(
    "inbox",
    i18n.t(locale, i18n_text.NoOpenPoolTasks),
    i18n.t(locale, i18n_text.NoOpenPoolTasksBody),
  )
  |> empty_state.with_meaning(empty_state.HealthyEmpty)
  |> empty_state.with_action(i18n.t(locale, i18n_text.NewTask), on_new_task)
  |> empty_state.view
}

pub fn tasks_no_claimable(locale: Locale) -> Element(msg) {
  empty_state.new(
    "hand-raised",
    i18n.t(locale, i18n_text.NoClaimablePoolTasks),
    i18n.t(locale, i18n_text.NoClaimablePoolTasksBody),
  )
  |> empty_state.with_meaning(empty_state.HealthyEmpty)
  |> empty_state.view
}

pub fn tasks_no_claimable_with_blocked(
  locale: Locale,
  blocked_count: Int,
  on_view_blocked: msg,
) -> Element(msg) {
  empty_state.new(
    "hand-raised",
    i18n.t(locale, i18n_text.NoClaimablePoolTasks),
    i18n.t(locale, i18n_text.NoClaimablePoolTasksBlockedBody(blocked_count)),
  )
  |> empty_state.with_meaning(empty_state.NoResults)
  |> empty_state.with_action(
    i18n.t(locale, i18n_text.ViewBlockedTasks),
    on_view_blocked,
  )
  |> empty_state.view
}

pub fn tasks_no_blocked(locale: Locale, on_view_open: msg) -> Element(msg) {
  empty_state.new(
    "check-circle",
    i18n.t(locale, i18n_text.NoBlockedPoolTasks),
    i18n.t(locale, i18n_text.NoBlockedPoolTasksBody),
  )
  |> empty_state.with_meaning(empty_state.HealthyEmpty)
  |> empty_state.with_action(
    i18n.t(locale, i18n_text.ViewOpenTasks),
    on_view_open,
  )
  |> empty_state.view
}

pub fn tasks_onboarding(locale: Locale, on_new_task: msg) -> Element(msg) {
  empty_state.new(
    "star",
    i18n.t(locale, i18n_text.NoAvailableTasksRightNow),
    i18n.t(locale, i18n_text.CreateFirstTaskToStartUsingPool),
  )
  |> empty_state.with_meaning(empty_state.Onboarding)
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
