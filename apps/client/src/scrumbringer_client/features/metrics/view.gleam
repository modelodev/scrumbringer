//// Metrics View
////
//// View functions for admin metrics section including org-wide overview
//// and project-specific task metrics.
////
//// ## Responsibilities
////
//// - Org-wide metrics overview panel (claims, releases, completions)
//// - Time-to-first-claim histogram and buckets
//// - Release rate distribution
//// - Per-project metrics table
//// - Project drill-down with task-level metrics

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h2, h3, p, table, tbody, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import domain/metrics.{
  type MetricsProjectTask, type OrgMetricsBucket,
  type OrgMetricsOverview, type OrgMetricsProjectOverview,
  type OrgMetricsProjectTasksPayload, MetricsProjectTask,
  OrgMetricsBucket, OrgMetricsOverview, OrgMetricsProjectOverview,
  OrgMetricsProjectTasksPayload,
}
import domain/project.{type Project, Project}
import domain/task.{Task}
import domain/task_status.{task_status_to_string}

import scrumbringer_client/client_state.{
  type Model, type Msg, NavigateTo, Push,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers

/// Renders the metrics section with overview and project panels.
pub fn view_metrics(model: Model, selected: opt.Option(Project)) -> Element(Msg) {
  div([attribute.class("section")], [
    // Section header (Story 4.8: consistent icons)
    section_header.view(
      icons.OrgMetrics,
      update_helpers.i18n_t(model, i18n_text.OrgMetrics),
    ),
    view_overview_panel(model),
    view_project_panel(model, selected),
  ])
}

/// Renders the org-wide metrics overview panel.
fn view_overview_panel(model: Model) -> Element(Msg) {
  ui_remote.view_remote_panel(
    remote: model.admin_metrics_overview,
    title: update_helpers.i18n_t(model, i18n_text.MetricsOverview),
    loading_msg: update_helpers.i18n_t(model, i18n_text.LoadingOverview),
    loaded: fn(overview) { view_overview_loaded(model, overview) },
  )
}

fn view_overview_loaded(
  model: Model,
  overview: OrgMetricsOverview,
) -> Element(Msg) {
  let OrgMetricsOverview(
    window_days: window_days,
    claimed_count: claimed_count,
    released_count: released_count,
    completed_count: completed_count,
    release_rate_percent: release_rate_percent,
    pool_flow_ratio_percent: pool_flow_ratio_percent,
    time_to_first_claim_p50_ms: time_to_first_claim_p50_ms,
    time_to_first_claim_sample_size: time_to_first_claim_sample_size,
    time_to_first_claim_buckets: time_to_first_claim_buckets,
    release_rate_buckets: release_rate_buckets,
    by_project: by_project,
  ) = overview

  div([attribute.class("panel")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.MetricsOverview))]),
    p([], [
      text(update_helpers.i18n_t(model, i18n_text.WindowDays(window_days))),
    ]),
    view_summary_table(
      model,
      claimed_count,
      released_count,
      completed_count,
      release_rate_percent,
      pool_flow_ratio_percent,
    ),
    view_time_to_first_claim(
      model,
      time_to_first_claim_p50_ms,
      time_to_first_claim_sample_size,
      time_to_first_claim_buckets,
    ),
    view_release_rate_buckets(model, release_rate_buckets),
    view_by_project_table(model, by_project),
  ])
}

fn view_summary_table(
  model: Model,
  claimed_count: Int,
  released_count: Int,
  completed_count: Int,
  release_rate_percent: opt.Option(Int),
  pool_flow_ratio_percent: opt.Option(Int),
) -> Element(Msg) {
  table([attribute.class("table")], [
    thead([], [
      tr([], [
        th([], [text(update_helpers.i18n_t(model, i18n_text.Claimed))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Released))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Completed))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.ReleasePercent))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.FlowPercent))]),
      ]),
    ]),
    tbody([], [
      tr([], [
        td([], [text(int.to_string(claimed_count))]),
        td([], [text(int.to_string(released_count))]),
        td([], [text(int.to_string(completed_count))]),
        td([], [text(option_percent_label(release_rate_percent))]),
        td([], [text(option_percent_label(pool_flow_ratio_percent))]),
      ]),
    ]),
  ])
}

fn view_time_to_first_claim(
  model: Model,
  p50_ms: opt.Option(Int),
  sample_size: Int,
  buckets: List(OrgMetricsBucket),
) -> Element(Msg) {
  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.TimeToFirstClaim))]),
    p([], [
      text(update_helpers.i18n_t(
        model,
        i18n_text.TimeToFirstClaimP50(option_ms_label(p50_ms), sample_size),
      )),
    ]),
    div([attribute.class("buckets")], [
      view_bucket_table(model, buckets),
    ]),
  ])
}

fn view_release_rate_buckets(
  model: Model,
  buckets: List(OrgMetricsBucket),
) -> Element(Msg) {
  div([], [
    h3([], [
      text(update_helpers.i18n_t(model, i18n_text.ReleaseRateDistribution)),
    ]),
    view_bucket_table(model, buckets),
  ])
}

fn view_bucket_table(
  model: Model,
  buckets: List(OrgMetricsBucket),
) -> Element(Msg) {
  table([attribute.class("table")], [
    thead([], [
      tr([], [
        th([], [text(update_helpers.i18n_t(model, i18n_text.Bucket))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Count))]),
      ]),
    ]),
    keyed.tbody(
      [],
      list.map(buckets, fn(b) {
        let OrgMetricsBucket(bucket: bucket, count: count) = b
        #(bucket, tr([], [td([], [text(bucket)]), td([], [text(int.to_string(count))])]))
      }),
    ),
  ])
}

fn view_by_project_table(
  model: Model,
  by_project: List(OrgMetricsProjectOverview),
) -> Element(Msg) {
  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.ByProject))]),
    table([attribute.class("table")], [
      thead([], [
        tr([], [
          th([], [text(update_helpers.i18n_t(model, i18n_text.ProjectLabel))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Claimed))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Released))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Completed))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.ReleasePercent))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.FlowPercent))]),
          th([], [text(update_helpers.i18n_t(model, i18n_text.Drill))]),
        ]),
      ]),
      keyed.tbody(
        [],
        list.map(by_project, fn(p) {
          let OrgMetricsProjectOverview(project_id: project_id, ..) = p
          #(int.to_string(project_id), view_project_row(model, p))
        }),
      ),
    ]),
  ])
}

fn view_project_row(
  model: Model,
  p: OrgMetricsProjectOverview,
) -> Element(Msg) {
  // Story 4.5: project_id no longer needed since we navigate to org Metrics
  let OrgMetricsProjectOverview(
    project_id: _,
    project_name: project_name,
    claimed_count: claimed,
    released_count: released,
    completed_count: completed,
    release_rate_percent: rrp,
    pool_flow_ratio_percent: pfrp,
  ) = p

  tr([], [
    td([], [text(project_name)]),
    td([], [text(int.to_string(claimed))]),
    td([], [text(int.to_string(released))]),
    td([], [text(int.to_string(completed))]),
    td([], [text(option_percent_label(rrp))]),
    td([], [text(option_percent_label(pfrp))]),
    td([], [
      // Story 4.5: Metrics is an org-scoped section
      button(
        [
          attribute.class("btn-xs"),
          event.on_click(NavigateTo(
            router.Org(permissions.Metrics),
            Push,
          )),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.View))],
      ),
    ]),
  ])
}

fn view_project_panel(
  model: Model,
  selected: opt.Option(Project),
) -> Element(Msg) {
  case selected {
    opt.None ->
      div([attribute.class("panel")], [
        h3([], [text(update_helpers.i18n_t(model, i18n_text.ProjectDrillDown))]),
        p([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.SelectProjectToInspectTasks,
          )),
        ]),
      ])

    opt.Some(Project(name: project_name, ..)) ->
      view_project_tasks_panel(model, project_name)
  }
}

fn view_project_tasks_panel(
  model: Model,
  project_name: String,
) -> Element(Msg) {
  let body = ui_remote.view_remote_inline(
    remote: model.admin_metrics_project_tasks,
    loading_msg: update_helpers.i18n_t(model, i18n_text.LoadingTasks),
    loaded: fn(payload) { view_project_tasks_table(model, payload) },
  )

  div([attribute.class("panel")], [
    h3([], [
      text(update_helpers.i18n_t(model, i18n_text.ProjectTasks(project_name))),
    ]),
    body,
  ])
}

fn view_project_tasks_table(
  model: Model,
  payload: OrgMetricsProjectTasksPayload,
) -> Element(Msg) {
  let OrgMetricsProjectTasksPayload(tasks: tasks, ..) = payload

  table([attribute.class("table")], [
    thead([], [
      tr([], [
        th([], [text(update_helpers.i18n_t(model, i18n_text.Title))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Status))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Claims))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Releases))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.Completes))]),
        th([], [text(update_helpers.i18n_t(model, i18n_text.FirstClaim))]),
      ]),
    ]),
    keyed.tbody(
      [],
      list.map(tasks, fn(t) {
        let MetricsProjectTask(task: Task(id: task_id, ..), ..) = t
        #(int.to_string(task_id), view_task_row(t))
      }),
    ),
  ])
}

fn view_task_row(t: MetricsProjectTask) -> Element(Msg) {
  let MetricsProjectTask(
    task: Task(title: title, status: status, ..),
    claim_count: claim_count,
    release_count: release_count,
    complete_count: complete_count,
    first_claim_at: first_claim_at,
  ) = t

  tr([], [
    td([], [text(title)]),
    td([], [text(task_status_to_string(status))]),
    td([], [text(int.to_string(claim_count))]),
    td([], [text(int.to_string(release_count))]),
    td([], [text(int.to_string(complete_count))]),
    td([], [text(option_string_label(first_claim_at))]),
  ])
}

// --- Helpers ---

fn option_percent_label(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(v) -> int.to_string(v) <> "%"
    opt.None -> "-"
  }
}

fn option_ms_label(value: opt.Option(Int)) -> String {
  case value {
    opt.Some(v) -> int.to_string(v) <> "ms"
    opt.None -> "-"
  }
}

fn option_string_label(value: opt.Option(String)) -> String {
  case value {
    opt.Some(v) -> v
    opt.None -> "-"
  }
}
