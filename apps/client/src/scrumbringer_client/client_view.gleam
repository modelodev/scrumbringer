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
import lustre/element/html.{a, button, div, h2, h3, p, span, style, text}
import lustre/event

import domain/org_role
import domain/project.{type Project}
import domain/user.{type User}
import domain/view_mode

import scrumbringer_client/client_state

// Story 4.8 UX: Collapse/expand card groups in Lista view
// Story 4.8 UX: Preferences popup toggle and theme/locale
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/features/now_working/panel as now_working_panel
import scrumbringer_client/features/pool/dialogs as pool_dialogs
import scrumbringer_client/features/pool/view as pool_view
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/features/skills/view as skills_view

// Story 4.5: i18n module no longer imported directly, using i18n_text via update_helpers
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme

// Story 4.5: css module no longer used after unified layout removal
import scrumbringer_client/ui/empty_state
import scrumbringer_client/ui/icons

// Story 4.5: ui_layout no longer directly imported (used via panels)
import scrumbringer_client/client_ffi
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/update_helpers

import domain/task.{type Task, ActiveTask, Task, WorkSession}
import domain/task_status.{Claimed, Taken}

import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/features/layout/left_panel
import scrumbringer_client/features/layout/responsive_drawer
import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/features/layout/three_panel_layout
import scrumbringer_client/features/views/grouped_list
import scrumbringer_client/features/views/kanban_board

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
    [text(update_helpers.i18n_t(model, i18n_text.SkipToContent))],
  )
}

fn view_global_overlays(model: client_state.Model) -> Element(client_state.Msg) {
  element.fragment([
    // New toast system with auto-dismiss (Story 4.8)
    ui_toast.view_container(model.ui.toast_state, fn(id) {
      client_state.ToastDismiss(id)
    }),
    // Global card dialog (Story 4.8 UX: renders on any page when open)
    case model.core.selected_project_id, model.admin.cards_dialog_mode {
      opt.Some(project_id), opt.Some(_) ->
        admin_view.view_card_crud_dialog(model, project_id)
      _, _ -> element.none()
    },
    // Global task creation dialog (Story 4.8 UX: renders on any page when open)
    case model.member.member_create_dialog_open {
      True -> pool_dialogs.view_create_dialog(model)
      False -> element.none()
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
  update_helpers.now_working_elapsed_from_ms(
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
  let projects = update_helpers.active_projects(model)
  let is_pm = case update_helpers.selected_project(model) {
    opt.Some(project) -> permissions.is_project_manager(project)
    opt.None -> False
  }
  let is_org_admin = user.org_role == org_role.Admin

  // Build panel configs (same left and right as member)
  let left_content =
    build_left_panel(model, user, projects, is_pm, is_org_admin)
  let center_content = build_admin_center_panel(model, user)
  let right_content = build_right_panel(model, user)

  three_panel_layout.view_i18n(
    left_content,
    center_content,
    right_content,
    update_helpers.i18n_t(model, i18n_text.MainNavigation),
    update_helpers.i18n_t(model, i18n_text.MyActivity),
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
  let projects = update_helpers.active_projects(model)
  let selected = update_helpers.selected_project(model)
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
        h2([], [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))]),
        p([], [text(update_helpers.i18n_t(model, i18n_text.NotPermittedBody))]),
      ])

    True ->
      case model.core.active_section {
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
        event.on_click(client_state.pool_msg(
          client_state.MobileLeftDrawerToggled,
        )),
      ],
      [icons.view_heroicon_inline("bars-3", 24, model.ui.theme)],
    ),
    div([attribute.class("topbar-title-mobile")], [
      text(
        update_helpers.i18n_t(model, case model.member.member_section {
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
        event.on_click(client_state.pool_msg(
          client_state.MobileRightDrawerToggled,
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
    now_working_mobile.view_mini_bar(model),
    // Overlay when sheet is open
    now_working_mobile.view_overlay(model),
    // Bottom sheet
    now_working_mobile.view_panel_sheet(model, user.id),
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
  let projects = update_helpers.active_projects(model)
  let is_pm = case update_helpers.selected_project(model) {
    opt.Some(project) -> permissions.is_project_manager(project)
    opt.None -> False
  }
  let is_org_admin = user.org_role == org_role.Admin

  let left_content =
    build_left_panel(model, user, projects, is_pm, is_org_admin)

  responsive_drawer.view(
    client_state.mobile_drawer_left_open(model.ui.mobile_drawer),
    responsive_drawer.Left,
    client_state.pool_msg(client_state.MobileDrawersClosed),
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
    client_state.pool_msg(client_state.MobileDrawersClosed),
    right_content,
  )
}

fn view_member_section(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  case model.member.member_section {
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
  let projects = update_helpers.active_projects(model)
  let is_pm = case update_helpers.selected_project(model) {
    opt.Some(project) -> permissions.is_project_manager(project)
    opt.None -> False
  }
  let is_org_admin = user.org_role == org_role.Admin

  // Build panel configs
  let left_content =
    build_left_panel(model, user, projects, is_pm, is_org_admin)
  let center_content = build_center_panel(model, user)
  let right_content = build_right_panel(model, user)

  three_panel_layout.view_i18n(
    left_content,
    center_content,
    right_content,
    update_helpers.i18n_t(model, i18n_text.MainNavigation),
    update_helpers.i18n_t(model, i18n_text.MyActivity),
  )
}

/// Builds the left panel with project selector and navigation
// Justification: large function kept intact to preserve cohesive UI logic.

fn build_left_panel(
  model: client_state.Model,
  user: User,
  projects: List(Project),
  is_pm: Bool,
  is_org_admin: Bool,
) -> Element(client_state.Msg) {
  // Story 4.5: Get badge counts for sidebar
  let pending_invites_count = case model.admin.invite_links {
    client_state.Loaded(links) ->
      list.count(links, fn(link) { link.used_at == opt.None })
    _ -> 0
  }

  // Story 4.5: Use Config and Org routes instead of client_state.Admin
  // Story 4.7: TRABAJO section visible for all roles (AC1, AC7-9)
  // Only show active view indicator when on client_state.Member page (AC3)
  let current_view = case model.core.page {
    client_state.Member -> opt.Some(model.member.view_mode)
    _ -> opt.None
  }

  left_panel.view(left_panel.LeftPanelConfig(
    locale: model.ui.locale,
    user: opt.Some(user),
    projects: projects,
    selected_project_id: model.core.selected_project_id,
    is_pm: is_pm,
    is_org_admin: is_org_admin,
    // Current view mode for active indicator (AC3) - only when on client_state.Member page
    current_view_mode: current_view,
    // Collapse state
    config_collapsed: client_state.sidebar_config_collapsed(
      model.ui.sidebar_collapse,
    ),
    org_collapsed: client_state.sidebar_org_collapsed(model.ui.sidebar_collapse),
    // Badge counts
    pending_invites_count: pending_invites_count,
    projects_count: list.length(projects),
    // Event handlers
    on_project_change: client_state.ProjectSelected,
    on_new_task: client_state.pool_msg(client_state.MemberCreateDialogOpened),
    on_new_card: client_state.pool_msg(client_state.OpenCardDialog(
      client_state.CardDialogCreate,
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
    // AC32: Org Metrics link for Org client_state.Admin
    on_navigate_org_metrics: client_state.NavigateTo(
      router.Org(permissions.Metrics),
      client_state.Push,
    ),
    on_toggle_config: client_state.pool_msg(client_state.SidebarConfigToggled),
    on_toggle_org: client_state.pool_msg(client_state.SidebarOrgToggled),
  ))
}

/// Builds the center panel with view mode toggle and content
// Justification: large function kept intact to preserve cohesive UI logic.

fn build_center_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  // Get filtered tasks and available filters
  let tasks = case model.member.member_tasks {
    client_state.Loaded(t) -> t
    _ -> []
  }
  let task_types = case model.member.member_task_types {
    client_state.Loaded(tt) -> tt
    _ -> []
  }
  let capabilities = case model.admin.capabilities {
    client_state.Loaded(caps) -> caps
    _ -> []
  }
  let cards = case model.admin.cards {
    client_state.Loaded(c) -> c
    _ -> []
  }

  // Build view-specific content
  let pool_content = pool_view.view_pool_main(model, user)
  // AC7: Extract org users for displaying claimed-by info
  let org_users = case model.admin.org_users_cache {
    client_state.Loaded(users) -> users
    _ -> []
  }
  let list_content =
    grouped_list.view(grouped_list.GroupedListConfig(
      locale: model.ui.locale,
      tasks: tasks,
      cards: cards,
      org_users: org_users,
      // Story 4.8 UX: Use model state for collapse/expand
      expanded_cards: model.member.member_list_expanded_cards,
      hide_completed: model.member.member_list_hide_completed,
      on_toggle_card: fn(card_id) {
        client_state.pool_msg(client_state.MemberListCardToggled(card_id))
      },
      on_toggle_hide_completed: client_state.pool_msg(
        client_state.MemberListHideCompletedToggled,
      ),
      on_task_click: fn(task_id) {
        client_state.pool_msg(client_state.MemberTaskDetailsOpened(task_id))
      },
      on_task_claim: fn(task_id, version) {
        client_state.pool_msg(client_state.MemberClaimClicked(task_id, version))
      },
    ))
  let cards_content =
    kanban_board.view(kanban_board.KanbanConfig(
      locale: model.ui.locale,
      cards: cards,
      tasks: tasks,
      // Story 4.8 UX: Added org_users for claimed_by display in task items
      org_users: org_users,
      is_pm_or_admin: {
        let is_pm = case update_helpers.selected_project(model) {
          opt.Some(project) -> permissions.is_project_manager(project)
          opt.None -> False
        }
        is_pm || user.org_role == org_role.Admin
      },
      on_card_click: fn(card_id) {
        client_state.pool_msg(client_state.OpenCardDetail(card_id))
      },
      on_card_edit: fn(card_id) {
        client_state.pool_msg(
          client_state.OpenCardDialog(client_state.CardDialogEdit(card_id)),
        )
      },
      on_card_delete: fn(card_id) {
        client_state.pool_msg(
          client_state.OpenCardDialog(client_state.CardDialogDelete(card_id)),
        )
      },
      on_new_card: client_state.pool_msg(client_state.OpenCardDialog(
        client_state.CardDialogCreate,
      )),
      // Story 4.8 UX: Task interaction handlers for consistency with Lista view
      on_task_click: fn(task_id) {
        client_state.pool_msg(client_state.MemberTaskDetailsOpened(task_id))
      },
      on_task_claim: fn(task_id, version) {
        client_state.pool_msg(client_state.MemberClaimClicked(task_id, version))
      },
    ))

  center_panel.view(center_panel.CenterPanelConfig(
    locale: model.ui.locale,
    view_mode: model.member.view_mode,
    on_view_mode_change: fn(mode) {
      client_state.pool_msg(client_state.ViewModeChanged(mode))
    },
    task_types: task_types,
    capabilities: capabilities,
    type_filter: parse_filter_id(model.member.member_filters_type_id),
    capability_filter: parse_filter_id(
      model.member.member_filters_capability_id,
    ),
    search_query: model.member.member_filters_q,
    on_type_filter_change: fn(value) {
      client_state.pool_msg(client_state.MemberPoolTypeChanged(value))
    },
    on_capability_filter_change: fn(value) {
      client_state.pool_msg(client_state.MemberPoolCapabilityChanged(value))
    },
    on_search_change: fn(value) {
      client_state.pool_msg(client_state.MemberPoolSearchChanged(value))
    },
    pool_content: pool_content,
    list_content: list_content,
    cards_content: cards_content,
    // Drag handlers for pool (Story 4.7 fix)
    on_drag_move: fn(x, y) {
      client_state.pool_msg(client_state.MemberDragMoved(x, y))
    },
    on_drag_end: client_state.pool_msg(client_state.MemberDragEnded),
  ))
}

/// Builds the right panel with activity and profile
// Justification: large function kept intact to preserve cohesive UI logic.

fn build_right_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  // Get claimed tasks for "my tasks" section
  let my_tasks = case model.member.member_tasks {
    client_state.Loaded(tasks) ->
      list.filter(tasks, fn(t) {
        t.status == Claimed(Taken) && t.claimed_by == opt.Some(user.id)
      })
    _ -> []
  }

  // Build my cards with progress (cards user is assigned to via tasks)
  let my_cards = case model.admin.cards {
    client_state.Loaded(cards) -> {
      // Get all tasks to compute progress
      let all_tasks = case model.member.member_tasks {
        client_state.Loaded(tasks) -> tasks
        _ -> []
      }
      // Find cards where user has claimed tasks
      cards
      |> list.filter_map(fn(card) {
        let card_tasks =
          list.filter(all_tasks, fn(t) { t.card_id == opt.Some(card.id) })
        let my_card_tasks =
          list.filter(card_tasks, fn(t) { t.claimed_by == opt.Some(user.id) })
        case my_card_tasks {
          [] -> Error(Nil)
          _ -> {
            let completed =
              list.count(card_tasks, fn(t) { t.status == task_status.Completed })
            let total = list.length(card_tasks)
            Ok(right_panel.MyCardProgress(
              card_id: card.id,
              card_title: card.title,
              completed: completed,
              total: total,
            ))
          }
        }
      })
    }
    _ -> []
  }

  // Build active tasks list (supports multiple concurrent tasks)
  let active_tasks_info =
    update_helpers.now_working_all_sessions(model)
    |> list.map(fn(session) {
      let WorkSession(
        task_id: id,
        started_at: started_at,
        accumulated_s: accumulated_s,
      ) = session
      // Find task title and type icon
      let #(title, type_icon) = case model.member.member_tasks {
        client_state.Loaded(tasks) ->
          case list.find(tasks, fn(t) { t.id == id }) {
            Ok(t) -> #(t.title, t.task_type.icon)
            Error(_) -> #("Task #" <> int.to_string(id), "clipboard-document")
          }
        _ -> #("Task #" <> int.to_string(id), "clipboard-document")
      }
      // Calculate elapsed time
      let started_ms = client_ffi.parse_iso_ms(started_at)
      let local_now_ms = client_ffi.now_ms()
      let server_now_ms =
        local_now_ms - model.member.now_working_server_offset_ms
      let elapsed =
        update_helpers.now_working_elapsed_from_ms(
          accumulated_s,
          started_ms,
          server_now_ms,
        )
      right_panel.ActiveTaskInfo(
        task_id: id,
        task_title: title,
        task_type_icon: type_icon,
        elapsed_display: elapsed,
        is_paused: False,
      )
    })

  let #(drag_armed, drag_over_my_tasks) = pool_drag_flags(model)

  right_panel.view(right_panel.RightPanelConfig(
    locale: model.ui.locale,
    user: opt.Some(user),
    my_tasks: my_tasks,
    my_cards: my_cards,
    active_tasks: active_tasks_info,
    on_task_start: fn(task_id) {
      client_state.pool_msg(client_state.MemberNowWorkingStartClicked(task_id))
    },
    on_task_pause: fn(_task_id) {
      client_state.pool_msg(client_state.MemberNowWorkingPauseClicked)
    },
    on_task_complete: fn(task_id) {
      // Find task version for complete action
      case model.member.member_tasks {
        client_state.Loaded(tasks) ->
          case list.find(tasks, fn(t) { t.id == task_id }) {
            Ok(t) ->
              client_state.pool_msg(client_state.MemberCompleteClicked(
                task_id,
                t.version,
              ))
            Error(_) -> client_state.NoOp
          }
        _ -> client_state.NoOp
      }
    },
    on_logout: client_state.auth_msg(client_state.LogoutClicked),
    on_task_release: fn(task_id) {
      // Find task version for release action
      case model.member.member_tasks {
        client_state.Loaded(tasks) ->
          case list.find(tasks, fn(t) { t.id == task_id }) {
            Ok(t) ->
              client_state.pool_msg(client_state.MemberReleaseClicked(
                task_id,
                t.version,
              ))
            Error(_) -> client_state.NoOp
          }
        _ -> client_state.NoOp
      }
    },
    on_card_click: fn(card_id) {
      client_state.pool_msg(client_state.OpenCardDetail(card_id))
    },
    // Drag-to-claim state for Pool view (Story 4.7)
    drag_armed: drag_armed,
    drag_over_my_tasks: drag_over_my_tasks,
    // Preferences popup (Story 4.8 UX: moved from inline to popup)
    preferences_popup_open: model.ui.preferences_popup_open,
    on_preferences_toggle: client_state.pool_msg(
      client_state.PreferencesPopupToggled,
    ),
    current_theme: model.ui.theme,
    on_theme_change: client_state.ThemeSelected,
    on_locale_change: client_state.LocaleSelected,
    disable_actions: model.member.member_task_mutation_in_flight
      || model.member.member_now_working_in_flight,
  ))
}

/// Parses a filter ID string to Option(Int)
fn parse_filter_id(s: String) -> opt.Option(Int) {
  case s {
    "" -> opt.None
    _ ->
      int.parse(s)
      |> opt.from_result
  }
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
    now_working_panel.view(model),
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
  let active_task_id = case update_helpers.now_working_active_task(model) {
    opt.Some(ActiveTask(task_id: id, ..)) -> opt.Some(id)
    opt.None -> opt.None
  }

  let claimed_tasks = case model.member.member_tasks {
    client_state.Loaded(tasks) ->
      tasks
      |> list.filter(fn(t) {
        let Task(status: status, claimed_by: claimed_by, ..) = t
        status == Claimed(Taken) && claimed_by == opt.Some(user.id)
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
              update_helpers.i18n_t(model, i18n_text.Claim)
              <> ": "
              <> update_helpers.i18n_t(model, i18n_text.MyTasks),
            ),
          ])
        False -> element.none()
      },
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
    ],
  )
}

fn pool_drag_flags(model: client_state.Model) -> #(Bool, Bool) {
  case model.member.member_pool_drag {
    client_state.PoolDragDragging(over_my_tasks: over, ..) -> #(True, over)
    client_state.PoolDragPendingRect -> #(True, False)
    client_state.PoolDragIdle -> #(False, False)
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
    model.member.member_task_mutation_in_flight
    || model.member.member_now_working_in_flight

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
          event.on_click(client_state.pool_msg(
            client_state.MemberNowWorkingPauseClicked,
          )),
        ],
        [icons.nav_icon(icons.Pause, icons.Small)],
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
          event.on_click(
            client_state.pool_msg(client_state.MemberNowWorkingStartClicked(id)),
          ),
        ],
        [icons.nav_icon(icons.Play, icons.Small)],
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
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Complete),
          ),
          attribute.disabled(disable_actions),
          event.on_click(
            client_state.pool_msg(client_state.MemberCompleteClicked(
              id,
              version,
            )),
          ),
        ],
        [icons.nav_icon(icons.Check, icons.Small)],
      ),
      button(
        [
          attribute.class("btn-xs btn-icon"),
          attribute.attribute(
            "title",
            update_helpers.i18n_t(model, i18n_text.Release),
          ),
          attribute.disabled(disable_actions),
          event.on_click(
            client_state.pool_msg(client_state.MemberReleaseClicked(id, version)),
          ),
        ],
        [icons.nav_icon(icons.Return, icons.Small)],
      ),
    ]),
  ])
}
