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
//// - client_state.Admin and member page assembly
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
//// - **features/metrics/view.gleam**: client_state.Admin metrics views
//// - **features/skills/view.gleam**: client_state.Member skills/capabilities
//// - **features/admin/view.gleam**: client_state.Admin section views
//// - **features/auth/view.gleam**: Auth views (login, register, etc.)

import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}

// Story 4.5: Removed label, option, select - no longer used after unified layout
import lustre/element/html.{a, button, div, h2, h3, li, p, span, style, text, ul}
import lustre/event

import domain/org_role
import domain/project.{type Project}
import domain/remote.{Loaded}
import domain/task_state
import domain/task_status
import domain/user.{type User}
import domain/view_mode

import scrumbringer_client/client_state
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/features/i18n/msg as i18n_messages
import scrumbringer_client/features/layout/msg as layout_messages
import scrumbringer_client/features/pool/msg as pool_messages

// Story 4.8 UX: Collapse/expand card groups in Lista view
// Story 4.8 UX: Preferences popup toggle and theme/locale
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/assignments/view as assignments_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/capabilities/view as capabilities_view
import scrumbringer_client/features/cards/view as cards_view
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/view as now_working_view
import scrumbringer_client/features/pool/dialogs as pool_dialogs
import scrumbringer_client/features/pool/view as pool_view
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/features/skills/view as skills_view
import scrumbringer_client/features/task_types/view as task_types_view
import scrumbringer_client/features/workflows/view as workflows_view

// Story 4.5: i18n module no longer imported directly; use helpers/i18n wrapper
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme

// Story 4.5: css module no longer used after unified layout removal
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/confirm_dialog
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/task_actions
import scrumbringer_client/ui/task_state as ui_task_state

// Story 4.5: ui_layout no longer directly imported (used via panels)
import scrumbringer_client/client_ffi
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/utils/card_queries

import domain/task.{type Task, ActiveTask, Task, WorkSession}

import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/features/layout/left_panel
import scrumbringer_client/features/layout/responsive_drawer
import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/features/layout/view as layout_view
import scrumbringer_client/features/views/grouped_list
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/helpers/time as helpers_time

// =============================================================================
// Main View
// =============================================================================

/// Renders the main application view.
pub fn view(model: client_state.Model) -> Element(client_state.Msg) {
  div(
    [
      attribute.class("app"),
      attribute.attribute("style", theme.css_vars(model.ui.theme)),
    ],
    [
      style([], styles.base_css()),
      view_skip_link(model),
      view_global_overlays(model),
      view_page(model),
    ],
  )
}

fn view_skip_link(model: client_state.Model) -> Element(client_state.Msg) {
  // A02: Skip link for keyboard navigation
  a(
    [
      attribute.href("#main-content"),
      attribute.class("skip-link"),
    ],
    [text(helpers_i18n.i18n_t(model, i18n_text.SkipToContent))],
  )
}

fn view_global_overlays(model: client_state.Model) -> Element(client_state.Msg) {
  element.fragment([
    // New toast system with auto-dismiss (Story 4.8)
    ui_toast.view_container(model.ui.toast_state, fn(id) {
      client_state.ToastDismiss(id)
    }),
    // Global card dialog (Story 4.8 UX: renders on any page when open)
    case model.core.selected_project_id, model.admin.cards.cards_dialog_mode {
      opt.Some(project_id), opt.Some(_) ->
        admin_view.view_card_crud_dialog(model, project_id)
      _, _ -> element.none()
    },
    // Global task creation dialog (Story 4.8 UX: renders on any page when open)
    case model.member.pool.member_create_dialog_mode {
      dialog_mode.DialogCreate -> pool_dialogs.view_create_dialog(model)
      _ -> element.none()
    },
    // Global task detail dialog (renders from list/canvas/pool)
    case model.member.notes.member_notes_task_id {
      opt.Some(task_id) -> pool_dialogs.view_task_details(model, task_id)
      opt.None -> element.none()
    },
    // Global position edit dialog (renders from list/canvas/pool)
    case model.member.positions.member_position_edit_task {
      opt.Some(task_id) -> pool_dialogs.view_position_edit(model, task_id)
      opt.None -> element.none()
    },
  ])
}

fn view_page(model: client_state.Model) -> Element(client_state.Msg) {
  case model.core.page {
    client_state.Login -> auth_view.view_login(model)
    client_state.AcceptInvite -> auth_view.view_accept_invite(model)
    client_state.ResetPassword -> auth_view.view_reset_password(model)
    client_state.Admin -> view_admin(model)
    client_state.Member -> view_member(model)
  }
}

/// Test helper for now_working elapsed time calculation.
pub fn now_working_elapsed_from_ms_for_test(
  accumulated_s: Int,
  started_ms: Int,
  server_now_ms: Int,
) -> String {
  helpers_time.now_working_elapsed_from_ms(
    accumulated_s,
    started_ms,
    server_now_ms,
  )
}

// =============================================================================
// client_state.Admin Views (Story 4.5: Now uses 3-panel layout like client_state.Member views)
// =============================================================================

// Justification: nested case improves clarity for branching logic.
fn view_admin(model: client_state.Model) -> Element(client_state.Msg) {
  case model.core.user {
    opt.None -> auth_view.view_login(model)

    opt.Some(user) ->
      case model.ui.is_mobile {
        // Mobile: mini-bar + drawer layout (same as member)
        True ->
          view_mobile_shell(
            model,
            user,
            view_admin_section_content(model, user),
          )

        // Desktop: 3-panel layout (Story 4.5 unification)
        False ->
          div([attribute.class("member")], [
            view_admin_three_panel(model, user),
          ])
      }
  }
}

/// Renders the admin view using the new unified 3-panel layout (Story 4.5)
fn view_admin_three_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let projects = helpers_selection.active_projects(model)
  let is_pm = case helpers_selection.selected_project(model) {
    opt.Some(project) -> permissions.is_project_manager(project)
    opt.None -> False
  }
  let is_org_admin = user.org_role == org_role.Admin

  // Build panel configs (same left and right as member)
  let left_content =
    build_left_panel(model, user, projects, is_pm, is_org_admin)
  let center_content = build_admin_center_panel(model, user)
  let right_content = build_right_panel(model, user)

  layout_view.view_i18n(
    left_content,
    center_content,
    right_content,
    helpers_i18n.i18n_t(model, i18n_text.MainNavigation),
    helpers_i18n.i18n_t(model, i18n_text.MyActivity),
  )
}

/// Builds the center panel for admin/config/org routes
fn build_admin_center_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  div(
    [
      attribute.class("admin-center-panel"),
      attribute.attribute("data-testid", "admin-center-panel"),
    ],
    [view_admin_section_content(model, user)],
  )
}

/// Renders the admin section content (CRUD views)
fn view_admin_section_content(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let projects = helpers_selection.active_projects(model)
  let selected = helpers_selection.selected_project(model)
  view_section(model, user, projects, selected)
}

// Story 4.5: Old admin topbar, nav, nav_grouped, nav_group, nav_item, nav_icon
// functions removed - now using unified 3-panel layout with left_panel.gleam

// Justification: nested case improves clarity for branching logic.
fn view_section(
  model: client_state.Model,
  user: User,
  projects: List(Project),
  selected: opt.Option(Project),
) -> Element(client_state.Msg) {
  let allowed =
    permissions.can_access_section(
      model.core.active_section,
      user.org_role,
      projects,
      selected,
    )

  case allowed {
    False ->
      div([attribute.class("not-permitted")], [
        h2([], [text(helpers_i18n.i18n_t(model, i18n_text.NotPermitted))]),
        p([], [text(helpers_i18n.i18n_t(model, i18n_text.NotPermittedBody))]),
      ])

    True ->
      case model.core.active_section {
        permissions.Invites -> invites_view.view_invites(model)
        permissions.OrgSettings -> admin_view.view_org_settings(model)
        permissions.Projects -> projects_view.view_projects(model)
        permissions.Assignments -> assignments_view.view_assignments(model)
        permissions.Metrics -> metrics_view.view_metrics(model, selected)
        permissions.RuleMetrics -> workflows_view.view_rule_metrics(model)
        permissions.Capabilities -> capabilities_view.view(model)
        permissions.Members -> admin_view.view_members(model, selected)
        permissions.TaskTypes -> task_types_view.view(model, selected)
        permissions.Cards -> cards_view.view(model, selected)
        permissions.Workflows -> workflows_view.view_workflows(model, selected)
        permissions.TaskTemplates ->
          workflows_view.view_task_templates(model, selected)
      }
  }
}

// =============================================================================
// client_state.Member Views
// =============================================================================

// Justification: nested case improves clarity for branching logic.
fn view_member(model: client_state.Model) -> Element(client_state.Msg) {
  case model.core.user {
    opt.None -> auth_view.view_login(model)

    opt.Some(user) ->
      case model.ui.is_mobile {
        // Mobile: mini-bar + drawer layout
        True -> view_mobile_shell(model, user, view_member_section(model, user))

        // Desktop: new 3-panel layout (Story 4.4)
        False ->
          div([attribute.class("member")], [
            view_member_three_panel(model, user),
          ])
      }
  }
}

/// Mobile topbar with hamburger menu and user icon
fn view_mobile_topbar(
  model: client_state.Model,
  _user: User,
) -> Element(client_state.Msg) {
  div([attribute.class("mobile-topbar")], [
    button(
      [
        attribute.class("mobile-menu-btn"),
        attribute.attribute("data-testid", "mobile-menu-btn"),
        attribute.attribute("aria-label", "Open navigation menu"),
        event.on_click(client_state.layout_msg(
          layout_messages.MobileLeftDrawerToggled,
        )),
      ],
      [icons.view_heroicon_inline("bars-3", 24, model.ui.theme)],
    ),
    div([attribute.class("topbar-title-mobile")], [
      text(
        helpers_i18n.i18n_t(model, case model.member.pool.member_section {
          member_section.Pool -> i18n_text.Pool
          member_section.MyBar -> i18n_text.MyBar
          member_section.MySkills -> i18n_text.MySkills
          member_section.Fichas -> i18n_text.MemberFichas
        }),
      ),
    ]),
    button(
      [
        attribute.class("mobile-user-btn"),
        attribute.attribute("data-testid", "mobile-user-btn"),
        attribute.attribute("aria-label", "Open activity panel"),
        event.on_click(client_state.layout_msg(
          layout_messages.MobileRightDrawerToggled,
        )),
      ],
      [icons.view_heroicon_inline("user-circle", 24, model.ui.theme)],
    ),
  ])
}

fn view_mobile_shell(
  model: client_state.Model,
  user: User,
  main_content: Element(client_state.Msg),
) -> Element(client_state.Msg) {
  div([attribute.class("member member-mobile")], [
    view_mobile_topbar(model, user),
    // A02: Skip link target - with padding for mini-bar
    div(
      [
        attribute.class("content member-content-mobile"),
        attribute.attribute("id", "main-content"),
        attribute.attribute("tabindex", "-1"),
      ],
      [main_content],
    ),
    // Mobile mini-bar (sticky bottom)
    now_working_view.view_mini_bar(model),
    // Overlay when sheet is open
    now_working_view.view_overlay(model),
    // Bottom sheet
    now_working_view.view_panel_sheet(model, user.id),
    // Left drawer (navigation)
    view_mobile_left_drawer(model, user),
    // Right drawer (my activity)
    view_mobile_right_drawer(model, user),
  ])
}

/// Left drawer containing navigation
fn view_mobile_left_drawer(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let projects = helpers_selection.active_projects(model)
  let is_pm = case helpers_selection.selected_project(model) {
    opt.Some(project) -> permissions.is_project_manager(project)
    opt.None -> False
  }
  let is_org_admin = user.org_role == org_role.Admin

  let left_content =
    build_left_panel(model, user, projects, is_pm, is_org_admin)

  responsive_drawer.view(
    client_state.mobile_drawer_left_open(model.ui.mobile_drawer),
    responsive_drawer.Left,
    client_state.layout_msg(layout_messages.MobileDrawersClosed),
    left_content,
  )
}

/// Right drawer containing activity panel
fn view_mobile_right_drawer(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let right_content = build_right_panel(model, user)

  responsive_drawer.view(
    client_state.mobile_drawer_right_open(model.ui.mobile_drawer),
    responsive_drawer.Right,
    client_state.layout_msg(layout_messages.MobileDrawersClosed),
    right_content,
  )
}

fn view_member_section(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  case model.member.pool.member_section {
    member_section.Pool -> pool_view.view_pool_main(model, user)
    member_section.MyBar -> my_bar_view.view_bar(model, user)
    member_section.MySkills -> skills_view.view_skills(model)
    member_section.Fichas -> fichas_view.view_fichas(model)
  }
}

// =============================================================================
// 3-Panel Layout (New IA Redesign)
// =============================================================================

/// Renders the member view using the new 3-panel layout
fn view_member_three_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let projects = helpers_selection.active_projects(model)
  let is_pm = case helpers_selection.selected_project(model) {
    opt.Some(project) -> permissions.is_project_manager(project)
    opt.None -> False
  }
  let is_org_admin = user.org_role == org_role.Admin

  // Build panel configs
  let left_content =
    build_left_panel(model, user, projects, is_pm, is_org_admin)
  let center_content = build_center_panel(model, user)
  let right_content = build_right_panel(model, user)

  element.fragment([
    layout_view.view_i18n(
      left_content,
      center_content,
      right_content,
      helpers_i18n.i18n_t(model, i18n_text.MainNavigation),
      helpers_i18n.i18n_t(model, i18n_text.MyActivity),
    ),
    // Story 5.3: Card detail modal for Pool/Lista/Kanban views
    view_member_card_detail_modal(model, user),
    view_member_blocked_claim_modal(model),
  ])
}

fn view_member_blocked_claim_modal(
  model: client_state.Model,
) -> Element(client_state.Msg) {
  case model.member.pool.member_blocked_claim_task {
    opt.None -> element.none()
    opt.Some(#(task_id, _version)) -> {
      let task_opt =
        helpers_lookup.find_task_by_id(
          model.member.pool.member_tasks,
          task_id,
        )
      let task_title = case task_opt {
        opt.Some(t) -> t.title
        opt.None -> helpers_i18n.i18n_t(model, i18n_text.TaskNumber(task_id))
      }
      let blocking = case task_opt {
        opt.Some(t) ->
          list.filter(t.dependencies, fn(dep) {
            dep.status != task_status.Completed
          })
        opt.None -> []
      }
      let count = list.length(blocking)
      let warning =
        helpers_i18n.i18n_t(model, i18n_text.BlockedTaskWarning(count))
      let list_items =
        list.map(blocking, fn(dep) {
          let status_label = ui_task_state.label(model.ui.locale, dep.status)
          let status_text = case dep.status {
            task_status.Claimed(_) ->
              case dep.claimed_by {
                opt.Some(email) ->
                  helpers_i18n.i18n_t(model, i18n_text.ClaimedBy)
                  <> " "
                  <> email
                opt.None -> status_label
              }
            _ -> status_label
          }
          li([], [text(dep.title <> " - " <> status_text)])
        })

      confirm_dialog.view(confirm_dialog.ConfirmConfig(
        title: helpers_i18n.i18n_t(model, i18n_text.BlockedTaskTitle),
        body: [
          p([attribute.class("blocked-claim-title")], [text(task_title)]),
          p([attribute.class("blocked-claim-warning")], [text(warning)]),
          case list_items {
            [] -> element.none()
            _ -> ul([attribute.class("blocked-claim-list")], list_items)
          },
        ],
        confirm_label: helpers_i18n.i18n_t(model, i18n_text.Claim),
        cancel_label: helpers_i18n.i18n_t(model, i18n_text.Cancel),
        on_confirm: client_state.pool_msg(
          pool_messages.MemberBlockedClaimConfirmed,
        ),
        on_cancel: client_state.pool_msg(
          pool_messages.MemberBlockedClaimCancelled,
        ),
        is_open: True,
        is_loading: False,
        error: opt.None,
        confirm_class: "btn-primary",
      ))
    }
  }
}

// Justification: large function kept intact to preserve cohesive UI logic.
/// Builds the left panel with project selector and navigation
fn build_left_panel(
  model: client_state.Model,
  user: User,
  projects: List(Project),
  is_pm: Bool,
  is_org_admin: Bool,
) -> Element(client_state.Msg) {
  // Story 4.5: Get badge counts for sidebar
  let pending_invites_count = case model.admin.invites.invite_links {
    Loaded(links) -> list.count(links, fn(link) { link.used_at == opt.None })
    _ -> 0
  }

  let users_count = case model.admin.members.org_users_cache {
    Loaded(users) -> list.length(users)
    _ -> 0
  }

  // Story 4.5: Use Config and Org routes instead of client_state.Admin
  // Story 4.7: TRABAJO section visible for all roles (AC1, AC7-9)
  // Unified active indicator: build current route from page state
  let current_route = case model.core.page {
    client_state.Member ->
      opt.Some(router.Member(
        member_section.Pool,
        model.core.selected_project_id,
        opt.Some(model.member.pool.view_mode),
      ))
    client_state.Admin ->
      // Determine if it's a Config or Org section based on active_section
      case model.core.active_section {
        permissions.Invites
        | permissions.OrgSettings
        | permissions.Projects
        | permissions.Assignments
        | permissions.Metrics -> opt.Some(router.Org(model.core.active_section))
        _ ->
          opt.Some(router.Config(
            model.core.active_section,
            model.core.selected_project_id,
          ))
      }
    _ -> opt.None
  }

  left_panel.view(left_panel.LeftPanelConfig(
    locale: model.ui.locale,
    user: opt.Some(user),
    projects: projects,
    selected_project_id: model.core.selected_project_id,
    is_pm: is_pm,
    is_org_admin: is_org_admin,
    // Unified current route for active indicator across all nav items
    current_route: current_route,
    // Collapse state
    config_collapsed: client_state.sidebar_config_collapsed(
      model.ui.sidebar_collapse,
    ),
    org_collapsed: client_state.sidebar_org_collapsed(model.ui.sidebar_collapse),
    // Badge counts
    pending_invites_count: pending_invites_count,
    projects_count: list.length(projects),
    users_count: users_count,
    // Event handlers
    on_project_change: client_state.ProjectSelected,
    on_new_task: client_state.pool_msg(pool_messages.MemberCreateDialogOpened),
    on_new_card: client_state.pool_msg(pool_messages.OpenCardDialog(
      state_types.CardDialogCreate,
    )),
    // Navigation to work views (AC2)
    on_navigate_pool: client_state.NavigateTo(
      router.Member(
        member_section.Pool,
        model.core.selected_project_id,
        opt.Some(view_mode.Pool),
      ),
      client_state.Push,
    ),
    on_navigate_list: client_state.NavigateTo(
      router.Member(
        member_section.Pool,
        model.core.selected_project_id,
        opt.Some(view_mode.List),
      ),
      client_state.Push,
    ),
    on_navigate_cards: client_state.NavigateTo(
      router.Member(
        member_section.Pool,
        model.core.selected_project_id,
        opt.Some(view_mode.Cards),
      ),
      client_state.Push,
    ),
    // Config navigation
    on_navigate_config_team: client_state.NavigateTo(
      router.Config(permissions.Members, model.core.selected_project_id),
      client_state.Push,
    ),
    on_navigate_config_capabilities: client_state.NavigateTo(
      router.Config(permissions.Capabilities, model.core.selected_project_id),
      client_state.Push,
    ),
    // Story 4.9: New config section navigation
    on_navigate_config_cards: client_state.NavigateTo(
      router.Config(permissions.Cards, model.core.selected_project_id),
      client_state.Push,
    ),
    on_navigate_config_task_types: client_state.NavigateTo(
      router.Config(permissions.TaskTypes, model.core.selected_project_id),
      client_state.Push,
    ),
    on_navigate_config_templates: client_state.NavigateTo(
      router.Config(permissions.TaskTemplates, model.core.selected_project_id),
      client_state.Push,
    ),
    on_navigate_config_rules: client_state.NavigateTo(
      router.Config(permissions.Workflows, model.core.selected_project_id),
      client_state.Push,
    ),
    // AC31: Metrics link for PM/client_state.Admin
    on_navigate_config_metrics: client_state.NavigateTo(
      router.Config(permissions.RuleMetrics, model.core.selected_project_id),
      client_state.Push,
    ),
    on_navigate_org_invites: client_state.NavigateTo(
      router.Org(permissions.Invites),
      client_state.Push,
    ),
    on_navigate_org_users: client_state.NavigateTo(
      router.Org(permissions.OrgSettings),
      client_state.Push,
    ),
    on_navigate_org_projects: client_state.NavigateTo(
      router.Org(permissions.Projects),
      client_state.Push,
    ),
    on_navigate_org_assignments: client_state.NavigateTo(
      router.Org(permissions.Assignments),
      client_state.Push,
    ),
    // AC32: Org Metrics link for Org client_state.Admin
    on_navigate_org_metrics: client_state.NavigateTo(
      router.Org(permissions.Metrics),
      client_state.Push,
    ),
    on_toggle_config: client_state.layout_msg(
      layout_messages.SidebarConfigToggled,
    ),
    on_toggle_org: client_state.layout_msg(layout_messages.SidebarOrgToggled),
  ))
}

// Justification: large function kept intact to preserve cohesive UI logic.
/// Builds the center panel with view mode toggle and content
fn build_center_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  // Get filtered tasks and available filters
  let tasks = case model.member.pool.member_tasks {
    Loaded(t) -> t
    _ -> []
  }
  let task_types = case model.member.pool.member_task_types {
    Loaded(tt) -> tt
    _ -> []
  }
  let capabilities = case model.admin.capabilities.capabilities {
    Loaded(caps) -> caps
    _ -> []
  }
  let cards = card_queries.get_project_cards(model)

  // Build view-specific content
  let pool_content = pool_view.view_pool_main(model, user)
  // AC7: Extract org users for displaying claimed-by info
  let org_users = case model.admin.members.org_users_cache {
    Loaded(users) -> users
    _ -> []
  }
  let list_content =
    grouped_list.view(grouped_list.GroupedListConfig(
      locale: model.ui.locale,
      theme: model.ui.theme,
      tasks: tasks,
      cards: cards,
      org_users: org_users,
      // Story 4.8 UX: Use model state for collapse/expand
      expanded_cards: model.member.pool.member_list_expanded_cards,
      hide_completed: model.member.pool.member_list_hide_completed,
      on_toggle_card: fn(card_id) {
        client_state.pool_msg(pool_messages.MemberListCardToggled(card_id))
      },
      on_toggle_hide_completed: client_state.pool_msg(
        pool_messages.MemberListHideCompletedToggled,
      ),
      on_task_click: fn(task_id) {
        client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
      },
      on_task_claim: fn(task_id, version) {
        client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
      },
    ))
  let cards_content =
    kanban_board.view(kanban_board.KanbanConfig(
      locale: model.ui.locale,
      theme: model.ui.theme,
      cards: cards,
      tasks: tasks,
      // Story 4.8 UX: Added org_users for claimed_by display in task items
      org_users: org_users,
      is_pm_or_admin: {
        let is_pm = case helpers_selection.selected_project(model) {
          opt.Some(project) -> permissions.is_project_manager(project)
          opt.None -> False
        }
        is_pm || user.org_role == org_role.Admin
      },
      on_card_click: fn(card_id) {
        client_state.pool_msg(pool_messages.OpenCardDetail(card_id))
      },
      on_card_edit: fn(card_id) {
        client_state.pool_msg(
          pool_messages.OpenCardDialog(state_types.CardDialogEdit(card_id)),
        )
      },
      on_card_delete: fn(card_id) {
        client_state.pool_msg(
          pool_messages.OpenCardDialog(state_types.CardDialogDelete(card_id)),
        )
      },
      on_new_card: client_state.pool_msg(pool_messages.OpenCardDialog(
        state_types.CardDialogCreate,
      )),
      // Story 4.8 UX: Task interaction handlers for consistency with Lista view
      on_task_click: fn(task_id) {
        client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
      },
      on_task_claim: fn(task_id, version) {
        client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
      },
      // Story 4.12 AC8-AC9: Create task pre-assigned to card
      on_create_task_in_card: fn(card_id) {
        client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
          card_id,
        ))
      },
    ))

  center_panel.view(center_panel.CenterPanelConfig(
    locale: model.ui.locale,
    view_mode: model.member.pool.view_mode,
    on_view_mode_change: fn(mode) {
      client_state.pool_msg(pool_messages.ViewModeChanged(mode))
    },
    task_types: task_types,
    capabilities: capabilities,
    type_filter: model.member.pool.member_filters_type_id,
    capability_filter: model.member.pool.member_filters_capability_id,
    search_query: model.member.pool.member_filters_q,
    on_type_filter_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolTypeChanged(value))
    },
    on_capability_filter_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolCapabilityChanged(value))
    },
    on_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolSearchChanged(value))
    },
    pool_content: pool_content,
    list_content: list_content,
    cards_content: cards_content,
    // Drag handlers for pool (Story 4.7 fix)
    on_drag_move: fn(x, y) {
      client_state.pool_msg(pool_messages.MemberDragMoved(x, y))
    },
    on_drag_end: client_state.pool_msg(pool_messages.MemberDragEnded),
  ))
}

// Justification: large function kept intact to preserve cohesive UI logic.
/// Builds the right panel with activity and profile
fn build_right_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  // Get claimed tasks for "my tasks" section
  let my_tasks = case model.member.pool.member_tasks {
    Loaded(tasks) ->
      list.filter(tasks, fn(t) {
        case t.state {
          task_state.Claimed(
            claimed_by: claimed_by,
            mode: task_status.Taken,
            ..,
          ) -> claimed_by == user.id
          _ -> False
        }
      })
    _ -> []
  }

  // Build my cards with progress (cards user is assigned to via tasks)
  let my_cards = case card_queries.get_project_cards(model) {
    [] -> []
    cards -> {
      // Get all tasks to compute progress
      let all_tasks = case model.member.pool.member_tasks {
        Loaded(tasks) -> tasks
        _ -> []
      }
      // Find cards where user has claimed tasks
      cards
      |> list.filter_map(fn(card) {
        let card_tasks =
          list.filter(all_tasks, fn(t) { t.card_id == opt.Some(card.id) })
        let my_card_tasks =
          list.filter(card_tasks, fn(t) {
            case t.state {
              task_state.Claimed(claimed_by: claimed_by, ..) ->
                claimed_by == user.id
              _ -> False
            }
          })
        case my_card_tasks {
          [] -> Error(Nil)
          _ -> {
            let completed =
              list.count(card_tasks, fn(t) {
                task_state.to_status(t.state) == task_status.Completed
              })
            let total = list.length(card_tasks)
            Ok(right_panel.MyCardProgress(
              card_id: card.id,
              card_title: card.title,
              card_color: card.color,
              completed: completed,
              total: total,
            ))
          }
        }
      })
    }
  }

  // Build active tasks list (supports multiple concurrent tasks)
  let active_tasks_info =
    helpers_selection.now_working_all_sessions(model)
    |> list.map(fn(session) {
      let WorkSession(
        task_id: id,
        started_at: started_at,
        accumulated_s: accumulated_s,
      ) = session
      // Find task title and type icon
      let #(title, type_icon, card_color) = case model.member.pool.member_tasks {
        Loaded(tasks) ->
          case list.find(tasks, fn(t) { t.id == id }) {
            Ok(t) -> {
              let #(_card_title_opt, resolved_color) =
                card_queries.resolve_task_card_info(model, t)
              #(t.title, t.task_type.icon, resolved_color)
            }
            Error(_) -> #(
              "Task #" <> int.to_string(id),
              "clipboard-document",
              opt.None,
            )
          }
        _ -> #("Task #" <> int.to_string(id), "clipboard-document", opt.None)
      }
      // Calculate elapsed time
      let started_ms = client_ffi.parse_iso_ms(started_at)
      let local_now_ms = client_ffi.now_ms()
      let server_now_ms =
        local_now_ms - model.member.now_working.now_working_server_offset_ms
      let elapsed =
        helpers_time.now_working_elapsed_from_ms(
          accumulated_s,
          started_ms,
          server_now_ms,
        )
      right_panel.ActiveTaskInfo(
        task_id: id,
        task_title: title,
        task_type_icon: type_icon,
        card_color: card_color,
        elapsed_display: elapsed,
        is_paused: False,
      )
    })

  let #(drag_armed, drag_over_my_tasks) = pool_drag_flags(model)

  right_panel.view(right_panel.RightPanelConfig(
    locale: model.ui.locale,
    model: model,
    user: opt.Some(user),
    my_tasks: my_tasks,
    my_cards: my_cards,
    active_tasks: active_tasks_info,
    on_task_start: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
    },
    on_task_pause: fn(_task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingPauseClicked)
    },
    on_task_complete: fn(task_id) {
      // Find task version for complete action
      case model.member.pool.member_tasks {
        Loaded(tasks) ->
          case list.find(tasks, fn(t) { t.id == task_id }) {
            Ok(t) ->
              client_state.pool_msg(pool_messages.MemberCompleteClicked(
                task_id,
                t.version,
              ))
            Error(_) -> client_state.NoOp
          }
        _ -> client_state.NoOp
      }
    },
    on_logout: client_state.auth_msg(auth_messages.LogoutClicked),
    on_task_release: fn(task_id) {
      // Find task version for release action
      case model.member.pool.member_tasks {
        Loaded(tasks) ->
          case list.find(tasks, fn(t) { t.id == task_id }) {
            Ok(t) ->
              client_state.pool_msg(pool_messages.MemberReleaseClicked(
                task_id,
                t.version,
              ))
            Error(_) -> client_state.NoOp
          }
        _ -> client_state.NoOp
      }
    },
    on_card_click: fn(card_id) {
      client_state.pool_msg(pool_messages.OpenCardDetail(card_id))
    },
    // Drag-to-claim state for Pool view (Story 4.7)
    drag_armed: drag_armed,
    drag_over_my_tasks: drag_over_my_tasks,
    // Preferences popup (Story 4.8 UX: moved from inline to popup)
    preferences_popup_open: model.ui.preferences_popup_open,
    on_preferences_toggle: client_state.layout_msg(
      layout_messages.PreferencesPopupToggled,
    ),
    current_theme: model.ui.theme,
    on_theme_change: client_state.ThemeSelected,
    on_locale_change: fn(value) {
      client_state.i18n_msg(i18n_messages.LocaleSelected(value))
    },
    disable_actions: model.member.pool.member_task_mutation_in_flight
      || model.member.now_working.member_now_working_in_flight,
  ))
}

// Story 4.5: Removed view_theme_switch, view_locale_switch, view_project_selector,
// admin_section_label - no longer needed after unified layout
// Theme/locale switches are now in the layout panels

// =============================================================================
// client_state.Member Right Panel (Unified)
// =============================================================================

/// Persistent right panel for member view.
/// Combines Now Working status/timer and claimed tasks list.
pub fn view_member_right_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  div([attribute.class("pool-right")], [
    now_working_view.view_panel(model),
    view_claimed_tasks_section(model, user),
  ])
}

/// Claimed tasks section within the right panel.
/// Shows list of tasks claimed by user with start/complete/release actions.
fn view_claimed_tasks_section(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let #(drag_armed, drag_over_my_tasks) = pool_drag_flags(model)
  let active_task_id = case helpers_selection.now_working_active_task(model) {
    opt.Some(ActiveTask(task_id: id, ..)) -> opt.Some(id)
    opt.None -> opt.None
  }

  let claimed_tasks = case model.member.pool.member_tasks {
    Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        case t.state {
          task_state.Claimed(
            claimed_by: claimed_by,
            mode: task_status.Taken,
            ..,
          ) -> claimed_by == user.id
          _ -> False
        }
      })
      |> list.sort(by: my_bar_view.compare_member_bar_tasks)
    _ -> []
  }

  // Dropzone class for drag-to-claim visual feedback
  let dropzone_class = case drag_armed, drag_over_my_tasks {
    True, True -> "pool-my-tasks-dropzone drop-over"
    True, False -> "pool-my-tasks-dropzone drag-active"
    False, _ -> "pool-my-tasks-dropzone"
  }

  div(
    [
      attribute.attribute("id", "pool-my-tasks"),
      attribute.class(dropzone_class),
    ],
    [
      // Dropzone hint when dragging
      case drag_armed {
        True ->
          div([attribute.class("dropzone-hint")], [
            text(
              helpers_i18n.i18n_t(model, i18n_text.Claim)
              <> ": "
              <> helpers_i18n.i18n_t(model, i18n_text.MyTasks),
            ),
          ])
        False -> element.none()
      },
      h3([], [text(helpers_i18n.i18n_t(model, i18n_text.MyTasks))]),
      case claimed_tasks {
        [] ->
          empty_state.simple(
            icons.Hand,
            helpers_i18n.i18n_t(model, i18n_text.NoClaimedTasks),
          )
        _ ->
          div(
            [attribute.class("task-list")],
            list.map(claimed_tasks, fn(t) {
              view_claimed_task_row(model, user, t, active_task_id)
            }),
          )
      },
    ],
  )
}

fn pool_drag_flags(model: client_state.Model) -> #(Bool, Bool) {
  case model.member.pool.member_pool_drag {
    state_types.PoolDragDragging(over_my_tasks: over, ..) -> #(True, over)
    state_types.PoolDragPendingRect -> #(True, False)
    state_types.PoolDragIdle -> #(False, False)
  }
}

/// Renders a claimed task row with start/complete/release actions.
fn view_claimed_task_row(
  model: client_state.Model,
  _user: User,
  task: Task,
  active_task_id: opt.Option(Int),
) -> Element(client_state.Msg) {
  let Task(id: id, title: title, task_type: task_type, version: version, ..) =
    task
  let is_active = active_task_id == opt.Some(id)
  let disable_actions =
    model.member.pool.member_task_mutation_in_flight
    || model.member.now_working.member_now_working_in_flight

  let start_or_pause = case is_active {
    True ->
      task_actions.pause_icon(
        helpers_i18n.i18n_t(model, i18n_text.Pause),
        client_state.pool_msg(pool_messages.MemberNowWorkingPauseClicked),
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
      )
    False ->
      task_actions.icon_action(
        helpers_i18n.i18n_t(model, i18n_text.Start),
        client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(id)),
        icons.Play,
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
      )
  }

  let row_class = case is_active {
    True -> "task-row task-row-active"
    False -> "task-row"
  }

  div([attribute.class(row_class)], [
    element.fragment([
      div([attribute.class("task-row-title")], [
        span([attribute.attribute("style", "margin-right: 6px;")], [
          admin_view.view_task_type_icon_inline(
            task_type.icon,
            16,
            model.ui.theme,
          ),
        ]),
        text(title),
      ]),
    ]),
    div([attribute.class("task-row-actions")], [
      start_or_pause,
      task_actions.complete_icon(
        helpers_i18n.i18n_t(model, i18n_text.Complete),
        client_state.pool_msg(pool_messages.MemberCompleteClicked(id, version)),
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
      ),
      task_actions.release_icon(
        helpers_i18n.i18n_t(model, i18n_text.Release),
        client_state.pool_msg(pool_messages.MemberReleaseClicked(id, version)),
        action_buttons.SizeXs,
        disable_actions,
        "",
        opt.None,
        opt.None,
      ),
    ]),
  ])
}

// =============================================================================
// Card Detail Modal for Member Views
// =============================================================================

/// Renders the card detail modal for Pool/Lista/Kanban views.
/// Story 5.3: Delegates to fichas_view.view_card_detail_modal.
fn view_member_card_detail_modal(
  model: client_state.Model,
  _user: User,
) -> Element(client_state.Msg) {
  fichas_view.view_card_detail_modal(model)
}
