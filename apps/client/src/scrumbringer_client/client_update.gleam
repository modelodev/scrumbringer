//// Update function and helpers for Scrumbringer client.
////
//// ## Mission
////
//// Handle all state transitions for the Lustre SPA client.
////
//// ## Responsibilities
////
//// - Message dispatch and state transitions
//// - Effect management (API calls, navigation, timers)
//// - URL handling and routing
////
//// ## Non-responsibilities
////
//// - Type definitions (see `client_state.gleam`)
//// - View rendering (see `scrumbringer_client.gleam`)
////
//// ## Line Count Justification
////
//// ~2300 lines: Central TEA update hub that dispatches all Msg variants to
//// feature-specific update handlers. While large, this file acts as an
//// orchestration layer with clear delegation patterns:
//// - Each `case msg { ... }` branch delegates to `features/*/update.gleam`
//// - Splitting further would fragment the single entry point pattern
//// - Lustre's TEA model benefits from a unified `update` function
//// Future: Consider code generation for message dispatch if Msg variants
//// exceed 100.

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/card as domain_card
import domain/org_role

import scrumbringer_client/accept_invite

// API modules
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/api/metrics as api_metrics
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/task.{TaskFilters}
import scrumbringer_client/client_ffi
import scrumbringer_client/hydration
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/theme
import scrumbringer_client/update_helpers

import scrumbringer_client/i18n/text as i18n_text

import scrumbringer_client/client_state.{
  type Model, type Msg, type NavMode, type Remote,
  AcceptInvite as AcceptInvitePage, AcceptInviteMsg, Admin,
  AdminMetricsOverviewFetched, AdminMetricsProjectTasksFetched,
  AdminRuleMetricsDrilldownClicked, AdminRuleMetricsDrilldownClosed,
  AdminRuleMetricsExecPageChanged, AdminRuleMetricsExecutionsFetched,
  AdminRuleMetricsFetched, AdminRuleMetricsFromChanged,
  AdminRuleMetricsRefreshClicked, AdminRuleMetricsRuleDetailsFetched,
  AdminRuleMetricsToChanged, AdminRuleMetricsWorkflowDetailsFetched,
  AdminRuleMetricsWorkflowExpanded, CapabilitiesFetched,
  CapabilityCreateDialogClosed, CapabilityCreateDialogOpened,
  CapabilityCreateNameChanged, CapabilityCreateSubmitted, CapabilityCreated,
  CardCreateColorChanged, CardCreateColorToggle, CardCreateDescriptionChanged,
  CardCreateDialogClosed, CardCreateDialogOpened,
  CardCreateSubmitted, CardCreateTitleChanged,
  CardAddTaskCreated, CardAddTaskPrioritySelect, CardAddTaskTitleInput,
  CardCreated, CardDeleteCancelled, CardDeleteClicked, CardDeleteConfirmed,
  CardDeleted, CardDetailTasksFetched, CardEditCancelled, CardEditClicked,
  CardEditColorChanged, CardEditColorToggle, CardEditDescriptionChanged,
  CardEditSubmitted, CardEditTitleChanged,
  CardUpdated, CardsFetched, CancelAddTask, CloseCardDetail, Failed,
  ForgotPasswordClicked, ForgotPasswordCopyClicked, ForgotPasswordCopyFinished,
  ForgotPasswordDismissed, ForgotPasswordEmailChanged, ForgotPasswordFinished,
  ForgotPasswordSubmitted, GlobalKeyDown, InviteLinkCopyClicked,
  InviteLinkCopyFinished, InviteLinkCreateSubmitted, InviteLinkCreated,
  InviteLinkEmailChanged, InviteLinkRegenerateClicked, InviteLinkRegenerated,
  InviteLinksFetched, Loaded, Loading, LocaleSelected, Login, LoginDomValuesRead,
  LoginEmailChanged, LoginFinished, LoginPasswordChanged, LoginSubmitted,
  LogoutClicked, LogoutFinished, MeFetched, Member, MemberActiveTaskFetched,
  MemberActiveTaskHeartbeated, MemberActiveTaskPaused, MemberActiveTaskStarted,
  MemberAddDialogClosed, MemberAddDialogOpened, MemberAddRoleChanged,
  MemberAddSubmitted, MemberAddUserSelected, MemberAdded,
  MemberCanvasRectFetched, MemberClaimClicked, MemberCompleteClicked,
  MemberCreateDescriptionChanged, MemberCreateDialogClosed,
  MemberCreateDialogOpened, MemberCreatePriorityChanged, MemberCreateSubmitted,
  MemberCreateTitleChanged, MemberCreateTypeIdChanged, MemberDragEnded,
  MemberDragMoved, MemberDragStarted, MemberMetricsFetched,
  MemberMyCapabilityIdsFetched, MemberMyCapabilityIdsSaved, MemberNoteAdded,
  MemberNoteContentChanged, MemberNoteSubmitted, MemberNotesFetched,
  MemberNowWorkingPauseClicked, MemberNowWorkingStartClicked,
  MemberPoolCapabilityChanged, MemberPoolDragToClaimArmed,
  MemberPoolFiltersToggled, MemberPoolMyTasksRectFetched,
  MemberPoolSearchChanged, MemberPoolSearchDebounced, MemberPoolStatusChanged,
  MemberPanelToggled, MemberPoolTypeChanged, MemberPoolViewModeSet, MemberPositionEditClosed,
  MemberPositionEditOpened, MemberPositionEditSubmitted,
  MemberPositionEditXChanged, MemberPositionEditYChanged, MemberPositionSaved,
  MemberPositionsFetched, MemberProjectTasksFetched, MemberReleaseClicked,
  MemberRemoveCancelled, MemberRemoveClicked, MemberRemoveConfirmed,
  MemberRemoved, MemberSaveCapabilitiesClicked, MemberTaskClaimed,
  MemberTaskCompleted, MemberTaskCreated, MemberTaskDetailsClosed,
  MemberTaskDetailsOpened, MemberTaskReleased, MemberTaskTypesFetched,
  MemberToggleCapability, MemberToggleMyCapabilitiesQuick,
  MemberWorkSessionHeartbeated, MemberWorkSessionPaused,
  MemberWorkSessionStarted, MemberWorkSessionsFetched, MembersFetched, Model,
  NavigateTo, NotAsked, NowWorkingTicked, OpenCardDetail, OrgSettingsRoleChanged,
  OrgSettingsSaveClicked, OrgSettingsSaved, OrgSettingsUsersFetched,
  OrgUsersCacheFetched, OrgUsersSearchChanged, OrgUsersSearchDebounced,
  UserProjectsDialogOpened, UserProjectsDialogClosed, UserProjectsFetched,
  UserProjectsAddProjectChanged, UserProjectsAddSubmitted, UserProjectAdded,
  UserProjectRemoveClicked, UserProjectRemoved,
  OrgUsersSearchResults, ProjectCreateNameChanged, ProjectCreateSubmitted,
  ProjectCreated, ProjectSelected, ProjectsFetched, Push, Rect, Replace,
  ResetPassword as ResetPasswordPage, ResetPasswordMsg,
  RuleAttachTemplateSelected, RuleAttachTemplateSubmitted,
  RuleCreateActiveChanged, RuleCreateDialogClosed, RuleCreateDialogOpened,
  RuleCreateGoalChanged, RuleCreateNameChanged,
  RuleCreateResourceTypeChanged, RuleCreateSubmitted,
  RuleCreateTaskTypeIdChanged, RuleCreateToStateChanged, RuleCreated,
  RuleDeleteCancelled, RuleDeleteClicked, RuleDeleteConfirmed, RuleDeleted,
  RuleEditActiveChanged, RuleEditCancelled, RuleEditClicked, RuleEditGoalChanged,
  RuleEditNameChanged, RuleEditResourceTypeChanged, RuleEditSubmitted,
  RuleEditTaskTypeIdChanged, RuleEditToStateChanged, RuleMetricsFetched,
  RuleTemplateAttached, RuleTemplateDetachClicked, RuleTemplateDetached,
  RuleTemplatesClicked, RuleTemplatesFetched, RuleUpdated, RulesBackClicked,
  RulesFetched, TaskTemplateCreateDescriptionChanged,
  TaskTemplateCreateDialogClosed, TaskTemplateCreateDialogOpened,
  TaskTemplateCreateNameChanged, TaskTemplateCreatePriorityChanged,
  TaskTemplateCreateSubmitted, TaskTemplateCreateTypeIdChanged,
  TaskTemplateCreated, TaskTemplateDeleteCancelled, TaskTemplateDeleteClicked,
  TaskTemplateDeleteConfirmed, TaskTemplateDeleted, TaskTemplateEditCancelled,
  TaskTemplateEditClicked, TaskTemplateEditDescriptionChanged,
  TaskTemplateEditNameChanged, TaskTemplateEditPriorityChanged,
  TaskTemplateEditSubmitted, TaskTemplateEditTypeIdChanged, TaskTemplateUpdated,
  TaskTemplatesOrgFetched, TaskTemplatesProjectFetched,
  TaskTypeCreateCapabilityChanged, TaskTypeCreateDialogClosed,
  TaskTypeCreateDialogOpened, TaskTypeCreateIconChanged,
  TaskTypeCreateNameChanged, TaskTypeCreateSubmitted, TaskTypeCreated,
  TaskTypeIconErrored, TaskTypeIconLoaded, TaskTypesFetched, ThemeSelected,
  ToastDismissed, ToggleAddTaskForm, SubmitAddTask, UrlChanged,
  WorkflowCreateActiveChanged, WorkflowCreateDialogClosed,
  WorkflowCreateDialogOpened, WorkflowCreateDescriptionChanged,
  WorkflowCreateNameChanged, WorkflowCreateSubmitted, WorkflowCreated,
  WorkflowDeleteCancelled,
  WorkflowDeleteClicked, WorkflowDeleteConfirmed, WorkflowDeleted,
  WorkflowEditActiveChanged, WorkflowEditCancelled, WorkflowEditClicked,
  WorkflowEditDescriptionChanged, WorkflowEditNameChanged, WorkflowEditSubmitted,
  WorkflowRulesClicked, WorkflowUpdated, WorkflowsOrgFetched,
  WorkflowsProjectFetched,
}

// Workflows
// Rules
// Rule templates
// Task templates

import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/auth/update as auth_workflow
import scrumbringer_client/features/capabilities/update as capabilities_workflow
import scrumbringer_client/features/i18n/update as i18n_workflow
import scrumbringer_client/features/invites/update as invite_links_workflow
import scrumbringer_client/features/metrics/update as metrics_workflow
import scrumbringer_client/features/now_working/update as now_working_workflow
import scrumbringer_client/features/pool/update as pool_workflow
import scrumbringer_client/features/projects/update as projects_workflow
import scrumbringer_client/features/skills/update as skills_workflow
import scrumbringer_client/features/task_types/update as task_types_workflow
import scrumbringer_client/features/tasks/update as tasks_workflow

// ---------------------------------------------------------------------------
// Routing helpers
// ---------------------------------------------------------------------------

fn current_route(model: Model) -> router.Route {
  case model.page {
    Login -> router.Login

    AcceptInvitePage -> {
      let accept_invite.Model(token: token, ..) = model.accept_invite
      router.AcceptInvite(token)
    }

    ResetPasswordPage -> {
      let reset_password.Model(token: token, ..) = model.reset_password
      router.ResetPassword(token)
    }

    Admin -> router.Admin(model.active_section, model.selected_project_id)

    Member -> router.Member(model.member_section, model.selected_project_id)
  }
}

fn replace_url(model: Model) -> Effect(Msg) {
  router.replace(current_route(model))
}

pub fn accept_invite_effect(action: accept_invite.Action) -> Effect(Msg) {
  case action {
    accept_invite.ValidateToken(token) ->
      api_auth.validate_invite_link_token(token, fn(result) {
        AcceptInviteMsg(accept_invite.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn reset_password_effect(action: reset_password.Action) -> Effect(Msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api_auth.validate_password_reset_token(token, fn(result) {
        ResetPasswordMsg(reset_password.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn register_popstate_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_popstate(fn(_) { dispatch(UrlChanged) })
  })
}

pub fn register_keydown_effect() -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_keydown(fn(payload) {
      let #(key, ctrl, meta, shift, is_editing, modal_open) = payload
      dispatch(
        GlobalKeyDown(pool_prefs.KeyEvent(
          key,
          ctrl,
          meta,
          shift,
          is_editing,
          modal_open,
        )),
      )
    })
  })
}

/// Write URL to browser history using the appropriate navigation mode.
///
/// Delegates to `router.push` or `router.replace` based on mode.
pub fn write_url(mode: NavMode, route: router.Route) -> Effect(Msg) {
  case mode {
    Push -> router.push(route)
    Replace -> router.replace(route)
  }
}

fn apply_route_fields(
  model: Model,
  route: router.Route,
) -> #(Model, Effect(Msg)) {
  let model = Model(..model, toast: opt.None)

  case route {
    router.Login -> {
      #(
        Model(
          ..model,
          page: Login,
          selected_project_id: opt.None,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        ),
        effect.none(),
      )
    }

    router.AcceptInvite(token) -> {
      let #(new_accept_model, action) = accept_invite.init(token)
      let model =
        Model(
          ..model,
          page: AcceptInvitePage,
          accept_invite: new_accept_model,
          selected_project_id: opt.None,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        )

      #(model, accept_invite_effect(action))
    }

    router.ResetPassword(token) -> {
      let #(new_reset_model, action) = reset_password.init(token)
      let model =
        Model(
          ..model,
          page: ResetPasswordPage,
          reset_password: new_reset_model,
          selected_project_id: opt.None,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        )

      #(model, reset_password_effect(action))
    }

    router.Admin(section, project_id) -> {
      let model =
        Model(
          ..model,
          page: Admin,
          active_section: section,
          selected_project_id: project_id,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    router.Member(section, project_id) -> {
      let capabilities_fx = case model.page {
        Admin -> api_org.list_capabilities(CapabilitiesFetched)
        _ -> effect.none()
      }

      #(
        Model(
          ..model,
          page: Member,
          member_section: section,
          selected_project_id: project_id,
          member_drag: opt.None,
          member_pool_drag_to_claim_armed: False,
          member_pool_drag_over_my_tasks: False,
        ),
        capabilities_fx,
      )
    }
  }
}

fn remote_state(remote: Remote(a)) -> hydration.ResourceState {
  case remote {
    NotAsked -> hydration.NotAsked
    Loading -> hydration.Loading
    Loaded(_) -> hydration.Loaded
    Failed(_) -> hydration.Failed
  }
}

fn auth_state(model: Model) -> hydration.AuthState {
  case model.user {
    opt.Some(user) -> hydration.Authed(user.org_role)

    opt.None ->
      case model.auth_checked {
        True -> hydration.Unauthed
        False -> hydration.Unknown
      }
  }
}

fn build_snapshot(model: Model) -> hydration.Snapshot {
  hydration.Snapshot(
    auth: auth_state(model),
    projects: remote_state(model.projects),
    invite_links: remote_state(model.invite_links),
    capabilities: remote_state(model.capabilities),
    my_capability_ids: remote_state(model.member_my_capability_ids),
    org_settings_users: remote_state(model.org_settings_users),
    members: remote_state(model.members),
    members_project_id: model.members_project_id,
    task_types: remote_state(model.task_types),
    task_types_project_id: model.task_types_project_id,
    member_tasks: remote_state(model.member_tasks),
    active_task: remote_state(model.member_active_task),
    me_metrics: remote_state(model.member_metrics),
    org_metrics_overview: remote_state(model.admin_metrics_overview),
    org_metrics_project_tasks: remote_state(model.admin_metrics_project_tasks),
    org_metrics_project_id: model.admin_metrics_project_id,
  )
}

/// Hydrate model based on current route and resource states.
///
/// ## Size Justification (259 lines)
///
/// This function handles hydration commands for 12 resource types, each requiring:
/// - State validation (Loading/Loaded check)
/// - Project ID validation where applicable
/// - Model updates and effect batching
///
/// Splitting would fragment the hydration logic and make the command-to-effect
/// mapping harder to understand. The function is a single-purpose dispatcher
/// that processes hydration.Command variants sequentially.
///
/// ## Example
///
/// ```gleam
/// let #(model, effects) = hydrate_model(model)
/// ```
fn hydrate_model(model: Model) -> #(Model, Effect(Msg)) {
  let route = current_route(model)
  let commands = hydration.plan(route, build_snapshot(model))

  case
    list.find(commands, fn(cmd) {
      case cmd {
        hydration.Redirect(_) -> True
        _ -> False
      }
    })
  {
    Ok(hydration.Redirect(to: to)) -> {
      case to == route {
        True -> #(model, effect.none())
        False -> handle_navigate_to(model, to, Replace)
      }
    }

    _ -> {
      let #(next, effects) =
        list.fold(commands, #(model, []), fn(state, cmd) {
          let #(m, fx) = state

          case cmd {
            hydration.FetchMe -> {
              #(m, [api_auth.fetch_me(MeFetched), ..fx])
            }

            hydration.FetchProjects -> {
              case m.projects {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, projects: Loading)
                  #(m, [api_projects.list_projects(ProjectsFetched), ..fx])
                }
              }
            }

            hydration.FetchInviteLinks -> {
              case m.invite_links {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, invite_links: Loading)
                  #(m, [api_org.list_invite_links(InviteLinksFetched), ..fx])
                }
              }
            }

            hydration.FetchCapabilities -> {
              case m.capabilities {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, capabilities: Loading)
                  #(m, [api_org.list_capabilities(CapabilitiesFetched), ..fx])
                }
              }
            }

            hydration.FetchMeCapabilityIds -> {
              case m.member_my_capability_ids {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_my_capability_ids: Loading)
                  #(m, [
                    api_tasks.get_me_capability_ids(
                      MemberMyCapabilityIdsFetched,
                    ),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchActiveTask -> {
              case m.member_work_sessions {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_work_sessions: Loading)
                  #(m, [
                    api_tasks.get_work_sessions(MemberWorkSessionsFetched),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchMeMetrics -> {
              case m.member_metrics {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, member_metrics: Loading)
                  #(m, [
                    api_metrics.get_me_metrics(30, MemberMetricsFetched),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsOverview -> {
              case m.admin_metrics_overview {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m = Model(..m, admin_metrics_overview: Loading)
                  #(m, [
                    api_metrics.get_org_metrics_overview(
                      30,
                      AdminMetricsOverviewFetched,
                    ),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsProjectTasks(project_id: project_id) -> {
              let can_fetch = case m.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case
                    m.admin_metrics_project_tasks,
                    m.admin_metrics_project_id
                  {
                    Loading, _ -> #(m, fx)
                    Loaded(_), opt.Some(pid) if pid == project_id -> #(m, fx)

                    _, _ -> {
                      let m =
                        Model(
                          ..m,
                          admin_metrics_project_tasks: Loading,
                          admin_metrics_project_id: opt.Some(project_id),
                        )

                      let fx_tasks =
                        api_metrics.get_org_metrics_project_tasks(
                          project_id,
                          30,
                          AdminMetricsProjectTasksFetched,
                        )

                      #(m, [fx_tasks, ..fx])
                    }
                  }
              }
            }

            hydration.FetchOrgSettingsUsers -> {
              case m.org_settings_users {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    Model(
                      ..m,
                      org_settings_users: Loading,
                      org_settings_role_drafts: dict.new(),
                      org_settings_save_in_flight: False,
                      org_settings_error: opt.None,
                      org_settings_error_user_id: opt.None,
                    )

                  #(m, [
                    api_org.list_org_users("", OrgSettingsUsersFetched),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchMembers(project_id: project_id) -> {
              let can_fetch = case m.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.members {
                    Loading -> #(m, fx)

                    _ -> {
                      let m =
                        Model(
                          ..m,
                          members: Loading,
                          members_project_id: opt.Some(project_id),
                          org_users_cache: Loading,
                        )

                      let fx_members =
                        api_projects.list_project_members(
                          project_id,
                          MembersFetched,
                        )
                      let fx_users =
                        api_org.list_org_users("", OrgUsersCacheFetched)

                      #(m, [effect.batch([fx_members, fx_users]), ..fx])
                    }
                  }
              }
            }

            hydration.FetchTaskTypes(project_id: project_id) -> {
              let can_fetch = case m.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.task_types {
                    Loading -> #(m, fx)

                    _ -> {
                      let m =
                        Model(
                          ..m,
                          task_types: Loading,
                          task_types_project_id: opt.Some(project_id),
                        )

                      #(m, [
                        api_tasks.list_task_types(project_id, TaskTypesFetched),
                        ..fx
                      ])
                    }
                  }
              }
            }

            hydration.RefreshMember -> {
              case m.projects {
                Loaded(_) -> {
                  let #(m, member_fx) = member_refresh(m)
                  #(m, [member_fx, ..fx])
                }

                _ -> #(m, fx)
              }
            }

            hydration.Redirect(_) -> #(m, fx)
          }
        })

      #(next, effect.batch(list.reverse(effects)))
    }
  }
}

fn handle_url_changed(model: Model) -> #(Model, Effect(Msg)) {
  let pathname = client_ffi.location_pathname()
  let search = client_ffi.location_search()
  let hash = client_ffi.location_hash()
  let is_mobile = client_ffi.is_mobile()

  let model = Model(..model, is_mobile: is_mobile)

  let parsed =
    router.parse(pathname, search, hash)
    |> router.apply_mobile_rules(is_mobile)

  let route = case parsed {
    router.Parsed(route) -> route
    router.Redirect(route) -> route
  }

  let current = current_route(model)
  let title_fx = router.update_page_title(route, model.locale)

  case parsed {
    router.Parsed(_) ->
      case route == current {
        True -> #(model, effect.none())

        False -> {
          let #(model, route_fx) = apply_route_fields(model, route)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([route_fx, hyd_fx, title_fx]))
        }
      }

    router.Redirect(_) -> {
      let #(model, route_fx) = apply_route_fields(model, route)
      let #(model, hyd_fx) = hydrate_model(model)
      #(
        model,
        effect.batch([write_url(Replace, route), route_fx, hyd_fx, title_fx]),
      )
    }
  }
}

fn handle_navigate_to(
  model: Model,
  route: router.Route,
  mode: NavMode,
) -> #(Model, Effect(Msg)) {
  let #(next_route, next_mode) = case model.is_mobile, route {
    True, router.Member(member_section.Pool, project_id) -> #(
      router.Member(member_section.MyBar, project_id),
      Replace,
    )
    _, _ -> #(route, mode)
  }

  case next_route == current_route(model) {
    True -> #(model, effect.none())

    False -> {
      let #(model, route_fx) = apply_route_fields(model, next_route)
      let #(model, hyd_fx) = hydrate_model(model)
      let title_fx = router.update_page_title(next_route, model.locale)

      #(
        model,
        effect.batch([
          write_url(next_mode, next_route),
          route_fx,
          hyd_fx,
          title_fx,
        ]),
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Bootstrap and refresh helpers
// ---------------------------------------------------------------------------

fn bootstrap_admin(model: Model) -> #(Model, Effect(Msg)) {
  let is_admin = case model.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  let model =
    Model(
      ..model,
      projects: Loading,
      capabilities: Loading,
      member_my_capability_ids: Loading,
      invite_links: case is_admin {
        True -> Loading
        False -> model.invite_links
      },
    )

  let effects = [
    api_projects.list_projects(ProjectsFetched),
    api_org.list_capabilities(CapabilitiesFetched),
    api_tasks.get_me_capability_ids(MemberMyCapabilityIdsFetched),
  ]

  let effects = case is_admin {
    True -> [api_org.list_invite_links(InviteLinksFetched), ..effects]
    False -> effects
  }

  #(model, effect.batch(effects))
}

pub fn refresh_section_for_test(model: Model) -> #(Model, Effect(Msg)) {
  case model.active_section {
    permissions.Invites -> {
      let model = Model(..model, invite_links: Loading)
      #(model, api_org.list_invite_links(InviteLinksFetched))
    }

    permissions.OrgSettings -> {
      let model =
        Model(
          ..model,
          org_settings_users: Loading,
          org_settings_role_drafts: dict.new(),
          org_settings_save_in_flight: False,
          org_settings_error: opt.None,
          org_settings_error_user_id: opt.None,
        )

      #(model, api_org.list_org_users("", OrgSettingsUsersFetched))
    }

    permissions.Projects -> #(
      model,
      api_projects.list_projects(ProjectsFetched),
    )

    permissions.Metrics -> {
      let model = Model(..model, admin_metrics_overview: Loading)

      let overview_fx =
        api_metrics.get_org_metrics_overview(30, AdminMetricsOverviewFetched)

      case model.selected_project_id {
        opt.None -> #(model, overview_fx)

        opt.Some(project_id) -> {
          let model =
            Model(
              ..model,
              admin_metrics_project_tasks: Loading,
              admin_metrics_project_id: opt.Some(project_id),
            )

          let tasks_fx =
            api_metrics.get_org_metrics_project_tasks(
              project_id,
              30,
              AdminMetricsProjectTasksFetched,
            )

          #(model, effect.batch([overview_fx, tasks_fx]))
        }
      }
    }

    permissions.RuleMetrics -> {
      // Don't auto-fetch - user needs to select date range first
      #(model, effect.none())
    }

    permissions.Capabilities -> #(
      model,
      api_org.list_capabilities(CapabilitiesFetched),
    )

    permissions.Members ->
      case model.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model =
            Model(
              ..model,
              members: Loading,
              members_project_id: opt.Some(project_id),
              org_users_cache: Loading,
            )
          #(
            model,
            effect.batch([
              api_projects.list_project_members(project_id, MembersFetched),
              api_org.list_org_users("", OrgUsersCacheFetched),
            ]),
          )
        }
      }

    permissions.TaskTypes ->
      case model.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model =
            Model(
              ..model,
              task_types: Loading,
              task_types_project_id: opt.Some(project_id),
            )
          #(model, api_tasks.list_task_types(project_id, TaskTypesFetched))
        }
      }

    permissions.Cards -> admin_workflow.fetch_cards_for_project(model)

    permissions.Workflows -> admin_workflow.fetch_workflows(model)

    permissions.TaskTemplates -> admin_workflow.fetch_task_templates(model)
  }
}

/// Refresh member section data (tasks, types, positions, active task, metrics).
///
/// ## Size Justification (105 lines)
///
/// Coordinates 5 parallel data fetches with project ID filtering:
/// - Tasks by project (with pending counter)
/// - Task types by project (with pending counter)
/// - Task positions
/// - Active task state
/// - Member metrics
///
/// The batched fetching logic and state updates are tightly coupled
/// and splitting would complicate the refresh coordination.
fn member_refresh(model: Model) -> #(Model, Effect(Msg)) {
  case model.member_section {
    member_section.MySkills -> #(model, effect.none())

    _ -> {
      let projects = update_helpers.active_projects(model)

      let project_ids = case model.selected_project_id {
        opt.Some(project_id) -> [project_id]
        opt.None -> projects |> list.map(fn(p) { p.id })
      }

      case project_ids {
        [] -> #(
          Model(
            ..model,
            member_tasks: NotAsked,
            member_tasks_pending: 0,
            member_tasks_by_project: dict.new(),
            member_task_types: NotAsked,
            member_task_types_pending: 0,
            member_task_types_by_project: dict.new(),
          ),
          effect.none(),
        )

        _ -> {
          let filters = case model.member_section {
            member_section.MyBar ->
              TaskFilters(
                status: opt.Some("claimed"),
                type_id: opt.None,
                capability_id: opt.None,
                q: opt.None,
              )

            member_section.Pool ->
              TaskFilters(
                status: opt.None,
                type_id: update_helpers.empty_to_int_opt(
                  model.member_filters_type_id,
                ),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member_filters_q),
              )

            _ ->
              TaskFilters(
                status: update_helpers.empty_to_opt(model.member_filters_status),
                type_id: update_helpers.empty_to_int_opt(
                  model.member_filters_type_id,
                ),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member_filters_q),
              )
          }

          let positions_effect =
            api_tasks.list_me_task_positions(
              model.selected_project_id,
              MemberPositionsFetched,
            )

          let task_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_project_tasks(project_id, filters, fn(result) {
                MemberProjectTasksFetched(project_id, result)
              })
            })

          let task_type_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_task_types(project_id, fn(result) {
                MemberTaskTypesFetched(project_id, result)
              })
            })

          let effects =
            list.append(
              task_effects,
              list.append(task_type_effects, [positions_effect]),
            )

          let model =
            Model(
              ..model,
              member_tasks: Loading,
              member_tasks_pending: list.length(project_ids),
              member_tasks_by_project: dict.new(),
              member_task_types: Loading,
              member_task_types_pending: list.length(project_ids),
              member_task_types_by_project: dict.new(),
            )

          #(model, effect.batch(effects))
        }
      }
    }
  }
}

pub fn should_pause_active_task_on_project_change(
  is_member_page: Bool,
  previous_project_id: opt.Option(Int),
  next_project_id: opt.Option(Int),
) -> Bool {
  case is_member_page {
    False -> False
    True -> previous_project_id != next_project_id
  }
}

// ---------------------------------------------------------------------------
// Main update function
// ---------------------------------------------------------------------------

/// Main Lustre update function - dispatches messages to handlers.
///
/// ## Size Justification (~2800 lines)
///
/// This function is the central message dispatcher for the Lustre/Elm architecture.
/// It handles 163 distinct Msg variants covering:
/// - Authentication flow (login, logout, password reset)
/// - Navigation and routing
/// - Admin sections (projects, capabilities, members, task types, metrics, org settings)
/// - Member sections (pool, tasks, notes, drag-and-drop, timer)
/// - API responses and error handling
/// - UI state (dialogs, filters, toasts, themes)
///
/// The large case expression is inherent to the Elm architecture pattern where
/// a single update function handles all application messages. Splitting would
/// require either:
/// 1. Breaking the Lustre contract (not possible)
/// 2. Adding dispatch indirection that increases complexity without benefit
///
/// Each case arm delegates to focused handler functions, keeping individual
/// logic units small and testable. The update function itself is a flat
/// dispatcher with minimal logic per branch.
///
/// ## Example
///
/// ```gleam
/// let #(new_model, effects) = update(model, LoginSubmit)
/// ```
pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UrlChanged -> handle_url_changed(model)

    NavigateTo(route, mode) -> handle_navigate_to(model, route, mode)

    MemberPoolMyTasksRectFetched(left, top, width, height) -> #(
      Model(
        ..model,
        member_pool_my_tasks_rect: opt.Some(Rect(
          left: left,
          top: top,
          width: width,
          height: height,
        )),
      ),
      effect.none(),
    )

    MemberPoolDragToClaimArmed(armed) -> #(
      Model(
        ..model,
        member_pool_drag_to_claim_armed: armed,
        member_pool_drag_over_my_tasks: False,
      ),
      effect.none(),
    )

    MeFetched(Ok(user)) -> {
      let default_page = case user.org_role {
        org_role.Admin -> Admin
        _ -> Member
      }

      let resolved_page = case model.page {
        Member -> Member

        Admin ->
          case user.org_role {
            org_role.Admin -> Admin
            _ -> Member
          }

        _ -> default_page
      }

      let model =
        Model(
          ..model,
          page: resolved_page,
          user: opt.Some(user),
          auth_checked: True,
        )
      let #(model, boot) = bootstrap_admin(model)
      let #(model, hyd_fx) = hydrate_model(model)

      #(
        model,
        effect.batch([
          boot,
          hyd_fx,
          replace_url(model),
        ]),
      )
    }

    MeFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model =
            Model(..model, page: Login, user: opt.None, auth_checked: True)
          #(model, replace_url(model))
        }

        False -> {
          let model =
            Model(
              ..model,
              page: Login,
              user: opt.None,
              auth_checked: True,
              login_error: opt.Some(err.message),
            )

          #(model, replace_url(model))
        }
      }
    }

    AcceptInviteMsg(inner) -> {
      let #(next_accept, action) =
        accept_invite.update(model.accept_invite, inner)
      let model = Model(..model, accept_invite: next_accept, toast: opt.None)

      case action {
        accept_invite.NoOp -> #(model, effect.none())

        accept_invite.ValidateToken(_) -> #(model, accept_invite_effect(action))

        accept_invite.Register(token: token, password: password) -> #(
          model,
          api_auth.register_with_invite_link(token, password, fn(result) {
            AcceptInviteMsg(accept_invite.Registered(result))
          }),
        )

        accept_invite.Authed(user) -> {
          let page = case user.org_role {
            org_role.Admin -> Admin
            _ -> Member
          }

          let model =
            Model(
              ..model,
              page: page,
              user: opt.Some(user),
              auth_checked: True,
              toast: opt.Some(update_helpers.i18n_t(model, i18n_text.Welcome)),
            )

          let #(model, boot) = bootstrap_admin(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(
            model,
            effect.batch([
              boot,
              hyd_fx,
              replace_url(model),
            ]),
          )
        }
      }
    }

    ResetPasswordMsg(inner) -> {
      let #(next_reset, action) =
        reset_password.update(model.reset_password, inner)

      let model = Model(..model, reset_password: next_reset, toast: opt.None)

      case action {
        reset_password.NoOp -> #(model, effect.none())

        reset_password.ValidateToken(_) -> #(
          model,
          reset_password_effect(action),
        )

        reset_password.Consume(token: token, password: password) -> #(
          model,
          api_auth.consume_password_reset_token(token, password, fn(result) {
            ResetPasswordMsg(reset_password.Consumed(result))
          }),
        )

        reset_password.GoToLogin -> {
          let model =
            Model(
              ..model,
              page: Login,
              toast: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.PasswordUpdated,
              )),
              login_password: "",
              login_error: opt.None,
            )

          #(model, replace_url(model))
        }
      }
    }

    LoginEmailChanged(email) ->
      auth_workflow.handle_login_email_changed(model, email)
    LoginPasswordChanged(password) ->
      auth_workflow.handle_login_password_changed(model, password)
    LoginSubmitted -> auth_workflow.handle_login_submitted(model)
    LoginDomValuesRead(raw_email, raw_password) ->
      auth_workflow.handle_login_dom_values_read(model, raw_email, raw_password)
    LoginFinished(Ok(user)) ->
      auth_workflow.handle_login_finished_ok(
        model,
        user,
        bootstrap_admin,
        hydrate_model,
        replace_url,
      )
    LoginFinished(Error(err)) ->
      auth_workflow.handle_login_finished_error(model, err)

    ForgotPasswordClicked -> auth_workflow.handle_forgot_password_clicked(model)
    ForgotPasswordEmailChanged(email) ->
      auth_workflow.handle_forgot_password_email_changed(model, email)
    ForgotPasswordSubmitted ->
      auth_workflow.handle_forgot_password_submitted(model)
    ForgotPasswordFinished(Ok(reset)) ->
      auth_workflow.handle_forgot_password_finished_ok(model, reset)
    ForgotPasswordFinished(Error(err)) ->
      auth_workflow.handle_forgot_password_finished_error(model, err)
    ForgotPasswordCopyClicked ->
      auth_workflow.handle_forgot_password_copy_clicked(model)
    ForgotPasswordCopyFinished(ok) ->
      auth_workflow.handle_forgot_password_copy_finished(model, ok)
    ForgotPasswordDismissed ->
      auth_workflow.handle_forgot_password_dismissed(model)

    LogoutClicked -> auth_workflow.handle_logout_clicked(model)
    LogoutFinished(Ok(_)) ->
      auth_workflow.handle_logout_finished_ok(model, replace_url)
    LogoutFinished(Error(err)) ->
      auth_workflow.handle_logout_finished_error(model, err, replace_url)

    ToastDismissed -> #(Model(..model, toast: opt.None), effect.none())

    ThemeSelected(value) -> {
      let next_theme = theme.deserialize(value)

      case next_theme == model.theme {
        True -> #(model, effect.none())

        False -> #(
          Model(..model, theme: next_theme),
          effect.from(fn(_dispatch) { theme.save_to_storage(next_theme) }),
        )
      }
    }

    LocaleSelected(value) -> i18n_workflow.handle_locale_selected(model, value)

    ProjectSelected(project_id) -> {
      let selected = case int.parse(project_id) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }

      let should_pause =
        should_pause_active_task_on_project_change(
          model.page == Member,
          model.selected_project_id,
          selected,
        )

      let model = case selected {
        opt.None ->
          Model(
            ..model,
            selected_project_id: selected,
            toast: opt.None,
            member_filters_type_id: "",
            member_task_types: NotAsked,
          )
        _ -> Model(..model, selected_project_id: selected, toast: opt.None)
      }

      case model.page {
        Member -> {
          let #(model, fx) = member_refresh(model)

          let pause_fx = case should_pause {
            True -> api_tasks.pause_me_active_task(MemberActiveTaskPaused)
            False -> effect.none()
          }

          #(model, effect.batch([fx, pause_fx, replace_url(model)]))
        }

        _ -> {
          let #(model, fx) = refresh_section_for_test(model)
          #(model, effect.batch([fx, replace_url(model)]))
        }
      }
    }

    ProjectsFetched(Ok(projects)) -> {
      let selected =
        update_helpers.ensure_selected_project(
          model.selected_project_id,
          projects,
        )
      let model =
        Model(
          ..model,
          projects: Loaded(projects),
          selected_project_id: selected,
        )

      let model = update_helpers.ensure_default_section(model)

      case model.page {
        Member -> {
          let #(model, fx) = member_refresh(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
        }

        Admin -> {
          let #(model, fx) = refresh_section_for_test(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([fx, hyd_fx, replace_url(model)]))
        }

        _ -> {
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([hyd_fx, replace_url(model)]))
        }
      }
    }

    ProjectsFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model =
            Model(
              ..model,
              page: Login,
              user: opt.None,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          #(model, replace_url(model))
        }

        False -> #(Model(..model, projects: Failed(err)), effect.none())
      }
    }

    ProjectCreateNameChanged(name) ->
      projects_workflow.handle_project_create_name_changed(model, name)
    ProjectCreateSubmitted ->
      projects_workflow.handle_project_create_submitted(model)
    ProjectCreated(Ok(project)) ->
      projects_workflow.handle_project_created_ok(model, project)
    ProjectCreated(Error(err)) ->
      projects_workflow.handle_project_created_error(model, err)

    InviteLinkEmailChanged(value) ->
      invite_links_workflow.handle_invite_link_email_changed(model, value)
    InviteLinksFetched(Ok(links)) ->
      invite_links_workflow.handle_invite_links_fetched_ok(model, links)
    InviteLinksFetched(Error(err)) ->
      invite_links_workflow.handle_invite_links_fetched_error(model, err)
    InviteLinkCreateSubmitted ->
      invite_links_workflow.handle_invite_link_create_submitted(model)
    InviteLinkRegenerateClicked(email) ->
      invite_links_workflow.handle_invite_link_regenerate_clicked(model, email)
    InviteLinkCreated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_created_ok(model, link)
    InviteLinkCreated(Error(err)) ->
      invite_links_workflow.handle_invite_link_created_error(model, err)
    InviteLinkRegenerated(Ok(link)) ->
      invite_links_workflow.handle_invite_link_regenerated_ok(model, link)
    InviteLinkRegenerated(Error(err)) ->
      invite_links_workflow.handle_invite_link_regenerated_error(model, err)
    InviteLinkCopyClicked(text) ->
      invite_links_workflow.handle_invite_link_copy_clicked(model, text)
    InviteLinkCopyFinished(ok) ->
      invite_links_workflow.handle_invite_link_copy_finished(model, ok)

    CapabilitiesFetched(Ok(capabilities)) ->
      capabilities_workflow.handle_capabilities_fetched_ok(model, capabilities)
    CapabilitiesFetched(Error(err)) ->
      capabilities_workflow.handle_capabilities_fetched_error(model, err)
    CapabilityCreateDialogOpened ->
      capabilities_workflow.handle_capability_dialog_opened(model)
    CapabilityCreateDialogClosed ->
      capabilities_workflow.handle_capability_dialog_closed(model)
    CapabilityCreateNameChanged(name) ->
      capabilities_workflow.handle_capability_create_name_changed(model, name)
    CapabilityCreateSubmitted ->
      capabilities_workflow.handle_capability_create_submitted(model)
    CapabilityCreated(Ok(capability)) ->
      capabilities_workflow.handle_capability_created_ok(model, capability)
    CapabilityCreated(Error(err)) ->
      capabilities_workflow.handle_capability_created_error(model, err)

    MembersFetched(Ok(members)) ->
      admin_workflow.handle_members_fetched_ok(model, members)
    MembersFetched(Error(err)) ->
      admin_workflow.handle_members_fetched_error(model, err)

    OrgUsersCacheFetched(Ok(users)) ->
      admin_workflow.handle_org_users_cache_fetched_ok(model, users)
    OrgUsersCacheFetched(Error(err)) ->
      admin_workflow.handle_org_users_cache_fetched_error(model, err)
    OrgSettingsUsersFetched(Ok(users)) ->
      admin_workflow.handle_org_settings_users_fetched_ok(model, users)

    OrgSettingsUsersFetched(Error(err)) ->
      admin_workflow.handle_org_settings_users_fetched_error(model, err)
    OrgSettingsRoleChanged(user_id, org_role) ->
      admin_workflow.handle_org_settings_role_changed(model, user_id, org_role)
    OrgSettingsSaveClicked(user_id) ->
      admin_workflow.handle_org_settings_save_clicked(model, user_id)
    OrgSettingsSaved(_user_id, Ok(updated)) ->
      admin_workflow.handle_org_settings_saved_ok(model, updated)
    OrgSettingsSaved(user_id, Error(err)) ->
      admin_workflow.handle_org_settings_saved_error(model, user_id, err)

    // User projects dialog handlers
    UserProjectsDialogOpened(user) ->
      admin_workflow.handle_user_projects_dialog_opened(model, user)
    UserProjectsDialogClosed ->
      admin_workflow.handle_user_projects_dialog_closed(model)
    UserProjectsFetched(Ok(projects)) ->
      admin_workflow.handle_user_projects_fetched_ok(model, projects)
    UserProjectsFetched(Error(err)) ->
      admin_workflow.handle_user_projects_fetched_error(model, err)
    UserProjectsAddProjectChanged(project_id) ->
      admin_workflow.handle_user_projects_add_project_changed(model, project_id)
    UserProjectsAddSubmitted ->
      admin_workflow.handle_user_projects_add_submitted(model)
    UserProjectAdded(Ok(project)) ->
      admin_workflow.handle_user_project_added_ok(model, project)
    UserProjectAdded(Error(err)) ->
      admin_workflow.handle_user_project_added_error(model, err)
    UserProjectRemoveClicked(project_id) ->
      admin_workflow.handle_user_project_remove_clicked(model, project_id)
    UserProjectRemoved(Ok(_)) ->
      admin_workflow.handle_user_project_removed_ok(model)
    UserProjectRemoved(Error(err)) ->
      admin_workflow.handle_user_project_removed_error(model, err)

    MemberAddDialogOpened ->
      admin_workflow.handle_member_add_dialog_opened(model)
    MemberAddDialogClosed ->
      admin_workflow.handle_member_add_dialog_closed(model)
    MemberAddRoleChanged(role) ->
      admin_workflow.handle_member_add_role_changed(model, role)
    MemberAddUserSelected(user_id) ->
      admin_workflow.handle_member_add_user_selected(model, user_id)
    MemberAddSubmitted -> admin_workflow.handle_member_add_submitted(model)
    MemberAdded(Ok(_)) ->
      admin_workflow.handle_member_added_ok(model, refresh_section_for_test)
    MemberAdded(Error(err)) ->
      admin_workflow.handle_member_added_error(model, err)

    MemberRemoveClicked(user_id) ->
      admin_workflow.handle_member_remove_clicked(model, user_id)
    MemberRemoveCancelled ->
      admin_workflow.handle_member_remove_cancelled(model)
    MemberRemoveConfirmed ->
      admin_workflow.handle_member_remove_confirmed(model)
    MemberRemoved(Ok(_)) ->
      admin_workflow.handle_member_removed_ok(model, refresh_section_for_test)
    MemberRemoved(Error(err)) ->
      admin_workflow.handle_member_removed_error(model, err)

    OrgUsersSearchChanged(query) ->
      admin_workflow.handle_org_users_search_changed(model, query)

    OrgUsersSearchDebounced(query) ->
      admin_workflow.handle_org_users_search_debounced(model, query)
    OrgUsersSearchResults(token, Ok(users)) ->
      admin_workflow.handle_org_users_search_results_ok(model, token, users)
    OrgUsersSearchResults(token, Error(err)) ->
      admin_workflow.handle_org_users_search_results_error(model, token, err)

    TaskTypesFetched(Ok(task_types)) ->
      task_types_workflow.handle_task_types_fetched_ok(model, task_types)
    TaskTypesFetched(Error(err)) ->
      task_types_workflow.handle_task_types_fetched_error(model, err)
    TaskTypeCreateDialogOpened ->
      task_types_workflow.handle_task_type_dialog_opened(model)
    TaskTypeCreateDialogClosed ->
      task_types_workflow.handle_task_type_dialog_closed(model)
    TaskTypeCreateNameChanged(name) ->
      task_types_workflow.handle_task_type_create_name_changed(model, name)
    TaskTypeCreateIconChanged(icon) ->
      task_types_workflow.handle_task_type_create_icon_changed(model, icon)
    TaskTypeIconLoaded ->
      task_types_workflow.handle_task_type_icon_loaded(model)
    TaskTypeIconErrored ->
      task_types_workflow.handle_task_type_icon_errored(model)
    TaskTypeCreateCapabilityChanged(value) ->
      task_types_workflow.handle_task_type_create_capability_changed(
        model,
        value,
      )
    TaskTypeCreateSubmitted ->
      task_types_workflow.handle_task_type_create_submitted(model)
    TaskTypeCreated(Ok(_)) ->
      task_types_workflow.handle_task_type_created_ok(
        model,
        refresh_section_for_test,
      )
    TaskTypeCreated(Error(err)) ->
      task_types_workflow.handle_task_type_created_error(model, err)

    MemberPoolStatusChanged(v) ->
      pool_workflow.handle_pool_status_changed(model, v, member_refresh)
    MemberPoolTypeChanged(v) ->
      pool_workflow.handle_pool_type_changed(model, v, member_refresh)
    MemberPoolCapabilityChanged(v) ->
      pool_workflow.handle_pool_capability_changed(model, v, member_refresh)

    MemberToggleMyCapabilitiesQuick ->
      pool_workflow.handle_toggle_my_capabilities_quick(model)
    MemberPoolFiltersToggled -> pool_workflow.handle_pool_filters_toggled(model)
    MemberPoolViewModeSet(mode) ->
      pool_workflow.handle_pool_view_mode_set(model, mode)
    MemberPanelToggled ->
      #(Model(..model, member_panel_expanded: !model.member_panel_expanded), effect.none())
    GlobalKeyDown(event) -> pool_workflow.handle_global_keydown(model, event)

    MemberPoolSearchChanged(v) ->
      pool_workflow.handle_pool_search_changed(model, v)
    MemberPoolSearchDebounced(v) ->
      pool_workflow.handle_pool_search_debounced(model, v, member_refresh)

    MemberProjectTasksFetched(project_id, Ok(tasks)) -> {
      let tasks_by_project =
        dict.insert(model.member_tasks_by_project, project_id, tasks)
      let pending = model.member_tasks_pending - 1

      let model =
        Model(
          ..model,
          member_tasks_by_project: tasks_by_project,
          member_tasks_pending: pending,
        )

      case pending <= 0 {
        True -> #(
          Model(
            ..model,
            member_tasks: Loaded(update_helpers.flatten_tasks(tasks_by_project)),
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    MemberProjectTasksFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(
          Model(..model, member_tasks: Failed(err), member_tasks_pending: 0),
          effect.none(),
        )
      }
    }

    MemberTaskTypesFetched(project_id, Ok(task_types)) -> {
      let task_types_by_project =
        dict.insert(model.member_task_types_by_project, project_id, task_types)
      let pending = model.member_task_types_pending - 1

      let model =
        Model(
          ..model,
          member_task_types_by_project: task_types_by_project,
          member_task_types_pending: pending,
        )

      case pending <= 0 {
        True -> #(
          Model(
            ..model,
            member_task_types: Loaded(update_helpers.flatten_task_types(
              task_types_by_project,
            )),
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }

    MemberTaskTypesFetched(_project_id, Error(err)) -> {
      case err.status {
        401 -> #(
          Model(
            ..model,
            page: Login,
            user: opt.None,
            member_drag: opt.None,
            member_pool_drag_to_claim_armed: False,
            member_pool_drag_over_my_tasks: False,
          ),
          effect.none(),
        )
        _ -> #(
          Model(
            ..model,
            member_task_types: Failed(err),
            member_task_types_pending: 0,
          ),
          effect.none(),
        )
      }
    }

    MemberCanvasRectFetched(left, top) ->
      pool_workflow.handle_canvas_rect_fetched(model, left, top)
    MemberDragStarted(task_id, offset_x, offset_y) ->
      pool_workflow.handle_drag_started(model, task_id, offset_x, offset_y)
    MemberDragMoved(client_x, client_y) ->
      pool_workflow.handle_drag_moved(model, client_x, client_y)
    MemberDragEnded -> pool_workflow.handle_drag_ended(model)

    MemberCreateDialogOpened ->
      tasks_workflow.handle_create_dialog_opened(model)
    MemberCreateDialogClosed ->
      tasks_workflow.handle_create_dialog_closed(model)
    MemberCreateTitleChanged(v) ->
      tasks_workflow.handle_create_title_changed(model, v)
    MemberCreateDescriptionChanged(v) ->
      tasks_workflow.handle_create_description_changed(model, v)
    MemberCreatePriorityChanged(v) ->
      tasks_workflow.handle_create_priority_changed(model, v)
    MemberCreateTypeIdChanged(v) ->
      tasks_workflow.handle_create_type_id_changed(model, v)

    MemberCreateSubmitted ->
      tasks_workflow.handle_create_submitted(model, member_refresh)

    MemberTaskCreated(Ok(_)) ->
      tasks_workflow.handle_task_created_ok(model, member_refresh)
    MemberTaskCreated(Error(err)) ->
      tasks_workflow.handle_task_created_error(model, err)

    MemberClaimClicked(task_id, version) ->
      tasks_workflow.handle_claim_clicked(model, task_id, version)
    MemberReleaseClicked(task_id, version) ->
      tasks_workflow.handle_release_clicked(model, task_id, version)
    MemberCompleteClicked(task_id, version) ->
      tasks_workflow.handle_complete_clicked(model, task_id, version)

    MemberTaskClaimed(Ok(_)) ->
      tasks_workflow.handle_task_claimed_ok(model, member_refresh)
    MemberTaskReleased(Ok(_)) ->
      tasks_workflow.handle_task_released_ok(model, member_refresh)
    MemberTaskCompleted(Ok(_)) ->
      tasks_workflow.handle_task_completed_ok(model, member_refresh)

    MemberTaskClaimed(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    MemberTaskReleased(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)
    MemberTaskCompleted(Error(err)) ->
      tasks_workflow.handle_mutation_error(model, err, member_refresh)

    MemberNowWorkingStartClicked(task_id) ->
      now_working_workflow.handle_start_clicked(model, task_id)
    MemberNowWorkingPauseClicked ->
      now_working_workflow.handle_pause_clicked(model)

    MemberActiveTaskFetched(Ok(payload)) ->
      now_working_workflow.handle_fetched_ok(model, payload)
    MemberActiveTaskFetched(Error(err)) ->
      now_working_workflow.handle_fetched_error(model, err)

    MemberActiveTaskStarted(Ok(payload)) ->
      now_working_workflow.handle_started_ok(model, payload)
    MemberActiveTaskStarted(Error(err)) ->
      now_working_workflow.handle_started_error(model, err)

    MemberActiveTaskPaused(Ok(payload)) ->
      now_working_workflow.handle_paused_ok(model, payload)
    MemberActiveTaskPaused(Error(err)) ->
      now_working_workflow.handle_paused_error(model, err)

    MemberActiveTaskHeartbeated(Ok(payload)) ->
      now_working_workflow.handle_heartbeated_ok(model, payload)
    MemberActiveTaskHeartbeated(Error(err)) ->
      now_working_workflow.handle_heartbeated_error(model, err)

    // Work sessions (multi-session) - delegate to workflow
    MemberWorkSessionsFetched(Ok(payload)) ->
      now_working_workflow.handle_sessions_fetched_ok(model, payload)
    MemberWorkSessionsFetched(Error(err)) ->
      now_working_workflow.handle_sessions_fetched_error(model, err)

    MemberWorkSessionStarted(Ok(payload)) ->
      now_working_workflow.handle_session_started_ok(model, payload)
    MemberWorkSessionStarted(Error(err)) ->
      now_working_workflow.handle_session_started_error(model, err)

    MemberWorkSessionPaused(Ok(payload)) ->
      now_working_workflow.handle_session_paused_ok(model, payload)
    MemberWorkSessionPaused(Error(err)) ->
      now_working_workflow.handle_session_paused_error(model, err)

    MemberWorkSessionHeartbeated(Ok(payload)) ->
      now_working_workflow.handle_session_heartbeated_ok(model, payload)
    MemberWorkSessionHeartbeated(Error(err)) ->
      now_working_workflow.handle_session_heartbeated_error(model, err)

    MemberMetricsFetched(Ok(metrics)) ->
      metrics_workflow.handle_member_metrics_fetched_ok(model, metrics)
    MemberMetricsFetched(Error(err)) ->
      metrics_workflow.handle_member_metrics_fetched_error(model, err)

    AdminMetricsOverviewFetched(Ok(overview)) ->
      metrics_workflow.handle_admin_overview_fetched_ok(model, overview)
    AdminMetricsOverviewFetched(Error(err)) ->
      metrics_workflow.handle_admin_overview_fetched_error(model, err)

    AdminMetricsProjectTasksFetched(Ok(payload)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_ok(model, payload)
    AdminMetricsProjectTasksFetched(Error(err)) ->
      metrics_workflow.handle_admin_project_tasks_fetched_error(model, err)

    // Rule metrics tab
    AdminRuleMetricsFetched(Ok(metrics)) ->
      admin_workflow.handle_rule_metrics_tab_fetched_ok(model, metrics)
    AdminRuleMetricsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_tab_fetched_error(model, err)
    AdminRuleMetricsFromChanged(from) ->
      admin_workflow.handle_rule_metrics_tab_from_changed(model, from)
    AdminRuleMetricsToChanged(to) ->
      admin_workflow.handle_rule_metrics_tab_to_changed(model, to)
    AdminRuleMetricsRefreshClicked ->
      admin_workflow.handle_rule_metrics_tab_refresh_clicked(model)
    // Rule metrics drill-down
    AdminRuleMetricsWorkflowExpanded(workflow_id) ->
      admin_workflow.handle_rule_metrics_workflow_expanded(model, workflow_id)
    AdminRuleMetricsWorkflowDetailsFetched(Ok(details)) ->
      admin_workflow.handle_rule_metrics_workflow_details_fetched_ok(
        model,
        details,
      )
    AdminRuleMetricsWorkflowDetailsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_workflow_details_fetched_error(
        model,
        err,
      )
    AdminRuleMetricsDrilldownClicked(rule_id) ->
      admin_workflow.handle_rule_metrics_drilldown_clicked(model, rule_id)
    AdminRuleMetricsDrilldownClosed ->
      admin_workflow.handle_rule_metrics_drilldown_closed(model)
    AdminRuleMetricsRuleDetailsFetched(Ok(details)) ->
      admin_workflow.handle_rule_metrics_rule_details_fetched_ok(model, details)
    AdminRuleMetricsRuleDetailsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_rule_details_fetched_error(model, err)
    AdminRuleMetricsExecutionsFetched(Ok(response)) ->
      admin_workflow.handle_rule_metrics_executions_fetched_ok(model, response)
    AdminRuleMetricsExecutionsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_executions_fetched_error(model, err)
    AdminRuleMetricsExecPageChanged(offset) ->
      admin_workflow.handle_rule_metrics_exec_page_changed(model, offset)

    NowWorkingTicked -> now_working_workflow.handle_ticked(model)

    MemberMyCapabilityIdsFetched(Ok(ids)) ->
      skills_workflow.handle_my_capability_ids_fetched_ok(model, ids)
    MemberMyCapabilityIdsFetched(Error(err)) ->
      skills_workflow.handle_my_capability_ids_fetched_error(model, err)

    MemberToggleCapability(id) ->
      skills_workflow.handle_toggle_capability(model, id)
    MemberSaveCapabilitiesClicked ->
      skills_workflow.handle_save_capabilities_clicked(model)

    MemberMyCapabilityIdsSaved(Ok(ids)) ->
      skills_workflow.handle_save_capabilities_ok(model, ids)
    MemberMyCapabilityIdsSaved(Error(err)) ->
      skills_workflow.handle_save_capabilities_error(model, err)

    MemberPositionsFetched(Ok(positions)) ->
      pool_workflow.handle_positions_fetched_ok(model, positions)
    MemberPositionsFetched(Error(err)) ->
      pool_workflow.handle_positions_fetched_error(model, err)

    MemberPositionEditOpened(task_id) ->
      pool_workflow.handle_position_edit_opened(model, task_id)
    MemberPositionEditClosed -> pool_workflow.handle_position_edit_closed(model)
    MemberPositionEditXChanged(v) ->
      pool_workflow.handle_position_edit_x_changed(model, v)
    MemberPositionEditYChanged(v) ->
      pool_workflow.handle_position_edit_y_changed(model, v)
    MemberPositionEditSubmitted ->
      pool_workflow.handle_position_edit_submitted(model)

    MemberPositionSaved(Ok(pos)) ->
      pool_workflow.handle_position_saved_ok(model, pos)
    MemberPositionSaved(Error(err)) ->
      pool_workflow.handle_position_saved_error(model, err)

    MemberTaskDetailsOpened(task_id) ->
      tasks_workflow.handle_task_details_opened(model, task_id)
    MemberTaskDetailsClosed -> tasks_workflow.handle_task_details_closed(model)

    MemberNotesFetched(Ok(notes)) ->
      tasks_workflow.handle_notes_fetched_ok(model, notes)
    MemberNotesFetched(Error(err)) ->
      tasks_workflow.handle_notes_fetched_error(model, err)

    MemberNoteContentChanged(v) ->
      tasks_workflow.handle_note_content_changed(model, v)
    MemberNoteSubmitted -> tasks_workflow.handle_note_submitted(model)

    MemberNoteAdded(Ok(note)) ->
      tasks_workflow.handle_note_added_ok(model, note)
    MemberNoteAdded(Error(err)) ->
      tasks_workflow.handle_note_added_error(model, err)

    // Cards (Fichas) handlers
    CardsFetched(Ok(cards)) ->
      admin_workflow.handle_cards_fetched_ok(model, cards)
    CardsFetched(Error(err)) ->
      admin_workflow.handle_cards_fetched_error(model, err)
    CardCreateDialogOpened ->
      admin_workflow.handle_card_create_dialog_opened(model)
    CardCreateDialogClosed ->
      admin_workflow.handle_card_create_dialog_closed(model)

    CardCreateTitleChanged(title) ->
      admin_workflow.handle_card_create_title_changed(model, title)
    CardCreateDescriptionChanged(description) ->
      admin_workflow.handle_card_create_description_changed(model, description)
    CardCreateColorChanged(color) ->
      admin_workflow.handle_card_create_color_changed(model, color)
    CardCreateColorToggle ->
      admin_workflow.handle_card_create_color_toggle(model)
    CardCreateSubmitted -> admin_workflow.handle_card_create_submitted(model)
    CardCreated(Ok(card)) -> admin_workflow.handle_card_created_ok(model, card)
    CardCreated(Error(err)) ->
      admin_workflow.handle_card_created_error(model, err)

    CardEditClicked(card) ->
      admin_workflow.handle_card_edit_clicked(model, card)
    CardEditTitleChanged(title) ->
      admin_workflow.handle_card_edit_title_changed(model, title)
    CardEditDescriptionChanged(description) ->
      admin_workflow.handle_card_edit_description_changed(model, description)
    CardEditColorChanged(color) ->
      admin_workflow.handle_card_edit_color_changed(model, color)
    CardEditColorToggle -> admin_workflow.handle_card_edit_color_toggle(model)
    CardEditSubmitted -> admin_workflow.handle_card_edit_submitted(model)
    CardEditCancelled -> admin_workflow.handle_card_edit_cancelled(model)
    CardUpdated(Ok(card)) -> admin_workflow.handle_card_updated_ok(model, card)
    CardUpdated(Error(err)) ->
      admin_workflow.handle_card_updated_error(model, err)

    CardDeleteClicked(card) ->
      admin_workflow.handle_card_delete_clicked(model, card)
    CardDeleteCancelled -> admin_workflow.handle_card_delete_cancelled(model)
    CardDeleteConfirmed -> admin_workflow.handle_card_delete_confirmed(model)
    CardDeleted(Ok(_)) -> admin_workflow.handle_card_deleted_ok(model)
    CardDeleted(Error(err)) ->
      admin_workflow.handle_card_deleted_error(model, err)

    // Card detail (member view) handlers
    OpenCardDetail(card_id) ->
      #(Model(..model, card_detail_open: opt.Some(card_id)), effect.none())
    CloseCardDetail ->
      #(
        Model(
          ..model,
          card_detail_open: opt.None,
          card_detail_tasks: NotAsked,
          card_add_task_open: False,
          card_add_task_title: "",
          card_add_task_priority: 3,
        ),
        effect.none(),
      )
    CardDetailTasksFetched(Ok(tasks)) ->
      #(Model(..model, card_detail_tasks: Loaded(tasks)), effect.none())
    CardDetailTasksFetched(Error(err)) ->
      #(Model(..model, card_detail_tasks: Failed(err)), effect.none())
    ToggleAddTaskForm ->
      #(Model(..model, card_add_task_open: !model.card_add_task_open), effect.none())
    CardAddTaskTitleInput(title) ->
      #(Model(..model, card_add_task_title: title), effect.none())
    CardAddTaskPrioritySelect(priority) ->
      #(Model(..model, card_add_task_priority: priority), effect.none())
    CancelAddTask ->
      #(
        Model(
          ..model,
          card_add_task_open: False,
          card_add_task_title: "",
          card_add_task_priority: 3,
        ),
        effect.none(),
      )
    SubmitAddTask ->
      handle_card_add_task_submit(model, member_refresh)
    CardAddTaskCreated(Ok(_task)) ->
      #(
        Model(
          ..model,
          card_add_task_in_flight: False,
          card_add_task_open: False,
          card_add_task_title: "",
          card_add_task_priority: 3,
        ),
        effect.none(),
      )
    CardAddTaskCreated(Error(err)) ->
      #(
        Model(
          ..model,
          card_add_task_in_flight: False,
          card_add_task_error: opt.Some(err.message),
        ),
        effect.none(),
      )

    // Workflows handlers
    WorkflowsOrgFetched(Ok(workflows)) ->
      admin_workflow.handle_workflows_org_fetched_ok(model, workflows)
    WorkflowsOrgFetched(Error(err)) ->
      admin_workflow.handle_workflows_org_fetched_error(model, err)
    WorkflowsProjectFetched(Ok(workflows)) ->
      admin_workflow.handle_workflows_project_fetched_ok(model, workflows)
    WorkflowsProjectFetched(Error(err)) ->
      admin_workflow.handle_workflows_project_fetched_error(model, err)
    WorkflowCreateDialogOpened ->
      admin_workflow.handle_workflow_create_dialog_opened(model)
    WorkflowCreateDialogClosed ->
      admin_workflow.handle_workflow_create_dialog_closed(model)

    WorkflowCreateNameChanged(name) ->
      admin_workflow.handle_workflow_create_name_changed(model, name)
    WorkflowCreateDescriptionChanged(description) ->
      admin_workflow.handle_workflow_create_description_changed(
        model,
        description,
      )
    WorkflowCreateActiveChanged(active) ->
      admin_workflow.handle_workflow_create_active_changed(model, active)
    WorkflowCreateSubmitted ->
      admin_workflow.handle_workflow_create_submitted(model)
    WorkflowCreated(Ok(workflow)) ->
      admin_workflow.handle_workflow_created_ok(model, workflow)
    WorkflowCreated(Error(err)) ->
      admin_workflow.handle_workflow_created_error(model, err)

    WorkflowEditClicked(workflow) ->
      admin_workflow.handle_workflow_edit_clicked(model, workflow)
    WorkflowEditNameChanged(name) ->
      admin_workflow.handle_workflow_edit_name_changed(model, name)
    WorkflowEditDescriptionChanged(description) ->
      admin_workflow.handle_workflow_edit_description_changed(
        model,
        description,
      )
    WorkflowEditActiveChanged(active) ->
      admin_workflow.handle_workflow_edit_active_changed(model, active)
    WorkflowEditSubmitted ->
      admin_workflow.handle_workflow_edit_submitted(model)
    WorkflowEditCancelled ->
      admin_workflow.handle_workflow_edit_cancelled(model)
    WorkflowUpdated(Ok(workflow)) ->
      admin_workflow.handle_workflow_updated_ok(model, workflow)
    WorkflowUpdated(Error(err)) ->
      admin_workflow.handle_workflow_updated_error(model, err)

    WorkflowDeleteClicked(workflow) ->
      admin_workflow.handle_workflow_delete_clicked(model, workflow)
    WorkflowDeleteCancelled ->
      admin_workflow.handle_workflow_delete_cancelled(model)
    WorkflowDeleteConfirmed ->
      admin_workflow.handle_workflow_delete_confirmed(model)
    WorkflowDeleted(Ok(_)) -> admin_workflow.handle_workflow_deleted_ok(model)
    WorkflowDeleted(Error(err)) ->
      admin_workflow.handle_workflow_deleted_error(model, err)

    WorkflowRulesClicked(workflow_id) ->
      admin_workflow.handle_workflow_rules_clicked(model, workflow_id)

    // Rules handlers
    RulesFetched(Ok(rules)) ->
      admin_workflow.handle_rules_fetched_ok(model, rules)
    RulesFetched(Error(err)) ->
      admin_workflow.handle_rules_fetched_error(model, err)
    RulesBackClicked -> admin_workflow.handle_rules_back_clicked(model)
    RuleMetricsFetched(Ok(metrics)) ->
      admin_workflow.handle_rule_metrics_fetched_ok(model, metrics)
    RuleMetricsFetched(Error(err)) ->
      admin_workflow.handle_rule_metrics_fetched_error(model, err)
    RuleCreateDialogOpened ->
      admin_workflow.handle_rule_create_dialog_opened(model)
    RuleCreateDialogClosed ->
      admin_workflow.handle_rule_create_dialog_closed(model)

    RuleCreateNameChanged(name) ->
      admin_workflow.handle_rule_create_name_changed(model, name)
    RuleCreateGoalChanged(goal) ->
      admin_workflow.handle_rule_create_goal_changed(model, goal)
    RuleCreateResourceTypeChanged(resource_type) ->
      admin_workflow.handle_rule_create_resource_type_changed(
        model,
        resource_type,
      )
    RuleCreateTaskTypeIdChanged(task_type_id) ->
      admin_workflow.handle_rule_create_task_type_id_changed(
        model,
        task_type_id,
      )
    RuleCreateToStateChanged(to_state) ->
      admin_workflow.handle_rule_create_to_state_changed(model, to_state)
    RuleCreateActiveChanged(active) ->
      admin_workflow.handle_rule_create_active_changed(model, active)
    RuleCreateSubmitted -> admin_workflow.handle_rule_create_submitted(model)
    RuleCreated(Ok(rule)) -> admin_workflow.handle_rule_created_ok(model, rule)
    RuleCreated(Error(err)) ->
      admin_workflow.handle_rule_created_error(model, err)

    RuleEditClicked(rule) ->
      admin_workflow.handle_rule_edit_clicked(model, rule)
    RuleEditNameChanged(name) ->
      admin_workflow.handle_rule_edit_name_changed(model, name)
    RuleEditGoalChanged(goal) ->
      admin_workflow.handle_rule_edit_goal_changed(model, goal)
    RuleEditResourceTypeChanged(resource_type) ->
      admin_workflow.handle_rule_edit_resource_type_changed(
        model,
        resource_type,
      )
    RuleEditTaskTypeIdChanged(task_type_id) ->
      admin_workflow.handle_rule_edit_task_type_id_changed(model, task_type_id)
    RuleEditToStateChanged(to_state) ->
      admin_workflow.handle_rule_edit_to_state_changed(model, to_state)
    RuleEditActiveChanged(active) ->
      admin_workflow.handle_rule_edit_active_changed(model, active)
    RuleEditSubmitted -> admin_workflow.handle_rule_edit_submitted(model)
    RuleEditCancelled -> admin_workflow.handle_rule_edit_cancelled(model)
    RuleUpdated(Ok(rule)) -> admin_workflow.handle_rule_updated_ok(model, rule)
    RuleUpdated(Error(err)) ->
      admin_workflow.handle_rule_updated_error(model, err)

    RuleDeleteClicked(rule) ->
      admin_workflow.handle_rule_delete_clicked(model, rule)
    RuleDeleteCancelled -> admin_workflow.handle_rule_delete_cancelled(model)
    RuleDeleteConfirmed -> admin_workflow.handle_rule_delete_confirmed(model)
    RuleDeleted(Ok(_)) -> admin_workflow.handle_rule_deleted_ok(model)
    RuleDeleted(Error(err)) ->
      admin_workflow.handle_rule_deleted_error(model, err)

    // Rule templates handlers
    RuleTemplatesClicked(_rule_id) -> #(model, effect.none())
    RuleTemplatesFetched(Ok(templates)) ->
      admin_workflow.handle_rule_templates_fetched_ok(model, templates)
    RuleTemplatesFetched(Error(err)) ->
      admin_workflow.handle_rule_templates_fetched_error(model, err)
    RuleAttachTemplateSelected(template_id) ->
      admin_workflow.handle_rule_attach_template_selected(model, template_id)
    RuleAttachTemplateSubmitted -> #(model, effect.none())
    RuleTemplateAttached(Ok(templates)) ->
      admin_workflow.handle_rule_template_attached_ok(model, templates)
    RuleTemplateAttached(Error(err)) ->
      admin_workflow.handle_rule_template_attached_error(model, err)
    RuleTemplateDetachClicked(_template_id) -> #(model, effect.none())
    RuleTemplateDetached(Ok(_)) -> #(model, effect.none())
    RuleTemplateDetached(Error(err)) ->
      admin_workflow.handle_rule_template_detached_error(model, err)

    // Task templates handlers
    TaskTemplatesOrgFetched(Ok(templates)) ->
      admin_workflow.handle_task_templates_org_fetched_ok(model, templates)
    TaskTemplatesOrgFetched(Error(err)) ->
      admin_workflow.handle_task_templates_org_fetched_error(model, err)
    TaskTemplatesProjectFetched(Ok(templates)) ->
      admin_workflow.handle_task_templates_project_fetched_ok(model, templates)
    TaskTemplatesProjectFetched(Error(err)) ->
      admin_workflow.handle_task_templates_project_fetched_error(model, err)
    TaskTemplateCreateDialogOpened ->
      admin_workflow.handle_task_template_create_dialog_opened(model)
    TaskTemplateCreateDialogClosed ->
      admin_workflow.handle_task_template_create_dialog_closed(model)

    TaskTemplateCreateNameChanged(name) ->
      admin_workflow.handle_task_template_create_name_changed(model, name)
    TaskTemplateCreateDescriptionChanged(description) ->
      admin_workflow.handle_task_template_create_description_changed(
        model,
        description,
      )
    TaskTemplateCreateTypeIdChanged(type_id) ->
      admin_workflow.handle_task_template_create_type_id_changed(model, type_id)
    TaskTemplateCreatePriorityChanged(priority) ->
      admin_workflow.handle_task_template_create_priority_changed(
        model,
        priority,
      )
    TaskTemplateCreateSubmitted ->
      admin_workflow.handle_task_template_create_submitted(model)
    TaskTemplateCreated(Ok(template)) ->
      admin_workflow.handle_task_template_created_ok(model, template)
    TaskTemplateCreated(Error(err)) ->
      admin_workflow.handle_task_template_created_error(model, err)

    TaskTemplateEditClicked(template) ->
      admin_workflow.handle_task_template_edit_clicked(model, template)
    TaskTemplateEditNameChanged(name) ->
      admin_workflow.handle_task_template_edit_name_changed(model, name)
    TaskTemplateEditDescriptionChanged(description) ->
      admin_workflow.handle_task_template_edit_description_changed(
        model,
        description,
      )
    TaskTemplateEditTypeIdChanged(type_id) ->
      admin_workflow.handle_task_template_edit_type_id_changed(model, type_id)
    TaskTemplateEditPriorityChanged(priority) ->
      admin_workflow.handle_task_template_edit_priority_changed(model, priority)
    TaskTemplateEditSubmitted ->
      admin_workflow.handle_task_template_edit_submitted(model)
    TaskTemplateEditCancelled ->
      admin_workflow.handle_task_template_edit_cancelled(model)
    TaskTemplateUpdated(Ok(template)) ->
      admin_workflow.handle_task_template_updated_ok(model, template)
    TaskTemplateUpdated(Error(err)) ->
      admin_workflow.handle_task_template_updated_error(model, err)

    TaskTemplateDeleteClicked(template) ->
      admin_workflow.handle_task_template_delete_clicked(model, template)
    TaskTemplateDeleteCancelled ->
      admin_workflow.handle_task_template_delete_cancelled(model)
    TaskTemplateDeleteConfirmed ->
      admin_workflow.handle_task_template_delete_confirmed(model)
    TaskTemplateDeleted(Ok(_)) ->
      admin_workflow.handle_task_template_deleted_ok(model)
    TaskTemplateDeleted(Error(err)) ->
      admin_workflow.handle_task_template_deleted_error(model, err)
  }
}

// =============================================================================
// Card Add Task Handler
// =============================================================================

/// Handle card add task form submission.
/// Validates input and creates task with card_id association.
fn handle_card_add_task_submit(
  model: Model,
  member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  // Guard: already in flight
  case model.card_add_task_in_flight {
    True -> #(model, effect.none())
    False -> validate_and_create_card_task(model, member_refresh)
  }
}

fn validate_and_create_card_task(
  model: Model,
  _member_refresh: fn(Model) -> #(Model, Effect(Msg)),
) -> #(Model, Effect(Msg)) {
  // Get card_id from open card detail
  case model.card_detail_open {
    opt.None -> #(model, effect.none())
    opt.Some(card_id) -> {
      // Find the card to get project_id
      case find_card_by_id(model, card_id) {
        opt.None ->
          #(
            Model(
              ..model,
              card_add_task_error: opt.Some(
                update_helpers.i18n_t(model, i18n_text.SelectProjectFirst),
              ),
            ),
            effect.none(),
          )
        opt.Some(card) -> validate_card_task_title(model, card)
      }
    }
  }
}

fn find_card_by_id(model: Model, card_id: Int) -> opt.Option(domain_card.Card) {
  case model.cards {
    client_state.Loaded(cards) ->
      list.find(cards, fn(c) { c.id == card_id })
      |> opt.from_result
    _ -> opt.None
  }
}

fn validate_card_task_title(
  model: Model,
  card: domain_card.Card,
) -> #(Model, Effect(Msg)) {
  let title = string.trim(model.card_add_task_title)
  case title == "" {
    True ->
      #(
        Model(
          ..model,
          card_add_task_error: opt.Some(
            update_helpers.i18n_t(model, i18n_text.TitleRequired),
          ),
        ),
        effect.none(),
      )
    False -> get_default_type_and_create(model, card, title)
  }
}

fn get_default_type_and_create(
  model: Model,
  card: domain_card.Card,
  title: String,
) -> #(Model, Effect(Msg)) {
  // Get task types for this project
  let types_for_project =
    dict.get(model.member_task_types_by_project, card.project_id)

  case types_for_project {
    Error(_) ->
      #(
        Model(
          ..model,
          card_add_task_error: opt.Some(
            update_helpers.i18n_t(model, i18n_text.TypeRequired),
          ),
        ),
        effect.none(),
      )
    Ok(types) ->
      case list.first(types) {
        Error(_) ->
          #(
            Model(
              ..model,
              card_add_task_error: opt.Some(
                update_helpers.i18n_t(model, i18n_text.TypeRequired),
              ),
            ),
            effect.none(),
          )
        Ok(first_type) ->
          submit_card_task(model, card, title, first_type.id)
      }
  }
}

fn submit_card_task(
  model: Model,
  card: domain_card.Card,
  title: String,
  type_id: Int,
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      ..model,
      card_add_task_in_flight: True,
      card_add_task_error: opt.None,
    )

  #(
    model,
    api_tasks.create_task_with_card(
      card.project_id,
      title,
      opt.None,
      model.card_add_task_priority,
      type_id,
      opt.Some(card.id),
      client_state.CardAddTaskCreated,
    ),
  )
}
