//// View Assembler for Scrumbringer client.
////
//// ## Mission
////
//// Thin assembler that composes views from domain-specific view modules.
//// Delegates all rendering to feature modules while handling top-level
//// page routing and shared layout concerns.
////
//// ## Responsibilities
////
//// - Main `view` function dispatching to page views
//// - Admin and member page assembly
//// - Topbar, nav, and layout composition
//// - Theme and locale switches
////
//// ## Non-responsibilities
////
//// - Domain-specific views (see `features/*/view.gleam`)
//// - State management (see `client_update.gleam`)
//// - Type definitions (see `client_state.gleam`)
////
//// ## Relations
////
//// - **features/pool/view.gleam**: Pool canvas, task cards, filters
//// - **features/tasks/view.gleam**: Task view utilities and distributed task view docs
//// - **features/metrics/view.gleam**: Admin metrics views
//// - **features/skills/view.gleam**: Member skills/capabilities
//// - **features/admin/view.gleam**: Admin section views
//// - **features/auth/view.gleam**: Auth views (login, register, etc.)

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, div, h2, h3, label, option, p, select, span, style, text,
}
import lustre/event

import domain/org_role
import domain/project.{type Project}
import domain/user.{type User}

import scrumbringer_client/client_state.{
  type Model, type Msg, AcceptInvite as AcceptInvitePage, Admin, Loaded,
  LocaleSelected, Login, LogoutClicked, Member,
  MemberCompleteClicked, MemberNowWorkingPauseClicked, MemberNowWorkingStartClicked,
  MemberReleaseClicked, NavigateTo, Push,
  ResetPassword as ResetPasswordPage, ThemeSelected, ToastDismissed,
}
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/features/now_working/panel as now_working_panel
import scrumbringer_client/features/pool/view as pool_view
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/features/skills/view as skills_view
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/i18n/i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme
import scrumbringer_client/ui/css_class as css
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/layout as ui_layout
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/update_helpers

import domain/task.{type Task, ActiveTask, Task}
import domain/task_status.{Claimed, Taken}

// =============================================================================
// Types
// =============================================================================

/// Navigation group definition for sidebar rendering.
type NavGroup {
  NavGroup(
    label_key: i18n_text.Text,
    sections: List(permissions.AdminSection),
  )
}

/// All sidebar navigation groups in display order.
fn nav_groups() -> List(NavGroup) {
  [
    NavGroup(i18n_text.NavGroupOrganization, [
      permissions.Invites,
      permissions.OrgSettings,
    ]),
    NavGroup(i18n_text.NavGroupProjects, [
      permissions.Projects,
      permissions.Metrics,
      permissions.RuleMetrics,
    ]),
    NavGroup(i18n_text.NavGroupConfiguration, [
      permissions.Members,
      permissions.Capabilities,
      permissions.TaskTypes,
    ]),
    NavGroup(i18n_text.NavGroupContent, [
      permissions.Cards,
      permissions.Workflows,
      permissions.TaskTemplates,
    ]),
  ]
}

// =============================================================================
// Main View
// =============================================================================

/// Renders the main application view.
pub fn view(model: Model) -> Element(Msg) {
  div(
    [
      attribute.class("app"),
      attribute.attribute("style", theme.css_vars(model.theme)),
    ],
    [
      style([], styles.base_css()),
      // A02: Skip link for keyboard navigation
      a(
        [
          attribute.href("#main-content"),
          attribute.class("skip-link"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.SkipToContent))],
      ),
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

/// Test helper for now_working elapsed time calculation.
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

// =============================================================================
// Admin Views
// =============================================================================

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
          // A02: Skip link target
          div(
            [
              attribute.class("content"),
              attribute.attribute("id", "main-content"),
              attribute.attribute("tabindex", "-1"),
            ],
            [view_section(model, user, projects, selected)],
          ),
        ]),
      ])
    }
  }
}

fn view_topbar(model: Model, user: User) -> Element(Msg) {
  let show_project_selector =
    model.active_section == permissions.Members
    || model.active_section == permissions.TaskTypes
    || model.active_section == permissions.Metrics

  div([attribute.class("topbar")], [
    div([attribute.class("topbar-title")], [
      text(i18n.t(model.locale, admin_section_label(model.active_section))),
    ]),
    case show_project_selector {
      True -> view_project_selector(model)
      False -> element.none()
    },
    div([attribute.class("topbar-actions")], [
      // H01-H03: Group theme and locale in settings group
      div([attribute.class("topbar-settings-group")], [
        view_theme_switch(model),
        view_locale_switch(model),
      ]),
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
      _ -> view_nav_grouped(model, sections)
    },
  ])
}

/// Renders the admin sidebar with grouped sections and icons.
///
/// Uses `nav_groups()` to define the group structure and filters to visible
/// sections, eliminating repetitive case expressions.
fn view_nav_grouped(
  model: Model,
  visible: List(permissions.AdminSection),
) -> Element(Msg) {
  let groups =
    nav_groups()
    |> list.filter_map(fn(group) {
      let NavGroup(label_key, group_sections) = group
      let visible_sections =
        list.filter(group_sections, fn(s) { list.contains(visible, s) })
      case visible_sections {
        [] -> Error(Nil)
        _ ->
          Ok(view_nav_group(
            model,
            update_helpers.i18n_t(model, label_key),
            visible_sections,
          ))
      }
    })

  div([], groups)
}

/// Renders a navigation group with title and items.
fn view_nav_group(
  model: Model,
  title: String,
  sections: List(permissions.AdminSection),
) -> Element(Msg) {
  div([attribute.class("sidebar-group")], [
    div([attribute.class("sidebar-group-title")], [text(title)]),
    div(
      [attribute.class("sidebar-group-items")],
      list.map(sections, fn(section) { view_nav_item(model, section) }),
    ),
  ])
}

/// Renders a single navigation item with icon.
fn view_nav_item(model: Model, section: permissions.AdminSection) -> Element(Msg) {
  let is_active = section == model.active_section
  let classes =
    [css.nav_item(), ..css.when(css.active(), is_active)]
    |> css.join

  let needs_project =
    section == permissions.Members || section == permissions.TaskTypes

  let disabled = needs_project && model.selected_project_id == opt.None

  button(
    [
      attribute.class(classes),
      attribute.disabled(disabled),
      event.on_click(NavigateTo(
        router.Admin(section, model.selected_project_id),
        Push,
      )),
    ],
    [
      view_nav_icon(section, model.theme),
      span([], [text(i18n.t(model.locale, admin_section_label(section)))]),
    ],
  )
}

/// Returns the heroicon element for an admin section.
///
/// Uses type-safe `icons.section_icon()` to map sections to heroicons,
/// eliminating magic strings and ensuring exhaustive coverage.
fn view_nav_icon(
  section: permissions.AdminSection,
  current_theme: theme.Theme,
) -> Element(Msg) {
  let icon = icons.section_icon(section)
  let url = icons.heroicon_typed_url(icon)
  let color = theme.icon_filter(current_theme)

  html.img([
    attribute.src(url),
    attribute.class(css.to_string(css.nav_item_icon())),
    attribute.attribute("style", "filter: " <> color),
    attribute.alt(""),
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
        permissions.Metrics -> metrics_view.view_metrics(model, selected)
        permissions.RuleMetrics -> admin_view.view_rule_metrics(model)
        permissions.Capabilities -> admin_view.view_capabilities(model)
        permissions.Members -> admin_view.view_members(model, selected)
        permissions.TaskTypes -> admin_view.view_task_types(model, selected)
        permissions.Cards -> admin_view.view_cards(model, selected)
        permissions.Workflows -> admin_view.view_workflows(model, selected)
        permissions.TaskTemplates ->
          admin_view.view_task_templates(model, selected)
      }
  }
}

// =============================================================================
// Member Views
// =============================================================================

fn view_member(model: Model) -> Element(Msg) {
  case model.user {
    opt.None -> auth_view.view_login(model)

    opt.Some(user) ->
      case model.is_mobile {
        // Mobile: mini-bar + bottom sheet layout
        True ->
          div([attribute.class("member member-mobile")], [
            view_member_topbar(model, user),
            view_member_nav(model),
            // A02: Skip link target - with padding for mini-bar
            div(
              [
                attribute.class("content member-content-mobile"),
                attribute.attribute("id", "main-content"),
                attribute.attribute("tabindex", "-1"),
              ],
              [view_member_section(model, user)],
            ),
            // Mobile mini-bar (sticky bottom)
            now_working_mobile.view_mini_bar(model),
            // Overlay when sheet is open
            now_working_mobile.view_overlay(model),
            // Bottom sheet
            now_working_mobile.view_panel_sheet(model, user.id),
          ])

        // Desktop: unified layout with persistent right panel
        False ->
          div([attribute.class("member")], [
            view_member_topbar(model, user),
            view_member_body(model, user),
          ])
      }
  }
}

/// Renders the member body with nav, content, and persistent right panel.
/// Uses pool-layout for consistent structure across all sections.
fn view_member_body(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    // Pool has special drag-drop handlers
    member_section.Pool ->
      div(
        [
          attribute.class("body"),
          attribute.attribute("id", "main-content"),
          attribute.attribute("tabindex", "-1"),
        ],
        [view_member_nav(model), pool_view.view_pool_body(model, user)],
      )

    // Other sections use unified layout with right panel
    _ ->
      div(
        [
          attribute.class("body"),
          attribute.attribute("id", "main-content"),
          attribute.attribute("tabindex", "-1"),
        ],
        [
          view_member_nav(model),
          div([attribute.class("pool-layout")], [
            div([attribute.class("content pool-main")], [
              view_member_section(model, user),
            ]),
            view_member_right_panel(model, user),
          ]),
        ],
      )
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
          member_section.Fichas -> i18n_text.MemberFichas
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
        _ -> element.none()
      },
      view_theme_switch(model),
      span([attribute.class("user")], [text(user.email)]),
      button([event.on_click(LogoutClicked)], [
        text(update_helpers.i18n_t(model, i18n_text.Logout)),
      ]),
    ]),
  ])
}

fn view_member_nav(model: Model) -> Element(Msg) {
  let items = case model.is_mobile {
    True -> [
      view_member_nav_button(model, member_section.MyBar, i18n_text.MyBar),
      view_member_nav_button(model, member_section.MySkills, i18n_text.MySkills),
      view_member_nav_button(model, member_section.Fichas, i18n_text.MemberFichas),
    ]

    False -> [
      view_member_nav_button(model, member_section.Pool, i18n_text.Pool),
      view_member_nav_button(model, member_section.MyBar, i18n_text.MyBar),
      view_member_nav_button(model, member_section.MySkills, i18n_text.MySkills),
      view_member_nav_button(model, member_section.Fichas, i18n_text.MemberFichas),
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
  label_text: i18n_text.Text,
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
    [text(update_helpers.i18n_t(model, label_text))],
  )
}

fn view_member_section(model: Model, user: User) -> Element(Msg) {
  case model.member_section {
    member_section.Pool -> pool_view.view_pool_main(model, user)
    member_section.MyBar -> my_bar_view.view_bar(model, user)
    member_section.MySkills -> skills_view.view_skills(model)
    member_section.Fichas -> fichas_view.view_fichas(model)
  }
}

// =============================================================================
// Shared Components
// =============================================================================

fn view_theme_switch(model: Model) -> Element(Msg) {
  ui_layout.theme_switch(model.locale, model.theme, ThemeSelected)
}

fn view_locale_switch(model: Model) -> Element(Msg) {
  ui_layout.locale_switch(model.locale, LocaleSelected)
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
          event.on_input(client_state.ProjectSelected),
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
      True -> element.none()
      False -> div([attribute.class("hint")], [text(helper)])
    },
  ])
}

// =============================================================================
// Helpers
// =============================================================================

/// Returns the i18n text key for an admin section label.
///
/// Used for nav items and topbar title display. Returns an i18n_text.Text
/// variant for use with i18n.t(). For browser title updates, use
/// router.update_admin_section_label() instead.
fn admin_section_label(section: permissions.AdminSection) -> i18n_text.Text {
  case section {
    permissions.Invites -> i18n_text.AdminInvites
    permissions.OrgSettings -> i18n_text.AdminOrgSettings
    permissions.Projects -> i18n_text.AdminProjects
    permissions.Metrics -> i18n_text.AdminMetrics
    permissions.RuleMetrics -> i18n_text.AdminRuleMetrics
    permissions.Members -> i18n_text.AdminMembers
    permissions.Capabilities -> i18n_text.AdminCapabilities
    permissions.TaskTypes -> i18n_text.AdminTaskTypes
    permissions.Cards -> i18n_text.AdminCards
    permissions.Workflows -> i18n_text.AdminWorkflows
    permissions.TaskTemplates -> i18n_text.AdminTaskTemplates
  }
}

// =============================================================================
// Member Right Panel (Unified)
// =============================================================================

/// Persistent right panel for member view.
/// Combines Now Working status/timer and claimed tasks list.
pub fn view_member_right_panel(model: Model, user: User) -> Element(Msg) {
  div([attribute.class("pool-right")], [
    now_working_panel.view(model),
    view_claimed_tasks_section(model, user),
  ])
}

/// Claimed tasks section within the right panel.
/// Shows list of tasks claimed by user with start/complete/release actions.
fn view_claimed_tasks_section(model: Model, user: User) -> Element(Msg) {
  let active_task_id = case update_helpers.now_working_active_task(model) {
    opt.Some(ActiveTask(task_id: id, ..)) -> opt.Some(id)
    opt.None -> opt.None
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
    h3([], [text(update_helpers.i18n_t(model, i18n_text.MyTasks))]),
    case claimed_tasks {
      [] ->
        empty_state.simple(
          icons.Hand,
          update_helpers.i18n_t(model, i18n_text.NoClaimedTasks),
        )
      _ ->
        div(
          [attribute.class("task-list")],
          list.map(claimed_tasks, fn(t) {
            view_claimed_task_row(model, user, t, active_task_id)
          }),
        )
    },
  ])
}

/// Renders a claimed task row with start/complete/release actions.
fn view_claimed_task_row(
  model: Model,
  _user: User,
  task: Task,
  active_task_id: opt.Option(Int),
) -> Element(Msg) {
  let Task(id: id, title: title, task_type: task_type, version: version, ..) =
    task
  let is_active = active_task_id == opt.Some(id)
  let disable_actions =
    model.member_task_mutation_in_flight || model.member_now_working_in_flight

  let start_or_pause = case is_active {
    True ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Pause),
          ),
          attribute.disabled(disable_actions),
          event.on_click(MemberNowWorkingPauseClicked),
        ],
        [text("⏸")],
      )
    False ->
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Start),
          ),
          attribute.disabled(disable_actions),
          event.on_click(MemberNowWorkingStartClicked(id)),
        ],
        [text("▶")],
      )
  }

  let row_class = case is_active {
    True -> "task-row task-row-active"
    False -> "task-row"
  }

  div([attribute.class(row_class)], [
    div([], [
      div([attribute.class("task-row-title")], [
        span([attribute.attribute("style", "margin-right: 6px;")], [
          admin_view.view_task_type_icon_inline(task_type.icon, 16, model.theme),
        ]),
        text(title),
      ]),
    ]),
    div([attribute.class("task-row-actions")], [
      start_or_pause,
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          attribute.disabled(disable_actions),
          event.on_click(MemberCompleteClicked(id, version)),
        ],
        [text("✓")],
      ),
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          attribute.disabled(disable_actions),
          event.on_click(MemberReleaseClicked(id, version)),
        ],
        [text("↩")],
      ),
    ]),
  ])
}
