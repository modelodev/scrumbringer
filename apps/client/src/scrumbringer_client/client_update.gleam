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
//// ## Structure Note
////
//// Central TEA update hub with thin dispatch to feature handlers.
//// Admin/Pool subtrees are delegated to feature update modules
//// to keep this file focused on top-level orchestration.

import domain/org_role
import domain/project.{type Project}
import domain/remote.{Failed, Loaded, Loading, NotAsked}
import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/uri.{type Uri}
import lustre/effect.{type Effect}

import scrumbringer_client/accept_invite
import scrumbringer_client/app/effects as app_effects
import scrumbringer_client/assignments_view_mode

// API modules
import scrumbringer_client/api/cards as api_cards
import scrumbringer_client/api/metrics as api_metrics
import scrumbringer_client/api/org as api_org
import scrumbringer_client/api/projects as api_projects
import scrumbringer_client/api/tasks as api_tasks

// Domain types
import domain/task.{type TaskFilters, TaskFilters}
import domain/task_status
import scrumbringer_client/client_ffi
import scrumbringer_client/member_section
import scrumbringer_client/permissions
import scrumbringer_client/pool_prefs
import scrumbringer_client/reset_password
import scrumbringer_client/router
import scrumbringer_client/state/normalized_store
import scrumbringer_client/theme
import scrumbringer_client/token_flow
import scrumbringer_client/ui/toast
import scrumbringer_client/url_state

import scrumbringer_client/client_state
import scrumbringer_client/client_state/admin as admin_state
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/admin/members as admin_members
import scrumbringer_client/client_state/admin/metrics as admin_metrics
import scrumbringer_client/client_state/admin/task_types as admin_task_types
import scrumbringer_client/client_state/auth as auth_state
import scrumbringer_client/client_state/member as member_state
import scrumbringer_client/client_state/member/pool as member_pool
import scrumbringer_client/client_state/member/skills as member_skills
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/client_state/ui as ui_state
import scrumbringer_client/features/hydration/update as hydration_workflow

// Story 4.10: Rule template attachment UI

// Workflows
// Rules
// Rule templates
// Task templates

import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/auth/update as auth_workflow
import scrumbringer_client/features/i18n/update as i18n_workflow
import scrumbringer_client/features/layout/update as layout_workflow
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/features/pool/update as pool_workflow
import scrumbringer_client/features/workflows/update as workflows_workflow
import scrumbringer_client/helpers/options as helpers_options
import scrumbringer_client/helpers/selection as helpers_selection

// ---------------------------------------------------------------------------
// Routing helpers
// ---------------------------------------------------------------------------

fn current_route(model: client_state.Model) -> router.Route {
  case model.core.page {
    client_state.Login -> router.Login

    client_state.AcceptInvite -> {
      let token_flow.Model(token: token, ..) = model.auth.accept_invite
      router.AcceptInvite(token)
    }

    client_state.ResetPassword -> {
      let token_flow.Model(token: token, ..) = model.auth.reset_password
      router.ResetPassword(token)
    }

    // Story 4.5: Use Config or Org routes based on section type
    client_state.Admin ->
      case model.core.active_section {
        permissions.Invites
        | permissions.OrgSettings
        | permissions.Projects
        | permissions.Assignments
        | permissions.Metrics -> router.Org(model.core.active_section)
        _ ->
          router.Config(
            model.core.active_section,
            model.core.selected_project_id,
          )
      }

    client_state.Member -> {
      let state = case model.core.selected_project_id {
        opt.Some(project_id) ->
          url_state.with_project(url_state.empty(), project_id)
        opt.None -> url_state.empty()
      }
      let state = url_state.with_view(state, model.member.pool.view_mode)
      router.Member(model.member.pool.member_section, state)
    }
  }
}

pub fn toast_action_to_msg(action: toast.ToastActionKind) -> client_state.Msg {
  case action {
    toast.ClearPoolFilters ->
      client_state.pool_msg(pool_messages.MemberClearFilters)
    toast.ViewTask(task_id) ->
      client_state.pool_msg(pool_messages.MemberTaskDetailsOpened(task_id))
  }
}

fn replace_url(model: client_state.Model) -> Effect(client_state.Msg) {
  router.replace(current_route(model))
}

/// Registers keydown effect.
///
/// Example:
///   register_keydown_effect(...)
pub fn register_keydown_effect() -> Effect(client_state.Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_keydown(fn(payload) {
      let #(key, ctrl, meta, shift, is_editing, modal_open) = payload
      dispatch(
        client_state.pool_msg(
          pool_messages.GlobalKeyDown(pool_prefs.KeyEvent(
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
pub fn write_url(
  mode: client_state.NavMode,
  route: router.Route,
) -> Effect(client_state.Msg) {
  case mode {
    client_state.Push -> router.push(route)
    client_state.Replace -> router.replace(route)
  }
}

// Justification: large function kept intact to preserve cohesive UI logic.
fn apply_route_fields(
  model: client_state.Model,
  route: router.Route,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case route {
    router.Login -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Login,
              selected_project_id: opt.None,
            )
          }),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              ),
            )
          },
        )
      #(model, effect.none())
    }

    router.AcceptInvite(token) -> {
      let #(new_accept_model, action) = accept_invite.init(token)
      let model =
        client_state.update_member(
          client_state.update_auth(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.AcceptInvite,
                selected_project_id: opt.None,
              )
            }),
            fn(auth) {
              auth_state.AuthModel(..auth, accept_invite: new_accept_model)
            },
          ),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              ),
            )
          },
        )

      #(model, auth_workflow.accept_invite_effect(action))
    }

    router.ResetPassword(token) -> {
      let #(new_reset_model, action) = reset_password.init(token)
      let model =
        client_state.update_member(
          client_state.update_auth(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.ResetPassword,
                selected_project_id: opt.None,
              )
            }),
            fn(auth) {
              auth_state.AuthModel(..auth, reset_password: new_reset_model)
            },
          ),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              ),
            )
          },
        )

      #(model, auth_workflow.reset_password_effect(action))
    }

    // Story 4.5: Config routes - project-scoped configuration
    router.Config(section, project_id) -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Admin,
              active_section: section,
              selected_project_id: project_id,
            )
          }),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              ),
            )
          },
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    // Story 4.5: Org routes - org-scoped administration
    router.Org(section) -> {
      let model =
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Admin,
              active_section: section,
              selected_project_id: opt.None,
            )
          }),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              ),
            )
          },
        )

      let model = case section {
        permissions.Assignments ->
          client_state.update_admin(model, fn(admin) {
            let state_types.AssignmentsModel(
              view_mode: _,
              search_input: search_input,
              search_query: search_query,
              project_members: project_members,
              user_projects: user_projects,
              expanded_projects: expanded_projects,
              expanded_users: expanded_users,
              inline_add_context: _,
              inline_add_selection: _,
              inline_add_search: _,
              inline_add_role: inline_add_role,
              inline_add_in_flight: _,
              inline_remove_confirm: _,
              role_change_in_flight: _,
              role_change_previous: _,
            ) = admin.assignments
            admin_state.AdminModel(
              ..admin,
              assignments: state_types.AssignmentsModel(
                view_mode: assignments_view_mode.ByProject,
                search_input: search_input,
                search_query: search_query,
                project_members: project_members,
                user_projects: user_projects,
                expanded_projects: expanded_projects,
                expanded_users: expanded_users,
                inline_add_context: opt.None,
                inline_add_selection: opt.None,
                inline_add_search: "",
                inline_add_role: inline_add_role,
                inline_add_in_flight: False,
                inline_remove_confirm: opt.None,
                role_change_in_flight: opt.None,
                role_change_previous: opt.None,
              ),
            )
          })
        _ -> model
      }
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    router.Member(section, state) -> {
      let project_id = url_state.project(state)
      let capabilities_fx = case model.core.page, project_id {
        client_state.Admin, opt.Some(pid) ->
          api_org.list_project_capabilities(pid, fn(result) {
            client_state.admin_msg(admin_messages.CapabilitiesFetched(result))
          })
        _, _ -> effect.none()
      }

      // Update view mode if provided in URL
      let new_view =
        opt.unwrap(url_state.view_param(state), model.member.pool.view_mode)

      #(
        client_state.update_member(
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(
              ..core,
              page: client_state.Member,
              selected_project_id: project_id,
            )
          }),
          fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_section: section,
                view_mode: new_view,
                member_drag: state_types.DragIdle,
                member_pool_drag: state_types.PoolDragIdle,
              ),
            )
          },
        ),
        capabilities_fx,
      )
    }
  }
}

fn hydrate_model(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  hydration_workflow.hydrate_model(
    model,
    hydration_workflow.Context(
      current_route: current_route,
      handle_navigate_to: handle_navigate_to,
      member_refresh: member_refresh,
    ),
  )
}

// Justification: nested case improves clarity for branching logic.
fn handle_url_changed(
  model: client_state.Model,
  uri: Uri,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let is_mobile = client_ffi.is_mobile()

  let model =
    client_state.update_ui(model, fn(ui) {
      ui_state.UiModel(..ui, is_mobile: is_mobile)
    })

  let parsed =
    router.parse_uri(uri)
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
          let model = apply_assignments_view_from_url(model, route, uri)
          let #(model, hyd_fx) = hydrate_model(model)
          #(model, effect.batch([route_fx, hyd_fx, title_fx]))
        }
      }

    router.Redirect(_) -> {
      let #(model, route_fx) = apply_route_fields(model, route)
      let model = apply_assignments_view_from_url(model, route, uri)
      let #(model, hyd_fx) = hydrate_model(model)
      #(
        model,
        effect.batch([
          write_url(client_state.Replace, route),
          route_fx,
          hyd_fx,
          title_fx,
        ]),
      )
    }
  }
}

fn apply_assignments_view_from_url(
  model: client_state.Model,
  route: router.Route,
  uri: Uri,
) -> client_state.Model {
  case route {
    router.Org(permissions.Assignments) ->
      case url_state.parse(uri, url_state.OrgAssignments) {
        url_state.Parsed(state) | url_state.Redirect(state) ->
          case url_state.assignments_view_param(state) {
            opt.Some(view_mode) ->
              client_state.update_admin(model, fn(admin) {
                let state_types.AssignmentsModel(
                  view_mode: _,
                  search_input: search_input,
                  search_query: search_query,
                  project_members: project_members,
                  user_projects: user_projects,
                  expanded_projects: expanded_projects,
                  expanded_users: expanded_users,
                  inline_add_context: inline_add_context,
                  inline_add_selection: inline_add_selection,
                  inline_add_search: inline_add_search,
                  inline_add_role: inline_add_role,
                  inline_add_in_flight: inline_add_in_flight,
                  inline_remove_confirm: inline_remove_confirm,
                  role_change_in_flight: role_change_in_flight,
                  role_change_previous: role_change_previous,
                ) = admin.assignments
                admin_state.AdminModel(
                  ..admin,
                  assignments: state_types.AssignmentsModel(
                    view_mode: view_mode,
                    search_input: search_input,
                    search_query: search_query,
                    project_members: project_members,
                    user_projects: user_projects,
                    expanded_projects: expanded_projects,
                    expanded_users: expanded_users,
                    inline_add_context: inline_add_context,
                    inline_add_selection: inline_add_selection,
                    inline_add_search: inline_add_search,
                    inline_add_role: inline_add_role,
                    inline_add_in_flight: inline_add_in_flight,
                    inline_remove_confirm: inline_remove_confirm,
                    role_change_in_flight: role_change_in_flight,
                    role_change_previous: role_change_previous,
                  ),
                )
              })
            opt.None -> model
          }
      }
    _ -> model
  }
}

fn handle_navigate_to(
  model: client_state.Model,
  route: router.Route,
  mode: client_state.NavMode,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next_route, next_mode) = case model.ui.is_mobile, route {
    True, router.Member(member_section.Pool, state) -> #(
      router.Member(member_section.MyBar, state),
      client_state.Replace,
    )
    _, _ -> #(route, mode)
  }

  case next_route == current_route(model) {
    True -> #(model, effect.none())

    False -> {
      let model =
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, mobile_drawer: ui_state.DrawerClosed)
        })
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

fn bootstrap_admin(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let is_admin = case model.core.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  // Capabilities and member capability IDs are now project-scoped
  // They will be fetched when a project is selected
  let model =
    client_state.update_admin(
      client_state.update_core(model, fn(core) {
        client_state.CoreModel(..core, projects: Loading)
      }),
      fn(admin) {
        admin_state.AdminModel(
          ..admin,
          invites: admin_invites.Model(
            ..admin.invites,
            invite_links: case is_admin {
              True -> Loading
              False -> admin.invites.invite_links
            },
          ),
        )
      },
    )

  let effects = [
    api_projects.list_projects(fn(result) {
      client_state.admin_msg(admin_messages.ProjectsFetched(result))
    }),
  ]

  // Fetch capabilities if project is selected
  let effects = case model.core.selected_project_id {
    opt.Some(project_id) -> [
      api_org.list_project_capabilities(project_id, fn(result) {
        client_state.admin_msg(admin_messages.CapabilitiesFetched(result))
      }),
      ..effects
    ]
    opt.None -> effects
  }

  // Fetch member capability IDs if project and user are available
  let effects = case model.core.selected_project_id, model.core.user {
    opt.Some(project_id), opt.Some(user) -> [
      api_tasks.get_member_capability_ids(project_id, user.id, fn(result) {
        client_state.pool_msg(pool_messages.MemberMyCapabilityIdsFetched(result))
      }),
      ..effects
    ]
    _, _ -> effects
  }

  let effects = case is_admin {
    True -> [
      api_org.list_invite_links(fn(result) {
        client_state.admin_msg(admin_messages.InviteLinksFetched(result))
      }),
      ..effects
    ]
    False -> effects
  }

  #(model, effect.batch(effects))
}

/// Provides refresh section for test.
///
/// Example:
///   refresh_section_for_test(...)
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn refresh_section_for_test(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.active_section {
    permissions.Invites -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(
            ..admin,
            invites: admin_invites.Model(..admin.invites, invite_links: Loading),
          )
        })
      #(
        model,
        api_org.list_invite_links(fn(result) {
          client_state.admin_msg(admin_messages.InviteLinksFetched(result))
        }),
      )
    }

    permissions.OrgSettings -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let members = admin.members
          admin_state.AdminModel(
            ..admin,
            members: admin_members.Model(
              ..members,
              org_settings_users: Loading,
              org_settings_save_in_flight: False,
              org_settings_error: opt.None,
              org_settings_error_user_id: opt.None,
            ),
          )
        })

      #(
        model,
        api_org.list_org_users("", fn(result) {
          client_state.admin_msg(admin_messages.OrgSettingsUsersFetched(result))
        }),
      )
    }

    permissions.Projects -> #(
      model,
      api_projects.list_projects(fn(result) {
        client_state.admin_msg(admin_messages.ProjectsFetched(result))
      }),
    )

    permissions.Assignments -> {
      let #(model, fx) = refresh_assignments(model)
      #(model, fx)
    }

    permissions.Metrics -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let metrics = admin.metrics
          admin_state.AdminModel(
            ..admin,
            metrics: admin_metrics.Model(
              ..metrics,
              admin_metrics_overview: Loading,
            ),
          )
        })

      let overview_fx =
        api_metrics.get_org_metrics_overview(30, fn(result) {
          client_state.pool_msg(pool_messages.AdminMetricsOverviewFetched(
            result,
          ))
        })

      case model.core.selected_project_id {
        opt.None -> #(model, overview_fx)

        opt.Some(project_id) -> {
          let model =
            client_state.update_admin(model, fn(admin) {
              let metrics = admin.metrics
              admin_state.AdminModel(
                ..admin,
                metrics: admin_metrics.Model(
                  ..metrics,
                  admin_metrics_project_tasks: Loading,
                  admin_metrics_project_id: opt.Some(project_id),
                ),
              )
            })

          let tasks_fx =
            api_metrics.get_org_metrics_project_tasks(
              project_id,
              30,
              fn(result) {
                client_state.pool_msg(
                  pool_messages.AdminMetricsProjectTasksFetched(result),
                )
              },
            )

          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(model, effect.batch([overview_fx, tasks_fx, ..right_panel_fx]))
        }
      }
    }

    permissions.RuleMetrics -> {
      // Initialize with default date range (last 30 days)
      let #(model, fx) = workflows_workflow.handle_rule_metrics_tab_init(model)
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
                client_state.admin_msg(admin_messages.CapabilitiesFetched(
                  result,
                ))
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
            client_state.update_admin(model, fn(admin) {
              let members = admin.members
              admin_state.AdminModel(
                ..admin,
                members: admin_members.Model(
                  ..members,
                  members: Loading,
                  members_project_id: opt.Some(project_id),
                  org_users_cache: Loading,
                ),
              )
            })
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_projects.list_project_members(project_id, fn(result) {
                client_state.admin_msg(admin_messages.MembersFetched(result))
              }),
              api_org.list_org_users("", fn(result) {
                client_state.admin_msg(admin_messages.OrgUsersCacheFetched(
                  result,
                ))
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
            client_state.update_admin(model, fn(admin) {
              let task_types = admin.task_types
              admin_state.AdminModel(
                ..admin,
                task_types: admin_task_types.Model(
                  ..task_types,
                  task_types: Loading,
                  task_types_project_id: opt.Some(project_id),
                ),
              )
            })
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_tasks.list_task_types(project_id, fn(result) {
                client_state.admin_msg(admin_messages.TaskTypesFetched(result))
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
        model.admin.task_types.task_types
      {
        opt.Some(project_id), NotAsked ->
          api_tasks.list_task_types(project_id, fn(result) {
            client_state.admin_msg(admin_messages.TaskTypesFetched(result))
          })
        opt.Some(project_id), Failed(_) ->
          api_tasks.list_task_types(project_id, fn(result) {
            client_state.admin_msg(admin_messages.TaskTypesFetched(result))
          })
        _, _ -> effect.none()
      }
      #(model, effect.batch([fx, task_types_fx, ..right_panel_fx]))
    }
  }
}

fn refresh_assignments(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(model, projects_fx) = refresh_assignments_projects(model)
  let #(model, users_fx) = refresh_assignments_org_users(model)
  let #(model, members_fx) = refresh_assignments_project_members(model)
  let #(model, user_projects_fx) = refresh_assignments_user_projects(model)
  let #(model, metrics_fx) = refresh_assignments_metrics(model)
  let #(model, metrics_users_fx) = refresh_assignments_metrics_users(model)
  #(
    model,
    effect.batch([
      projects_fx,
      users_fx,
      members_fx,
      user_projects_fx,
      metrics_fx,
      metrics_users_fx,
    ]),
  )
}

fn refresh_assignments_metrics(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.admin.metrics.admin_metrics_overview {
    Loading | Loaded(_) -> #(model, effect.none())
    _ -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let metrics = admin.metrics
          admin_state.AdminModel(
            ..admin,
            metrics: admin_metrics.Model(
              ..metrics,
              admin_metrics_overview: Loading,
            ),
          )
        })
      let fx =
        api_metrics.get_org_metrics_overview(30, fn(result) {
          client_state.pool_msg(pool_messages.AdminMetricsOverviewFetched(
            result,
          ))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_metrics_users(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.admin.metrics.admin_metrics_users {
    Loading | Loaded(_) -> #(model, effect.none())
    _ -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let metrics = admin.metrics
          admin_state.AdminModel(
            ..admin,
            metrics: admin_metrics.Model(
              ..metrics,
              admin_metrics_users: Loading,
            ),
          )
        })
      let fx =
        api_metrics.get_org_metrics_users(30, fn(result) {
          client_state.pool_msg(pool_messages.AdminMetricsUsersFetched(result))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_projects(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.projects {
    Loading | Loaded(_) -> #(model, effect.none())
    _ -> {
      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(..core, projects: Loading)
        })
      let fx =
        api_projects.list_projects(fn(result) {
          client_state.admin_msg(admin_messages.ProjectsFetched(result))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_org_users(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.admin.members.org_users_cache {
    Loading | Loaded(_) -> #(model, effect.none())
    _ -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          let members = admin.members
          admin_state.AdminModel(
            ..admin,
            members: admin_members.Model(..members, org_users_cache: Loading),
          )
        })
      let fx =
        api_org.list_org_users("", fn(result) {
          client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
        })
      #(model, fx)
    }
  }
}

fn refresh_assignments_project_members(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let projects = helpers_selection.active_projects(model)
  case projects {
    [] -> #(model, effect.none())
    _ -> {
      let assignments = model.admin.assignments

      let #(next_assignments, effects) =
        list.fold(projects, #(assignments, []), fn(state, project) {
          let #(current, fx) = state
          let state_types.AssignmentsModel(project_members: members, ..) =
            current
          let should_fetch = case dict.get(members, project.id) {
            Ok(Loading) -> False
            Ok(Loaded(_)) -> False
            Ok(NotAsked) -> True
            Ok(Failed(_)) -> True
            Error(_) -> True
          }
          case should_fetch {
            False -> #(current, fx)
            True -> {
              let updated =
                state_types.AssignmentsModel(
                  ..current,
                  project_members: dict.insert(members, project.id, Loading),
                )
              let effect =
                api_projects.list_project_members(project.id, fn(result) {
                  client_state.admin_msg(
                    admin_messages.AssignmentsProjectMembersFetched(
                      project.id,
                      result,
                    ),
                  )
                })
              #(updated, [effect, ..fx])
            }
          }
        })

      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, assignments: next_assignments)
        })
      #(model, effect.batch(list.reverse(effects)))
    }
  }
}

fn refresh_assignments_user_projects(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.admin.members.org_users_cache {
    Loaded(users) -> {
      let assignments = model.admin.assignments

      let #(next_assignments, effects) =
        list.fold(users, #(assignments, []), fn(state, user) {
          let #(current, fx) = state
          let state_types.AssignmentsModel(user_projects: projects, ..) =
            current
          let should_fetch = case dict.get(projects, user.id) {
            Ok(Loading) -> False
            Ok(Loaded(_)) -> False
            Ok(NotAsked) -> True
            Ok(Failed(_)) -> True
            Error(_) -> True
          }
          case should_fetch {
            False -> #(current, fx)
            True -> {
              let updated =
                state_types.AssignmentsModel(
                  ..current,
                  user_projects: dict.insert(projects, user.id, Loading),
                )
              let effect =
                api_org.list_user_projects(user.id, fn(result) {
                  client_state.admin_msg(
                    admin_messages.AssignmentsUserProjectsFetched(
                      user.id,
                      result,
                    ),
                  )
                })
              #(updated, [effect, ..fx])
            }
          }
        })

      let model =
        client_state.update_admin(model, fn(admin) {
          admin_state.AdminModel(..admin, assignments: next_assignments)
        })
      #(model, effect.batch(list.reverse(effects)))
    }
    _ -> #(model, effect.none())
  }
}

/// Fetches tasks and cards for the right panel in config views.
/// This ensures "My Tasks" and "My Cards" sections are populated
/// even when navigating directly to config routes.
/// Returns updated model (with pending counters) and list of effects.
fn fetch_right_panel_data(
  model: client_state.Model,
) -> #(client_state.Model, List(Effect(client_state.Msg))) {
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
            blocked: opt.None,
          ),
          fn(result) {
            client_state.pool_msg(pool_messages.MemberProjectTasksFetched(
              project_id,
              result,
            ))
          },
        )

      // Fetch cards for "My Cards" section
      let cards_effect =
        api_cards.list_cards(project_id, fn(result) {
          client_state.pool_msg(pool_messages.CardsFetched(result))
        })

      // Update model with pending counter and loading state
      let model =
        client_state.update_admin(
          client_state.update_member(model, fn(member) {
            let pool = member.pool
            member_state.MemberModel(
              ..member,
              pool: member_pool.Model(
                ..pool,
                member_tasks_pending: 1,
                member_tasks_by_project: dict.new(),
              ),
            )
          }),
          fn(admin) {
            let cards = admin.cards
            admin_state.AdminModel(
              ..admin,
              cards: admin_cards.Model(
                ..cards,
                cards: Loading,
                cards_project_id: opt.Some(project_id),
              ),
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
/// - client_state.Member metrics
///
/// The batched fetching logic and state updates are tightly coupled
/// and splitting would complicate the refresh coordination.
/// Justification: large function kept intact to preserve cohesive UI logic.
fn member_refresh(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.member.pool.member_section {
    member_section.MySkills -> refresh_member_capabilities(model)
    member_section.Fichas -> refresh_member_cards(model)
    _ -> refresh_member_tasks(model)
  }
}

fn refresh_member_capabilities(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> #(
      client_state.update_member(model, fn(member) {
        let skills = member.skills
        member_state.MemberModel(
          ..member,
          skills: member_skills.Model(..skills, member_capabilities: Loading),
        )
      }),
      api_org.list_project_capabilities(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberProjectCapabilitiesFetched(
          result,
        ))
      }),
    )
    opt.None -> #(
      client_state.update_member(model, fn(member) {
        let skills = member.skills
        member_state.MemberModel(
          ..member,
          skills: member_skills.Model(..skills, member_capabilities: NotAsked),
        )
      }),
      effect.none(),
    )
  }
}

fn refresh_member_cards(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let projects = helpers_selection.active_projects(model)
  let project_ids = project_ids_for_member_refresh(model, projects)

  case project_ids {
    [] -> reset_member_cards(model)
    _ -> refresh_member_cards_for_projects(model, project_ids)
  }
}

fn reset_member_cards(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_cards_store: normalized_store.new(),
          member_cards: NotAsked,
        ),
      )
    }),
    effect.none(),
  )
}

fn refresh_member_cards_for_projects(
  model: client_state.Model,
  project_ids: List(Int),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let effects =
    list.map(project_ids, fn(project_id) {
      api_cards.list_cards(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
          project_id,
          result,
        ))
      })
    })

  let next =
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      let next_store =
        normalized_store.with_pending(
          pool.member_cards_store,
          list.length(project_ids),
        )
      let next_member_cards = case pool.member_cards {
        Loaded(_) -> pool.member_cards
        _ -> Loading
      }
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_cards_store: next_store,
          member_cards: next_member_cards,
        ),
      )
    })

  #(next, effect.batch(effects))
}

fn refresh_member_tasks(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let projects = helpers_selection.active_projects(model)
  let project_ids = project_ids_for_member_refresh(model, projects)

  case project_ids {
    [] -> reset_member_tasks(model)
    _ -> refresh_member_data(model, project_ids)
  }
}

fn project_ids_for_member_refresh(
  model: client_state.Model,
  projects: List(Project),
) -> List(Int) {
  case model.core.selected_project_id {
    opt.Some(project_id) -> [project_id]
    opt.None -> projects |> list.map(fn(p) { p.id })
  }
}

fn reset_member_tasks(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  #(
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: NotAsked,
          member_tasks_pending: 0,
          member_tasks_by_project: dict.new(),
          member_task_types: NotAsked,
          member_task_types_pending: 0,
          member_task_types_by_project: dict.new(),
          people_roster: NotAsked,
          people_expansions: dict.new(),
        ),
      )
    }),
    effect.none(),
  )
}

fn refresh_member_data(
  model: client_state.Model,
  project_ids: List(Int),
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let filters = task_filters_for_member_section(model)

  let positions_effect =
    api_tasks.list_me_task_positions(model.core.selected_project_id, fn(result) {
      client_state.pool_msg(pool_messages.MemberPositionsFetched(result))
    })

  let task_effects =
    list.map(project_ids, fn(project_id) {
      api_tasks.list_project_tasks(project_id, filters, fn(result) {
        client_state.pool_msg(pool_messages.MemberProjectTasksFetched(
          project_id,
          result,
        ))
      })
    })

  let task_type_effects =
    list.map(project_ids, fn(project_id) {
      api_tasks.list_task_types(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberTaskTypesFetched(
          project_id,
          result,
        ))
      })
    })

  let member_card_effects =
    list.map(project_ids, fn(project_id) {
      api_cards.list_cards(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberProjectCardsFetched(
          project_id,
          result,
        ))
      })
    })

  let roster_project_id = case model.core.selected_project_id, project_ids {
    opt.Some(project_id), _ -> opt.Some(project_id)
    opt.None, [project_id, ..] -> opt.Some(project_id)
    opt.None, [] -> opt.None
  }

  let roster_effect = case roster_project_id {
    opt.Some(project_id) ->
      api_projects.list_project_members(project_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberPeopleRosterFetched(result))
      })
    opt.None -> effect.none()
  }

  let should_fetch_org_users = case model.admin.members.org_users_cache {
    Loading | Loaded(_) -> False
    _ -> True
  }

  let org_users_effect = case should_fetch_org_users {
    True ->
      api_org.list_org_users("", fn(result) {
        client_state.admin_msg(admin_messages.OrgUsersCacheFetched(result))
      })
    False -> effect.none()
  }

  let effects =
    list.append(
      task_effects,
      list.append(
        task_type_effects,
        list.append(
          [positions_effect, roster_effect, org_users_effect],
          member_card_effects,
        ),
      ),
    )

  let next =
    client_state.update_member(model, fn(member) {
      let pool = member.pool
      member_state.MemberModel(
        ..member,
        pool: member_pool.Model(
          ..pool,
          member_tasks: Loading,
          member_tasks_pending: list.length(project_ids),
          member_tasks_by_project: dict.new(),
          member_task_types: Loading,
          member_task_types_pending: list.length(project_ids),
          member_task_types_by_project: dict.new(),
          people_roster: case roster_project_id {
            opt.Some(_) -> Loading
            opt.None -> NotAsked
          },
          people_expansions: case roster_project_id {
            opt.Some(_) -> pool.people_expansions
            opt.None -> dict.new()
          },
          member_cards_store: normalized_store.with_pending(
            pool.member_cards_store,
            list.length(project_ids),
          ),
          member_cards: case pool.member_cards {
            Loaded(_) -> pool.member_cards
            _ -> Loading
          },
        ),
      )
    })

  let next = case should_fetch_org_users {
    False -> next
    True ->
      client_state.update_admin(next, fn(admin) {
        let members = admin.members
        admin_state.AdminModel(
          ..admin,
          members: admin_members.Model(..members, org_users_cache: Loading),
        )
      })
  }

  #(next, effect.batch(effects))
}

// cards_effects_for_refresh removed from member refresh to avoid admin coupling.

fn task_filters_for_member_section(model: client_state.Model) -> TaskFilters {
  case model.member.pool.member_section {
    member_section.MyBar ->
      TaskFilters(
        status: opt.Some(task_status.Claimed(task_status.Taken)),
        type_id: opt.None,
        capability_id: opt.None,
        q: opt.None,
        blocked: opt.None,
      )

    member_section.Pool ->
      TaskFilters(
        status: opt.None,
        type_id: model.member.pool.member_filters_type_id,
        capability_id: model.member.pool.member_filters_capability_id,
        q: helpers_options.empty_to_opt(model.member.pool.member_filters_q),
        blocked: opt.None,
      )

    _ ->
      TaskFilters(
        status: model.member.pool.member_filters_status,
        type_id: model.member.pool.member_filters_type_id,
        capability_id: model.member.pool.member_filters_capability_id,
        q: helpers_options.empty_to_opt(model.member.pool.member_filters_q),
        blocked: opt.None,
      )
  }
}

/// Provides should pause active task on project change.
///
/// Example:
///   should_pause_active_task_on_project_change(...)
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
/// It handles 163 distinct client_state.Msg variants covering:
/// - Authentication flow (login, logout, password reset)
/// - Navigation and routing
/// - client_state.Admin sections (projects, capabilities, members, task types, metrics, org settings)
/// - client_state.Member sections (pool, tasks, notes, drag-and-drop, timer)
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
/// Justification: large function kept intact to preserve cohesive UI logic.
pub fn update(
  model: client_state.Model,
  msg: client_state.Msg,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case msg {
    // No operation - used for placeholder handlers
    client_state.NoOp -> #(model, effect.none())

    client_state.UrlChanged(uri) -> handle_url_changed(model, uri)

    client_state.NavigateTo(route, mode) ->
      handle_navigate_to(model, route, mode)

    client_state.MeFetched(Ok(user)) -> {
      // Default landing for authenticated users is member pool.
      let default_page = client_state.Member

      // Keep client_state.Admin page if user requested it - hydration will check access
      // after projects load (to determine if user is a project manager)
      let resolved_page = case model.core.page {
        client_state.Member -> client_state.Member
        client_state.Admin -> client_state.Admin
        _ -> default_page
      }

      let model =
        client_state.update_core(model, fn(core) {
          client_state.CoreModel(
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

    client_state.MeFetched(Error(err)) -> {
      case err.status == 401 {
        True -> {
          let model =
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: client_state.Login,
                user: opt.None,
                auth_checked: True,
              )
            })
          #(model, replace_url(model))
        }

        False -> {
          let model =
            client_state.update_auth(
              client_state.update_core(model, fn(core) {
                client_state.CoreModel(
                  ..core,
                  page: client_state.Login,
                  user: opt.None,
                  auth_checked: True,
                )
              }),
              fn(auth) {
                auth_state.AuthModel(..auth, login_error: opt.Some(err.message))
              },
            )

          #(model, replace_url(model))
        }
      }
    }

    client_state.AuthMsg(inner) ->
      auth_workflow.update(
        model,
        inner,
        bootstrap_admin,
        hydrate_model,
        replace_url,
      )

    // New toast system (Story 4.8)
    client_state.ToastShow(message, variant) -> {
      let now = client_ffi.now_ms()
      let next_state = toast.show(model.ui.toast_state, message, variant, now)
      // Schedule tick for auto-dismiss
      let tick_effect =
        app_effects.schedule_timeout(toast.auto_dismiss_ms, fn() {
          client_state.ToastTick(client_ffi.now_ms())
        })
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, toast_state: next_state)
        }),
        tick_effect,
      )
    }

    client_state.ToastShowWithAction(message, variant, action) -> {
      let now = client_ffi.now_ms()
      let next_state =
        toast.show_with_action(
          model.ui.toast_state,
          message,
          variant,
          opt.Some(action),
          now,
        )
      let tick_effect =
        app_effects.schedule_timeout(toast.auto_dismiss_ms, fn() {
          client_state.ToastTick(client_ffi.now_ms())
        })
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, toast_state: next_state)
        }),
        tick_effect,
      )
    }

    client_state.ToastActionTriggered(action) -> {
      let action_msg = toast_action_to_msg(action)

      #(model, effect.from(fn(dispatch) { dispatch(action_msg) }))
    }

    client_state.ToastDismiss(id) -> {
      let next_state = toast.dismiss(model.ui.toast_state, id)
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, toast_state: next_state)
        }),
        effect.none(),
      )
    }

    client_state.ToastTick(now) -> {
      let #(next_state, should_schedule) = toast.tick(model.ui.toast_state, now)
      let tick_effect = case should_schedule {
        True ->
          app_effects.schedule_timeout(1000, fn() {
            client_state.ToastTick(client_ffi.now_ms())
          })
        False -> effect.none()
      }
      #(
        client_state.update_ui(model, fn(ui) {
          ui_state.UiModel(..ui, toast_state: next_state)
        }),
        tick_effect,
      )
    }

    client_state.ThemeSelected(value) -> {
      let next_theme = theme.deserialize(value)

      case next_theme == model.ui.theme {
        True -> #(model, effect.none())

        False -> #(
          client_state.update_ui(model, fn(ui) {
            ui_state.UiModel(..ui, theme: next_theme)
          }),
          effect.from(fn(_dispatch) { theme.save_to_storage(next_theme) }),
        )
      }
    }

    client_state.I18nMsg(inner) -> i18n_workflow.update(model, inner)
    client_state.LayoutMsg(inner) -> layout_workflow.update(model, inner)

    client_state.ProjectSelected(project_id) -> {
      let selected = case int.parse(project_id) {
        Ok(id) -> opt.Some(id)
        Error(_) -> opt.None
      }

      let should_pause =
        should_pause_active_task_on_project_change(
          model.core.page == client_state.Member,
          model.core.selected_project_id,
          selected,
        )

      let model = case selected {
        opt.None ->
          client_state.update_member(
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(..core, selected_project_id: selected)
            }),
            fn(member) {
              let pool = member.pool

              member_state.MemberModel(
                ..member,
                pool: member_pool.Model(
                  ..pool,
                  member_filters_type_id: opt.None,
                  member_task_types: NotAsked,
                ),
              )
            },
          )
        _ ->
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(..core, selected_project_id: selected)
          })
      }

      case model.core.page {
        client_state.Member ->
          refresh_member_after_project_change(model, should_pause)
        _ -> refresh_admin_after_project_change(model)
      }
    }

    client_state.AdminMsg(inner) ->
      admin_workflow.update(
        model,
        inner,
        admin_workflow.Context(
          member_refresh: member_refresh,
          refresh_section_for_test: refresh_section_for_test,
          hydrate_model: hydrate_model,
          replace_url: replace_url,
        ),
      )

    client_state.PoolMsg(inner) ->
      pool_workflow.update(
        model,
        inner,
        pool_workflow.Context(member_refresh: member_refresh),
      )
  }
}

fn refresh_member_after_project_change(
  model: client_state.Model,
  should_pause: Bool,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next, fx) = member_refresh(model)
  let pause_fx = pause_fx_for_project_change(next, should_pause)
  #(next, effect.batch([fx, pause_fx, replace_url(next)]))
}

fn pause_fx_for_project_change(
  model: client_state.Model,
  should_pause: Bool,
) -> Effect(client_state.Msg) {
  case should_pause {
    True -> pause_active_task_fx(model)
    False -> effect.none()
  }
}

fn pause_active_task_fx(model: client_state.Model) -> Effect(client_state.Msg) {
  case helpers_selection.now_working_active_task_id(model) {
    opt.Some(task_id) ->
      api_tasks.pause_work_session(task_id, fn(result) {
        client_state.pool_msg(pool_messages.MemberWorkSessionPaused(result))
      })
    opt.None -> effect.none()
  }
}

fn refresh_admin_after_project_change(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next, fx) = refresh_section_for_test(model)
  #(next, effect.batch([fx, replace_url(next)]))
}
// =============================================================================
// Card Add Task Handler
// Card add task functionality moved to card_detail_modal component
