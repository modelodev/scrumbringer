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

import domain/org_role
import domain/project_role.{Member as MemberRole}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import lustre/effect.{type Effect}

import scrumbringer_client/accept_invite
import scrumbringer_client/app/effects as app_effects

// API modules
import scrumbringer_client/api/auth as api_auth
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/metrics as api_metrics
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/card
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
import scrumbringer_client/ui/toast

import scrumbringer_client/client_state.{
  type Model, type Msg, type NavMode, type Remote,
  AcceptInvite as AcceptInvitePage, AcceptInviteMsg, Admin,
  AdminMetricsOverviewFetched, AdminMetricsProjectTasksFetched, AdminModel,
  AdminMsg, AdminRuleMetricsDrilldownClicked, AdminRuleMetricsDrilldownClosed,
  AdminRuleMetricsExecPageChanged, AdminRuleMetricsExecutionsFetched,
  AdminRuleMetricsFetched, AdminRuleMetricsFromChanged,
  AdminRuleMetricsFromChangedAndRefresh, AdminRuleMetricsQuickRangeClicked,
  AdminRuleMetricsRefreshClicked, AdminRuleMetricsRuleDetailsFetched,
  AdminRuleMetricsToChanged, AdminRuleMetricsToChangedAndRefresh,
  AdminRuleMetricsWorkflowDetailsFetched, AdminRuleMetricsWorkflowExpanded,
  AttachTemplateFailed, AttachTemplateModalClosed, AttachTemplateModalOpened,
  AttachTemplateSelected, AttachTemplateSubmitted, AttachTemplateSucceeded,
  AuthModel, AuthMsg, CapabilitiesFetched, CapabilityCreateDialogClosed,
  CapabilityCreateDialogOpened, CapabilityCreateNameChanged,
  CapabilityCreateSubmitted, CapabilityCreated, CapabilityDeleteDialogClosed,
  CapabilityDeleteDialogOpened, CapabilityDeleteSubmitted, CapabilityDeleted,
  CapabilityMembersDialogClosed, CapabilityMembersDialogOpened,
  CapabilityMembersFetched, CapabilityMembersSaveClicked, CapabilityMembersSaved,
  CapabilityMembersToggled, CardCrudCreated, CardCrudDeleted, CardCrudUpdated,
  CardsFetched, CardsSearchChanged, CardsShowCompletedToggled,
  CardsShowEmptyToggled, CardsStateFilterChanged, CloseCardDetail,
  CloseCardDialog, CloseRuleDialog, CloseTaskTemplateDialog, CloseTaskTypeDialog,
  CloseWorkflowDialog, CoreModel, Failed, GlobalKeyDown,
  InviteCreateDialogClosed, InviteCreateDialogOpened, InviteLinkCopyClicked,
  InviteLinkCopyFinished, InviteLinkCreateSubmitted, InviteLinkCreated,
  InviteLinkEmailChanged, InviteLinkRegenerateClicked, InviteLinkRegenerated,
  InviteLinksFetched, Loaded, Loading, LocaleSelected, Login, MeFetched, Member,
  MemberActiveTaskFetched, MemberActiveTaskHeartbeated, MemberActiveTaskPaused,
  MemberActiveTaskStarted, MemberAddDialogClosed, MemberAddDialogOpened,
  MemberAddRoleChanged, MemberAddSubmitted, MemberAddUserSelected, MemberAdded,
  MemberCanvasRectFetched, MemberCapabilitiesDialogClosed,
  MemberCapabilitiesDialogOpened, MemberCapabilitiesFetched,
  MemberCapabilitiesSaveClicked, MemberCapabilitiesSaved,
  MemberCapabilitiesToggled, MemberClaimClicked, MemberClearFilters,
  MemberCompleteClicked, MemberCreateDescriptionChanged,
  MemberCreateDialogClosed, MemberCreateDialogOpened,
  MemberCreatePriorityChanged, MemberCreateSubmitted, MemberCreateTitleChanged,
  MemberCreateTypeIdChanged, MemberDragEnded, MemberDragMoved, MemberDragStarted,
  MemberListCardToggled, MemberListHideCompletedToggled, MemberMetricsFetched,
  MemberModel, MemberMyCapabilityIdsFetched, MemberMyCapabilityIdsSaved,
  MemberNoteAdded, MemberNoteContentChanged, MemberNoteSubmitted,
  MemberNotesFetched, MemberNowWorkingPauseClicked, MemberNowWorkingStartClicked,
  MemberPanelToggled, MemberPoolCapabilityChanged, MemberPoolDragToClaimArmed,
  MemberPoolFiltersToggled, MemberPoolMyTasksRectFetched,
  MemberPoolSearchChanged, MemberPoolSearchDebounced, MemberPoolStatusChanged,
  MemberPoolTypeChanged, MemberPoolViewModeSet, MemberPositionEditClosed,
  MemberPositionEditOpened, MemberPositionEditSubmitted,
  MemberPositionEditXChanged, MemberPositionEditYChanged, MemberPositionSaved,
  MemberPositionsFetched, MemberProjectTasksFetched, MemberReleaseClicked,
  MemberRemoveCancelled, MemberRemoveClicked, MemberRemoveConfirmed,
  MemberRemoved, MemberRoleChangeRequested, MemberRoleChanged,
  MemberSaveCapabilitiesClicked, MemberTaskClaimed, MemberTaskCompleted,
  MemberTaskCreated, MemberTaskDetailsClosed, MemberTaskDetailsOpened,
  MemberTaskReleased, MemberTaskTypesFetched, MemberToggleCapability,
  MemberToggleMyCapabilitiesQuick, MemberWorkSessionHeartbeated,
  MemberWorkSessionPaused, MemberWorkSessionStarted, MemberWorkSessionsFetched,
  MembersFetched, MobileDrawersClosed, MobileLeftDrawerToggled,
  MobileRightDrawerToggled, NavigateTo, NoOp, NotAsked, NowWorkingTicked,
  OpenCardDetail, OpenCardDialog, OpenRuleDialog, OpenTaskTemplateDialog,
  OpenTaskTypeDialog, OpenWorkflowDialog, OrgSettingsRoleChanged,
  OrgSettingsSaveAllClicked, OrgSettingsSaveClicked, OrgSettingsSaved,
  OrgSettingsUsersFetched, OrgUsersCacheFetched, OrgUsersSearchChanged,
  OrgUsersSearchDebounced, OrgUsersSearchResults, PoolMsg,
  PreferencesPopupToggled, ProjectCreateDialogClosed, ProjectCreateDialogOpened,
  ProjectCreateNameChanged, ProjectCreateSubmitted, ProjectCreated,
  ProjectDeleteConfirmClosed, ProjectDeleteConfirmOpened, ProjectDeleteSubmitted,
  ProjectDeleted, ProjectEditDialogClosed, ProjectEditDialogOpened,
  ProjectEditNameChanged, ProjectEditSubmitted, ProjectSelected, ProjectUpdated,
  ProjectsFetched, Push, Rect, Replace, ResetPassword as ResetPasswordPage,
  ResetPasswordMsg, RuleAttachTemplateSelected, RuleAttachTemplateSubmitted,
  RuleCrudCreated, RuleCrudDeleted, RuleCrudUpdated, RuleExpandToggled,
  RuleMetricsFetched, RuleTemplateAttached, RuleTemplateDetachClicked,
  RuleTemplateDetached, RuleTemplatesClicked, RuleTemplatesFetched,
  RulesBackClicked, RulesFetched, SidebarConfigToggled, SidebarOrgToggled,
  TaskTemplateCrudCreated, TaskTemplateCrudDeleted, TaskTemplateCrudUpdated,
  TaskTemplatesProjectFetched, TaskTypeCreateCapabilityChanged,
  TaskTypeCreateDialogClosed, TaskTypeCreateDialogOpened,
  TaskTypeCreateIconCategoryChanged, TaskTypeCreateIconChanged,
  TaskTypeCreateIconSearchChanged, TaskTypeCreateNameChanged,
  TaskTypeCreateSubmitted, TaskTypeCreated, TaskTypeCrudCreated,
  TaskTypeCrudDeleted, TaskTypeCrudUpdated, TaskTypeIconErrored,
  TaskTypeIconLoaded, TaskTypesFetched, TemplateDetachClicked,
  TemplateDetachFailed, TemplateDetachSucceeded, ThemeSelected, ToastDismiss,
  ToastDismissed, ToastShow, ToastTick, UiModel, UrlChanged, UserProjectAdded,
  UserProjectRemoveClicked, UserProjectRemoved, UserProjectRoleChangeRequested,
  UserProjectRoleChanged, UserProjectsAddProjectChanged,
  UserProjectsAddRoleChanged, UserProjectsAddSubmitted, UserProjectsDialogClosed,
  UserProjectsDialogOpened, UserProjectsFetched, ViewModeChanged,
  WorkflowCrudCreated, WorkflowCrudDeleted, WorkflowCrudUpdated,
  WorkflowRulesClicked, WorkflowsProjectFetched, admin_msg, pool_msg,
  update_admin, update_auth, update_core, update_member, update_ui,
}

// Story 4.10: Rule template attachment UI

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
  case model.core.page {
    Login -> router.Login

    AcceptInvitePage -> {
      let accept_invite.Model(token: token, ..) = model.auth.accept_invite
      router.AcceptInvite(token)
    }

    ResetPasswordPage -> {
      let reset_password.Model(token: token, ..) = model.auth.reset_password
      router.ResetPassword(token)
    }

    // Story 4.5: Use Config or Org routes based on section type
    Admin ->
      case model.core.active_section {
        permissions.Invites
        | permissions.OrgSettings
        | permissions.Projects
        | permissions.Metrics -> router.Org(model.core.active_section)
        _ ->
          router.Config(
            model.core.active_section,
            model.core.selected_project_id,
          )
      }

    Member ->
      router.Member(
        model.member.member_section,
        model.core.selected_project_id,
        opt.Some(model.member.view_mode),
      )
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
        pool_msg(
          GlobalKeyDown(pool_prefs.KeyEvent(
            key,
            ctrl,
            meta,
            shift,
            is_editing,
            modal_open,
          )),
        ),
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
  let model = update_ui(model, fn(ui) { UiModel(..ui, toast: opt.None) })

  case route {
    router.Login -> {
      let model =
        update_member(
          update_core(model, fn(core) {
            CoreModel(..core, page: Login, selected_project_id: opt.None)
          }),
          fn(member) {
            MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
        )
      #(model, effect.none())
    }

    router.AcceptInvite(token) -> {
      let #(new_accept_model, action) = accept_invite.init(token)
      let model =
        update_member(
          update_auth(
            update_core(model, fn(core) {
              CoreModel(
                ..core,
                page: AcceptInvitePage,
                selected_project_id: opt.None,
              )
            }),
            fn(auth) { AuthModel(..auth, accept_invite: new_accept_model) },
          ),
          fn(member) {
            MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
        )

      #(model, accept_invite_effect(action))
    }

    router.ResetPassword(token) -> {
      let #(new_reset_model, action) = reset_password.init(token)
      let model =
        update_member(
          update_auth(
            update_core(model, fn(core) {
              CoreModel(
                ..core,
                page: ResetPasswordPage,
                selected_project_id: opt.None,
              )
            }),
            fn(auth) { AuthModel(..auth, reset_password: new_reset_model) },
          ),
          fn(member) {
            MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
        )

      #(model, reset_password_effect(action))
    }

    // Story 4.5: Config routes - project-scoped configuration
    router.Config(section, project_id) -> {
      let model =
        update_member(
          update_core(model, fn(core) {
            CoreModel(
              ..core,
              page: Admin,
              active_section: section,
              selected_project_id: project_id,
            )
          }),
          fn(member) {
            MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    // Story 4.5: Org routes - org-scoped administration
    router.Org(section) -> {
      let model =
        update_member(
          update_core(model, fn(core) {
            CoreModel(
              ..core,
              page: Admin,
              active_section: section,
              selected_project_id: opt.None,
            )
          }),
          fn(member) {
            MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    // Legacy Admin routes - still supported but will redirect via router.parse()
    router.Admin(section, project_id) -> {
      let model =
        update_member(
          update_core(model, fn(core) {
            CoreModel(
              ..core,
              page: Admin,
              active_section: section,
              selected_project_id: project_id,
            )
          }),
          fn(member) {
            MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    router.Member(section, project_id, view) -> {
      let capabilities_fx = case model.core.page, project_id {
        Admin, opt.Some(pid) ->
          api_org.list_project_capabilities(pid, fn(result) {
            admin_msg(CapabilitiesFetched(result))
          })
        _, _ -> effect.none()
      }

      // Update view mode if provided in URL
      let new_view = opt.unwrap(view, model.member.view_mode)

      #(
        update_member(
          update_core(model, fn(core) {
            CoreModel(..core, page: Member, selected_project_id: project_id)
          }),
          fn(member) {
            MemberModel(
              ..member,
              member_section: section,
              view_mode: new_view,
              member_drag: opt.None,
              member_pool_drag_to_claim_armed: False,
              member_pool_drag_over_my_tasks: False,
            )
          },
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
  case model.core.user {
    opt.Some(user) -> hydration.Authed(user.org_role)

    opt.None ->
      case model.core.auth_checked {
        True -> hydration.Unauthed
        False -> hydration.Unknown
      }
  }
}

fn build_snapshot(model: Model) -> hydration.Snapshot {
  let projects = update_helpers.active_projects(model)
  hydration.Snapshot(
    auth: auth_state(model),
    projects: remote_state(model.core.projects),
    is_any_project_manager: permissions.any_project_manager(projects),
    invite_links: remote_state(model.admin.invite_links),
    capabilities: remote_state(model.admin.capabilities),
    my_capability_ids: remote_state(model.member.member_my_capability_ids),
    org_settings_users: remote_state(model.admin.org_settings_users),
    org_users_cache: remote_state(model.admin.org_users_cache),
    members: remote_state(model.admin.members),
    members_project_id: model.admin.members_project_id,
    task_types: remote_state(model.admin.task_types),
    task_types_project_id: model.admin.task_types_project_id,
    member_tasks: remote_state(model.member.member_tasks),
    active_task: remote_state(model.member.member_active_task),
    me_metrics: remote_state(model.member.member_metrics),
    org_metrics_overview: remote_state(model.admin.admin_metrics_overview),
    org_metrics_project_tasks: remote_state(
      model.admin.admin_metrics_project_tasks,
    ),
    org_metrics_project_id: model.admin.admin_metrics_project_id,
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
              case m.core.projects {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_core(m, fn(core) {
                      CoreModel(..core, projects: Loading)
                    })
                  #(m, [
                    api_projects.list_projects(fn(result) {
                      admin_msg(ProjectsFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchInviteLinks -> {
              case m.admin.invite_links {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_admin(m, fn(admin) {
                      AdminModel(..admin, invite_links: Loading)
                    })
                  #(m, [
                    api_org.list_invite_links(fn(result) {
                      admin_msg(InviteLinksFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchCapabilities -> {
              case m.admin.capabilities, m.core.selected_project_id {
                Loading, _ | Loaded(_), _ -> #(m, fx)

                _, opt.Some(project_id) -> {
                  let m =
                    update_admin(m, fn(admin) {
                      AdminModel(..admin, capabilities: Loading)
                    })
                  #(m, [
                    api_org.list_project_capabilities(project_id, fn(result) {
                      admin_msg(CapabilitiesFetched(result))
                    }),
                    ..fx
                  ])
                }

                _, opt.None -> #(m, fx)
              }
            }

            hydration.FetchMeCapabilityIds -> {
              case
                m.member.member_my_capability_ids,
                m.core.selected_project_id,
                m.core.user
              {
                Loading, _, _ | Loaded(_), _, _ -> #(m, fx)

                _, opt.Some(project_id), opt.Some(user) -> {
                  let m =
                    update_member(m, fn(member) {
                      MemberModel(..member, member_my_capability_ids: Loading)
                    })
                  #(m, [
                    api_tasks.get_member_capability_ids(
                      project_id,
                      user.id,
                      fn(result) {
                        pool_msg(MemberMyCapabilityIdsFetched(result))
                      },
                    ),
                    ..fx
                  ])
                }

                _, _, _ -> #(m, fx)
              }
            }

            hydration.FetchActiveTask -> {
              case m.member.member_work_sessions {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_member(m, fn(member) {
                      MemberModel(..member, member_work_sessions: Loading)
                    })
                  #(m, [
                    api_tasks.get_work_sessions(fn(result) {
                      pool_msg(MemberWorkSessionsFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchMeMetrics -> {
              case m.member.member_metrics {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_member(m, fn(member) {
                      MemberModel(..member, member_metrics: Loading)
                    })
                  #(m, [
                    api_metrics.get_me_metrics(30, fn(result) {
                      pool_msg(MemberMetricsFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsOverview -> {
              case m.admin.admin_metrics_overview {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_admin(m, fn(admin) {
                      AdminModel(..admin, admin_metrics_overview: Loading)
                    })
                  #(m, [
                    api_metrics.get_org_metrics_overview(30, fn(result) {
                      pool_msg(AdminMetricsOverviewFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsProjectTasks(project_id: project_id) -> {
              let can_fetch = case m.core.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case
                    m.admin.admin_metrics_project_tasks,
                    m.admin.admin_metrics_project_id
                  {
                    Loading, _ -> #(m, fx)
                    Loaded(_), opt.Some(pid) if pid == project_id -> #(m, fx)

                    _, _ -> {
                      let m =
                        update_admin(m, fn(admin) {
                          AdminModel(
                            ..admin,
                            admin_metrics_project_tasks: Loading,
                            admin_metrics_project_id: opt.Some(project_id),
                          )
                        })

                      let fx_tasks =
                        api_metrics.get_org_metrics_project_tasks(
                          project_id,
                          30,
                          fn(result) {
                            pool_msg(AdminMetricsProjectTasksFetched(result))
                          },
                        )

                      #(m, [fx_tasks, ..fx])
                    }
                  }
              }
            }

            hydration.FetchOrgSettingsUsers -> {
              case m.admin.org_settings_users {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_admin(m, fn(admin) {
                      AdminModel(
                        ..admin,
                        org_settings_users: Loading,
                        org_settings_role_drafts: dict.new(),
                        org_settings_save_in_flight: False,
                        org_settings_error: opt.None,
                        org_settings_error_user_id: opt.None,
                      )
                    })

                  #(m, [
                    api_org.list_org_users("", fn(result) {
                      admin_msg(OrgSettingsUsersFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            // AC7: Fetch org users cache for member views (Lista)
            hydration.FetchOrgUsersCache -> {
              case m.admin.org_users_cache {
                Loading | Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    update_admin(m, fn(admin) {
                      AdminModel(..admin, org_users_cache: Loading)
                    })
                  #(m, [
                    api_org.list_org_users("", fn(result) {
                      admin_msg(OrgUsersCacheFetched(result))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchMembers(project_id: project_id) -> {
              let can_fetch = case m.core.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.admin.members {
                    Loading -> #(m, fx)

                    _ -> {
                      let m =
                        update_admin(m, fn(admin) {
                          AdminModel(
                            ..admin,
                            members: Loading,
                            members_project_id: opt.Some(project_id),
                            org_users_cache: Loading,
                          )
                        })

                      let fx_members =
                        api_projects.list_project_members(
                          project_id,
                          fn(result) { admin_msg(MembersFetched(result)) },
                        )
                      let fx_users =
                        api_org.list_org_users("", fn(result) {
                          admin_msg(OrgUsersCacheFetched(result))
                        })

                      #(m, [effect.batch([fx_members, fx_users]), ..fx])
                    }
                  }
              }
            }

            hydration.FetchTaskTypes(project_id: project_id) -> {
              let can_fetch = case m.core.projects {
                Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.admin.task_types {
                    Loading -> #(m, fx)

                    _ -> {
                      let m =
                        update_admin(m, fn(admin) {
                          AdminModel(
                            ..admin,
                            task_types: Loading,
                            task_types_project_id: opt.Some(project_id),
                          )
                        })

                      #(m, [
                        api_tasks.list_task_types(project_id, fn(result) {
                          admin_msg(TaskTypesFetched(result))
                        }),
                        ..fx
                      ])
                    }
                  }
              }
            }

            hydration.RefreshMember -> {
              case m.core.projects {
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

  let model = update_ui(model, fn(ui) { UiModel(..ui, is_mobile: is_mobile) })

  let parsed =
    router.parse(pathname, search, hash)
    |> router.apply_mobile_rules(is_mobile)

  let route = case parsed {
    router.Parsed(route) -> route
    router.Redirect(route) -> route
  }

  let current = current_route(model)
  let title_fx = router.update_page_title(route, model.ui.locale)

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
  let #(next_route, next_mode) = case model.ui.is_mobile, route {
    True, router.Member(member_section.Pool, project_id, view) -> #(
      router.Member(member_section.MyBar, project_id, view),
      Replace,
    )
    _, _ -> #(route, mode)
  }

  case next_route == current_route(model) {
    True -> #(model, effect.none())

    False -> {
      let #(model, route_fx) = apply_route_fields(model, next_route)
      let #(model, hyd_fx) = hydrate_model(model)
      let title_fx = router.update_page_title(next_route, model.ui.locale)

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
  let is_admin = case model.core.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  // Capabilities and member capability IDs are now project-scoped
  // They will be fetched when a project is selected
  let model =
    update_admin(
      update_core(model, fn(core) { CoreModel(..core, projects: Loading) }),
      fn(admin) {
        AdminModel(..admin, invite_links: case is_admin {
          True -> Loading
          False -> admin.invite_links
        })
      },
    )

  let effects = [
    api_projects.list_projects(fn(result) { admin_msg(ProjectsFetched(result)) }),
  ]

  // Fetch capabilities if project is selected
  let effects = case model.core.selected_project_id {
    opt.Some(project_id) -> [
      api_org.list_project_capabilities(project_id, fn(result) {
        admin_msg(CapabilitiesFetched(result))
      }),
      ..effects
    ]
    opt.None -> effects
  }

  // Fetch member capability IDs if project and user are available
  let effects = case model.core.selected_project_id, model.core.user {
    opt.Some(project_id), opt.Some(user) -> [
      api_tasks.get_member_capability_ids(project_id, user.id, fn(result) {
        pool_msg(MemberMyCapabilityIdsFetched(result))
      }),
      ..effects
    ]
    _, _ -> effects
  }

  let effects = case is_admin {
    True -> [
      api_org.list_invite_links(fn(result) {
        admin_msg(InviteLinksFetched(result))
      }),
      ..effects
    ]
    False -> effects
  }

  #(model, effect.batch(effects))
}

pub fn refresh_section_for_test(model: Model) -> #(Model, Effect(Msg)) {
  case model.core.active_section {
    permissions.Invites -> {
      let model =
        update_admin(model, fn(admin) {
          AdminModel(..admin, invite_links: Loading)
        })
      #(
        model,
        api_org.list_invite_links(fn(result) {
          admin_msg(InviteLinksFetched(result))
        }),
      )
    }

    permissions.OrgSettings -> {
      let model =
        update_admin(model, fn(admin) {
          AdminModel(
            ..admin,
            org_settings_users: Loading,
            org_settings_role_drafts: dict.new(),
            org_settings_save_in_flight: False,
            org_settings_error: opt.None,
            org_settings_error_user_id: opt.None,
          )
        })

      #(
        model,
        api_org.list_org_users("", fn(result) {
          admin_msg(OrgSettingsUsersFetched(result))
        }),
      )
    }

    permissions.Projects -> #(
      model,
      api_projects.list_projects(fn(result) {
        admin_msg(ProjectsFetched(result))
      }),
    )

    permissions.Metrics -> {
      let model =
        update_admin(model, fn(admin) {
          AdminModel(..admin, admin_metrics_overview: Loading)
        })

      let overview_fx =
        api_metrics.get_org_metrics_overview(30, fn(result) {
          pool_msg(AdminMetricsOverviewFetched(result))
        })

      case model.core.selected_project_id {
        opt.None -> #(model, overview_fx)

        opt.Some(project_id) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                admin_metrics_project_tasks: Loading,
                admin_metrics_project_id: opt.Some(project_id),
              )
            })

          let tasks_fx =
            api_metrics.get_org_metrics_project_tasks(
              project_id,
              30,
              fn(result) { pool_msg(AdminMetricsProjectTasksFetched(result)) },
            )

          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(model, effect.batch([overview_fx, tasks_fx, ..right_panel_fx]))
        }
      }
    }

    permissions.RuleMetrics -> {
      // Initialize with default date range (last 30 days)
      let #(model, fx) = admin_workflow.handle_rule_metrics_tab_init(model)
      let #(model, right_panel_fx) = fetch_right_panel_data(model)
      #(model, effect.batch([fx, ..right_panel_fx]))
    }

    permissions.Capabilities ->
      case model.core.selected_project_id {
        opt.Some(project_id) -> {
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_org.list_project_capabilities(project_id, fn(result) {
                admin_msg(CapabilitiesFetched(result))
              }),
              ..right_panel_fx
            ]),
          )
        }
        opt.None -> #(model, effect.none())
      }

    permissions.Members ->
      case model.core.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                members: Loading,
                members_project_id: opt.Some(project_id),
                org_users_cache: Loading,
              )
            })
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_projects.list_project_members(project_id, fn(result) {
                admin_msg(MembersFetched(result))
              }),
              api_org.list_org_users("", fn(result) {
                admin_msg(OrgUsersCacheFetched(result))
              }),
              ..right_panel_fx
            ]),
          )
        }
      }

    permissions.TaskTypes ->
      case model.core.selected_project_id {
        opt.None -> #(model, effect.none())
        opt.Some(project_id) -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                task_types: Loading,
                task_types_project_id: opt.Some(project_id),
              )
            })
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_tasks.list_task_types(project_id, fn(result) {
                admin_msg(TaskTypesFetched(result))
              }),
              ..right_panel_fx
            ]),
          )
        }
      }

    permissions.Cards -> {
      let #(model, fx) = admin_workflow.fetch_cards_for_project(model)
      let #(model, right_panel_fx) = fetch_right_panel_data(model)
      #(model, effect.batch([fx, ..right_panel_fx]))
    }

    permissions.Workflows -> {
      let #(model, fx) = admin_workflow.fetch_workflows(model)
      let #(model, right_panel_fx) = fetch_right_panel_data(model)
      #(model, effect.batch([fx, ..right_panel_fx]))
    }

    permissions.TaskTemplates -> {
      let #(model, fx) = admin_workflow.fetch_task_templates(model)
      let #(model, right_panel_fx) = fetch_right_panel_data(model)
      // Also fetch task types for the template dialog type selector
      let task_types_fx = case
        model.core.selected_project_id,
        model.admin.task_types
      {
        opt.Some(project_id), NotAsked ->
          api_tasks.list_task_types(project_id, fn(result) {
            admin_msg(TaskTypesFetched(result))
          })
        opt.Some(project_id), Failed(_) ->
          api_tasks.list_task_types(project_id, fn(result) {
            admin_msg(TaskTypesFetched(result))
          })
        _, _ -> effect.none()
      }
      #(model, effect.batch([fx, task_types_fx, ..right_panel_fx]))
    }
  }
}

/// Fetches tasks and cards for the right panel in config views.
/// This ensures "My Tasks" and "My Cards" sections are populated
/// even when navigating directly to config routes.
/// Returns updated model (with pending counters) and list of effects.
fn fetch_right_panel_data(model: Model) -> #(Model, List(Effect(Msg))) {
  case model.core.selected_project_id {
    opt.None -> #(model, [])
    opt.Some(project_id) -> {
      // Fetch tasks with no filter to get all tasks
      let tasks_effect =
        api_tasks.list_project_tasks(
          project_id,
          TaskFilters(
            status: opt.None,
            type_id: opt.None,
            capability_id: opt.None,
            q: opt.None,
          ),
          fn(result) { pool_msg(MemberProjectTasksFetched(project_id, result)) },
        )

      // Fetch cards for "My Cards" section
      let cards_effect =
        api_cards.list_cards(project_id, fn(result) {
          pool_msg(CardsFetched(result))
        })

      // Update model with pending counter and loading state
      let model =
        update_admin(
          update_member(model, fn(member) {
            MemberModel(
              ..member,
              member_tasks_pending: 1,
              member_tasks_by_project: dict.new(),
            )
          }),
          fn(admin) {
            AdminModel(
              ..admin,
              cards: Loading,
              cards_project_id: opt.Some(project_id),
            )
          },
        )

      #(model, [tasks_effect, cards_effect])
    }
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
  case model.member.member_section {
    member_section.MySkills -> #(model, effect.none())

    _ -> {
      let projects = update_helpers.active_projects(model)

      let project_ids = case model.core.selected_project_id {
        opt.Some(project_id) -> [project_id]
        opt.None -> projects |> list.map(fn(p) { p.id })
      }

      case project_ids {
        [] -> #(
          update_member(model, fn(member) {
            MemberModel(
              ..member,
              member_tasks: NotAsked,
              member_tasks_pending: 0,
              member_tasks_by_project: dict.new(),
              member_task_types: NotAsked,
              member_task_types_pending: 0,
              member_task_types_by_project: dict.new(),
            )
          }),
          effect.none(),
        )

        _ -> {
          let filters = case model.member.member_section {
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
                  model.member.member_filters_type_id,
                ),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member.member_filters_q),
              )

            _ ->
              TaskFilters(
                status: update_helpers.empty_to_opt(
                  model.member.member_filters_status,
                ),
                type_id: update_helpers.empty_to_int_opt(
                  model.member.member_filters_type_id,
                ),
                capability_id: update_helpers.empty_to_int_opt(
                  model.member.member_filters_capability_id,
                ),
                q: update_helpers.empty_to_opt(model.member.member_filters_q),
              )
          }

          let positions_effect =
            api_tasks.list_me_task_positions(
              model.core.selected_project_id,
              fn(result) { pool_msg(MemberPositionsFetched(result)) },
            )

          let task_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_project_tasks(project_id, filters, fn(result) {
                pool_msg(MemberProjectTasksFetched(project_id, result))
              })
            })

          let task_type_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_task_types(project_id, fn(result) {
                pool_msg(MemberTaskTypesFetched(project_id, result))
              })
            })

          // Story 4.8 UX: Fetch cards for ALL views (Lista, Kanban need them too)
          let #(cards_effects, cards_model_update) = case
            model.core.selected_project_id
          {
            opt.Some(project_id) -> #(
              [
                api_cards.list_cards(project_id, fn(result) {
                  pool_msg(CardsFetched(result))
                }),
              ],
              fn(m: Model) {
                update_admin(m, fn(admin) {
                  AdminModel(
                    ..admin,
                    cards: Loading,
                    cards_project_id: opt.Some(project_id),
                  )
                })
              },
            )
            opt.None -> #([], fn(m: Model) { m })
          }

          let effects =
            list.append(
              task_effects,
              list.append(
                task_type_effects,
                list.append([positions_effect], cards_effects),
              ),
            )

          let model =
            update_member(model, fn(member) {
              MemberModel(
                ..member,
                member_tasks: Loading,
                member_tasks_pending: list.length(project_ids),
                member_tasks_by_project: dict.new(),
                member_task_types: Loading,
                member_task_types_pending: list.length(project_ids),
                member_task_types_by_project: dict.new(),
              )
            })
            |> cards_model_update

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
    // No operation - used for placeholder handlers
    NoOp -> #(model, effect.none())

    UrlChanged -> handle_url_changed(model)

    NavigateTo(route, mode) -> handle_navigate_to(model, route, mode)

    MeFetched(Ok(user)) -> {
      let default_page = case user.org_role {
        org_role.Admin -> Admin
        _ -> Member
      }

      // Keep Admin page if user requested it - hydration will check access
      // after projects load (to determine if user is a project manager)
      let resolved_page = case model.core.page {
        Member -> Member
        Admin -> Admin
        _ -> default_page
      }

      let model =
        update_core(model, fn(core) {
          CoreModel(
            ..core,
            page: resolved_page,
            user: opt.Some(user),
            auth_checked: True,
          )
        })
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
            update_core(model, fn(core) {
              CoreModel(..core, page: Login, user: opt.None, auth_checked: True)
            })
          #(model, replace_url(model))
        }

        False -> {
          let model =
            update_auth(
              update_core(model, fn(core) {
                CoreModel(
                  ..core,
                  page: Login,
                  user: opt.None,
                  auth_checked: True,
                )
              }),
              fn(auth) { AuthModel(..auth, login_error: opt.Some(err.message)) },
            )

          #(model, replace_url(model))
        }
      }
    }

    AcceptInviteMsg(inner) -> {
      let #(next_accept, action) =
        accept_invite.update(model.auth.accept_invite, inner)
      let model =
        update_ui(
          update_auth(model, fn(auth) {
            AuthModel(..auth, accept_invite: next_accept)
          }),
          fn(ui) { UiModel(..ui, toast: opt.None) },
        )

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
            update_ui(
              update_core(model, fn(core) {
                CoreModel(
                  ..core,
                  page: page,
                  user: opt.Some(user),
                  auth_checked: True,
                )
              }),
              fn(ui) {
                UiModel(
                  ..ui,
                  toast: opt.Some(update_helpers.i18n_t(
                    model,
                    i18n_text.Welcome,
                  )),
                )
              },
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
        reset_password.update(model.auth.reset_password, inner)

      let model =
        update_ui(
          update_auth(model, fn(auth) {
            AuthModel(..auth, reset_password: next_reset)
          }),
          fn(ui) { UiModel(..ui, toast: opt.None) },
        )

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
            update_ui(
              update_auth(
                update_core(model, fn(core) { CoreModel(..core, page: Login) }),
                fn(auth) {
                  AuthModel(..auth, login_password: "", login_error: opt.None)
                },
              ),
              fn(ui) {
                UiModel(
                  ..ui,
                  toast: opt.Some(update_helpers.i18n_t(
                    model,
                    i18n_text.PasswordUpdated,
                  )),
                )
              },
            )

          #(model, replace_url(model))
        }
      }
    }

    AuthMsg(inner) ->
      auth_workflow.update(
        model,
        inner,
        bootstrap_admin,
        hydrate_model,
        replace_url,
      )

    ToastDismissed -> #(
      update_ui(model, fn(ui) { UiModel(..ui, toast: opt.None) }),
      effect.none(),
    )

    // New toast system (Story 4.8)
    ToastShow(message, variant) -> {
      let now = client_ffi.now_ms()
      let next_state = toast.show(model.ui.toast_state, message, variant, now)
      // Schedule tick for auto-dismiss
      let tick_effect =
        effect.from(fn(dispatch) {
          client_ffi.set_timeout(toast.auto_dismiss_ms, fn(_) {
            dispatch(ToastTick(client_ffi.now_ms()))
          })
          Nil
        })
      #(
        update_ui(model, fn(ui) { UiModel(..ui, toast_state: next_state) }),
        tick_effect,
      )
    }

    ToastDismiss(id) -> {
      let next_state = toast.dismiss(model.ui.toast_state, id)
      #(
        update_ui(model, fn(ui) { UiModel(..ui, toast_state: next_state) }),
        effect.none(),
      )
    }

    ToastTick(now) -> {
      let #(next_state, should_schedule) = toast.tick(model.ui.toast_state, now)
      let tick_effect = case should_schedule {
        True ->
          effect.from(fn(dispatch) {
            client_ffi.set_timeout(1000, fn(_) {
              dispatch(ToastTick(client_ffi.now_ms()))
            })
            Nil
          })
        False -> effect.none()
      }
      #(
        update_ui(model, fn(ui) { UiModel(..ui, toast_state: next_state) }),
        tick_effect,
      )
    }

    ThemeSelected(value) -> {
      let next_theme = theme.deserialize(value)

      case next_theme == model.ui.theme {
        True -> #(model, effect.none())

        False -> #(
          update_ui(model, fn(ui) { UiModel(..ui, theme: next_theme) }),
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
          model.core.page == Member,
          model.core.selected_project_id,
          selected,
        )

      let model = case selected {
        opt.None ->
          update_member(
            update_core(model, fn(core) {
              CoreModel(..core, selected_project_id: selected)
            }),
            fn(member) {
              MemberModel(
                ..member,
                member_filters_type_id: "",
                member_task_types: NotAsked,
              )
            },
          )
          |> update_ui(fn(ui) { UiModel(..ui, toast: opt.None) })
        _ ->
          update_ui(
            update_core(model, fn(core) {
              CoreModel(..core, selected_project_id: selected)
            }),
            fn(ui) { UiModel(..ui, toast: opt.None) },
          )
      }

      case model.core.page {
        Member -> {
          let #(model, fx) = member_refresh(model)

          let pause_fx = case should_pause {
            True ->
              api_tasks.pause_me_active_task(fn(result) {
                pool_msg(MemberActiveTaskPaused(result))
              })
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

    AdminMsg(inner) -> {
      case inner {
        ProjectsFetched(Ok(projects)) -> {
          let selected =
            update_helpers.ensure_selected_project(
              model.core.selected_project_id,
              projects,
            )
          let model =
            update_core(model, fn(core) {
              CoreModel(
                ..core,
                projects: Loaded(projects),
                selected_project_id: selected,
              )
            })

          let model = update_helpers.ensure_default_section(model)

          case model.core.page {
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
                update_member(
                  update_core(model, fn(core) {
                    CoreModel(..core, page: Login, user: opt.None)
                  }),
                  fn(member) {
                    MemberModel(
                      ..member,
                      member_drag: opt.None,
                      member_pool_drag_to_claim_armed: False,
                      member_pool_drag_over_my_tasks: False,
                    )
                  },
                )
              #(model, replace_url(model))
            }

            False -> #(
              update_core(model, fn(core) {
                CoreModel(..core, projects: Failed(err))
              }),
              effect.none(),
            )
          }
        }

        ProjectCreateDialogOpened ->
          projects_workflow.handle_project_create_dialog_opened(model)
        ProjectCreateDialogClosed ->
          projects_workflow.handle_project_create_dialog_closed(model)
        ProjectCreateNameChanged(name) ->
          projects_workflow.handle_project_create_name_changed(model, name)
        ProjectCreateSubmitted ->
          projects_workflow.handle_project_create_submitted(model)
        ProjectCreated(Ok(project)) ->
          projects_workflow.handle_project_created_ok(model, project)
        ProjectCreated(Error(err)) ->
          projects_workflow.handle_project_created_error(model, err)
        // Project Edit (Story 4.8 AC39)
        ProjectEditDialogOpened(project_id, project_name) ->
          projects_workflow.handle_project_edit_dialog_opened(
            model,
            project_id,
            project_name,
          )
        ProjectEditDialogClosed ->
          projects_workflow.handle_project_edit_dialog_closed(model)
        ProjectEditNameChanged(name) ->
          projects_workflow.handle_project_edit_name_changed(model, name)
        ProjectEditSubmitted ->
          projects_workflow.handle_project_edit_submitted(model)
        ProjectUpdated(Ok(project)) ->
          projects_workflow.handle_project_updated_ok(model, project)
        ProjectUpdated(Error(err)) ->
          projects_workflow.handle_project_updated_error(model, err)
        // Project Delete (Story 4.8 AC39)
        ProjectDeleteConfirmOpened(project_id, project_name) ->
          projects_workflow.handle_project_delete_confirm_opened(
            model,
            project_id,
            project_name,
          )
        ProjectDeleteConfirmClosed ->
          projects_workflow.handle_project_delete_confirm_closed(model)
        ProjectDeleteSubmitted ->
          projects_workflow.handle_project_delete_submitted(model)
        ProjectDeleted(Ok(_)) ->
          projects_workflow.handle_project_deleted_ok(model)
        ProjectDeleted(Error(err)) ->
          projects_workflow.handle_project_deleted_error(model, err)

        InviteCreateDialogOpened ->
          invite_links_workflow.handle_invite_create_dialog_opened(model)
        InviteCreateDialogClosed ->
          invite_links_workflow.handle_invite_create_dialog_closed(model)
        InviteLinkEmailChanged(value) ->
          invite_links_workflow.handle_invite_link_email_changed(model, value)
        InviteLinksFetched(Ok(links)) ->
          invite_links_workflow.handle_invite_links_fetched_ok(model, links)
        InviteLinksFetched(Error(err)) ->
          invite_links_workflow.handle_invite_links_fetched_error(model, err)
        InviteLinkCreateSubmitted ->
          invite_links_workflow.handle_invite_link_create_submitted(model)
        InviteLinkRegenerateClicked(email) ->
          invite_links_workflow.handle_invite_link_regenerate_clicked(
            model,
            email,
          )
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
          capabilities_workflow.handle_capabilities_fetched_ok(
            model,
            capabilities,
          )
        CapabilitiesFetched(Error(err)) ->
          capabilities_workflow.handle_capabilities_fetched_error(model, err)
        CapabilityCreateDialogOpened ->
          capabilities_workflow.handle_capability_dialog_opened(model)
        CapabilityCreateDialogClosed ->
          capabilities_workflow.handle_capability_dialog_closed(model)
        CapabilityCreateNameChanged(name) ->
          capabilities_workflow.handle_capability_create_name_changed(
            model,
            name,
          )
        CapabilityCreateSubmitted ->
          capabilities_workflow.handle_capability_create_submitted(model)
        CapabilityCreated(Ok(capability)) ->
          capabilities_workflow.handle_capability_created_ok(model, capability)
        CapabilityCreated(Error(err)) ->
          capabilities_workflow.handle_capability_created_error(model, err)
        // Capability delete (Story 4.9 AC9)
        CapabilityDeleteDialogOpened(capability_id) ->
          capabilities_workflow.handle_capability_delete_dialog_opened(
            model,
            capability_id,
          )
        CapabilityDeleteDialogClosed ->
          capabilities_workflow.handle_capability_delete_dialog_closed(model)
        CapabilityDeleteSubmitted ->
          capabilities_workflow.handle_capability_delete_submitted(model)
        CapabilityDeleted(Ok(deleted_id)) ->
          capabilities_workflow.handle_capability_deleted_ok(model, deleted_id)
        CapabilityDeleted(Error(err)) ->
          capabilities_workflow.handle_capability_deleted_error(model, err)

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
          admin_workflow.handle_org_settings_role_changed(
            model,
            user_id,
            org_role,
          )
        OrgSettingsSaveClicked(user_id) ->
          admin_workflow.handle_org_settings_save_clicked(model, user_id)
        OrgSettingsSaved(_user_id, Ok(updated)) ->
          admin_workflow.handle_org_settings_saved_ok(model, updated)
        OrgSettingsSaved(user_id, Error(err)) ->
          admin_workflow.handle_org_settings_saved_error(model, user_id, err)
        OrgSettingsSaveAllClicked ->
          admin_workflow.handle_org_settings_save_all_clicked(model)

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
          admin_workflow.handle_user_projects_add_project_changed(
            model,
            project_id,
          )
        UserProjectsAddRoleChanged(role) ->
          admin_workflow.handle_user_projects_add_role_changed(model, role)
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
        UserProjectRoleChangeRequested(project_id, new_role) ->
          admin_workflow.handle_user_project_role_change_requested(
            model,
            project_id,
            new_role,
          )
        UserProjectRoleChanged(project_id, Ok(updated)) ->
          admin_workflow.handle_user_project_role_changed_ok(
            model,
            project_id,
            updated,
          )
        UserProjectRoleChanged(_project_id, Error(err)) ->
          admin_workflow.handle_user_project_role_changed_error(model, err)

        MemberAddDialogOpened ->
          admin_workflow.handle_member_add_dialog_opened(model)
        MemberAddDialogClosed ->
          admin_workflow.handle_member_add_dialog_closed(model)
        MemberAddRoleChanged(role_string) -> {
          let role = case project_role.parse(role_string) {
            Ok(r) -> r
            Error(_) -> MemberRole
          }
          admin_workflow.handle_member_add_role_changed(model, role)
        }
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
          admin_workflow.handle_member_removed_ok(
            model,
            refresh_section_for_test,
          )
        MemberRemoved(Error(err)) ->
          admin_workflow.handle_member_removed_error(model, err)

        MemberRoleChangeRequested(user_id, new_role) ->
          admin_workflow.handle_member_role_change_requested(
            model,
            user_id,
            new_role,
          )
        MemberRoleChanged(Ok(result)) ->
          admin_workflow.handle_member_role_changed_ok(model, result)
        MemberRoleChanged(Error(err)) ->
          admin_workflow.handle_member_role_changed_error(model, err)

        // Member capabilities dialog (Story 4.7 AC10-14)
        MemberCapabilitiesDialogOpened(user_id) ->
          admin_workflow.handle_member_capabilities_dialog_opened(
            model,
            user_id,
          )
        MemberCapabilitiesDialogClosed ->
          admin_workflow.handle_member_capabilities_dialog_closed(model)
        MemberCapabilitiesToggled(capability_id) ->
          admin_workflow.handle_member_capabilities_toggled(
            model,
            capability_id,
          )
        MemberCapabilitiesSaveClicked ->
          admin_workflow.handle_member_capabilities_save_clicked(model)
        MemberCapabilitiesFetched(Ok(result)) ->
          admin_workflow.handle_member_capabilities_fetched_ok(model, result)
        MemberCapabilitiesFetched(Error(err)) ->
          admin_workflow.handle_member_capabilities_fetched_error(model, err)
        MemberCapabilitiesSaved(Ok(result)) ->
          admin_workflow.handle_member_capabilities_saved_ok(model, result)
        MemberCapabilitiesSaved(Error(err)) ->
          admin_workflow.handle_member_capabilities_saved_error(model, err)

        // Capability members dialog (Story 4.7 AC16-17)
        CapabilityMembersDialogOpened(capability_id) ->
          admin_workflow.handle_capability_members_dialog_opened(
            model,
            capability_id,
          )
        CapabilityMembersDialogClosed ->
          admin_workflow.handle_capability_members_dialog_closed(model)
        CapabilityMembersToggled(user_id) ->
          admin_workflow.handle_capability_members_toggled(model, user_id)
        CapabilityMembersSaveClicked ->
          admin_workflow.handle_capability_members_save_clicked(model)
        CapabilityMembersFetched(Ok(result)) ->
          admin_workflow.handle_capability_members_fetched_ok(model, result)
        CapabilityMembersFetched(Error(err)) ->
          admin_workflow.handle_capability_members_fetched_error(model, err)
        CapabilityMembersSaved(Ok(result)) ->
          admin_workflow.handle_capability_members_saved_ok(model, result)
        CapabilityMembersSaved(Error(err)) ->
          admin_workflow.handle_capability_members_saved_error(model, err)

        OrgUsersSearchChanged(query) ->
          admin_workflow.handle_org_users_search_changed(model, query)

        OrgUsersSearchDebounced(query) ->
          admin_workflow.handle_org_users_search_debounced(model, query)
        OrgUsersSearchResults(token, Ok(users)) ->
          admin_workflow.handle_org_users_search_results_ok(model, token, users)
        OrgUsersSearchResults(token, Error(err)) ->
          admin_workflow.handle_org_users_search_results_error(
            model,
            token,
            err,
          )

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
        TaskTypeCreateIconSearchChanged(search) ->
          task_types_workflow.handle_task_type_create_icon_search_changed(
            model,
            search,
          )
        TaskTypeCreateIconCategoryChanged(category) ->
          task_types_workflow.handle_task_type_create_icon_category_changed(
            model,
            category,
          )
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
        // Task types - dialog mode control (component pattern)
        OpenTaskTypeDialog(mode) ->
          task_types_workflow.handle_open_task_type_dialog(model, mode)
        CloseTaskTypeDialog ->
          task_types_workflow.handle_close_task_type_dialog(model)
        // Task types - component events
        TaskTypeCrudCreated(task_type) ->
          task_types_workflow.handle_task_type_crud_created(
            model,
            task_type,
            refresh_section_for_test,
          )
        TaskTypeCrudUpdated(task_type) ->
          task_types_workflow.handle_task_type_crud_updated(model, task_type)
        TaskTypeCrudDeleted(type_id) ->
          task_types_workflow.handle_task_type_crud_deleted(model, type_id)
      }
    }

    PoolMsg(inner) -> {
      case inner {
        MemberPoolMyTasksRectFetched(left, top, width, height) -> #(
          update_member(model, fn(member) {
            MemberModel(
              ..member,
              member_pool_my_tasks_rect: opt.Some(Rect(
                left: left,
                top: top,
                width: width,
                height: height,
              )),
            )
          }),
          effect.none(),
        )
        MemberPoolDragToClaimArmed(armed) -> #(
          update_member(model, fn(member) {
            MemberModel(
              ..member,
              member_pool_drag_to_claim_armed: armed,
              member_pool_drag_over_my_tasks: False,
            )
          }),
          effect.none(),
        )
        MemberPoolStatusChanged(v) ->
          pool_workflow.handle_pool_status_changed(model, v, member_refresh)
        MemberPoolTypeChanged(v) ->
          pool_workflow.handle_pool_type_changed(model, v, member_refresh)
        MemberPoolCapabilityChanged(v) ->
          pool_workflow.handle_pool_capability_changed(model, v, member_refresh)

        MemberToggleMyCapabilitiesQuick ->
          pool_workflow.handle_toggle_my_capabilities_quick(model)
        MemberPoolFiltersToggled ->
          pool_workflow.handle_pool_filters_toggled(model)
        MemberClearFilters ->
          pool_workflow.handle_clear_filters(model, member_refresh)
        MemberPoolViewModeSet(mode) ->
          pool_workflow.handle_pool_view_mode_set(model, mode)
        MemberListHideCompletedToggled -> #(
          update_member(model, fn(member) {
            MemberModel(
              ..member,
              member_list_hide_completed: !model.member.member_list_hide_completed,
            )
          }),
          effect.none(),
        )
        // Story 4.8 UX: Collapse/expand card groups in Lista view
        MemberListCardToggled(card_id) -> {
          let current =
            dict.get(model.member.member_list_expanded_cards, card_id)
            |> opt.from_result
            |> opt.unwrap(True)
          let new_cards =
            dict.insert(
              model.member.member_list_expanded_cards,
              card_id,
              !current,
            )
          #(
            update_member(model, fn(member) {
              MemberModel(..member, member_list_expanded_cards: new_cards)
            }),
            effect.none(),
          )
        }
        ViewModeChanged(mode) -> {
          let new_model =
            update_member(model, fn(member) {
              MemberModel(..member, view_mode: mode)
            })
          let route =
            router.Member(
              model.member.member_section,
              model.core.selected_project_id,
              opt.Some(mode),
            )
          #(new_model, router.replace(route))
        }
        MemberPanelToggled -> #(
          update_member(model, fn(member) {
            MemberModel(
              ..member,
              member_panel_expanded: !model.member.member_panel_expanded,
            )
          }),
          effect.none(),
        )
        MobileLeftDrawerToggled -> #(
          update_ui(model, fn(ui) {
            UiModel(
              ..ui,
              mobile_left_drawer_open: !model.ui.mobile_left_drawer_open,
              mobile_right_drawer_open: False,
            )
          }),
          effect.none(),
        )
        MobileRightDrawerToggled -> #(
          update_ui(model, fn(ui) {
            UiModel(
              ..ui,
              mobile_right_drawer_open: !model.ui.mobile_right_drawer_open,
              mobile_left_drawer_open: False,
            )
          }),
          effect.none(),
        )
        MobileDrawersClosed -> #(
          update_ui(model, fn(ui) {
            UiModel(
              ..ui,
              mobile_left_drawer_open: False,
              mobile_right_drawer_open: False,
            )
          }),
          effect.none(),
        )
        SidebarConfigToggled -> #(
          update_ui(model, fn(ui) {
            UiModel(
              ..ui,
              sidebar_config_collapsed: !model.ui.sidebar_config_collapsed,
            )
          }),
          app_effects.save_sidebar_state(
            !model.ui.sidebar_config_collapsed,
            model.ui.sidebar_org_collapsed,
          ),
        )
        SidebarOrgToggled -> #(
          update_ui(model, fn(ui) {
            UiModel(
              ..ui,
              sidebar_org_collapsed: !model.ui.sidebar_org_collapsed,
            )
          }),
          app_effects.save_sidebar_state(
            model.ui.sidebar_config_collapsed,
            !model.ui.sidebar_org_collapsed,
          ),
        )
        // Story 4.8 UX: Preferences popup toggle
        PreferencesPopupToggled -> #(
          update_ui(model, fn(ui) {
            UiModel(
              ..ui,
              preferences_popup_open: !model.ui.preferences_popup_open,
            )
          }),
          effect.none(),
        )
        GlobalKeyDown(event) ->
          pool_workflow.handle_global_keydown(model, event)

        MemberPoolSearchChanged(v) ->
          pool_workflow.handle_pool_search_changed(model, v)
        MemberPoolSearchDebounced(v) ->
          pool_workflow.handle_pool_search_debounced(model, v, member_refresh)

        MemberProjectTasksFetched(project_id, Ok(tasks)) -> {
          let tasks_by_project =
            dict.insert(model.member.member_tasks_by_project, project_id, tasks)
          let pending = model.member.member_tasks_pending - 1

          let model =
            update_member(model, fn(member) {
              MemberModel(
                ..member,
                member_tasks_by_project: tasks_by_project,
                member_tasks_pending: pending,
              )
            })

          case pending <= 0 {
            True -> #(
              update_member(model, fn(member) {
                MemberModel(
                  ..member,
                  member_tasks: Loaded(update_helpers.flatten_tasks(
                    tasks_by_project,
                  )),
                )
              }),
              effect.none(),
            )
            False -> #(model, effect.none())
          }
        }

        MemberProjectTasksFetched(_project_id, Error(err)) -> {
          case err.status {
            401 -> #(
              update_member(
                update_core(model, fn(core) {
                  CoreModel(..core, page: Login, user: opt.None)
                }),
                fn(member) {
                  MemberModel(
                    ..member,
                    member_drag: opt.None,
                    member_pool_drag_to_claim_armed: False,
                    member_pool_drag_over_my_tasks: False,
                  )
                },
              ),
              effect.none(),
            )
            _ -> #(
              update_member(model, fn(member) {
                MemberModel(
                  ..member,
                  member_tasks: Failed(err),
                  member_tasks_pending: 0,
                )
              }),
              effect.none(),
            )
          }
        }

        MemberTaskTypesFetched(project_id, Ok(task_types)) -> {
          let task_types_by_project =
            dict.insert(
              model.member.member_task_types_by_project,
              project_id,
              task_types,
            )
          let pending = model.member.member_task_types_pending - 1

          let model =
            update_member(model, fn(member) {
              MemberModel(
                ..member,
                member_task_types_by_project: task_types_by_project,
                member_task_types_pending: pending,
              )
            })

          case pending <= 0 {
            True -> #(
              update_member(model, fn(member) {
                MemberModel(
                  ..member,
                  member_task_types: Loaded(update_helpers.flatten_task_types(
                    task_types_by_project,
                  )),
                )
              }),
              effect.none(),
            )
            False -> #(model, effect.none())
          }
        }

        MemberTaskTypesFetched(_project_id, Error(err)) -> {
          case err.status {
            401 -> #(
              update_member(
                update_core(model, fn(core) {
                  CoreModel(..core, page: Login, user: opt.None)
                }),
                fn(member) {
                  MemberModel(
                    ..member,
                    member_drag: opt.None,
                    member_pool_drag_to_claim_armed: False,
                    member_pool_drag_over_my_tasks: False,
                  )
                },
              ),
              effect.none(),
            )
            _ -> #(
              update_member(model, fn(member) {
                MemberModel(
                  ..member,
                  member_task_types: Failed(err),
                  member_task_types_pending: 0,
                )
              }),
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
        AdminRuleMetricsFromChangedAndRefresh(from) ->
          admin_workflow.handle_rule_metrics_tab_from_changed_and_refresh(
            model,
            from,
          )
        AdminRuleMetricsToChangedAndRefresh(to) ->
          admin_workflow.handle_rule_metrics_tab_to_changed_and_refresh(
            model,
            to,
          )
        AdminRuleMetricsRefreshClicked ->
          admin_workflow.handle_rule_metrics_tab_refresh_clicked(model)
        AdminRuleMetricsQuickRangeClicked(from, to) ->
          admin_workflow.handle_rule_metrics_tab_quick_range_clicked(
            model,
            from,
            to,
          )
        // Rule metrics drill-down
        AdminRuleMetricsWorkflowExpanded(workflow_id) ->
          admin_workflow.handle_rule_metrics_workflow_expanded(
            model,
            workflow_id,
          )
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
          admin_workflow.handle_rule_metrics_rule_details_fetched_ok(
            model,
            details,
          )
        AdminRuleMetricsRuleDetailsFetched(Error(err)) ->
          admin_workflow.handle_rule_metrics_rule_details_fetched_error(
            model,
            err,
          )
        AdminRuleMetricsExecutionsFetched(Ok(response)) ->
          admin_workflow.handle_rule_metrics_executions_fetched_ok(
            model,
            response,
          )
        AdminRuleMetricsExecutionsFetched(Error(err)) ->
          admin_workflow.handle_rule_metrics_executions_fetched_error(
            model,
            err,
          )
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
        MemberPositionEditClosed ->
          pool_workflow.handle_position_edit_closed(model)
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
        MemberTaskDetailsClosed ->
          tasks_workflow.handle_task_details_closed(model)

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

        // Cards (Fichas) handlers - list loading and dialog mode
        CardsFetched(Ok(cards)) ->
          admin_workflow.handle_cards_fetched_ok(model, cards)
        CardsFetched(Error(err)) ->
          admin_workflow.handle_cards_fetched_error(model, err)
        OpenCardDialog(mode) ->
          admin_workflow.handle_open_card_dialog(model, mode)
        CloseCardDialog -> admin_workflow.handle_close_card_dialog(model)
        // Cards (Fichas) - component events
        CardCrudCreated(card) ->
          admin_workflow.handle_card_crud_created(model, card)
        CardCrudUpdated(card) ->
          admin_workflow.handle_card_crud_updated(model, card)
        CardCrudDeleted(card_id) ->
          admin_workflow.handle_card_crud_deleted(model, card_id)
        // Cards - filter changes (Story 4.9 AC7-8, UX improvements)
        CardsShowEmptyToggled -> #(
          update_admin(model, fn(admin) {
            AdminModel(..admin, cards_show_empty: !model.admin.cards_show_empty)
          }),
          effect.none(),
        )
        CardsShowCompletedToggled -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              cards_show_completed: !model.admin.cards_show_completed,
            )
          }),
          effect.none(),
        )
        CardsStateFilterChanged(state_str) -> {
          let filter = case state_str {
            "" -> opt.None
            "pendiente" -> opt.Some(card.Pendiente)
            "en_curso" -> opt.Some(card.EnCurso)
            "cerrada" -> opt.Some(card.Cerrada)
            _ -> opt.None
          }
          #(
            update_admin(model, fn(admin) {
              AdminModel(..admin, cards_state_filter: filter)
            }),
            effect.none(),
          )
        }
        CardsSearchChanged(query) -> #(
          update_admin(model, fn(admin) {
            AdminModel(..admin, cards_search: query)
          }),
          effect.none(),
        )

        // Card detail (member view) handlers - component manages internal state
        OpenCardDetail(card_id) -> #(
          update_member(model, fn(member) {
            MemberModel(..member, card_detail_open: opt.Some(card_id))
          }),
          effect.none(),
        )
        CloseCardDetail -> #(
          update_member(model, fn(member) {
            MemberModel(..member, card_detail_open: opt.None)
          }),
          effect.none(),
        )

        // Workflows handlers
        WorkflowsProjectFetched(Ok(workflows)) ->
          admin_workflow.handle_workflows_project_fetched_ok(model, workflows)
        WorkflowsProjectFetched(Error(err)) ->
          admin_workflow.handle_workflows_project_fetched_error(model, err)
        // Workflow dialog control (component pattern)
        OpenWorkflowDialog(mode) ->
          admin_workflow.handle_open_workflow_dialog(model, mode)
        CloseWorkflowDialog ->
          admin_workflow.handle_close_workflow_dialog(model)
        // Workflow component events
        WorkflowCrudCreated(workflow) ->
          admin_workflow.handle_workflow_crud_created(model, workflow)
        WorkflowCrudUpdated(workflow) ->
          admin_workflow.handle_workflow_crud_updated(model, workflow)
        WorkflowCrudDeleted(workflow_id) ->
          admin_workflow.handle_workflow_crud_deleted(model, workflow_id)

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

        // Rules - dialog mode control (component pattern)
        OpenRuleDialog(mode) ->
          admin_workflow.handle_open_rule_dialog(model, mode)
        CloseRuleDialog -> admin_workflow.handle_close_rule_dialog(model)

        // Rules - component events (rule-crud-dialog emits these)
        RuleCrudCreated(rule) ->
          admin_workflow.handle_rule_crud_created(model, rule)
        RuleCrudUpdated(rule) ->
          admin_workflow.handle_rule_crud_updated(model, rule)
        RuleCrudDeleted(rule_id) ->
          admin_workflow.handle_rule_crud_deleted(model, rule_id)

        // Rule templates handlers
        RuleTemplatesClicked(_rule_id) -> #(model, effect.none())
        RuleTemplatesFetched(Ok(templates)) ->
          admin_workflow.handle_rule_templates_fetched_ok(model, templates)
        RuleTemplatesFetched(Error(err)) ->
          admin_workflow.handle_rule_templates_fetched_error(model, err)
        RuleAttachTemplateSelected(template_id) ->
          admin_workflow.handle_rule_attach_template_selected(
            model,
            template_id,
          )
        RuleAttachTemplateSubmitted -> #(model, effect.none())
        RuleTemplateAttached(Ok(templates)) ->
          admin_workflow.handle_rule_template_attached_ok(model, templates)
        RuleTemplateAttached(Error(err)) ->
          admin_workflow.handle_rule_template_attached_error(model, err)
        RuleTemplateDetachClicked(_template_id) -> #(model, effect.none())
        RuleTemplateDetached(Ok(_)) -> #(model, effect.none())
        RuleTemplateDetached(Error(err)) ->
          admin_workflow.handle_rule_template_detached_error(model, err)

        // Story 4.10: Rule template attachment UI handlers
        RuleExpandToggled(rule_id) ->
          admin_workflow.handle_rule_expand_toggled(model, rule_id)
        AttachTemplateModalOpened(rule_id) ->
          admin_workflow.handle_attach_template_modal_opened(model, rule_id)
        AttachTemplateModalClosed ->
          admin_workflow.handle_attach_template_modal_closed(model)
        AttachTemplateSelected(template_id) ->
          admin_workflow.handle_attach_template_selected(model, template_id)
        AttachTemplateSubmitted ->
          admin_workflow.handle_attach_template_submitted(model)
        AttachTemplateSucceeded(rule_id, templates) ->
          admin_workflow.handle_attach_template_succeeded(
            model,
            rule_id,
            templates,
          )
        AttachTemplateFailed(err) ->
          admin_workflow.handle_attach_template_failed(model, err)
        TemplateDetachClicked(rule_id, template_id) ->
          admin_workflow.handle_template_detach_clicked(
            model,
            rule_id,
            template_id,
          )
        TemplateDetachSucceeded(rule_id, template_id) ->
          admin_workflow.handle_template_detach_succeeded(
            model,
            rule_id,
            template_id,
          )
        TemplateDetachFailed(rule_id, template_id, err) ->
          admin_workflow.handle_template_detach_failed(
            model,
            rule_id,
            template_id,
            err,
          )

        // Task templates handlers
        TaskTemplatesProjectFetched(Ok(templates)) ->
          admin_workflow.handle_task_templates_project_fetched_ok(
            model,
            templates,
          )
        TaskTemplatesProjectFetched(Error(err)) ->
          admin_workflow.handle_task_templates_project_fetched_error(model, err)

        // Task templates - dialog mode control (component pattern)
        OpenTaskTemplateDialog(mode) ->
          admin_workflow.handle_open_task_template_dialog(model, mode)
        CloseTaskTemplateDialog ->
          admin_workflow.handle_close_task_template_dialog(model)

        // Task templates - component events
        TaskTemplateCrudCreated(template) ->
          admin_workflow.handle_task_template_crud_created(model, template)
        TaskTemplateCrudUpdated(template) ->
          admin_workflow.handle_task_template_crud_updated(model, template)
        TaskTemplateCrudDeleted(template_id) ->
          admin_workflow.handle_task_template_crud_deleted(model, template_id)
      }
    }
  }
}
// =============================================================================
// Card Add Task Handler
// Card add task functionality moved to card_detail_modal component
