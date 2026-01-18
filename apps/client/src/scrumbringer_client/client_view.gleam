//// View functions for Scrumbringer client.
////
//// ## Mission
////
//// Provides all view rendering functions for the Lustre SPA. Pure functions
//// that transform Model state into Element(Msg) trees.
////
//// ## Responsibilities
////
//// - Main `view` function dispatching to page-specific views
//// - Page views: login, accept_invite, reset_password, admin, member
//// - Component views: toast, topbar, nav, dialogs, forms
//// - Admin section views: projects, members, capabilities, invites, etc.
//// - Member section views: pool, bar, skills, metrics
////
//// ## Non-responsibilities
////
//// - State management (see `client_update.gleam`)
//// - Type definitions (see `client_state.gleam`)
//// - API calls (see `api/` modules)
////
//// ## Relations
////
//// - **client_state.gleam**: Provides Model, Msg, and state types
//// - **client_update.gleam**: Provides update function
//// - **scrumbringer_client.gleam**: Entry point that uses this view
//// - **update_helpers.gleam**: Provides i18n_t, format helpers
////
//// ## Line Count Justification
////
//// ~1800 lines: Contains pool canvas views and task card rendering that are
//// tightly coupled to drag-drop state, mouse event handlers, and canvas
//// positioning. Extracting pool/view.gleam and tasks/view.gleam was deferred
//// (see ref3-005F story) due to:
//// - High technical risk from threading drag state through multiple modules
//// - Mouse event handlers (mousemove/mouseup/mouseleave) coordination
//// - Canvas positioning logic interleaved with task rendering
//// Follow-up: Planned for Sprint 4 after comprehensive drag-drop refactor.

import gleam/dict
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, h2, h3, input, label, option, p, select, span,
  style, table, tbody, td, text, th, thead, tr,
}
import lustre/event

import scrumbringer_domain/org_role
import scrumbringer_domain/user.{type User}

// Domain types from shared
import domain/project.{type Project, Project}
import domain/task.{type Task, Task, TaskNote}
import domain/task_type.{type TaskTypeInline}
import domain/task_status.{Available, Claimed, Taken, task_status_to_string}
import domain/metrics.{
  type MetricsProjectTask, type OrgMetricsBucket,
  type OrgMetricsOverview, type OrgMetricsProjectOverview,
  type OrgMetricsProjectTasksPayload, MetricsProjectTask,
  OrgMetricsBucket, OrgMetricsOverview, OrgMetricsProjectOverview,
  OrgMetricsProjectTasksPayload,
}
import scrumbringer_client/client_ffi
import scrumbringer_client/member_section
import scrumbringer_client/member_visuals
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme
import scrumbringer_client/ui/layout as ui_layout
import scrumbringer_client/ui/remote as ui_remote
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/update_helpers
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/view as now_working_view
import scrumbringer_client/features/projects/view as projects_view

import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text

import scrumbringer_client/client_state.{
  type Model, type Msg, AcceptInvite as AcceptInvitePage,
  Admin, Failed, Loaded, Loading,
  LocaleSelected, Login, LogoutClicked, Member,
  MemberClaimClicked, MemberCompleteClicked,
  MemberCreateDescriptionChanged, MemberCreateDialogClosed,
  MemberCreateDialogOpened, MemberCreatePriorityChanged, MemberCreateSubmitted,
  MemberCreateTitleChanged, MemberCreateTypeIdChanged, MemberDragEnded,
  MemberDragMoved, MemberDragStarted, MemberNoteContentChanged,
  MemberNoteSubmitted,
  MemberPoolCapabilityChanged, MemberPoolFiltersToggled, MemberPoolSearchChanged,
  MemberPoolSearchDebounced, MemberPoolTypeChanged, MemberPoolViewModeSet,
  MemberPositionEditClosed, MemberPositionEditSubmitted, MemberPositionEditXChanged,
  MemberPositionEditYChanged, MemberReleaseClicked,
  MemberSaveCapabilitiesClicked,
  MemberTaskDetailsClosed, MemberToggleCapability, MemberToggleMyCapabilitiesQuick,
  NavigateTo, NotAsked,
  ProjectSelected, Push, ResetPassword as ResetPasswordPage,
  ThemeSelected, ToastDismissed,
}

// =============================================================================
// View Helpers
// =============================================================================

fn page_title(section: permissions.AdminSection) -> i18n_text.Text {
  case section {
    permissions.Invites -> i18n_text.AdminInvites
    permissions.OrgSettings -> i18n_text.AdminOrgSettings
    permissions.Projects -> i18n_text.AdminProjects
    permissions.Metrics -> i18n_text.AdminMetrics
    permissions.Members -> i18n_text.AdminMembers
    permissions.Capabilities -> i18n_text.AdminCapabilities
    permissions.TaskTypes -> i18n_text.AdminTaskTypes
  }
}

pub fn now_working_elapsed_from_ms_for_test(
  accumulated_s: Int,
  started_ms: Int,
  server_now_ms: Int,
) -> String {
  update_helpers.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}

pub fn view(model: Model) -> Element(Msg) {
  div(
    [
      attribute.class("app"),
      attribute.attribute("style", theme.css_vars(model.theme)),
    ],
    [
      style([], styles.base_css()),
      ui_toast.view(
        model.toast,
        update_helpers.i18n_t(model, i18n_text.Dismiss),
        ToastDismissed,
      ),
      case model.page {
        Login -> auth_view.view_login(model)
        AcceptInvitePage -> auth_view.view_accept_invite(model)
        ResetPasswordPage -> auth_view.view_reset_password(model)
        Admin -> view_admin(model)
        Member -> view_member(model)
      },
    ],
  )
}

fn view_admin(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> auth_view.view_login(model)

    opt.Some(user) -> {
      let projects = update_helpers.active_projects(model)
      let selected = update_helpers.selected_project(model)
      let sections = permissions.visible_sections(user.org_role, projects)

      div([attribute.class("admin")], [
        view_topbar(model, user),
        div([attribute.class("body")], [
          view_nav(model, sections),
          div([attribute.class("content")], [
            view_section(model, user, projects, selected),
          ]),
        ]),
      ])
    }
  }
}

fn view_theme_switch(model: Model) -> Element(Msg) {
  ui_layout.theme_switch(model.locale, model.theme, ThemeSelected)
}

fn view_locale_switch(model: Model) -> Element(Msg) {
  ui_layout.locale_switch(model.locale, LocaleSelected)
}

fn view_topbar(model: Model, user: User) -> Element(Msg) {
  let show_project_selector =
    model.active_section == permissions.Members
    || model.active_section == permissions.TaskTypes
    || model.active_section == permissions.Metrics

  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(i18n.t(model.locale, page_title(model.active_section))),
    ]),
    case show_project_selector {
      True -> view_project_selector(model)
      False -> div([], [])
    },
    div([attribute.class("topbar-actions")], [
      view_theme_switch(model),
      view_locale_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button(
        [
          event.on_click(NavigateTo(
            router.Member(model.member_section, model.selected_project_id),
            Push,
          )),
        ],
        [text(i18n.t(model.locale, i18n_text.Pool))],
      ),
      button([event.on_click(LogoutClicked)], [
        text(i18n.t(model.locale, i18n_text.Logout)),
      ]),
    ]),
  ])
}

fn view_project_selector(model: Model) -> Element(Msg) {
  let projects = update_helpers.active_projects(model)

  let selected_id = case model.selected_project_id {
    opt.Some(id) -> int.to_string(id)
    opt.None -> ""
  }

  let empty_label = case model.page {
    Member -> update_helpers.i18n_t(model, i18n_text.AllProjects)
    _ -> update_helpers.i18n_t(model, i18n_text.SelectProjectToManageSettings)
  }

  let helper = case model.page, model.selected_project_id {
    Member, opt.None ->
      update_helpers.i18n_t(model, i18n_text.ShowingTasksFromAllProjects)
    Member, _ -> ""
    _, opt.None ->
      update_helpers.i18n_t(
        model,
        i18n_text.SelectProjectToManageMembersOrTaskTypes,
      )
    _, _ -> ""
  }

  div([attribute.class("project-selector")], [
    div([attribute.class("topbar-group")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.ProjectLabel))]),
      select(
        [
          attribute.value(selected_id),
          event.on_input(ProjectSelected),
        ],
        [
          option([attribute.value("")], empty_label),
          ..list.map(projects, fn(p) {
            option([attribute.value(int.to_string(p.id))], p.name)
          })
        ],
      ),
    ]),
    case helper == "" {
      True -> div([], [])
      False -> div([attribute.class("hint")], [text(helper)])
    },
  ])
}

fn view_nav(
  model: Model,
  sections: List(permissions.AdminSection),
) -> Element(Msg) {
  div([attribute.class("nav")], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.Admin))]),
    case sections {
      [] ->
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.NoAdminPermissions)),
        ])
      _ ->
        div(
          [],
          list.map(sections, fn(section) {
            let classes = case section == model.active_section {
              True -> "nav-item active"
              False -> "nav-item"
            }

            let needs_project =
              section == permissions.Members || section == permissions.TaskTypes

            let disabled =
              needs_project && model.selected_project_id == opt.None

            button(
              [
                attribute.class(classes),
                attribute.disabled(disabled),
                event.on_click(NavigateTo(
                  router.Admin(section, model.selected_project_id),
                  Push,
                )),
              ],
              [text(i18n.t(model.locale, page_title(section)))],
            )
          }),
        )
    },
  ])
}

fn view_section(
  model: Model,
  user: User,
  projects: List(Project),
  selected: opt.Option(Project),
) -> Element(Msg) {
  let allowed =
    permissions.can_access_section(
      model.active_section,
      user.org_role,
      projects,
      selected,
    )

  case allowed {
    False ->
      div([attribute.class("not-permitted")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NotPermittedBody))]),
      ])

    True ->
      case model.active_section {
        permissions.Invites -> invites_view.view_invites(model)
        permissions.OrgSettings -> admin_view.view_org_settings(model)
        permissions.Projects -> projects_view.view_projects(model)
        permissions.Metrics -> view_metrics(model, selected)
        permissions.Capabilities -> admin_view.view_capabilities(model)
        permissions.Members -> admin_view.view_members(model, selected)
        permissions.TaskTypes -> admin_view.view_task_types(model, selected)
      }
  }
}

fn view_metrics(model: Model, selected: opt.Option(Project)) -> Element(Msg) {
  div([attribute.class("section")], [
    view_metrics_overview_panel(model),
    view_metrics_project_panel(model, selected),
  ])
}

fn view_metrics_overview_panel(model: Model) -> Element(Msg) {
  ui_remote.view_remote_panel(
    remote: model.admin_metrics_overview,
    title: update_helpers.i18n_t(model, i18n_text.MetricsOverview),
    loading_msg: update_helpers.i18n_t(model, i18n_text.LoadingOverview),
    loaded: fn(overview) { view_metrics_overview_loaded(model, overview) },
  )
}

fn view_metrics_overview_loaded(
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
    view_metrics_summary_table(
      model,
      claimed_count,
      released_count,
      completed_count,
      release_rate_percent,
      pool_flow_ratio_percent,
    ),
    view_metrics_time_to_first_claim(
      model,
      time_to_first_claim_p50_ms,
      time_to_first_claim_sample_size,
      time_to_first_claim_buckets,
    ),
    view_metrics_release_rate_buckets(model, release_rate_buckets),
    view_metrics_by_project_table(model, by_project),
  ])
}

fn view_metrics_summary_table(
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

fn view_metrics_time_to_first_claim(
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
      view_metrics_bucket_table(model, buckets),
    ]),
  ])
}

fn view_metrics_release_rate_buckets(
  model: Model,
  buckets: List(OrgMetricsBucket),
) -> Element(Msg) {
  div([], [
    h3([], [
      text(update_helpers.i18n_t(model, i18n_text.ReleaseRateDistribution)),
    ]),
    view_metrics_bucket_table(model, buckets),
  ])
}

fn view_metrics_bucket_table(
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
    tbody(
      [],
      list.map(buckets, fn(b) {
        let OrgMetricsBucket(bucket: bucket, count: count) = b
        tr([], [td([], [text(bucket)]), td([], [text(int.to_string(count))])])
      }),
    ),
  ])
}

fn view_metrics_by_project_table(
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
      tbody([], list.map(by_project, view_metrics_project_row(model, _))),
    ]),
  ])
}

fn view_metrics_project_row(
  model: Model,
  p: OrgMetricsProjectOverview,
) -> Element(Msg) {
  let OrgMetricsProjectOverview(
    project_id: project_id,
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
      button(
        [
          attribute.class("btn-xs"),
          event.on_click(NavigateTo(
            router.Admin(permissions.Metrics, opt.Some(project_id)),
            Push,
          )),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.View))],
      ),
    ]),
  ])
}

fn view_metrics_project_panel(
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
      view_metrics_project_tasks_panel(model, project_name)
  }
}

fn view_metrics_project_tasks_panel(
  model: Model,
  project_name: String,
) -> Element(Msg) {
  let body = ui_remote.view_remote_inline(
    remote: model.admin_metrics_project_tasks,
    loading_msg: update_helpers.i18n_t(model, i18n_text.LoadingTasks),
    loaded: fn(payload) { view_metrics_project_tasks_table(model, payload) },
  )

  div([attribute.class("panel")], [
    h3([], [
      text(update_helpers.i18n_t(model, i18n_text.ProjectTasks(project_name))),
    ]),
    body,
  ])
}

fn view_metrics_project_tasks_table(
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
    tbody([], list.map(tasks, view_metrics_task_row)),
  ])
}

fn view_metrics_task_row(t: MetricsProjectTask) -> Element(Msg) {
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

// --- Member UI (Story 1.8) ---

fn view_member(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> auth_view.view_login(model)

    opt.Some(user) ->
      case model.is_mobile {
        True ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            now_working_view.view_panel(model),
            div([attribute.class("content")], [view_member_section(model, user)]),
          ])

        False ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            case model.member_section {
              member_section.Pool ->
                div(
                  [
                    attribute.class("body"),
                    event.on("mousemove", {
                      use x <- decode.field("clientX", decode.int)
                      use y <- decode.field("clientY", decode.int)
                      decode.success(MemberDragMoved(x, y))
                    }),
                    event.on("mouseup", decode.success(MemberDragEnded)),
                    // Safety: if leaving the pool layout while dragging, end drag.
                    event.on("mouseleave", decode.success(MemberDragEnded)),
                  ],
                  [
                    view_member_nav(model),
                    div([attribute.class("content pool-main")], [
                      view_member_pool_main(model, user),
                    ]),
                    div([attribute.class("pool-right")], [
                      view_pool_right_panel(model, user),
                    ]),
                  ],
                )

              _ ->
                div([], [
                  now_working_view.view_panel(model),
                  div([attribute.class("body")], [
                    view_member_nav(model),
                    div([attribute.class("content")], [
                      view_member_section(model, user),
                    ]),
                  ]),
                ])
            },
          ])
      }
  }
}

fn view_member_topbar(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(
        update_helpers.i18n_t(model, case model.member_section {
          member_section.Pool -> i18n_text.Pool
          member_section.MyBar -> i18n_text.MyBar
          member_section.MySkills -> i18n_text.MySkills
        }),
      ),
    ]),
    view_project_selector(model),
    div([attribute.class("topbar-actions")], [
      case user.org_role {
        org_role.Admin ->
          button(
            [
              event.on_click(NavigateTo(
                router.Admin(permissions.Invites, model.selected_project_id),
                Push,
              )),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Admin))],
          )
        _ -> div([], [])
      },
      view_theme_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [
        text(update_helpers.i18n_t(model, i18n_text.Logout)),
      ]),
    ]),
  ])
}

fn view_pool_right_panel(model: Model, user: User) -> Element(Msg) {
  let dropzone_class = case
    model.member_pool_drag_to_claim_armed,
    model.member_pool_drag_over_my_tasks
  {
    True, True -> "pool-my-tasks-dropzone drop-over"
    True, False -> "pool-my-tasks-dropzone drag-active"
    False, _ -> "pool-my-tasks-dropzone"
  }

  let claimed_tasks = case model.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        let Task(status: status, claimed_by: claimed_by, ..) = t
        status == Claimed(Taken) && claimed_by == opt.Some(user.id)
      })
      |> list.sort(by: my_bar_view.compare_member_bar_tasks)

    _ -> []
  }

  div([], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.NowWorking))]),
    now_working_view.view_panel(model),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.MyTasks))]),
    // Drop-to-claim target (optional UX): we wrap the My Tasks area so we can
    // measure it and highlight it while dragging.
    div(
      [
        attribute.attribute("id", "pool-my-tasks"),
        attribute.class(dropzone_class),
      ],
      [
        case model.member_pool_drag_to_claim_armed {
          True ->
            div([attribute.class("dropzone-hint")], [
              text(
                update_helpers.i18n_t(model, i18n_text.Claim)
                <> ": "
                <> update_helpers.i18n_t(model, i18n_text.MyTasks),
              ),
            ])
          False -> div([], [])
        },
        case claimed_tasks {
          [] ->
            div([attribute.class("empty")], [
              text(update_helpers.i18n_t(model, i18n_text.NoClaimedTasks)),
            ])
          _ ->
            div(
              [attribute.class("task-list")],
              list.map(claimed_tasks, fn(t) {
                my_bar_view.view_member_bar_task_row(model, user, t)
              }),
            )
        },
      ],
    ),
  ])
}

fn view_member_nav(model: Model) -> Element(Msg) {
  let items = case model.is_mobile {
    True -> [
      view_member_nav_button(model, member_section.MyBar, i18n_text.MyBar),
      view_member_nav_button(model, member_section.MySkills, i18n_text.MySkills),
    ]

    False -> [
      view_member_nav_button(model, member_section.Pool, i18n_text.Pool),
      view_member_nav_button(model, member_section.MyBar, i18n_text.MyBar),
      view_member_nav_button(model, member_section.MySkills, i18n_text.MySkills),
    ]
  }

  div([attribute.class("nav")], [
    h3([], [text(update_helpers.i18n_t(model, i18n_text.AppSectionTitle))]),
    div([], items),
  ])
}

fn view_member_nav_button(
  model: Model,
  section: member_section.MemberSection,
  label: i18n_text.Text,
) -> Element(Msg) {
  let classes = case section == model.member_section {
    True -> "nav-item active"
    False -> "nav-item"
  }

  button(
    [
      attribute.class(classes),
      event.on_click(NavigateTo(
        router.Member(section, model.selected_project_id),
        Push,
      )),
    ],
    [text(update_helpers.i18n_t(model, label))],
  )
}

fn view_member_section(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    member_section.Pool -> view_member_pool_main(model, user)
    member_section.MyBar -> my_bar_view.view_bar(model, user)
    member_section.MySkills -> view_member_skills(model)
  }
}

fn view_member_pool_main(model: Model, _user: User) -> Element(Msg) {
  case update_helpers.active_projects(model) {
    [] ->
      div([attribute.class("empty")], [
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsYet))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NoProjectsBody))]),
      ])

    _ -> {
      let filters_toggle_label = case model.member_pool_filters_visible {
        True -> update_helpers.i18n_t(model, i18n_text.HideFilters)
        False -> update_helpers.i18n_t(model, i18n_text.ShowFilters)
      }

      let canvas_classes = case model.member_pool_view_mode {
        pool_prefs.Canvas -> "btn-xs btn-active"
        pool_prefs.List -> "btn-xs"
      }

      let list_classes = case model.member_pool_view_mode {
        pool_prefs.List -> "btn-xs btn-active"
        pool_prefs.Canvas -> "btn-xs"
      }

      div([attribute.class("section")], [
        div([attribute.class("actions")], [
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(MemberPoolFiltersToggled),
            ],
            [text(filters_toggle_label)],
          ),
          button(
            [
              attribute.class(canvas_classes),
              attribute.attribute(
                "aria-label",
                update_helpers.i18n_t(model, i18n_text.ViewCanvas),
              ),
              event.on_click(MemberPoolViewModeSet(pool_prefs.Canvas)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Canvas))],
          ),
          button(
            [
              attribute.class(list_classes),
              attribute.attribute(
                "aria-label",
                update_helpers.i18n_t(model, i18n_text.ViewList),
              ),
              event.on_click(MemberPoolViewModeSet(pool_prefs.List)),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.List))],
          ),
          button(
            [
              attribute.class("btn-xs"),
              event.on_click(MemberCreateDialogOpened),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NewTaskShortcut))],
          ),
        ]),
        case model.member_pool_filters_visible {
          True -> view_member_filters(model)
          False -> div([], [])
        },
        view_member_tasks(model),
        case model.member_create_dialog_open {
          True -> view_member_create_dialog(model)
          False -> div([], [])
        },
        case model.member_notes_task_id {
          opt.Some(task_id) -> view_member_task_details(model, task_id)
          opt.None -> div([], [])
        },
        case model.member_position_edit_task {
          opt.Some(task_id) -> view_member_position_edit(model, task_id)
          opt.None -> div([], [])
        },
      ])
    }
  }
}

/// Render the member pool filter panel with status, type, capability, and search filters.
///
/// ## Size Justification (~120 lines)
///
/// Builds a filter form with 5 filter controls, each requiring:
/// - Options loading from model state (capabilities, task types)
/// - Event handlers for changes
/// - i18n labels
/// - Responsive layout considerations
///
/// The filters are semantically related and user-facing as a single panel.
/// Splitting individual filter controls would complicate the shared layout
/// and state coordination between filters.
fn view_member_filters(model: Model) -> Element(Msg) {
  let type_options = case model.member_task_types {
    Loaded(task_types) -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
      ..list.map(task_types, fn(tt) {
        option([attribute.value(int.to_string(tt.id))], tt.name)
      })
    ]

    _ -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
    ]
  }

  let capability_options = case model.capabilities {
    Loaded(caps) -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
      ..list.map(caps, fn(c) {
        option([attribute.value(int.to_string(c.id))], c.name)
      })
    ]

    _ -> [
      option(
        [attribute.value("")],
        update_helpers.i18n_t(model, i18n_text.AllOption),
      ),
    ]
  }

  let my_caps_active = model.member_quick_my_caps

  let my_caps_class = case my_caps_active {
    True -> "btn-xs btn-icon"
    False -> "btn-xs btn-icon"
  }

  div([attribute.class("filters-row")], [
    div([attribute.class("field")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.TypeLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.TypeLabel),
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("🏷")],
      ),
      label(
        [
          attribute.class("filter-label"),
          attribute.attribute("for", "pool-filter-type"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.TypeLabel))],
      ),
      select(
        [
          attribute.attribute("id", "pool-filter-type"),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.TypeLabel),
          ),
          attribute.value(model.member_filters_type_id),
          event.on_input(MemberPoolTypeChanged),
          attribute.disabled(case model.member_task_types {
            Loaded(_) -> False
            _ -> True
          }),
        ],
        type_options,
      ),
    ]),
    div([attribute.class("field")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.CapabilityLabel),
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("🎯")],
      ),
      label(
        [
          attribute.class("filter-label"),
          attribute.attribute("for", "pool-filter-capability"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel))],
      ),
      select(
        [
          attribute.attribute("id", "pool-filter-capability"),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.CapabilityLabel),
          ),
          attribute.value(model.member_filters_capability_id),
          event.on_input(MemberPoolCapabilityChanged),
        ],
        capability_options,
      ),
    ]),
    div([attribute.class("field")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel),
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("★")],
      ),
      label([attribute.class("filter-label")], [
        text(update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)),
      ]),
      button(
        [
          attribute.class(my_caps_class),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.MyCapabilitiesLabel)
              <> ": "
              <> case my_caps_active {
              True -> update_helpers.i18n_t(model, i18n_text.MyCapabilitiesOn)
              False -> update_helpers.i18n_t(model, i18n_text.MyCapabilitiesOff)
            },
          ),
          event.on_click(MemberToggleMyCapabilitiesQuick),
        ],
        [
          text(case my_caps_active {
            True -> "★"
            False -> "☆"
          }),
        ],
      ),
    ]),

    div([attribute.class("field filter-q")], [
      span([attribute.class("filter-tooltip")], [
        text(update_helpers.i18n_t(model, i18n_text.SearchLabel)),
      ]),
      span(
        [
          attribute.class("filter-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.SearchLabel),
          ),
          attribute.attribute("aria-hidden", "true"),
        ],
        [text("⌕")],
      ),
      label(
        [
          attribute.class("filter-label"),
          attribute.attribute("for", "pool-filter-q"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.SearchLabel))],
      ),
      input([
        attribute.attribute("id", "pool-filter-q"),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.SearchLabel),
        ),
        attribute.type_("text"),
        attribute.value(model.member_filters_q),
        event.on_input(MemberPoolSearchChanged),
        event.debounce(event.on_input(MemberPoolSearchDebounced), 350),
        attribute.placeholder(update_helpers.i18n_t(
          model,
          i18n_text.SearchPlaceholder,
        )),
      ]),
    ]),
  ])
}

fn view_member_tasks(model: Model) -> Element(Msg) {
  case model.member_tasks {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])
    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(tasks) -> {
      let available_tasks =
        tasks
        |> list.filter(fn(t) {
          let Task(status: status, ..) = t
          status == Available
        })

      case available_tasks {
        [] -> {
          let no_filters =
            string.trim(model.member_filters_type_id) == ""
            && string.trim(model.member_filters_capability_id) == ""
            && string.trim(model.member_filters_q) == ""

          case no_filters {
            True ->
              div([attribute.class("empty")], [
                h2([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.NoAvailableTasksRightNow,
                  )),
                ]),
                p([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.CreateFirstTaskToStartUsingPool,
                  )),
                ]),
                button([event.on_click(MemberCreateDialogOpened)], [
                  text(update_helpers.i18n_t(model, i18n_text.NewTask)),
                ]),
              ])

            False ->
              div([attribute.class("empty")], [
                text(update_helpers.i18n_t(
                  model,
                  i18n_text.NoTasksMatchYourFilters,
                )),
              ])
          }
        }

        _ -> {
          case model.member_pool_view_mode {
            pool_prefs.Canvas ->
              view_member_tasks_canvas(model, available_tasks)
            pool_prefs.List -> view_member_tasks_list(model, available_tasks)
          }
        }
      }
    }
  }
}

fn view_member_tasks_canvas(model: Model, tasks: List(Task)) -> Element(Msg) {
  div(
    [
      attribute.attribute("id", "member-canvas"),
      attribute.attribute(
        "style",
        "position: relative; min-height: 600px; touch-action: none;",
      ),
    ],
    list.map(tasks, fn(task) { view_member_task_card(model, task) }),
  )
}

fn view_member_tasks_list(model: Model, tasks: List(Task)) -> Element(Msg) {
  div(
    [attribute.class("task-list")],
    list.map(tasks, fn(task) { view_member_pool_task_row(model, task) }),
  )
}

fn view_member_pool_task_row(model: Model, task: Task) -> Element(Msg) {
  let Task(
    id: id,
    title: title,
    type_id: _type_id,
    task_type: task_type,
    priority: priority,
    created_at: created_at,
    version: version,
    ..,
  ) = task

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let disable_actions = model.member_task_mutation_in_flight

  let claim_action =
    button(
      [
        attribute.class("btn-xs btn-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Claim),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.Claim),
        ),
        event.on_click(MemberClaimClicked(id, version)),
        attribute.disabled(disable_actions),
      ],
      [text("✋")],
    )

  div([attribute.class("task-row")], [
    div([], [
      div([attribute.class("task-row-title")], [text(title)]),
      div([attribute.class("task-row-meta")], [
        text(update_helpers.i18n_t(model, i18n_text.MetaType)),
        case type_icon {
          opt.Some(icon) ->
            span([attribute.attribute("style", "margin-right:4px;")], [
              admin_view.view_task_type_icon_inline(icon, 16, model.theme),
            ])
        },
        text(type_label),
        text(" · "),
        text(update_helpers.i18n_t(model, i18n_text.MetaPriority)),
        text(int.to_string(priority)),
        text(" · "),
        text(update_helpers.i18n_t(model, i18n_text.MetaCreated)),
        text(created_at),
      ]),
    ]),
    div([attribute.class("task-row-actions")], [claim_action]),
  ])
}

/// Render a task card for the pool grid/canvas view with drag-and-drop support.
///
/// ## Size Justification (~180 lines)
///
/// Renders a complete task card with:
/// - Header (type icon, title, priority badge)
/// - Status indicators (claimed by, assignee)
/// - Action buttons (claim, start, notes, position edit)
/// - Drag-and-drop event handlers
/// - Position styling for canvas placement
/// - Conditional sections based on task state and user permissions
///
/// Task cards are cohesive UI units. Splitting would scatter related
/// rendering logic across helpers with no clear boundaries. The card
/// elements are interdependent (actions depend on status, layout depends
/// on all elements present).
fn view_member_task_card(model: Model, task: Task) -> Element(Msg) {
  let Task(
    id: id,
    type_id: _type_id,
    task_type: task_type,
    title: title,
    priority: priority,
    status: status,
    claimed_by: claimed_by,
    created_at: created_at,
    version: version,
    ..,
  ) = task

  let current_user_id = case model.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  let is_mine = claimed_by == opt.Some(current_user_id)

  let type_label = task_type.name

  let type_icon = opt.Some(task_type.icon)

  let highlight = member_should_highlight_task(model, opt.Some(task_type))

  let #(x, y) = case dict.get(model.member_positions_by_task, id) {
    Ok(xy) -> xy
    Error(_) -> #(0, 0)
  }

  let size = member_visuals.priority_to_px(priority)

  let age_days = age_in_days(created_at)

  let #(opacity, saturation) = decay_to_visuals(age_days)

  let prefer_left =
    // Flip the tooltip left when the card is near the right edge of the viewport.
    // Heuristic: if there is less than ~420px to the right, flip.
    x > 760

  let card_classes = case highlight, prefer_left {
    True, True -> "task-card highlight preview-left"
    True, False -> "task-card highlight"
    False, True -> "task-card preview-left"
    False, False -> "task-card"
  }

  let style =
    "position:absolute; left:"
    <> int.to_string(x)
    <> "px; top:"
    <> int.to_string(y)
    <> "px; width:"
    <> int.to_string(size)
    <> "px; height:"
    <> int.to_string(size)
    <> "px; opacity:"
    <> float.to_string(opacity)
    <> "; filter:saturate("
    <> float.to_string(saturation)
    <> ");"

  let disable_actions = model.member_task_mutation_in_flight

  // Make the primary action visible even on tiny cards (the card size is
  // priority-driven and content is overflow-hidden).
  let primary_action = case status, is_mine {
    Available, _ ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Claim),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.Claim),
          ),
          event.on_click(MemberClaimClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("✋")],
      )

    Claimed(_), True ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          event.on_click(MemberReleaseClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("⟲")],
      )

    _, _ -> div([], [])
  }

  let drag_handle =
    button(
      [
        attribute.class("btn-xs btn-icon secondary-action drag-handle"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Drag),
        ),
        attribute.attribute(
          "aria-label",
          update_helpers.i18n_t(model, i18n_text.Drag),
        ),
        // Avoid accidental form submits if this ends up in a form.
        attribute.attribute("type", "button"),
        event.on("mousedown", {
          use ox <- decode.field("offsetX", decode.int)
          use oy <- decode.field("offsetY", decode.int)
          decode.success(MemberDragStarted(id, ox, oy))
        }),
      ],
      [text("⠿")],
    )

  let complete_action = case status, is_mine {
    Claimed(_), True ->
      button(
        [
          attribute.class("btn-xs btn-icon secondary-action"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          attribute.attribute(
            "aria-label",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          event.on_click(MemberCompleteClicked(id, version)),
          attribute.disabled(disable_actions),
        ],
        [text("☑")],
      )

    _, _ -> div([], [])
  }

  div(
    [
      attribute.class(card_classes),
      attribute.attribute("style", style),
      attribute.attribute(
        "aria-describedby",
        "task-preview-" <> int.to_string(id),
      ),
    ],
    [
      div([attribute.class("task-card-top")], [
        div([attribute.class("task-card-actions")], [
          primary_action,
          drag_handle,
          // Note: complete is only valid for claimed tasks; keep it secondary.
          complete_action,
        ]),
      ]),
      div([attribute.class("task-card-body")], [
        div([attribute.class("task-card-center")], [
          case type_icon {
            opt.Some(icon) ->
              div([attribute.class("task-card-center-icon")], [
                admin_view.view_task_type_icon_inline(icon, 22, model.theme),
              ])
          },
          div(
            [
              attribute.class("task-card-title"),
              attribute.attribute("title", title),
            ],
            [text(title)],
          ),
        ]),
      ]),
      div(
        [
          attribute.class("task-card-preview"),
          attribute.attribute("id", "task-preview-" <> int.to_string(id)),
          attribute.attribute("role", "tooltip"),
        ],
        [
          div([attribute.class("task-preview-grid")], [
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverType)),
            ]),
            span([attribute.class("task-preview-value")], [text(type_label)]),
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverCreated)),
            ]),
            span([attribute.class("task-preview-value")], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.CreatedAgoDays(age_days),
              )),
            ]),
            span([attribute.class("task-preview-label")], [
              text(update_helpers.i18n_t(model, i18n_text.PopoverStatus)),
            ]),
            span([attribute.class("task-preview-value")], [
              span(
                [
                  attribute.class(
                    "task-preview-badge task-preview-badge-"
                    <> task_status_to_string(status),
                  ),
                ],
                [text(task_status_to_string(status))],
              ),
            ]),
          ]),
        ],
      ),
    ],
  )
}

fn view_member_create_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.NewTask))]),
      case model.member_create_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Title))]),
        input([
          attribute.type_("text"),
          attribute.attribute("maxlength", "56"),
          attribute.value(model.member_create_title),
          event.on_input(MemberCreateTitleChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Description))]),
        input([
          attribute.type_("text"),
          attribute.value(model.member_create_description),
          event.on_input(MemberCreateDescriptionChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Priority))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_create_priority),
          event.on_input(MemberCreatePriorityChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.TypeLabel))]),
        select(
          [
            attribute.value(model.member_create_type_id),
            event.on_input(MemberCreateTypeIdChanged),
          ],
          case model.member_task_types {
            Loaded(task_types) -> [
              option(
                [attribute.value("")],
                update_helpers.i18n_t(model, i18n_text.SelectType),
              ),
              ..list.map(task_types, fn(tt) {
                option([attribute.value(int.to_string(tt.id))], tt.name)
              })
            ]
            _ -> [
              option(
                [attribute.value("")],
                update_helpers.i18n_t(model, i18n_text.LoadingEllipsis),
              ),
            ]
          },
        ),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberCreateDialogClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberCreateSubmitted),
            attribute.disabled(model.member_create_in_flight),
          ],
          [
            text(case model.member_create_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Creating)
              False -> update_helpers.i18n_t(model, i18n_text.Create)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_member_skills(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.MySkills))]),
    case model.member_my_capabilities_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    view_member_skills_list(model),
    button(
      [
        event.on_click(MemberSaveCapabilitiesClicked),
        attribute.disabled(model.member_my_capabilities_in_flight),
      ],
      [
        text(case model.member_my_capabilities_in_flight {
          True -> update_helpers.i18n_t(model, i18n_text.Saving)
          False -> update_helpers.i18n_t(model, i18n_text.Save)
        }),
      ],
    ),
  ])
}

fn view_member_skills_list(model: Model) -> Element(Msg) {
  case model.capabilities {
    Loaded(capabilities) ->
      div(
        [attribute.class("skills-list")],
        list.map(capabilities, fn(c) {
          let selected = case
            dict.get(model.member_my_capability_ids_edit, c.id)
          {
            Ok(v) -> v
            Error(_) -> False
          }

          div([attribute.class("skill-row")], [
            span([attribute.class("skill-name")], [text(c.name)]),
            input([
              attribute.type_("checkbox"),
              attribute.attribute("checked", case selected {
                True -> "true"
                False -> "false"
              }),
              event.on_click(MemberToggleCapability(c.id)),
            ]),
          ])
        }),
      )

    _ ->
      div(
        [
          attribute.class("empty"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis))],
      )
  }
}

fn view_member_position_edit(model: Model, _task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditPosition))]),
      case model.member_position_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> div([], [])
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.XLabel))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_position_edit_x),
          event.on_input(MemberPositionEditXChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.YLabel))]),
        input([
          attribute.type_("number"),
          attribute.value(model.member_position_edit_y),
          event.on_input(MemberPositionEditYChanged),
        ]),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberPositionEditClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberPositionEditSubmitted),
            attribute.disabled(model.member_position_edit_in_flight),
          ],
          [
            text(case model.member_position_edit_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Saving)
              False -> update_helpers.i18n_t(model, i18n_text.Save)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_member_task_details(model: Model, task_id: Int) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.Notes))]),
      button([event.on_click(MemberTaskDetailsClosed)], [
        text(update_helpers.i18n_t(model, i18n_text.Close)),
      ]),
      view_member_notes(model, task_id),
    ]),
  ])
}

fn view_member_notes(model: Model, _task_id: Int) -> Element(Msg) {
  let current_user_id = case model.user {
    opt.Some(u) -> u.id
    opt.None -> 0
  }

  div([], [
    case model.member_notes {
      NotAsked | Loading ->
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
        ])
      Failed(err) -> div([attribute.class("error")], [text(err.message)])
      Loaded(notes) ->
        div(
          [],
          list.map(notes, fn(n) {
            let TaskNote(
              user_id: user_id,
              content: content,
              created_at: created_at,
              ..,
            ) = n
            let author = case user_id == current_user_id {
              True -> update_helpers.i18n_t(model, i18n_text.You)
              False ->
                update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
            }

            div([attribute.class("note")], [
              p([], [text(author <> " @ " <> created_at)]),
              p([], [text(content)]),
            ])
          }),
        )
    },
    case model.member_note_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> div([], [])
    },
    div([attribute.class("field")], [
      label([], [text(update_helpers.i18n_t(model, i18n_text.AddNote))]),
      input([
        attribute.type_("text"),
        attribute.value(model.member_note_content),
        event.on_input(MemberNoteContentChanged),
      ]),
    ]),
    button(
      [
        event.on_click(MemberNoteSubmitted),
        attribute.disabled(model.member_note_in_flight),
      ],
      [
        text(case model.member_note_in_flight {
          True -> update_helpers.i18n_t(model, i18n_text.Adding)
          False -> update_helpers.i18n_t(model, i18n_text.Add)
        }),
      ],
    ),
  ])
}

fn age_in_days(created_at: String) -> Int {
  client_ffi.days_since_iso(created_at)
}

fn decay_to_visuals(age_days: Int) -> #(Float, Float) {
  case age_days {
    d if d < 9 -> #(1.0, 1.0)
    d if d < 18 -> #(0.95, 0.85)
    d if d < 27 -> #(0.85, 0.65)
    _ -> #(0.8, 0.55)
  }
}

fn member_should_highlight_task(
  model: Model,
  _task_type: opt.Option(TaskTypeInline),
) -> Bool {
  case model.member_quick_my_caps {
    False -> False
    True ->
      // Capability highlighting depends on `task_type.capability_id`, which is
      // not present on the inline task type contract (id/name/icon).
      False
  }
}
