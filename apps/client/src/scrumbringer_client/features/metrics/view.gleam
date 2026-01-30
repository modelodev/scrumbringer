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
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{button, div, h2, h3, p, text}
import lustre/event

import domain/metrics.{
  type OrgMetricsBucket, type OrgMetricsOverview, type OrgMetricsProjectOverview,
  type OrgMetricsProjectTasksPayload, MetricsProjectTask, OrgMetricsBucket,
  OrgMetricsOverview, OrgMetricsProjectOverview, OrgMetricsProjectTasksPayload,
}
import domain/project.{type Project, Project}
import domain/task.{Task}
import domain/task_status.{task_status_to_string}

import scrumbringer_client/client_state.{type Model, type Msg, NavigateTo, Push}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers

/// Renders the metrics section with overview and project panels.
pub fn view_metrics(model: Model, selected: opt.Option(Project)) -> Element(Msg) {
  div([attrs.section()], [
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
    remote: model.admin.admin_metrics_overview,
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
  let row = #(
    claimed_count,
    released_count,
    completed_count,
    release_rate_percent,
    pool_flow_ratio_percent,
  )

  data_table.new()
  |> data_table.with_columns([
    data_table.column(update_helpers.i18n_t(model, i18n_text.Claimed), fn(r) {
      let #(claimed, _, _, _, _) = r
      text(int.to_string(claimed))
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Released), fn(r) {
      let #(_, released, _, _, _) = r
      text(int.to_string(released))
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Completed), fn(r) {
      let #(_, _, completed, _, _) = r
      text(int.to_string(completed))
    }),
    data_table.column(
      update_helpers.i18n_t(model, i18n_text.ReleasePercent),
      fn(r) {
        let #(_, _, _, release_rate, _) = r
        text(option_percent_label(release_rate))
      },
    ),
    data_table.column(
      update_helpers.i18n_t(model, i18n_text.FlowPercent),
      fn(r) {
        let #(_, _, _, _, flow_rate) = r
        text(option_percent_label(flow_rate))
      },
    ),
  ])
  |> data_table.with_rows([row], fn(_) { "summary" })
  |> data_table.view()
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
  data_table.new()
  |> data_table.with_columns([
    data_table.column(update_helpers.i18n_t(model, i18n_text.Bucket), fn(b) {
      let OrgMetricsBucket(bucket: bucket, ..) = b
      text(bucket)
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Count), fn(b) {
      let OrgMetricsBucket(count: count, ..) = b
      text(int.to_string(count))
    }),
  ])
  |> data_table.with_rows(buckets, fn(b) {
    let OrgMetricsBucket(bucket: bucket, ..) = b
    bucket
  })
  |> data_table.view()
}

fn view_by_project_table(
  model: Model,
  by_project: List(OrgMetricsProjectOverview),
) -> Element(Msg) {
  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.ByProject))]),
    data_table.new()
      |> data_table.with_columns([
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.ProjectLabel),
          fn(p) {
            let OrgMetricsProjectOverview(project_name: project_name, ..) = p
            text(project_name)
          },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.Claimed),
          fn(p) {
            let OrgMetricsProjectOverview(claimed_count: claimed, ..) = p
            text(int.to_string(claimed))
          },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.Released),
          fn(p) {
            let OrgMetricsProjectOverview(released_count: released, ..) = p
            text(int.to_string(released))
          },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.Completed),
          fn(p) {
            let OrgMetricsProjectOverview(completed_count: completed, ..) = p
            text(int.to_string(completed))
          },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.ReleasePercent),
          fn(p) {
            let OrgMetricsProjectOverview(release_rate_percent: rrp, ..) = p
            text(option_percent_label(rrp))
          },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.FlowPercent),
          fn(p) {
            let OrgMetricsProjectOverview(pool_flow_ratio_percent: pfrp, ..) = p
            text(option_percent_label(pfrp))
          },
        ),
        data_table.column(update_helpers.i18n_t(model, i18n_text.Drill), fn(_) {
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(NavigateTo(router.Org(permissions.Metrics), Push)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.View))],
          )
        }),
      ])
      |> data_table.with_rows(by_project, fn(p) {
        let OrgMetricsProjectOverview(project_id: project_id, ..) = p
        int.to_string(project_id)
      })
      |> data_table.view(),
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

fn view_project_tasks_panel(model: Model, project_name: String) -> Element(Msg) {
  let body =
    ui_remote.view_remote_inline(
      remote: model.admin.admin_metrics_project_tasks,
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

  data_table.new()
  |> data_table.with_columns([
    data_table.column(update_helpers.i18n_t(model, i18n_text.Title), fn(t) {
      let MetricsProjectTask(task: Task(title: title, ..), ..) = t
      text(title)
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Status), fn(t) {
      let MetricsProjectTask(task: Task(status: status, ..), ..) = t
      text(task_status_to_string(status))
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Claims), fn(t) {
      let MetricsProjectTask(claim_count: claim_count, ..) = t
      text(int.to_string(claim_count))
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Releases), fn(t) {
      let MetricsProjectTask(release_count: release_count, ..) = t
      text(int.to_string(release_count))
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.Completes), fn(t) {
      let MetricsProjectTask(complete_count: complete_count, ..) = t
      text(int.to_string(complete_count))
    }),
    data_table.column(update_helpers.i18n_t(model, i18n_text.FirstClaim), fn(t) {
      let MetricsProjectTask(first_claim_at: first_claim_at, ..) = t
      text(option_string_label(first_claim_at))
    }),
  ])
  |> data_table.with_rows(tasks, fn(t) {
    let MetricsProjectTask(task: Task(id: task_id, ..), ..) = t
    int.to_string(task_id)
  })
  |> data_table.view()
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
