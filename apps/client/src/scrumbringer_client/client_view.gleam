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
//// - **features/metrics/view.gleam**: client_state.Admin metrics views
//// - **features/admin/view.gleam**: client_state.Admin section views
//// - **features/auth/view.gleam**: Auth views (login, register, etc.)

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}

import lustre/element/html.{a, div, h2, p, style, text}

import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/org_role
import domain/project.{type Project, type ProjectDepthName}
import domain/project/project_codec
import domain/remote
import domain/task_type.{type TaskType}
import domain/user.{type User}
import domain/view_mode

import scrumbringer_client/automation_deep_link
import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/rules as admin_rules
import scrumbringer_client/client_state/admin/task_templates as admin_task_templates
import scrumbringer_client/client_state/admin/workflows as admin_workflows
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/auth/msg as auth_messages
import scrumbringer_client/features/i18n/msg as i18n_messages
import scrumbringer_client/features/layout/msg as layout_messages
import scrumbringer_client/features/pool/msg as pool_messages

import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/view as admin_view
import scrumbringer_client/features/assignments/components/project_card
import scrumbringer_client/features/assignments/components/user_card
import scrumbringer_client/features/assignments/view as assignments_view
import scrumbringer_client/features/auth/view as auth_view
import scrumbringer_client/features/automations/console as automations_console
import scrumbringer_client/features/automations/engine_list
import scrumbringer_client/features/automations/engine_list_config
import scrumbringer_client/features/automations/execution_history
import scrumbringer_client/features/automations/execution_history_config
import scrumbringer_client/features/automations/focus_target as automation_focus
import scrumbringer_client/features/automations/rule_list_config as automation_rule_list_config
import scrumbringer_client/features/automations/template_library
import scrumbringer_client/features/automations/template_library_config
import scrumbringer_client/features/capability_board/view as capability_board_view
import scrumbringer_client/features/cards/view as cards_view
import scrumbringer_client/features/cards/view_config as cards_view_config
import scrumbringer_client/features/hierarchy/scope_view
import scrumbringer_client/features/invites/view as invites_view
import scrumbringer_client/features/metrics/view as metrics_view
import scrumbringer_client/features/now_working/mobile as now_working_mobile
import scrumbringer_client/features/people/view as people_view
import scrumbringer_client/features/plan/kanban_view as plan_kanban_view
import scrumbringer_client/features/plan/structure_view as plan_structure_view
import scrumbringer_client/features/pool/create_dialog_config
import scrumbringer_client/features/pool/position_edit_dialog_config
import scrumbringer_client/features/pool/task_show_config
import scrumbringer_client/features/pool/view_config as pool_view
import scrumbringer_client/features/pool/view_context as pool_view_context
import scrumbringer_client/features/projects/view as projects_view

import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/router
import scrumbringer_client/styles
import scrumbringer_client/theme
import scrumbringer_client/url_state

import scrumbringer_client/client_ffi
import scrumbringer_client/ui/button
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/toast as ui_toast
import scrumbringer_client/utils/card_queries

import domain/task.{type Task}

import scrumbringer_client/client_state/selectors as state_selectors
import scrumbringer_client/features/layout/center_panel
import scrumbringer_client/features/layout/center_panel_data
import scrumbringer_client/features/layout/left_panel
import scrumbringer_client/features/layout/left_panel_data
import scrumbringer_client/features/layout/member_mobile_shell
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
        )
      _ -> element.none()
    },
    // Global Task Show dialog (renders from list/canvas/pool)
    case model.member.notes.member_notes_task_id {
      opt.Some(task_id) ->
        task_show_config.view(
          model.ui.locale,
          model.member.pool,
          model.member.dependencies,
          model.member.notes,
          model.core.user |> opt.map(fn(user) { user.id }),
          can_manage_task_notes(model),
          project_cards(model),
          project_capabilities(model),
          task_id,
          task_show_callbacks(),
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

fn task_show_callbacks() -> task_show_config.Callbacks(client_state.Msg) {
  task_show_config.Callbacks(
    on_close: client_state.pool_msg(pool_messages.MemberTaskShowClosed),
    on_tab_clicked: fn(tab) {
      client_state.pool_msg(pool_messages.MemberTaskShowTabClicked(tab))
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
      pool_messages.MemberTaskShowEditStarted,
    ),
    on_edit_cancelled: client_state.pool_msg(
      pool_messages.MemberTaskShowEditCancelled,
    ),
    on_edit_title_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberTaskShowEditTitleChanged(value))
    },
    on_edit_description_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberTaskShowEditDescriptionChanged(
        value,
      ))
    },
    on_edit_priority_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberTaskShowEditPriorityChanged(
        value,
      ))
    },
    on_edit_type_id_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberTaskShowEditTypeIdChanged(value))
    },
    on_edit_card_id_changed: fn(value) {
      client_state.pool_msg(pool_messages.MemberTaskShowEditCardIdChanged(value))
    },
    on_edit_submitted: client_state.pool_msg(
      pool_messages.MemberTaskShowEditSubmitted,
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
    on_note_delete: fn(note_id) {
      client_state.pool_msg(pool_messages.MemberNoteDeleteClicked(note_id))
    },
    on_note_pin_toggle: fn(note_id, pinned) {
      client_state.pool_msg(pool_messages.MemberNotePinClicked(note_id, pinned))
    },
    on_activity_more: client_state.pool_msg(
      pool_messages.MemberActivityMoreClicked,
    ),
    on_open_parent_card: fn(card_id) {
      client_state.pool_msg(pool_messages.OpenCardShow(card_id))
    },
    on_claim: fn(claim_task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(
        claim_task_id,
        version,
      ))
    },
    on_start_work: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberNowWorkingStartClicked(task_id))
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
    on_delete: fn(delete_task_id) {
      client_state.pool_msg(pool_messages.MemberDeleteTaskClicked(
        delete_task_id,
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
        permissions.Team ->
          assignments_view.view_assignments(admin_assignments_config(model))
        permissions.ApiTokens -> admin_view.view_api_tokens(model)
        permissions.Metrics ->
          metrics_view.view_metrics(admin_metrics_config(model, selected))
        permissions.Capabilities -> admin_view.view_capabilities(model)
        permissions.Members -> admin_view.view_members(model, selected)
        permissions.TaskTypes -> admin_view.view_task_types(model, selected)
        permissions.Cards -> admin_view.view_cards(model, selected)
        permissions.Workflows ->
          view_automations_console(
            model,
            projects,
            selected,
            automations_console.Engines,
          )
        permissions.TaskTemplates ->
          view_automations_console(
            model,
            projects,
            selected,
            automations_console.Templates,
          )
        permissions.RuleMetrics ->
          view_automations_console(
            model,
            projects,
            selected,
            automations_console.Executions,
          )
      }
  }
}

fn view_automations_console(
  model: client_state.Model,
  projects: List(Project),
  selected: opt.Option(Project),
  mode: automations_console.Mode,
) -> Element(client_state.Msg) {
  automations_console.view(automations_console.Config(
    locale: model.ui.locale,
    selected_project_id: model.core.selected_project_id,
    mode: mode,
    selected_entity: model.core.automation_selection,
    active_engines_count: loaded_count_where(
      model.admin.workflows.workflows_project,
      fn(workflow) { workflow.active },
    ),
    rules_count: loaded_count(model.admin.rules.rules),
    templates_count: loaded_count(
      model.admin.task_templates.task_templates_project,
    ),
    created_tasks_count: created_tasks_count(model),
    primary_action: opt.Some(
      button.icon_text(
        i18n.t(model.ui.locale, i18n_text.CreateWorkflow),
        client_state.pool_msg(pool_messages.OpenWorkflowDialog(
          admin_workflows.WorkflowDialogCreate,
        )),
        icons.Plus,
        button.Primary,
        button.GlobalAction,
      )
      |> button.with_id(automation_focus.create_engine_trigger_id)
      |> button.with_testid("automation-create-engine")
      |> button.view,
    ),
    engines_view: engine_list.view(engine_list_config.from_state(
      model.ui.locale,
      model.ui.theme,
      selected,
      model.core.selected_project_id,
      model.admin.workflows,
      model.admin.rules,
      model.admin.task_templates,
      model.admin.task_types,
      configured_depth_names(projects, model.core.selected_project_id),
      model.core.automation_selection,
      admin_workflow_callbacks(model),
    )),
    templates_view: template_library.view(template_library_config.from_state(
      model.ui.locale,
      selected,
      model.core.selected_project_id,
      model.admin.task_templates,
      model.admin.task_types,
      automation_deep_link.template_id(model.core.automation_selection),
      admin_task_template_callbacks(),
    )),
    executions_view: execution_history.view(execution_history_config.from_state(
      model.ui.locale,
      model.admin.metrics,
      model.core.selected_project_id,
      automation_deep_link.execution_id(model.core.automation_selection),
      admin_rule_metrics_callbacks(),
    )),
  ))
}

fn loaded_count(remote_value: remote.Remote(List(a))) -> Int {
  case remote_value {
    remote.Loaded(items) -> list.length(items)
    _ -> 0
  }
}

fn loaded_count_where(
  remote_value: remote.Remote(List(a)),
  predicate: fn(a) -> Bool,
) -> Int {
  case remote_value {
    remote.Loaded(items) -> items |> list.filter(predicate) |> list.length
    _ -> 0
  }
}

fn created_tasks_count(model: client_state.Model) -> Int {
  case model.admin.metrics.admin_rule_metrics {
    remote.Loaded(workflows) ->
      list.fold(workflows, 0, fn(total, workflow) {
        total + workflow.applied_count
      })
    _ -> 0
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
    on_link_invalidate_clicked: fn(email) {
      client_state.admin_msg(admin_messages.InviteLinkInvalidateClicked(email))
    },
    on_link_invalidate_cancelled: client_state.admin_msg(
      admin_messages.InviteLinkInvalidateCancelled,
    ),
    on_link_invalidate_confirmed: client_state.admin_msg(
      admin_messages.InviteLinkInvalidateConfirmed,
    ),
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
    on_create_next_clicked: client_state.admin_msg(
      admin_messages.ProjectCreateNextClicked,
    ),
    on_create_back_clicked: client_state.admin_msg(
      admin_messages.ProjectCreateBackClicked,
    ),
    on_create_name_changed: fn(value) {
      client_state.admin_msg(admin_messages.ProjectCreateNameChanged(value))
    },
    on_create_max_depth_changed: fn(value) {
      client_state.admin_msg(admin_messages.ProjectCreateMaxDepthChanged(value))
    },
    on_create_healthy_pool_limit_changed: fn(value) {
      client_state.admin_msg(
        admin_messages.ProjectCreateHealthyPoolLimitChanged(value),
      )
    },
    on_create_depth_singular_changed: fn(depth, value) {
      client_state.admin_msg(admin_messages.ProjectCreateDepthSingularChanged(
        depth,
        value,
      ))
    },
    on_create_depth_plural_changed: fn(depth, value) {
      client_state.admin_msg(admin_messages.ProjectCreateDepthPluralChanged(
        depth,
        value,
      ))
    },
    on_edit_dialog_opened: fn(project_id, name, healthy_pool_limit, depth_names) {
      client_state.admin_msg(admin_messages.ProjectEditDialogOpened(
        project_id,
        name,
        healthy_pool_limit,
        depth_names,
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
    on_edit_max_depth_changed: fn(value) {
      client_state.admin_msg(admin_messages.ProjectEditMaxDepthChanged(value))
    },
    on_edit_healthy_pool_limit_changed: fn(value) {
      client_state.admin_msg(admin_messages.ProjectEditHealthyPoolLimitChanged(
        value,
      ))
    },
    on_edit_depth_singular_changed: fn(depth, value) {
      client_state.admin_msg(admin_messages.ProjectEditDepthSingularChanged(
        depth,
        value,
      ))
    },
    on_edit_depth_plural_changed: fn(depth, value) {
      client_state.admin_msg(admin_messages.ProjectEditDepthPluralChanged(
        depth,
        value,
      ))
    },
    on_edit_depth_reduction_review_clicked: client_state.admin_msg(
      admin_messages.ProjectEditDepthReductionReviewClicked,
    ),
    on_edit_depth_reduction_confirmed: client_state.admin_msg(
      admin_messages.ProjectEditDepthReductionConfirmed,
    ),
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

fn admin_workflow_callbacks(
  model: client_state.Model,
) -> engine_list_config.Callbacks(client_state.Msg) {
  engine_list_config.Callbacks(
    on_create_clicked: client_state.pool_msg(pool_messages.OpenWorkflowDialog(
      admin_workflows.WorkflowDialogCreate,
    )),
    on_search_changed: fn(value) {
      client_state.pool_msg(pool_messages.WorkflowsSearchChanged(value))
    },
    on_status_filter_changed: fn(value) {
      client_state.pool_msg(pool_messages.WorkflowsStatusFilterChanged(value))
    },
    on_rules_clicked: fn(workflow_id) {
      client_state.pool_msg(pool_messages.WorkflowRulesClicked(workflow_id))
    },
    on_edit_clicked: fn(workflow) {
      client_state.pool_msg(
        pool_messages.OpenWorkflowDialog(admin_workflows.WorkflowDialogEdit(
          workflow,
        )),
      )
    },
    on_delete_clicked: fn(workflow) {
      client_state.pool_msg(
        pool_messages.OpenWorkflowDialog(admin_workflows.WorkflowDialogDelete(
          workflow,
        )),
      )
    },
    on_name_changed: fn(value) {
      client_state.pool_msg(pool_messages.WorkflowNameChanged(value))
    },
    on_description_changed: fn(value) {
      client_state.pool_msg(pool_messages.WorkflowDescriptionChanged(value))
    },
    on_active_changed: fn(value) {
      client_state.pool_msg(pool_messages.WorkflowActiveChanged(value))
    },
    on_submitted: fn(project_id) {
      client_state.pool_msg(pool_messages.WorkflowFormSubmitted(project_id))
    },
    on_delete_confirmed: client_state.pool_msg(
      pool_messages.WorkflowDeleteConfirmed,
    ),
    on_closed: client_state.pool_msg(pool_messages.CloseWorkflowDialog),
    rules: admin_workflow_rule_callbacks(model),
  )
}

fn admin_rule_metrics_callbacks() -> execution_history_config.Callbacks(
  client_state.Msg,
) {
  execution_history_config.Callbacks(
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
    on_project_exec_page_changed: fn(offset) {
      client_state.pool_msg(pool_messages.AdminProjectRuleExecutionsPageChanged(
        offset,
      ))
    },
  )
}

fn admin_task_template_callbacks() -> template_library_config.Callbacks(
  client_state.Msg,
) {
  template_library_config.Callbacks(
    on_create_clicked: client_state.pool_msg(
      pool_messages.OpenTaskTemplateDialog(
        admin_task_templates.TaskTemplateDialogCreate,
      ),
    ),
    on_edit_clicked: fn(template) {
      client_state.pool_msg(
        pool_messages.OpenTaskTemplateDialog(
          admin_task_templates.TaskTemplateDialogEdit(template),
        ),
      )
    },
    on_delete_clicked: fn(template) {
      client_state.pool_msg(
        pool_messages.OpenTaskTemplateDialog(
          admin_task_templates.TaskTemplateDialogDelete(template),
        ),
      )
    },
    on_search_changed: fn(value) {
      client_state.pool_msg(pool_messages.TaskTemplatesSearchChanged(value))
    },
    on_name_changed: fn(value) {
      client_state.pool_msg(pool_messages.TaskTemplateNameChanged(value))
    },
    on_description_changed: fn(value) {
      client_state.pool_msg(pool_messages.TaskTemplateDescriptionChanged(value))
    },
    on_type_changed: fn(value) {
      client_state.pool_msg(pool_messages.TaskTemplateTypeChanged(value))
    },
    on_priority_changed: fn(value) {
      client_state.pool_msg(pool_messages.TaskTemplatePriorityChanged(value))
    },
    on_submitted: fn(project_id) {
      client_state.pool_msg(pool_messages.TaskTemplateFormSubmitted(project_id))
    },
    on_delete_confirmed: client_state.pool_msg(
      pool_messages.TaskTemplateDeleteConfirmed,
    ),
    on_closed: client_state.pool_msg(pool_messages.CloseTaskTemplateDialog),
  )
}

fn admin_workflow_rule_callbacks(
  model: client_state.Model,
) -> automation_rule_list_config.Callbacks(client_state.Msg) {
  automation_rule_list_config.Callbacks(
    on_back_clicked: client_state.pool_msg(pool_messages.RulesBackClicked),
    on_create_clicked: client_state.pool_msg(pool_messages.OpenRuleDialog(
      admin_rules.RuleDialogCreate,
    )),
    on_rule_expanded: fn(rule_id) {
      client_state.pool_msg(pool_messages.RuleExpandToggled(rule_id))
    },
    on_edit_clicked: fn(rule) {
      client_state.pool_msg(
        pool_messages.OpenRuleDialog(admin_rules.RuleDialogEdit(rule)),
      )
    },
    on_delete_clicked: fn(rule) {
      client_state.pool_msg(
        pool_messages.OpenRuleDialog(admin_rules.RuleDialogDelete(rule)),
      )
    },
    on_rule_name_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleNameChanged(value))
    },
    on_rule_goal_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleGoalChanged(value))
    },
    on_rule_subject_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleSubjectChanged(value))
    },
    on_rule_task_type_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleTaskTypeChanged(value))
    },
    on_rule_event_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleEventChanged(value))
    },
    on_rule_card_scope_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleCardScopeChanged(value))
    },
    on_rule_template_search_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleTemplateSearchChanged(value))
    },
    on_rule_template_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleTemplateChanged(value))
    },
    on_create_template_clicked: client_state.pool_msg(
      pool_messages.OpenTaskTemplateDialog(
        admin_task_templates.TaskTemplateDialogCreate,
      ),
    ),
    on_rule_active_changed: fn(value) {
      client_state.pool_msg(pool_messages.RuleActiveChanged(value))
    },
    on_rule_submitted: client_state.pool_msg(pool_messages.RuleFormSubmitted),
    on_rule_delete_confirmed: client_state.pool_msg(
      pool_messages.RuleDeleteConfirmed,
    ),
    on_rule_panel_closed: client_state.pool_msg(pool_messages.CloseRuleDialog),
    on_noop: client_state.NoOp,
    template_panel: template_library.panel(template_library_config.from_state(
      model.ui.locale,
      opt.None,
      model.core.selected_project_id,
      model.admin.task_templates,
      model.admin.task_types,
      automation_deep_link.template_id(model.core.automation_selection),
      admin_task_template_callbacks(),
    )),
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
        True ->
          view_mobile_shell(
            model,
            user,
            element.fragment([
              view_member_app(model, user),
              view_member_card_show(model, user),
            ]),
          )

        False ->
          div([attribute.class("member")], [
            view_member_three_panel(model, user),
          ])
      }
  }
}

fn view_mobile_shell(
  model: client_state.Model,
  user: User,
  main_content: Element(client_state.Msg),
) -> Element(client_state.Msg) {
  member_mobile_shell.view(member_mobile_shell.Config(
    title: mobile_title(model),
    theme: model.ui.theme,
    left_drawer_open: ui_state.mobile_drawer_left_open(model.ui.mobile_drawer),
    right_drawer_open: ui_state.mobile_drawer_right_open(model.ui.mobile_drawer),
    main_content: main_content,
    left_content: build_left_panel(model, user),
    right_content: build_right_panel(model, user),
    now_working: now_working_mobile_config(model, user),
    on_left_drawer_toggle: client_state.layout_msg(
      layout_messages.MobileLeftDrawerToggled,
    ),
    on_right_drawer_toggle: client_state.layout_msg(
      layout_messages.MobileRightDrawerToggled,
    ),
    on_drawers_close: client_state.layout_msg(
      layout_messages.MobileDrawersClosed,
    ),
  ))
}

fn mobile_title(model: client_state.Model) -> String {
  i18n.t(model.ui.locale, mobile_title_key(model))
}

fn mobile_title_key(model: client_state.Model) -> i18n_text.Text {
  case model.core.page {
    client_state.Admin -> admin_mobile_title_key(model.core.active_section)
    _ -> member_mobile_pool_title(model)
  }
}

fn admin_mobile_title_key(section: permissions.AdminSection) -> i18n_text.Text {
  case section {
    permissions.Invites -> i18n_text.AdminInvites
    permissions.OrgSettings -> i18n_text.AdminOrgSettings
    permissions.Projects -> i18n_text.AdminProjects
    permissions.Team -> i18n_text.Team
    permissions.ApiTokens -> i18n_text.AdminApiTokens
    permissions.Metrics -> i18n_text.AdminMetrics
    permissions.RuleMetrics -> i18n_text.AdminWorkflows
    permissions.Members -> i18n_text.AdminMembers
    permissions.Capabilities -> i18n_text.Capabilities
    permissions.Cards -> i18n_text.MemberCards
    permissions.TaskTypes -> i18n_text.TaskTypes
    permissions.Workflows -> i18n_text.AdminWorkflows
    permissions.TaskTemplates -> i18n_text.AdminWorkflows
  }
}

fn member_mobile_pool_title(model: client_state.Model) -> i18n_text.Text {
  case model.member.pool.view_mode {
    view_mode.Pool -> i18n_text.Pool
    view_mode.Cards ->
      case model.member.pool.member_plan_mode {
        member_pool.PlanKanban -> i18n_text.Kanban
        member_pool.PlanStructure -> i18n_text.MemberCards
      }
    view_mode.Capabilities -> i18n_text.CapabilitiesBoard
    view_mode.People -> i18n_text.People
  }
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

fn view_member_app(
  model: client_state.Model,
  user: User,
) -> Element(client_state.Msg) {
  let cards = project_cards(model)
  let pool_context = pool_view_context.from_state(model, cards)

  view_mobile_pool_content(model, user, pool_context)
}

fn view_mobile_pool_content(
  model: client_state.Model,
  user: User,
  pool_context: pool_view.Context(client_state.Msg),
) -> Element(client_state.Msg) {
  case model.member.pool.view_mode {
    view_mode.Pool -> pool_view.view_pool_main(pool_context, user)
    _ -> build_center_panel(model, user)
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
    view_member_card_show(model, user),
  ])
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
  let member_plan_route = left_panel_data.member_plan_route(member_route_config)
  let member_kanban_route =
    left_panel_data.member_kanban_route(member_route_config)
  let member_depth_route_for = fn(depth: Int) {
    left_panel_data.member_depth_route(member_route_config, depth)
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
    depth_names: configured_depth_names(
      projects,
      model.core.selected_project_id,
    ),
    // Event handlers
    on_project_change: client_state.ProjectSelected,
    on_new_task: client_state.pool_msg(pool_messages.MemberCreateDialogOpened),
    on_new_card: client_state.pool_msg(
      pool_messages.OpenCardDialog(admin_cards.CardDialogCreate(opt.None)),
    ),
    on_navigate_pool: client_state.NavigateTo(
      member_route_for(view_mode.Pool),
      client_state.Push,
    ),
    on_navigate_kanban: client_state.NavigateTo(
      member_kanban_route,
      client_state.Push,
    ),
    on_navigate_cards: client_state.NavigateTo(
      member_plan_route,
      client_state.Push,
    ),
    on_navigate_depth: fn(depth) {
      client_state.NavigateTo(member_depth_route_for(depth), client_state.Push)
    },
    on_navigate_capabilities: client_state.NavigateTo(
      member_route_for(view_mode.Capabilities),
      client_state.Push,
    ),
    on_navigate_people: client_state.NavigateTo(
      member_route_for(view_mode.People),
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
    on_navigate_config_rules: client_state.NavigateTo(
      router.Config(permissions.Workflows, model.core.selected_project_id),
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
      router.Org(permissions.Team),
      client_state.Push,
    ),
    on_navigate_org_api_tokens: client_state.NavigateTo(
      router.Org(permissions.ApiTokens),
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

fn configured_depth_names(
  projects: List(Project),
  selected_project_id: opt.Option(Int),
) -> List(scope_view.DepthName) {
  case selected_project_id {
    opt.None -> default_depth_names()
    opt.Some(project_id) ->
      case list.find(projects, fn(project) { project.id == project_id }) {
        Ok(project) -> project_depth_names(project.card_depth_names)
        Error(_) -> default_depth_names()
      }
  }
}

fn project_depth_names(
  depth_names: List(ProjectDepthName),
) -> List(scope_view.DepthName) {
  case depth_names {
    [] -> default_depth_names()
    _ ->
      list.map(depth_names, fn(depth_name) {
        scope_view.DepthName(
          depth_name.depth,
          depth_name.singular_name,
          depth_name.plural_name,
        )
      })
  }
}

fn default_depth_names() -> List(scope_view.DepthName) {
  project_depth_names(project_codec.default_card_depth_names())
}

fn left_panel_member_route_config(
  model: client_state.Model,
) -> left_panel_data.MemberRouteConfig {
  left_panel_data.MemberRouteConfig(
    selected_project_id: model.core.selected_project_id,
    view_mode: model.member.pool.view_mode,
    capability_scope: model.member.pool.member_capability_scope,
    type_filter: model.member.pool.member_filters_type_id,
    capability_filter: model.member.pool.member_filters_capability_id,
    search: helpers_options.empty_to_opt(model.member.pool.member_filters_q),
    card_depth: model.member.pool.member_card_depth_filter,
    plan_mode: current_plan_mode_param(model.member.pool.member_plan_mode),
  )
}

fn current_plan_mode_param(
  plan_mode: member_pool.PlanMode,
) -> url_state.PlanModeParam {
  case plan_mode {
    member_pool.PlanStructure -> url_state.PlanStructureParam
    member_pool.PlanKanban -> url_state.PlanKanbanParam
  }
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
  let pool_context = pool_view_context.from_state(model, cards)

  // Build view-specific content
  let pool_content = pool_view.view_pool_main(pool_context, user)
  let cards_content = case model.member.pool.member_plan_mode {
    member_pool.PlanStructure ->
      plan_structure_view.view(plan_structure_config(
        model,
        user,
        cards,
        data.tasks,
      ))
    member_pool.PlanKanban ->
      plan_kanban_view.view(kanban_config(
        model,
        user,
        cards,
        data.tasks,
        data.task_types,
        data.org_users,
        data.my_capability_ids,
      ))
  }
  let people_content = people_view.view(people_config(model, cards))
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
    pool_content: pool_content,
    cards_content: cards_content,
    capabilities_content: capabilities_content,
    people_content: people_content,
    on_drag_move: fn(x, y) {
      client_state.pool_msg(pool_messages.MemberDragMoved(x, y))
    },
    on_drag_end: client_state.pool_msg(pool_messages.MemberDragEnded),
  ))
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
    surface_title: i18n.t(model.ui.locale, i18n_text.Kanban),
    surface_purpose: i18n.t(model.ui.locale, i18n_text.KanbanSurfacePurpose),
    purpose: kanban_board.ExecutionKanban,
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
      client_state.pool_msg(pool_messages.OpenCardShow(card_id))
    },
    on_card_edit: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(admin_cards.CardDialogEdit(card_id)),
      )
    },
    on_card_delete: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(admin_cards.CardDialogDelete(card_id)),
      )
    },
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id))
    },
    on_task_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
    on_create_task_in_card: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
    },
    depth_names: configured_depth_names(
      state_selectors.active_projects(model),
      model.core.selected_project_id,
    ),
    scope_kind: model.member.pool.member_plan_scope_kind,
    selected_depth: model.member.pool.member_card_depth_filter,
    selected_card_id: model.member.pool.member_plan_scope_card_id,
    card_query: model.member.pool.member_plan_scope_card_query,
    show_closed: model.member.pool.member_plan_show_closed,
    plan_mode: model.member.pool.member_plan_mode,
    on_plan_mode_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanModeChanged(value))
    },
    on_scope_kind_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeKindChanged(value))
    },
    on_scope_depth_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeDepthChanged(value))
    },
    on_scope_card_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardChanged(value))
    },
    on_scope_card_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardSearchChanged(
        value,
      ))
    },
    on_closed_toggled: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanClosedToggled(value))
    },
  )
}

fn plan_structure_config(
  model: client_state.Model,
  user: User,
  cards: List(Card),
  tasks: List(Task),
) -> plan_structure_view.Config(client_state.Msg) {
  plan_structure_view.Config(
    locale: model.ui.locale,
    cards: cards,
    tasks: tasks,
    depth_names: configured_depth_names(
      state_selectors.active_projects(model),
      model.core.selected_project_id,
    ),
    scope_kind: model.member.pool.member_plan_scope_kind,
    selected_depth: model.member.pool.member_card_depth_filter,
    selected_card_id: model.member.pool.member_plan_scope_card_id,
    card_query: model.member.pool.member_plan_scope_card_query,
    show_closed: model.member.pool.member_plan_show_closed,
    status_filter: model.member.pool.member_plan_status_filter,
    sort_order: model.member.pool.member_plan_sort,
    collapsed_card_ids: collapsed_plan_card_ids(model.member.pool),
    search_query: model.member.pool.member_filters_q,
    is_pm_or_admin: permissions.can_manage_project_content(
      user.org_role,
      state_selectors.selected_project(model),
    ),
    plan_mode: model.member.pool.member_plan_mode,
    move_mode: model.member.pool.member_plan_move_mode,
    move_drag_state: model.member.pool.member_plan_move_drag,
    move_in_flight: model.member.pool.member_plan_move_in_flight,
    move_error: model.member.pool.member_plan_move_error,
    on_plan_mode_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanModeChanged(value))
    },
    on_scope_kind_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeKindChanged(value))
    },
    on_scope_depth_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeDepthChanged(value))
    },
    on_scope_card_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardChanged(value))
    },
    on_scope_card_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardSearchChanged(
        value,
      ))
    },
    on_closed_toggled: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanClosedToggled(value))
    },
    on_status_filter_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanStatusChanged(value))
    },
    on_sort_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanSortChanged(value))
    },
    on_card_toggle: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberPlanCardToggled(card_id))
    },
    on_card_click: fn(card_id) {
      client_state.pool_msg(pool_messages.OpenCardShow(card_id))
    },
    on_card_edit: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(admin_cards.CardDialogEdit(card_id)),
      )
    },
    on_card_delete: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(admin_cards.CardDialogDelete(card_id)),
      )
    },
    on_move_requested: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberPlanMoveRequested(card_id))
    },
    on_move_cancelled: client_state.pool_msg(
      pool_messages.MemberPlanMoveCancelled,
    ),
    on_move_destination_search_change: fn(value) {
      client_state.pool_msg(
        pool_messages.MemberPlanMoveDestinationSearchChanged(value),
      )
    },
    on_move_destination_selected: fn(target) {
      client_state.pool_msg(pool_messages.MemberPlanMoveDestinationSelected(
        target,
      ))
    },
    on_move_drag_started: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberPlanMoveDragStarted(card_id))
    },
    on_move_drag_entered: fn(target) {
      client_state.pool_msg(pool_messages.MemberPlanMoveDragEntered(target))
    },
    on_move_dropped: fn(target) {
      client_state.pool_msg(pool_messages.MemberPlanMoveDroppedOn(target))
    },
    on_move_drag_ended: client_state.pool_msg(
      pool_messages.MemberPlanMoveDragEnded,
    ),
    on_create_task_in_card: fn(card_id) {
      client_state.pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(
        card_id,
      ))
    },
    on_create_subcard: fn(card_id) {
      client_state.pool_msg(
        pool_messages.OpenCardDialog(
          admin_cards.CardDialogCreate(case card_id {
            0 -> opt.None
            _ -> opt.Some(card_id)
          }),
        ),
      )
    },
  )
}

fn collapsed_plan_card_ids(pool: member_pool.Model) -> List(Int) {
  pool.member_plan_collapsed_cards
  |> dict.to_list
  |> list.filter_map(fn(entry) {
    case entry {
      #(card_id, True) -> Ok(card_id)
      #(_, False) -> Error(Nil)
    }
  })
}

fn people_config(
  model: client_state.Model,
  cards: List(Card),
) -> people_view.Config(client_state.Msg) {
  people_view.Config(
    locale: model.ui.locale,
    people_roster: model.member.pool.people_roster,
    member_tasks: model.member.pool.member_tasks,
    task_types: model.member.pool.member_task_types,
    capabilities: model.admin.capabilities.capabilities,
    cards: cards,
    depth_names: configured_depth_names(
      state_selectors.active_projects(model),
      model.core.selected_project_id,
    ),
    scope_kind: model.member.pool.member_plan_scope_kind,
    selected_depth: model.member.pool.member_card_depth_filter,
    selected_card_id: model.member.pool.member_plan_scope_card_id,
    card_query: model.member.pool.member_plan_scope_card_query,
    org_users: model.admin.members.org_users_cache,
    people_expansions: model.member.pool.people_expansions,
    search_query: model.member.pool.member_people_search_query,
    visibility_filter: model.member.pool.member_people_filter,
    sort: model.member.pool.member_people_sort,
    task_card_color: fn(task) { resolved_task_card_color(model, task) },
    on_scope_kind_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeKindChanged(value))
    },
    on_scope_depth_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeDepthChanged(value))
    },
    on_scope_card_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardChanged(value))
    },
    on_scope_card_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardSearchChanged(
        value,
      ))
    },
    on_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPeopleSearchChanged(value))
    },
    on_visibility_filter_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPeopleFilterChanged(value))
    },
    on_sort_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPeopleSortChanged(value))
    },
    on_person_toggle: fn(user_id) {
      client_state.pool_msg(pool_messages.MemberPeopleRowToggled(user_id))
    },
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id))
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
    on_task_click: fn(task_id) {
      client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id))
    },
    on_task_claim: fn(task_id, version) {
      client_state.pool_msg(pool_messages.MemberClaimClicked(task_id, version))
    },
    depth_names: configured_depth_names(
      state_selectors.active_projects(model),
      model.core.selected_project_id,
    ),
    scope_kind: model.member.pool.member_plan_scope_kind,
    capability_mode: model.member.pool.member_plan_capability_mode,
    selected_depth: model.member.pool.member_card_depth_filter,
    selected_card_id: model.member.pool.member_plan_scope_card_id,
    card_query: model.member.pool.member_plan_scope_card_query,
    show_closed: model.member.pool.member_plan_show_closed,
    on_scope_kind_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeKindChanged(value))
    },
    on_scope_depth_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeDepthChanged(value))
    },
    on_scope_card_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardChanged(value))
    },
    on_scope_card_search_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanScopeCardSearchChanged(
        value,
      ))
    },
    on_closed_toggled: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanClosedToggled(value))
    },
    on_capability_mode_change: fn(value) {
      client_state.pool_msg(pool_messages.MemberPlanCapabilityModeChanged(value))
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
      client_state.pool_msg(pool_messages.MemberTaskShowOpened(task_id))
    },
    on_card_click: fn(card_id) {
      client_state.pool_msg(pool_messages.OpenCardShow(card_id))
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
    member_pool.PoolDragDragging(over_my_tasks: over, ..) -> #(True, over)
    member_pool.PoolDragPendingRect -> #(True, False)
    member_pool.PoolDragIdle -> #(False, False)
  }
}

// =============================================================================
// Card Show for Member Views
// =============================================================================

/// Renders Card Show for Pool/Kanban/Hierarchies views.
fn view_member_card_show(
  model: client_state.Model,
  _user: User,
) -> Element(client_state.Msg) {
  cards_view.view_card_show(member_cards_config(model))
}

fn member_cards_config(
  model: client_state.Model,
) -> cards_view.Config(client_state.Msg) {
  cards_view_config.from_state(
    model.ui.locale,
    project_cards(model),
    model.member.pool,
    selected_member_show_card(model),
    model.core.user,
    state_selectors.selected_project(model),
    fn(id) { client_state.pool_msg(pool_messages.OpenCardShow(id)) },
    fn(msg) { client_state.pool_msg(pool_messages.CardShowMsg(msg)) },
  )
}

fn selected_member_show_card(model: client_state.Model) -> opt.Option(Card) {
  case model.member.pool.card_show_open {
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

fn project_capabilities(model: client_state.Model) {
  remote.unwrap(model.member.skills.member_capabilities, [])
}

fn can_manage_task_notes(model: client_state.Model) -> Bool {
  case model.core.user {
    opt.Some(user) ->
      permissions.can_manage_project_content(
        user.org_role,
        state_selectors.selected_project(model),
      )
    opt.None -> False
  }
}

fn resolve_task_card_info(model: client_state.Model, task: Task) {
  card_queries.resolve_task_card_info(project_cards(model), task)
}
