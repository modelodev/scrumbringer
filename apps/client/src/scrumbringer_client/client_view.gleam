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

import lustre/element/html.{a, button, div, h2, p, style, text}
import lustre/event

import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/org_role
import domain/project.{type Project}
import domain/task_type.{type TaskType}
import domain/user.{type User}
import domain/view_mode

import scrumbringer_client/client_state
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/features/i18n/msg as i18n_messages
import scrumbringer_client/features/layout/msg as layout_messages
import scrumbringer_client/features/pool/blocked_claim_modal
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/rule_metrics_view as admin_rule_metrics_view
import scrumbringer_client/features/admin/rule_metrics_view_config as admin_rule_metrics_view_config
import scrumbringer_client/features/admin/task_templates_view as admin_task_templates_view
import scrumbringer_client/features/admin/task_templates_view_config as admin_task_templates_view_config
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/admin/views/workflows as admin_workflows_view
import scrumbringer_client/features/admin/views/workflows_config as admin_workflows_config
import scrumbringer_client/features/admin/workflow_rules_view_config as admin_workflow_rules_config
import scrumbringer_client/features/assignments/components/project_card
import scrumbringer_client/features/assignments/components/user_card
import scrumbringer_client/features/assignments/view as assignments_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/capability_board/view as capability_board_view
import scrumbringer_client/features/fichas/view as fichas_view
import scrumbringer_client/features/fichas/view_config as fichas_view_config
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/features/milestones/access as milestone_access
import scrumbringer_client/features/milestones/view_config as milestones_view
import scrumbringer_client/features/my_bar/view as my_bar_view
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/features/people/view as people_view
import scrumbringer_client/features/pool/create_dialog_config
import scrumbringer_client/features/pool/position_edit_dialog_config
import scrumbringer_client/features/pool/task_details_dialog_config
import scrumbringer_client/features/pool/view_config as pool_view
import scrumbringer_client/features/projects/view as projects_view
import scrumbringer_client/features/skills/view as skills_view

import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme

import scrumbringer_client/ui/icons

import scrumbringer_client/client_ffi
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/utils/card_queries

import domain/task.{type Task}

import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/features/layout/center_panel_data
import scrumbringer_client/features/layout/left_panel
import scrumbringer_client/features/layout/left_panel_data
import scrumbringer_client/features/layout/responsive_drawer
import scrumbringer_client/features/layout/right_panel
import scrumbringer_client/features/layout/right_panel_data
import scrumbringer_client/features/layout/three_panel_layout
import scrumbringer_client/features/views/kanban_board
import scrumbringer_client/helpers/options as helpers_options
import scrumbringer_client/helpers/time as helpers_time
import scrumbringer_client/i18n/i18n

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
    [text(i18n.t(model.ui.locale, i18n_text.SkipToContent))],
  )
}

fn view_global_overlays(model: client_state.Model) -> Element(client_state.Msg) {
  element.fragment([
    ui_toast.view_container(
      model.ui.toast_state,
      fn(id) { client_state.ToastDismiss(id) },
      fn(action) { client_state.ToastActionTriggered(action) },
    ),
    case model.core.selected_project_id, model.admin.cards.cards_dialog_mode {
      opt.Some(project_id), opt.Some(_) ->
        admin_view.view_card_crud_dialog(model, project_id)
      _, _ -> element.none()
    },
    case model.member.pool.member_create_dialog_mode {
      dialog_mode.DialogCreate ->
        create_dialog_config.view(
          model.ui.locale,
          model.member.pool,
          project_cards(model),
          client_state.pool_msg(pool_messages.MemberCreateDialogClosed),
          client_state.pool_msg(pool_messages.MemberCreateSubmitted),
          fn(value) {
            client_state.pool_msg(pool_messages.MemberCreateTitleChanged(value))
          },
          fn(value) {
            client_state.pool_msg(pool_messages.MemberCreateDescriptionChanged(
              value,
            ))
          },
          fn(value) {
            client_state.pool_msg(pool_messages.MemberCreatePriorityChanged(
              value,
            ))
          },
          fn(value) {
            client_state.pool_msg(pool_messages.MemberCreateTypeIdChanged(value))
          },
          client_state.pool_msg(
            pool_messages.MemberCreateTypeOptionsRetryClicked,
          ),
          fn(value) {
            client_state.pool_msg(pool_messages.MemberCreateCardIdChanged(value))
          },
        )
      _ -> element.none()
    },
    // Global task detail dialog (renders from list/canvas/pool)
    case model.member.notes.member_notes_task_id {
      opt.Some(task_id) ->
        task_details_dialog_config.view(
          model.ui.locale,
          model.member.pool,
          model.member.dependencies,
          model.member.notes,
          model.core.user |> opt.map(fn(user) { user.id }),
          project_cards(model),
          task_id,
          task_details_callbacks(),
        )
      opt.None -> element.none()
    },
    // Global position edit dialog (renders from list/canvas/pool)
    case model.member.positions.member_position_edit_task {
      opt.Some(_) ->
        position_edit_dialog_config.view(
          model.ui.locale,
          model.member.positions,
          client_state.pool_msg(pool_messages.MemberPositionEditClosed),
          fn(value) {
            client_state.pool_msg(pool_messages.MemberPositionEditXChanged(
              value,
            ))
          },
          fn(value) {
            client_state.pool_msg(pool_messages.MemberPositionEditYChanged(
              value,
            ))
          },
          client_state.pool_msg(pool_messages.MemberPositionEditSubmitted),
        )
      opt.None -> element.none()
    },
  ])
}

fn task_details_callbacks() -> task_details_dialog_config.Callbacks(
  client_state.Msg,
) {
  task_details_dialog_config.Callbacks(
    on_close: client_state.pool_msg(pool_messages.MemberTaskDetailsClosed),
    on_tab_clicked: fn(tab) {
      client_state.pool_msg(pool_messages.MemberTaskDetailTabClicked(tab))
    },
    on_dependency_dialog_opened: client_state.pool_msg(
      pool_messages.MemberDependencyDialogOpened,
    ),
    on_dependency_dialog_closed: client_state.pool_msg(
      pool_messages.MemberDependencyDialogClosed,
    ),
    on_dependency_add_submitted: client_state.pool_msg(
      pool_messages.MemberDependencyAddSubmitted,
    ),
    on_dependency_search_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberDependencySearchChanged(value))
    },
    on_dependency_selected: fn(selected_task_id) {
      client_state.pool_msg(pool_messages.MemberDependencySelected(
        selected_task_id,
      ))
    },
    on_dependency_remove: fn(depends_on_task_id) {
      client_state.pool_msg(pool_messages.MemberDependencyRemoveClicked(
        depends_on_task_id,
      ))
    },
    on_edit_started: client_state.pool_msg(
      pool_messages.MemberTaskDetailEditStarted,
    ),
    on_edit_cancelled: client_state.pool_msg(
      pool_messages.MemberTaskDetailEditCancelled,
    ),
    on_edit_title_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberTaskDetailEditTitleChanged(
        value,
      ))
    },
    on_edit_description_changed: fn(value) {
      client_state.pool_msg(
        pool_messages.MemberTaskDetailEditDescriptionChanged(value),
      )
    },
    on_edit_submitted: client_state.pool_msg(
      pool_messages.MemberTaskDetailEditSubmitted,
    ),
    on_note_dialog_opened: client_state.pool_msg(
      pool_messages.MemberNoteDialogOpened,
    ),
    on_note_dialog_closed: client_state.pool_msg(
      pool_messages.MemberNoteDialogClosed,
    ),
    on_note_content_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberNoteContentChanged(value))
    },
    on_note_submitted: client_state.pool_msg(pool_messages.MemberNoteSubmitted),
    on_note_delete: fn(_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsClosed)
    },
    on_claim: fn(claim_task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(
        claim_task_id,
        version,
      ))
    },
    on_release: fn(release_task_id, version) {
      client_state.pool_msg(pool_messages.MemberReleaseClicked(
        release_task_id,
        version,
      ))
    },
    on_complete: fn(complete_task_id, version) {
      client_state.pool_msg(pool_messages.MemberCompleteClicked(
        complete_task_id,
        version,
      ))
    },
  )
}

fn view_page(model: client_state.Model) -> Element(client_state.Msg) {
  case model.core.page {
    client_state.Login -> auth_view.view_login(auth_config(model))
    client_state.AcceptInvite ->
      auth_view.view_accept_invite(auth_config(model))
    client_state.ResetPassword ->
      auth_view.view_reset_password(auth_config(model))
    client_state.Admin -> view_admin(model)
    client_state.Member -> view_member(model)
  }
}

fn auth_config(model: client_state.Model) -> auth_view.Config(client_state.Msg) {
  auth_view.Config(
    locale: model.ui.locale,
    auth: model.auth,
    origin: client_ffi.location_origin(),
    on_login_email_changed: fn(value) {
      client_state.auth_msg(auth_messages.LoginEmailChanged(value))
    },
    on_login_password_changed: fn(value) {
      client_state.auth_msg(auth_messages.LoginPasswordChanged(value))
    },
    on_login_submitted: client_state.auth_msg(auth_messages.LoginSubmitted),
    on_forgot_password_clicked: client_state.auth_msg(
      auth_messages.ForgotPasswordClicked,
    ),
    on_forgot_password_email_changed: fn(value) {
      client_state.auth_msg(auth_messages.ForgotPasswordEmailChanged(value))
    },
    on_forgot_password_submitted: client_state.auth_msg(
      auth_messages.ForgotPasswordSubmitted,
    ),
    on_forgot_password_copy_clicked: client_state.auth_msg(
      auth_messages.ForgotPasswordCopyClicked,
    ),
    on_forgot_password_dismissed: client_state.auth_msg(
      auth_messages.ForgotPasswordDismissed,
    ),
    on_accept_invite: fn(msg) {
      client_state.auth_msg(auth_messages.AcceptInvite(msg))
    },
    on_reset_password: fn(msg) {
      client_state.auth_msg(auth_messages.ResetPassword(msg))
    },
  )
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

fn view_admin(model: client_state.Model) -> Element(client_state.Msg) {
  case model.core.user {
    opt.None -> auth_view.view_login(auth_config(model))

    opt.Some(user) ->
      case model.ui.is_mobile {
        // Mobile: mini-bar + drawer layout (same as member)
        True ->
          view_mobile_shell(
            model,
            user,
            view_admin_section_content(model, user),
          )

        False ->
          div([attribute.class("member")], [
            view_admin_three_panel(model, user),
          ])
      }
  }
}

fn view_admin_three_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  // Build panel configs (same left and right as member)
  let left_content = build_left_panel(model, user)
  let center_content = build_admin_center_panel(model, user)
  let right_content = build_right_panel(model, user)

  three_panel_layout.view_i18n(
    left_content,
    center_content,
    right_content,
    i18n.t(model.ui.locale, i18n_text.MainNavigation),
    i18n.t(model.ui.locale, i18n_text.MyActivity),
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
  let projects = state_selectors.active_projects(model)
  let selected = state_selectors.selected_project(model)
  view_section(model, user, projects, selected)
}

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
        h2([], [
          text(i18n.t(model.ui.locale, i18n_text.NotPermitted)),
        ]),
        p([], [
          text(i18n.t(model.ui.locale, i18n_text.NotPermittedBody)),
        ]),
      ])

    True ->
      case model.core.active_section {
        permissions.Invites ->
          invites_view.view_invites(admin_invites_config(model))
        permissions.OrgSettings -> admin_view.view_org_settings(model)
        permissions.Projects ->
          projects_view.view_projects(admin_projects_config(model))
        permissions.Assignments ->
          assignments_view.view_assignments(admin_assignments_config(model))
        permissions.Metrics ->
          metrics_view.view_metrics(admin_metrics_config(model, selected))
        permissions.RuleMetrics ->
          admin_rule_metrics_view.view_rule_metrics(
            admin_rule_metrics_view_config.from_state(
              model.ui.locale,
              model.admin.metrics,
              admin_rule_metrics_callbacks(),
            ),
          )
        permissions.Capabilities -> admin_view.view_capabilities(model)
        permissions.Members -> admin_view.view_members(model, selected)
        permissions.TaskTypes -> admin_view.view_task_types(model, selected)
        permissions.Cards -> admin_view.view_cards(model, selected)
        permissions.Workflows ->
          admin_workflows_view.view_workflows(admin_workflows_config.from_state(
            model.ui.locale,
            model.ui.theme,
            selected,
            model.core.selected_project_id,
            model.admin.workflows,
            model.admin.rules,
            model.admin.task_templates,
            model.admin.task_types,
            admin_workflow_callbacks(),
          ))
        permissions.TaskTemplates ->
          admin_task_templates_view.view_task_templates(
            admin_task_templates_view_config.from_state(
              model.ui.locale,
              selected,
              model.core.selected_project_id,
              model.admin.task_templates,
              model.admin.task_types,
              admin_task_template_callbacks(),
            ),
          )
      }
  }
}

fn admin_invites_config(
  model: client_state.Model,
) -> invites_view.Config(client_state.Msg) {
  invites_view.Config(
    locale: model.ui.locale,
    invites: model.admin.invites,
    origin: client_ffi.location_origin(),
    on_create_dialog_opened: client_state.admin_msg(
      admin_messages.InviteCreateDialogOpened,
    ),
    on_create_dialog_closed: client_state.admin_msg(
      admin_messages.InviteCreateDialogClosed,
    ),
    on_create_submitted: client_state.admin_msg(
      admin_messages.InviteLinkCreateSubmitted,
    ),
    on_email_changed: fn(value) {
      client_state.admin_msg(admin_messages.InviteLinkEmailChanged(value))
    },
    on_link_copy_clicked: fn(full) {
      client_state.admin_msg(admin_messages.InviteLinkCopyClicked(full))
    },
    on_link_regenerate_clicked: fn(email) {
      client_state.admin_msg(admin_messages.InviteLinkRegenerateClicked(email))
    },
  )
}

fn admin_projects_config(
  model: client_state.Model,
) -> projects_view.Config(client_state.Msg) {
  projects_view.Config(
    locale: model.ui.locale,
    projects: model.core.projects,
    project_dialog: model.admin.projects,
    on_create_dialog_opened: client_state.admin_msg(
      admin_messages.ProjectCreateDialogOpened,
    ),
    on_create_dialog_closed: client_state.admin_msg(
      admin_messages.ProjectCreateDialogClosed,
    ),
    on_create_submitted: client_state.admin_msg(
      admin_messages.ProjectCreateSubmitted,
    ),
    on_create_name_changed: fn(value) {
      client_state.admin_msg(admin_messages.ProjectCreateNameChanged(value))
    },
    on_edit_dialog_opened: fn(project_id, name) {
      client_state.admin_msg(admin_messages.ProjectEditDialogOpened(
        project_id,
        name,
      ))
    },
    on_edit_dialog_closed: client_state.admin_msg(
      admin_messages.ProjectEditDialogClosed,
    ),
    on_edit_submitted: client_state.admin_msg(
      admin_messages.ProjectEditSubmitted,
    ),
    on_edit_name_changed: fn(value) {
      client_state.admin_msg(admin_messages.ProjectEditNameChanged(value))
    },
    on_delete_confirm_opened: fn(project_id, name) {
      client_state.admin_msg(admin_messages.ProjectDeleteConfirmOpened(
        project_id,
        name,
      ))
    },
    on_delete_confirm_closed: client_state.admin_msg(
      admin_messages.ProjectDeleteConfirmClosed,
    ),
    on_delete_submitted: client_state.admin_msg(
      admin_messages.ProjectDeleteSubmitted,
    ),
  )
}

fn admin_metrics_config(
  model: client_state.Model,
  selected: opt.Option(Project),
) -> metrics_view.Config(client_state.Msg) {
  metrics_view.Config(
    locale: model.ui.locale,
    overview: model.admin.metrics.admin_metrics_overview,
    project_tasks: model.admin.metrics.admin_metrics_project_tasks,
    selected_project: selected,
    on_project_selected: fn(project_id) {
      client_state.ProjectSelected(int.to_string(project_id))
    },
  )
}

fn admin_assignments_config(
  model: client_state.Model,
) -> assignments_view.Config(client_state.Msg) {
  assignments_view.Config(
    locale: model.ui.locale,
    assignments: model.admin.assignments,
    projects: model.core.projects,
    org_users: model.admin.members.org_users_cache,
    project_card: admin_assignments_project_card(model),
    user_card: admin_assignments_user_card(model),
    on_view_mode_changed: fn(mode) {
      client_state.admin_msg(admin_messages.AssignmentsViewModeChanged(mode))
    },
    on_search_changed: fn(value) {
      client_state.admin_msg(admin_messages.AssignmentsSearchChanged(value))
    },
    on_search_debounced: fn(value) {
      client_state.admin_msg(admin_messages.AssignmentsSearchDebounced(value))
    },
    on_project_create_clicked: client_state.admin_msg(
      admin_messages.ProjectCreateDialogOpened,
    ),
    on_invites_clicked: client_state.NavigateTo(
      router.Org(permissions.Invites),
      client_state.Push,
    ),
    project_dialogs: admin_projects_config(model),
  )
}

fn admin_assignments_project_card(
  model: client_state.Model,
) -> project_card.Config(client_state.Msg) {
  project_card.Config(
    locale: model.ui.locale,
    assignments: model.admin.assignments,
    current_user_id: model.core.user |> opt.map(fn(user) { user.id }),
    org_users: model.admin.members.org_users_cache,
    metrics: model.admin.metrics.admin_metrics_overview,
    on_project_toggled: fn(project_id) {
      client_state.admin_msg(admin_messages.AssignmentsProjectToggled(
        project_id,
      ))
    },
    on_inline_add_started: fn(context) {
      client_state.admin_msg(admin_messages.AssignmentsInlineAddStarted(context))
    },
    on_role_changed: fn(project_id, user_id, role) {
      client_state.admin_msg(admin_messages.AssignmentsRoleChanged(
        project_id,
        user_id,
        role,
      ))
    },
    on_remove_confirmed: client_state.admin_msg(
      admin_messages.AssignmentsRemoveConfirmed,
    ),
    on_remove_cancelled: client_state.admin_msg(
      admin_messages.AssignmentsRemoveCancelled,
    ),
    on_remove_clicked: fn(project_id, user_id) {
      client_state.admin_msg(admin_messages.AssignmentsRemoveClicked(
        project_id,
        user_id,
      ))
    },
    on_inline_add_search_changed: fn(value) {
      client_state.admin_msg(admin_messages.AssignmentsInlineAddSearchChanged(
        value,
      ))
    },
    on_inline_add_selection_changed: fn(value) {
      client_state.admin_msg(
        admin_messages.AssignmentsInlineAddSelectionChanged(value),
      )
    },
    on_inline_add_role_changed: fn(role) {
      client_state.admin_msg(admin_messages.AssignmentsInlineAddRoleChanged(
        role,
      ))
    },
    on_inline_add_cancelled: client_state.admin_msg(
      admin_messages.AssignmentsInlineAddCancelled,
    ),
    on_inline_add_submitted: client_state.admin_msg(
      admin_messages.AssignmentsInlineAddSubmitted,
    ),
    noop: client_state.NoOp,
  )
}

fn admin_assignments_user_card(
  model: client_state.Model,
) -> user_card.Config(client_state.Msg) {
  user_card.Config(
    locale: model.ui.locale,
    assignments: model.admin.assignments,
    all_projects: model.core.projects,
    metrics: model.admin.metrics.admin_metrics_users,
    on_user_toggled: fn(user_id) {
      client_state.admin_msg(admin_messages.AssignmentsUserToggled(user_id))
    },
    on_inline_add_started: fn(context) {
      client_state.admin_msg(admin_messages.AssignmentsInlineAddStarted(context))
    },
    on_role_changed: fn(project_id, user_id, role) {
      client_state.admin_msg(admin_messages.AssignmentsRoleChanged(
        project_id,
        user_id,
        role,
      ))
    },
    on_remove_confirmed: client_state.admin_msg(
      admin_messages.AssignmentsRemoveConfirmed,
    ),
    on_remove_cancelled: client_state.admin_msg(
      admin_messages.AssignmentsRemoveCancelled,
    ),
    on_remove_clicked: fn(project_id, user_id) {
      client_state.admin_msg(admin_messages.AssignmentsRemoveClicked(
        project_id,
        user_id,
      ))
    },
    on_inline_add_selection_changed: fn(value) {
      client_state.admin_msg(
        admin_messages.AssignmentsInlineAddSelectionChanged(value),
      )
    },
    on_inline_add_role_changed: fn(role) {
      client_state.admin_msg(admin_messages.AssignmentsInlineAddRoleChanged(
        role,
      ))
    },
    on_inline_add_cancelled: client_state.admin_msg(
      admin_messages.AssignmentsInlineAddCancelled,
    ),
    on_inline_add_submitted: client_state.admin_msg(
      admin_messages.AssignmentsInlineAddSubmitted,
    ),
    noop: client_state.NoOp,
  )
}

fn admin_workflow_callbacks() -> admin_workflows_config.Callbacks(
  client_state.Msg,
) {
  admin_workflows_config.Callbacks(
    on_create_clicked: client_state.pool_msg(pool_messages.OpenWorkflowDialog(
      state_types.WorkflowDialogCreate,
    )),
    on_rules_clicked: fn(workflow_id) {
      client_state.pool_msg(pool_messages.WorkflowRulesClicked(workflow_id))
    },
    on_edit_clicked: fn(workflow) {
      client_state.pool_msg(
        pool_messages.OpenWorkflowDialog(state_types.WorkflowDialogEdit(
          workflow,
        )),
      )
    },
    on_delete_clicked: fn(workflow) {
      client_state.pool_msg(
        pool_messages.OpenWorkflowDialog(state_types.WorkflowDialogDelete(
          workflow,
        )),
      )
    },
    on_created: fn(workflow) {
      client_state.pool_msg(pool_messages.WorkflowCrudCreated(workflow))
    },
    on_updated: fn(workflow) {
      client_state.pool_msg(pool_messages.WorkflowCrudUpdated(workflow))
    },
    on_deleted: fn(id) {
      client_state.pool_msg(pool_messages.WorkflowCrudDeleted(id))
    },
    on_closed: client_state.pool_msg(pool_messages.CloseWorkflowDialog),
    rules: admin_workflow_rule_callbacks(),
  )
}

fn admin_rule_metrics_callbacks() -> admin_rule_metrics_view_config.Callbacks(
  client_state.Msg,
) {
  admin_rule_metrics_view_config.Callbacks(
    on_quick_range_clicked: fn(from, to) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsQuickRangeClicked(
        from,
        to,
      ))
    },
    on_from_changed: fn(value) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsFromChangedAndRefresh(
        value,
      ))
    },
    on_to_changed: fn(value) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsToChangedAndRefresh(
        value,
      ))
    },
    on_workflow_expanded: fn(workflow_id) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsWorkflowExpanded(
        workflow_id,
      ))
    },
    on_drilldown_clicked: fn(rule_id) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsDrilldownClicked(
        rule_id,
      ))
    },
    on_drilldown_closed: client_state.pool_msg(
      pool_messages.AdminRuleMetricsDrilldownClosed,
    ),
    on_exec_page_changed: fn(offset) {
      client_state.pool_msg(pool_messages.AdminRuleMetricsExecPageChanged(
        offset,
      ))
    },
  )
}

fn admin_task_template_callbacks() -> admin_task_templates_view_config.Callbacks(
  client_state.Msg,
) {
  admin_task_templates_view_config.Callbacks(
    on_create_clicked: client_state.pool_msg(
      pool_messages.OpenTaskTemplateDialog(state_types.TaskTemplateDialogCreate),
    ),
    on_edit_clicked: fn(template) {
      client_state.pool_msg(
        pool_messages.OpenTaskTemplateDialog(state_types.TaskTemplateDialogEdit(
          template,
        )),
      )
    },
    on_delete_clicked: fn(template) {
      client_state.pool_msg(
        pool_messages.OpenTaskTemplateDialog(
          state_types.TaskTemplateDialogDelete(template),
        ),
      )
    },
    on_created: fn(template) {
      client_state.pool_msg(pool_messages.TaskTemplateCrudCreated(template))
    },
    on_updated: fn(template) {
      client_state.pool_msg(pool_messages.TaskTemplateCrudUpdated(template))
    },
    on_deleted: fn(id) {
      client_state.pool_msg(pool_messages.TaskTemplateCrudDeleted(id))
    },
    on_closed: client_state.pool_msg(pool_messages.CloseTaskTemplateDialog),
  )
}

fn admin_workflow_rule_callbacks() -> admin_workflow_rules_config.Callbacks(
  client_state.Msg,
) {
  admin_workflow_rules_config.Callbacks(
    on_back_clicked: client_state.pool_msg(pool_messages.RulesBackClicked),
    on_create_clicked: client_state.pool_msg(pool_messages.OpenRuleDialog(
      state_types.RuleDialogCreate,
    )),
    on_rule_expanded: fn(rule_id) {
      client_state.pool_msg(pool_messages.RuleExpandToggled(rule_id))
    },
    on_edit_clicked: fn(rule) {
      client_state.pool_msg(
        pool_messages.OpenRuleDialog(state_types.RuleDialogEdit(rule)),
      )
    },
    on_delete_clicked: fn(rule) {
      client_state.pool_msg(
        pool_messages.OpenRuleDialog(state_types.RuleDialogDelete(rule)),
      )
    },
    on_attach_modal_opened: fn(rule_id) {
      client_state.pool_msg(pool_messages.AttachTemplateModalOpened(rule_id))
    },
    on_attach_modal_closed: client_state.pool_msg(
      pool_messages.AttachTemplateModalClosed,
    ),
    on_template_detached: fn(rule_id, template_id) {
      client_state.pool_msg(pool_messages.TemplateDetachClicked(
        rule_id,
        template_id,
      ))
    },
    on_template_selected: fn(template_id) {
      client_state.pool_msg(pool_messages.AttachTemplateSelected(template_id))
    },
    on_attach_submitted: client_state.pool_msg(
      pool_messages.AttachTemplateSubmitted,
    ),
    on_rule_created: fn(rule) {
      client_state.pool_msg(pool_messages.RuleCrudCreated(rule))
    },
    on_rule_updated: fn(rule) {
      client_state.pool_msg(pool_messages.RuleCrudUpdated(rule))
    },
    on_rule_deleted: fn(rule_id) {
      client_state.pool_msg(pool_messages.RuleCrudDeleted(rule_id))
    },
    on_rule_dialog_closed: client_state.pool_msg(pool_messages.CloseRuleDialog),
    on_noop: client_state.NoOp,
  )
}

// =============================================================================
// client_state.Member Views
// =============================================================================

fn view_member(model: client_state.Model) -> Element(client_state.Msg) {
  case model.core.user {
    opt.None -> auth_view.view_login(auth_config(model))

    opt.Some(user) ->
      case model.ui.is_mobile {
        // Mobile: mini-bar + drawer layout
        True -> view_mobile_shell(model, user, view_member_section(model, user))

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
        i18n.t(model.ui.locale, case model.member.pool.member_section {
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
  let mobile_now_working = now_working_mobile_config(model, user)

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
    now_working_mobile.view_mini_bar(mobile_now_working),
    // Overlay when sheet is open
    now_working_mobile.view_overlay(mobile_now_working),
    // Bottom sheet
    now_working_mobile.view_panel_sheet(mobile_now_working),
    // Left drawer (navigation)
    view_mobile_left_drawer(model, user),
    // Right drawer (my activity)
    view_mobile_right_drawer(model, user),
  ])
}

fn now_working_mobile_config(
  model: client_state.Model,
  user: User,
) -> now_working_mobile.Config(client_state.Msg) {
  now_working_mobile.Config(
    locale: model.ui.locale,
    theme: model.ui.theme,
    panel_expanded: model.member.pool.member_panel_expanded,
    user_id: user.id,
    tasks: model.member.pool.member_tasks,
    active_sessions: state_selectors.now_working_all_sessions(model),
    server_offset_ms: model.member.now_working.now_working_server_offset_ms,
    disable_actions: model.member.pool.member_task_mutation_in_flight
      || model.member.now_working.member_now_working_in_flight,
    on_panel_toggled: client_state.layout_msg(
      layout_messages.MemberPanelToggled,
    ),
    on_pause: client_state.pool_msg(pool_messages.MemberNowWorkingPauseClicked),
    on_complete: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberCompleteClicked(
        task_id,
        version,
      ))
    },
    on_start: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
    },
    on_release: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberReleaseClicked(task_id, version))
    },
  )
}

/// Left drawer containing navigation
fn view_mobile_left_drawer(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let left_content = build_left_panel(model, user)

  responsive_drawer.view(
    ui_state.mobile_drawer_left_open(model.ui.mobile_drawer),
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
    ui_state.mobile_drawer_right_open(model.ui.mobile_drawer),
    responsive_drawer.Right,
    client_state.layout_msg(layout_messages.MobileDrawersClosed),
    right_content,
  )
}

fn view_member_section(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let pool_context = pool_view_context(model)

  case model.member.pool.member_section {
    member_section.Pool -> pool_view.view_pool_main(pool_context, user)
    member_section.MyBar -> my_bar_view.view_bar(my_bar_config(model, user))
    member_section.MySkills ->
      skills_view.view_skills(
        skills_view.Config(
          locale: model.ui.locale,
          capabilities: model.member.skills.member_capabilities,
          selected_capability_ids: model.member.skills.member_my_capability_ids_edit,
          error: model.member.skills.member_my_capabilities_error,
          in_flight: model.member.skills.member_my_capabilities_in_flight,
          on_save: client_state.pool_msg(
            pool_messages.MemberSaveCapabilitiesClicked,
          ),
          on_capability_toggle: fn(capability_id) {
            client_state.pool_msg(pool_messages.MemberToggleCapability(
              capability_id,
            ))
          },
        ),
      )
    member_section.Fichas ->
      fichas_view.view_fichas(member_fichas_config(model))
  }
}

fn my_bar_config(
  model: client_state.Model,
  user: User,
) -> my_bar_view.Config(client_state.Msg) {
  my_bar_view.Config(
    locale: model.ui.locale,
    has_active_projects: !list.is_empty(state_selectors.active_projects(model)),
    member_tasks: model.member.pool.member_tasks,
    member_metrics: model.member.metrics.member_metrics,
    task_row_config: my_bar_task_row_config(model, user),
    on_create_task_in_card: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
    },
  )
}

fn my_bar_task_row_config(
  model: client_state.Model,
  user: User,
) -> my_bar_view.TaskRowConfig(client_state.Msg) {
  my_bar_view.TaskRowConfig(
    locale: model.ui.locale,
    theme: model.ui.theme,
    user_id: user.id,
    active_task_id: state_selectors.now_working_active_task_id(model),
    disable_actions: model.member.pool.member_task_mutation_in_flight
      || model.member.now_working.member_now_working_in_flight,
    task_card_info: fn(task) { resolve_task_card_info(model, task) },
    on_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
    on_start: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
    },
    on_pause: client_state.pool_msg(pool_messages.MemberNowWorkingPauseClicked),
    on_release: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberReleaseClicked(task_id, version))
    },
    on_complete: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberCompleteClicked(
        task_id,
        version,
      ))
    },
    on_task_open: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
    },
  )
}

// =============================================================================
// 3-Panel Layout (New IA Redesign)
// =============================================================================

/// Renders the member view using the new 3-panel layout
fn view_member_three_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  // Build panel configs
  let left_content = build_left_panel(model, user)
  let center_content = build_center_panel(model, user)
  let right_content = build_right_panel(model, user)

  element.fragment([
    three_panel_layout.view_i18n(
      left_content,
      center_content,
      right_content,
      i18n.t(model.ui.locale, i18n_text.MainNavigation),
      i18n.t(model.ui.locale, i18n_text.MyActivity),
    ),
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
      blocked_claim_modal.view(blocked_claim_modal.Config(
        locale: model.ui.locale,
        task_id: task_id,
        task: right_panel_data.find_loaded_task(
          model.member.pool.member_tasks,
          task_id,
        ),
        on_confirm: client_state.pool_msg(
          pool_messages.MemberBlockedClaimConfirmed,
        ),
        on_cancel: client_state.pool_msg(
          pool_messages.MemberBlockedClaimCancelled,
        ),
      ))
    }
  }
}

/// Builds the left panel with project selector and navigation
fn build_left_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let projects = state_selectors.active_projects(model)
  let is_pm =
    permissions.is_selected_project_manager(state_selectors.selected_project(
      model,
    ))
  let is_org_admin = user.org_role == org_role.Admin

  let pending_invites_count =
    left_panel_data.pending_invites_count(model.admin.invites.invite_links)
  let users_count =
    left_panel_data.loaded_count(model.admin.members.org_users_cache)

  let member_route_config = left_panel_member_route_config(model)
  let member_route_for = fn(mode: view_mode.ViewMode) {
    left_panel_data.member_route(member_route_config, mode)
  }

  let current_route = case model.core.page {
    client_state.Member ->
      opt.Some(left_panel_data.current_member_route(member_route_config))
    client_state.Admin ->
      opt.Some(left_panel_data.admin_route(
        model.core.active_section,
        model.core.selected_project_id,
      ))
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
    config_collapsed: ui_state.sidebar_config_collapsed(
      model.ui.sidebar_collapse,
    ),
    org_collapsed: ui_state.sidebar_org_collapsed(model.ui.sidebar_collapse),
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
    on_navigate_pool: client_state.NavigateTo(
      member_route_for(view_mode.Pool),
      client_state.Push,
    ),
    on_navigate_cards: client_state.NavigateTo(
      member_route_for(view_mode.Cards),
      client_state.Push,
    ),
    on_navigate_capabilities: client_state.NavigateTo(
      member_route_for(view_mode.Capabilities),
      client_state.Push,
    ),
    on_navigate_people: client_state.NavigateTo(
      member_route_for(view_mode.People),
      client_state.Push,
    ),
    on_navigate_milestones: client_state.NavigateTo(
      member_route_for(view_mode.Milestones),
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

fn left_panel_member_route_config(
  model: client_state.Model,
) -> left_panel_data.MemberRouteConfig {
  left_panel_data.MemberRouteConfig(
    selected_project_id: model.core.selected_project_id,
    member_section: model.member.pool.member_section,
    view_mode: model.member.pool.view_mode,
    capability_scope: model.member.pool.member_capability_scope,
    type_filter: model.member.pool.member_filters_type_id,
    capability_filter: model.member.pool.member_filters_capability_id,
    search: helpers_options.empty_to_opt(model.member.pool.member_filters_q),
  )
}

/// Builds the center panel with view mode toggle and content
fn build_center_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let data =
    center_panel_data.from_remotes(
      model.member.pool.member_tasks,
      model.member.pool.member_task_types,
      model.admin.capabilities.capabilities,
      model.admin.members.org_users_cache,
      model.member.skills.member_my_capability_ids,
    )
  let cards = project_cards(model)
  let pool_context = pool_view_context(model)

  // Build view-specific content
  let pool_content = pool_view.view_pool_main(pool_context, user)
  let milestones_content =
    milestones_view.view(
      model.ui.locale,
      model.ui.theme,
      model.core.selected_project_id,
      model.member.pool,
      model.admin.members.org_users_cache,
      milestone_access.can_manage(
        model.core.user,
        state_selectors.selected_project(model),
      ),
      milestone_callbacks(),
    )
  let cards_content =
    kanban_board.view(kanban_config(
      model,
      user,
      cards,
      data.tasks,
      data.task_types,
      data.org_users,
      data.my_capability_ids,
    ))
  let people_content = people_view.view(people_config(model))
  let capabilities_content =
    capability_board_view.view(capability_board_config(
      model,
      cards,
      data.org_users,
      data.my_capability_ids,
    ))

  center_panel.view(center_panel.CenterPanelConfig(
    locale: model.ui.locale,
    view_mode: model.member.pool.view_mode,
    on_view_mode_change: fn(mode) {
      client_state.pool_msg(pool_messages.ViewModeChanged(mode))
    },
    task_types: data.task_types,
    capabilities: data.capabilities,
    capability_scope: model.member.pool.member_capability_scope,
    type_filter: model.member.pool.member_filters_type_id,
    capability_filter: model.member.pool.member_filters_capability_id,
    search_query: model.member.pool.member_filters_q,
    on_capability_scope_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPoolCapabilityScopeChanged(
        value,
      ))
    },
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
    cards_content: cards_content,
    capabilities_content: capabilities_content,
    people_content: people_content,
    milestones_content: milestones_content,
    on_drag_move: fn(x, y) {
      client_state.pool_msg(pool_messages.MemberDragMoved(x, y))
    },
    on_drag_end: client_state.pool_msg(pool_messages.MemberDragEnded),
  ))
}

fn milestone_callbacks() -> milestones_view.Callbacks(client_state.Msg) {
  milestones_view.Callbacks(
    on_create_milestone: client_state.pool_msg(
      pool_messages.MemberMilestoneCreateClicked,
    ),
    on_dialog_close: client_state.pool_msg(
      pool_messages.MemberMilestoneDialogClosed,
    ),
    on_activate_clicked: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneActivateClicked(id))
    },
    on_create_submitted: client_state.pool_msg(
      pool_messages.MemberMilestoneCreateSubmitted,
    ),
    on_edit_submitted: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneEditSubmitted(id))
    },
    on_delete_submitted: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneDeleteSubmitted(id))
    },
    on_name_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberMilestoneNameChanged(value))
    },
    on_description_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberMilestoneDescriptionChanged(
        value,
      ))
    },
    on_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberMilestoneSearchChanged(value))
    },
    on_toggle_completed: client_state.pool_msg(
      pool_messages.MemberMilestonesShowCompletedToggled,
    ),
    on_toggle_empty: client_state.pool_msg(
      pool_messages.MemberMilestonesShowEmptyToggled,
    ),
    on_select: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneDetailsClicked(id))
    },
    on_summary_toggle: client_state.pool_msg(
      pool_messages.MemberMilestoneSummaryToggled,
    ),
    on_quick_create_card: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneCreateCardClicked(id))
    },
    on_quick_create_task: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneCreateTaskClicked(id))
    },
    on_activate_prompt: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneActivatePromptClicked(
        id,
      ))
    },
    on_edit: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneEditClicked(id))
    },
    on_delete: fn(id) {
      client_state.pool_msg(pool_messages.MemberMilestoneDeleteClicked(id))
    },
    on_task_open: fn(id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(id))
    },
    on_task_claim: fn(id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(id, version))
    },
    on_card_drag_started: fn(card_id, milestone_id) {
      client_state.pool_msg(pool_messages.MemberMilestoneCardDragStarted(
        card_id,
        milestone_id,
      ))
    },
    on_task_drag_started: fn(task_id, milestone_id) {
      client_state.pool_msg(pool_messages.MemberMilestoneTaskDragStarted(
        task_id,
        milestone_id,
      ))
    },
    on_drag_ended: client_state.pool_msg(pool_messages.MemberMilestoneDragEnded),
    on_card_move: fn(card_id, milestone_id, destination_id) {
      client_state.pool_msg(pool_messages.MemberMilestoneCardMoveClicked(
        card_id,
        milestone_id,
        destination_id,
      ))
    },
    on_task_move: fn(task_id, milestone_id, destination_id) {
      client_state.pool_msg(pool_messages.MemberMilestoneTaskMoveClicked(
        task_id,
        milestone_id,
        destination_id,
      ))
    },
    on_card_create_task: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
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
  )
}

fn kanban_config(
  model: client_state.Model,
  user: User,
  cards: List(Card),
  tasks: List(Task),
  task_types: List(TaskType),
  org_users: List(OrgUser),
  my_capability_ids: List(Int),
) -> kanban_board.KanbanConfig(client_state.Msg) {
  kanban_board.KanbanConfig(
    locale: model.ui.locale,
    theme: model.ui.theme,
    cards: cards,
    tasks: tasks,
    task_types: task_types,
    type_filter: model.member.pool.member_filters_type_id,
    capability_filter: model.member.pool.member_filters_capability_id,
    search_query: model.member.pool.member_filters_q,
    capability_scope: model.member.pool.member_capability_scope,
    my_capability_ids: my_capability_ids,
    org_users: org_users,
    is_pm_or_admin: permissions.can_manage_project_content(
      user.org_role,
      state_selectors.selected_project(model),
    ),
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
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
    },
    on_task_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
    on_create_task_in_card: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
    },
  )
}

fn people_config(
  model: client_state.Model,
) -> people_view.Config(client_state.Msg) {
  people_view.Config(
    locale: model.ui.locale,
    people_roster: model.member.pool.people_roster,
    member_tasks: model.member.pool.member_tasks,
    org_users: model.admin.members.org_users_cache,
    people_expansions: model.member.pool.people_expansions,
    search_query: model.member.pool.member_filters_q,
    task_card_color: fn(task) { resolved_task_card_color(model, task) },
    on_person_toggle: fn(user_id) {
      client_state.pool_msg(pool_messages.MemberPeopleRowToggled(user_id))
    },
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
    },
  )
}

fn capability_board_config(
  model: client_state.Model,
  cards: List(Card),
  org_users: List(OrgUser),
  my_capability_ids: List(Int),
) -> capability_board_view.Config(client_state.Msg) {
  capability_board_view.Config(
    locale: model.ui.locale,
    theme: model.ui.theme,
    tasks: model.member.pool.member_tasks,
    task_types: model.member.pool.member_task_types,
    capabilities: model.admin.capabilities.capabilities,
    cards: cards,
    org_users: org_users,
    capability_scope: model.member.pool.member_capability_scope,
    my_capability_ids: my_capability_ids,
    type_filter: model.member.pool.member_filters_type_id,
    search_query: model.member.pool.member_filters_q,
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
    },
    on_task_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
  )
}

/// Builds the right panel with activity and profile
fn build_right_panel(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let tasks =
    right_panel_data.loaded_tasks_or_empty(model.member.pool.member_tasks)
  let task_card_color = fn(task) { resolved_task_card_color(model, task) }
  let #(drag_armed, drag_over_my_tasks) = pool_drag_flags(model)

  right_panel.view(right_panel.RightPanelConfig(
    locale: model.ui.locale,
    user: opt.Some(user),
    my_tasks: right_panel_data.claimed_tasks(tasks, user.id),
    my_cards: right_panel_data.my_cards(project_cards(model), tasks, user.id),
    active_tasks: right_panel_data.active_tasks(
      state_selectors.now_working_all_sessions(model),
      tasks,
      model.member.now_working.now_working_server_offset_ms,
      client_ffi.now_ms(),
      client_ffi.parse_iso_ms,
      task_card_color,
    ),
    task_card_color: task_card_color,
    on_task_start: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
    },
    on_task_pause: fn(_task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingPauseClicked)
    },
    on_task_complete: fn(task_id) {
      case
        right_panel_data.find_loaded_task(
          model.member.pool.member_tasks,
          task_id,
        )
      {
        opt.Some(task) ->
          client_state.pool_msg(pool_messages.MemberCompleteClicked(
            task_id,
            task.version,
          ))
        _ -> client_state.NoOp
      }
    },
    on_logout: client_state.auth_msg(auth_messages.LogoutClicked),
    on_task_release: fn(task_id) {
      case
        right_panel_data.find_loaded_task(
          model.member.pool.member_tasks,
          task_id,
        )
      {
        opt.Some(task) ->
          client_state.pool_msg(pool_messages.MemberReleaseClicked(
            task_id,
            task.version,
          ))
        _ -> client_state.NoOp
      }
    },
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
    },
    on_card_click: fn(card_id) {
      client_state.pool_msg(pool_messages.OpenCardDetail(card_id))
    },
    drag_armed: drag_armed,
    drag_over_my_tasks: drag_over_my_tasks,
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

fn resolved_task_card_color(model: client_state.Model, task: Task) {
  let #(_card_title_opt, resolved_color) = resolve_task_card_info(model, task)
  resolved_color
}

fn pool_drag_flags(model: client_state.Model) -> #(Bool, Bool) {
  case model.member.pool.member_pool_drag {
    state_types.PoolDragDragging(over_my_tasks: over, ..) -> #(True, over)
    state_types.PoolDragPendingRect -> #(True, False)
    state_types.PoolDragIdle -> #(False, False)
  }
}

// =============================================================================
// Card Detail Modal for Member Views
// =============================================================================

/// Renders the card detail modal for Pool/Kanban/Milestones views.
fn view_member_card_detail_modal(
  model: client_state.Model,
  _user: User,
) -> Element(client_state.Msg) {
  fichas_view.view_card_detail_modal(member_fichas_config(model))
}

fn member_fichas_config(
  model: client_state.Model,
) -> fichas_view.Config(client_state.Msg) {
  fichas_view_config.from_state(
    model.ui.locale,
    project_cards(model),
    model.member.pool,
    selected_member_detail_card(model),
    model.core.user,
    state_selectors.selected_project(model),
    fn(id) { client_state.pool_msg(pool_messages.OpenCardDetail(id)) },
    fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
    },
    client_state.pool_msg(pool_messages.CloseCardDetail),
  )
}

fn selected_member_detail_card(model: client_state.Model) -> opt.Option(Card) {
  case model.member.pool.card_detail_open {
    opt.Some(card_id) -> find_card(model, card_id)
    opt.None -> opt.None
  }
}

fn find_card(model: client_state.Model, card_id: Int) -> opt.Option(Card) {
  card_queries.find_card(
    model.member.pool.member_cards_store,
    model.admin.cards.cards,
    card_id,
  )
}

fn project_cards(model: client_state.Model) -> List(Card) {
  card_queries.get_project_cards(
    model.member.pool.member_cards_store,
    model.admin.cards.cards,
    model.core.selected_project_id,
  )
}

fn resolve_task_card_info(model: client_state.Model, task: Task) {
  card_queries.resolve_task_card_info(project_cards(model), task)
}

fn pool_view_context(
  model: client_state.Model,
) -> pool_view.Context(client_state.Msg) {
  pool_view.Context(
    locale: model.ui.locale,
    theme: model.ui.theme,
    has_active_projects: !list.is_empty(state_selectors.active_projects(model)),
    current_user_id: current_user_id_or_zero(model),
    active_task_id: state_selectors.now_working_active_task_id(model),
    now_working_sessions: state_selectors.now_working_all_sessions(model),
    cards: project_cards(model),
    pool: model.member.pool,
    now_working: model.member.now_working,
    skills: model.member.skills,
    notes: model.member.notes,
    positions: model.member.positions,
    callbacks: pool_view_callbacks(),
  )
}

fn pool_view_callbacks() -> pool_view.Callbacks(client_state.Msg) {
  pool_view.Callbacks(
    on_drag_moved: fn(x, y) {
      client_state.pool_msg(pool_messages.MemberDragMoved(x, y))
    },
    on_drag_ended: client_state.pool_msg(pool_messages.MemberDragEnded),
    on_create_opened: client_state.pool_msg(
      pool_messages.MemberCreateDialogOpened,
    ),
    on_now_working_pause: client_state.pool_msg(
      pool_messages.MemberNowWorkingPauseClicked,
    ),
    on_now_working_start: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
    },
    on_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
    on_release: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberReleaseClicked(task_id, version))
    },
    on_complete: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberCompleteClicked(
        task_id,
        version,
      ))
    },
    on_open: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
    },
    on_hover_opened: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskHoverOpened(task_id))
    },
    on_hover_closed: client_state.pool_msg(pool_messages.MemberTaskHoverClosed),
    on_focused: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskFocused(task_id))
    },
    on_blurred: client_state.pool_msg(pool_messages.MemberTaskBlurred),
    on_drag_started: fn(task_id, x, y) {
      client_state.pool_msg(pool_messages.MemberDragStarted(task_id, x, y))
    },
    on_touch_started: fn(task_id, x, y) {
      client_state.pool_msg(pool_messages.MemberPoolTouchStarted(task_id, x, y))
    },
    on_touch_ended: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberPoolTouchEnded(task_id))
    },
  )
}

fn current_user_id_or_zero(model: client_state.Model) -> Int {
  case model.core.user {
    opt.Some(user) -> user.id
    opt.None -> 0
  }
}
