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
//// ~2300 lines: Central TEA update hub that dispatches all client_state.Msg variants to
//// feature-specific update handlers. While large, this file acts as an
//// orchestration layer with clear delegation patterns:
//// - Each `case msg { ... }` branch delegates to `features/*/update.gleam`
//// - Splitting further would fragment the single entry point pattern
//// - Lustre's TEA model benefits from a unified `update` function
//// Future: Consider code generation for message dispatch if client_state.Msg variants
//// exceed 100.

import domain/org_role
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

import scrumbringer_client/client_state
import scrumbringer_client/client_update_dispatch as update_dispatch

// Story 4.10: Rule template attachment UI

// Workflows
// Rules
// Rule templates
// Task templates

import scrumbringer_client/features/admin/update as admin_workflow
import scrumbringer_client/features/auth/update as auth_workflow
import scrumbringer_client/features/i18n/update as i18n_workflow

// ---------------------------------------------------------------------------
// Routing helpers
// ---------------------------------------------------------------------------

fn current_route(model: client_state.Model) -> router.Route {
  case model.core.page {
    client_state.Login -> router.Login

    client_state.AcceptInvite -> {
      let accept_invite.Model(token: token, ..) = model.auth.accept_invite
      router.AcceptInvite(token)
    }

    client_state.ResetPassword -> {
      let reset_password.Model(token: token, ..) = model.auth.reset_password
      router.ResetPassword(token)
    }

    // Story 4.5: Use Config or Org routes based on section type
    client_state.Admin ->
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

    client_state.Member ->
      router.Member(
        model.member.member_section,
        model.core.selected_project_id,
        opt.Some(model.member.view_mode),
      )
  }
}

fn replace_url(model: client_state.Model) -> Effect(client_state.Msg) {
  router.replace(current_route(model))
}

pub fn accept_invite_effect(
  action: accept_invite.Action,
) -> Effect(client_state.Msg) {
  case action {
    accept_invite.ValidateToken(token) ->
      api_auth.validate_invite_link_token(token, fn(result) {
        client_state.AcceptInviteMsg(accept_invite.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn reset_password_effect(
  action: reset_password.Action,
) -> Effect(client_state.Msg) {
  case action {
    reset_password.ValidateToken(token) ->
      api_auth.validate_password_reset_token(token, fn(result) {
        client_state.ResetPasswordMsg(reset_password.TokenValidated(result))
      })

    _ -> effect.none()
  }
}

pub fn register_popstate_effect() -> Effect(client_state.Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_popstate(fn(_) { dispatch(client_state.UrlChanged) })
  })
}

pub fn register_keydown_effect() -> Effect(client_state.Msg) {
  effect.from(fn(dispatch) {
    client_ffi.register_keydown(fn(payload) {
      let #(key, ctrl, meta, shift, is_editing, modal_open) = payload
      dispatch(
        client_state.pool_msg(
          client_state.GlobalKeyDown(pool_prefs.KeyEvent(
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
            client_state.MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
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
              client_state.AuthModel(..auth, accept_invite: new_accept_model)
            },
          ),
          fn(member) {
            client_state.MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
            )
          },
        )

      #(model, accept_invite_effect(action))
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
              client_state.AuthModel(..auth, reset_password: new_reset_model)
            },
          ),
          fn(member) {
            client_state.MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
            )
          },
        )

      #(model, reset_password_effect(action))
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
            client_state.MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
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
            client_state.MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
            )
          },
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    // Legacy client_state.Admin routes - still supported but will redirect via router.parse()
    router.Admin(section, project_id) -> {
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
            client_state.MemberModel(
              ..member,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
            )
          },
        )
      let #(model, fx) = refresh_section_for_test(model)
      #(model, fx)
    }

    router.Member(section, project_id, view) -> {
      let capabilities_fx = case model.core.page, project_id {
        client_state.Admin, opt.Some(pid) ->
          api_org.list_project_capabilities(pid, fn(result) {
            client_state.admin_msg(client_state.CapabilitiesFetched(result))
          })
        _, _ -> effect.none()
      }

      // Update view mode if provided in URL
      let new_view = opt.unwrap(view, model.member.view_mode)

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
            client_state.MemberModel(
              ..member,
              member_section: section,
              view_mode: new_view,
              member_drag: opt.None,
              member_pool_drag: client_state.PoolDragIdle,
            )
          },
        ),
        capabilities_fx,
      )
    }
  }
}

fn remote_state(remote: client_state.Remote(a)) -> hydration.ResourceState {
  case remote {
    client_state.NotAsked -> hydration.NotAsked
    client_state.Loading -> hydration.Loading
    client_state.Loaded(_) -> hydration.Loaded
    client_state.Failed(_) -> hydration.Failed
  }
}

fn auth_state(model: client_state.Model) -> hydration.AuthState {
  case model.core.user {
    opt.Some(user) -> hydration.Authed(user.org_role)

    opt.None ->
      case model.core.auth_checked {
        True -> hydration.Unauthed
        False -> hydration.Unknown
      }
  }
}

fn build_snapshot(model: client_state.Model) -> hydration.Snapshot {
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
/// - State validation (client_state.Loading/client_state.Loaded check)
/// - Project ID validation where applicable
/// - client_state.Model updates and effect batching
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
fn hydrate_model(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
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
        False -> handle_navigate_to(model, to, client_state.Replace)
      }
    }

    _ -> {
      let #(next, effects) =
        list.fold(commands, #(model, []), fn(state, cmd) {
          let #(m, fx) = state

          case cmd {
            hydration.FetchMe -> {
              #(m, [api_auth.fetch_me(client_state.MeFetched), ..fx])
            }

            hydration.FetchProjects -> {
              case m.core.projects {
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_core(m, fn(core) {
                      client_state.CoreModel(
                        ..core,
                        projects: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_projects.list_projects(fn(result) {
                      client_state.admin_msg(client_state.ProjectsFetched(
                        result,
                      ))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchInviteLinks -> {
              case m.admin.invite_links {
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_admin(m, fn(admin) {
                      client_state.AdminModel(
                        ..admin,
                        invite_links: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_org.list_invite_links(fn(result) {
                      client_state.admin_msg(client_state.InviteLinksFetched(
                        result,
                      ))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchCapabilities -> {
              case m.admin.capabilities, m.core.selected_project_id {
                client_state.Loading, _ | client_state.Loaded(_), _ -> #(m, fx)

                _, opt.Some(project_id) -> {
                  let m =
                    client_state.update_admin(m, fn(admin) {
                      client_state.AdminModel(
                        ..admin,
                        capabilities: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_org.list_project_capabilities(project_id, fn(result) {
                      client_state.admin_msg(client_state.CapabilitiesFetched(
                        result,
                      ))
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
                client_state.Loading, _, _ | client_state.Loaded(_), _, _ -> #(
                  m,
                  fx,
                )

                _, opt.Some(project_id), opt.Some(user) -> {
                  let m =
                    client_state.update_member(m, fn(member) {
                      client_state.MemberModel(
                        ..member,
                        member_my_capability_ids: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_tasks.get_member_capability_ids(
                      project_id,
                      user.id,
                      fn(result) {
                        client_state.pool_msg(
                          client_state.MemberMyCapabilityIdsFetched(result),
                        )
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
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_member(m, fn(member) {
                      client_state.MemberModel(
                        ..member,
                        member_work_sessions: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_tasks.get_work_sessions(fn(result) {
                      client_state.pool_msg(
                        client_state.MemberWorkSessionsFetched(result),
                      )
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchMeMetrics -> {
              case m.member.member_metrics {
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_member(m, fn(member) {
                      client_state.MemberModel(
                        ..member,
                        member_metrics: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_metrics.get_me_metrics(30, fn(result) {
                      client_state.pool_msg(client_state.MemberMetricsFetched(
                        result,
                      ))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsOverview -> {
              case m.admin.admin_metrics_overview {
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_admin(m, fn(admin) {
                      client_state.AdminModel(
                        ..admin,
                        admin_metrics_overview: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_metrics.get_org_metrics_overview(30, fn(result) {
                      client_state.pool_msg(
                        client_state.AdminMetricsOverviewFetched(result),
                      )
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchOrgMetricsProjectTasks(project_id: project_id) -> {
              let can_fetch = case m.core.projects {
                client_state.Loaded(projects) ->
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
                    client_state.Loading, _ -> #(m, fx)
                    client_state.Loaded(_), opt.Some(pid) if pid == project_id -> #(
                      m,
                      fx,
                    )

                    _, _ -> {
                      let m =
                        client_state.update_admin(m, fn(admin) {
                          client_state.AdminModel(
                            ..admin,
                            admin_metrics_project_tasks: client_state.Loading,
                            admin_metrics_project_id: opt.Some(project_id),
                          )
                        })

                      let fx_tasks =
                        api_metrics.get_org_metrics_project_tasks(
                          project_id,
                          30,
                          fn(result) {
                            client_state.pool_msg(
                              client_state.AdminMetricsProjectTasksFetched(
                                result,
                              ),
                            )
                          },
                        )

                      #(m, [fx_tasks, ..fx])
                    }
                  }
              }
            }

            hydration.FetchOrgSettingsUsers -> {
              case m.admin.org_settings_users {
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_admin(m, fn(admin) {
                      client_state.AdminModel(
                        ..admin,
                        org_settings_users: client_state.Loading,
                        org_settings_role_drafts: dict.new(),
                        org_settings_save_in_flight: False,
                        org_settings_error: opt.None,
                        org_settings_error_user_id: opt.None,
                      )
                    })

                  #(m, [
                    api_org.list_org_users("", fn(result) {
                      client_state.admin_msg(
                        client_state.OrgSettingsUsersFetched(result),
                      )
                    }),
                    ..fx
                  ])
                }
              }
            }

            // AC7: Fetch org users cache for member views (Lista)
            hydration.FetchOrgUsersCache -> {
              case m.admin.org_users_cache {
                client_state.Loading | client_state.Loaded(_) -> #(m, fx)

                _ -> {
                  let m =
                    client_state.update_admin(m, fn(admin) {
                      client_state.AdminModel(
                        ..admin,
                        org_users_cache: client_state.Loading,
                      )
                    })
                  #(m, [
                    api_org.list_org_users("", fn(result) {
                      client_state.admin_msg(client_state.OrgUsersCacheFetched(
                        result,
                      ))
                    }),
                    ..fx
                  ])
                }
              }
            }

            hydration.FetchMembers(project_id: project_id) -> {
              let can_fetch = case m.core.projects {
                client_state.Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.admin.members {
                    client_state.Loading -> #(m, fx)

                    _ -> {
                      let m =
                        client_state.update_admin(m, fn(admin) {
                          client_state.AdminModel(
                            ..admin,
                            members: client_state.Loading,
                            members_project_id: opt.Some(project_id),
                            org_users_cache: client_state.Loading,
                          )
                        })

                      let fx_members =
                        api_projects.list_project_members(
                          project_id,
                          fn(result) {
                            client_state.admin_msg(client_state.MembersFetched(
                              result,
                            ))
                          },
                        )
                      let fx_users =
                        api_org.list_org_users("", fn(result) {
                          client_state.admin_msg(
                            client_state.OrgUsersCacheFetched(result),
                          )
                        })

                      #(m, [effect.batch([fx_members, fx_users]), ..fx])
                    }
                  }
              }
            }

            hydration.FetchTaskTypes(project_id: project_id) -> {
              let can_fetch = case m.core.projects {
                client_state.Loaded(projects) ->
                  list.any(projects, fn(p) { p.id == project_id })
                _ -> False
              }

              case can_fetch {
                False -> #(m, fx)

                True ->
                  case m.admin.task_types {
                    client_state.Loading -> #(m, fx)

                    _ -> {
                      let m =
                        client_state.update_admin(m, fn(admin) {
                          client_state.AdminModel(
                            ..admin,
                            task_types: client_state.Loading,
                            task_types_project_id: opt.Some(project_id),
                          )
                        })

                      #(m, [
                        api_tasks.list_task_types(project_id, fn(result) {
                          client_state.admin_msg(client_state.TaskTypesFetched(
                            result,
                          ))
                        }),
                        ..fx
                      ])
                    }
                  }
              }
            }

            hydration.RefreshMember -> {
              case m.core.projects {
                client_state.Loaded(_) -> {
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

fn handle_url_changed(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let pathname = client_ffi.location_pathname()
  let search = client_ffi.location_search()
  let hash = client_ffi.location_hash()
  let is_mobile = client_ffi.is_mobile()

  let model =
    client_state.update_ui(model, fn(ui) {
      client_state.UiModel(..ui, is_mobile: is_mobile)
    })

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

fn handle_navigate_to(
  model: client_state.Model,
  route: router.Route,
  mode: client_state.NavMode,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  let #(next_route, next_mode) = case model.ui.is_mobile, route {
    True, router.Member(member_section.Pool, project_id, view) -> #(
      router.Member(member_section.MyBar, project_id, view),
      client_state.Replace,
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
        client_state.CoreModel(..core, projects: client_state.Loading)
      }),
      fn(admin) {
        client_state.AdminModel(..admin, invite_links: case is_admin {
          True -> client_state.Loading
          False -> admin.invite_links
        })
      },
    )

  let effects = [
    api_projects.list_projects(fn(result) {
      client_state.admin_msg(client_state.ProjectsFetched(result))
    }),
  ]

  // Fetch capabilities if project is selected
  let effects = case model.core.selected_project_id {
    opt.Some(project_id) -> [
      api_org.list_project_capabilities(project_id, fn(result) {
        client_state.admin_msg(client_state.CapabilitiesFetched(result))
      }),
      ..effects
    ]
    opt.None -> effects
  }

  // Fetch member capability IDs if project and user are available
  let effects = case model.core.selected_project_id, model.core.user {
    opt.Some(project_id), opt.Some(user) -> [
      api_tasks.get_member_capability_ids(project_id, user.id, fn(result) {
        client_state.pool_msg(client_state.MemberMyCapabilityIdsFetched(result))
      }),
      ..effects
    ]
    _, _ -> effects
  }

  let effects = case is_admin {
    True -> [
      api_org.list_invite_links(fn(result) {
        client_state.admin_msg(client_state.InviteLinksFetched(result))
      }),
      ..effects
    ]
    False -> effects
  }

  #(model, effect.batch(effects))
}

pub fn refresh_section_for_test(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case model.core.active_section {
    permissions.Invites -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          client_state.AdminModel(..admin, invite_links: client_state.Loading)
        })
      #(
        model,
        api_org.list_invite_links(fn(result) {
          client_state.admin_msg(client_state.InviteLinksFetched(result))
        }),
      )
    }

    permissions.OrgSettings -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          client_state.AdminModel(
            ..admin,
            org_settings_users: client_state.Loading,
            org_settings_role_drafts: dict.new(),
            org_settings_save_in_flight: False,
            org_settings_error: opt.None,
            org_settings_error_user_id: opt.None,
          )
        })

      #(
        model,
        api_org.list_org_users("", fn(result) {
          client_state.admin_msg(client_state.OrgSettingsUsersFetched(result))
        }),
      )
    }

    permissions.Projects -> #(
      model,
      api_projects.list_projects(fn(result) {
        client_state.admin_msg(client_state.ProjectsFetched(result))
      }),
    )

    permissions.Metrics -> {
      let model =
        client_state.update_admin(model, fn(admin) {
          client_state.AdminModel(
            ..admin,
            admin_metrics_overview: client_state.Loading,
          )
        })

      let overview_fx =
        api_metrics.get_org_metrics_overview(30, fn(result) {
          client_state.pool_msg(client_state.AdminMetricsOverviewFetched(result))
        })

      case model.core.selected_project_id {
        opt.None -> #(model, overview_fx)

        opt.Some(project_id) -> {
          let model =
            client_state.update_admin(model, fn(admin) {
              client_state.AdminModel(
                ..admin,
                admin_metrics_project_tasks: client_state.Loading,
                admin_metrics_project_id: opt.Some(project_id),
              )
            })

          let tasks_fx =
            api_metrics.get_org_metrics_project_tasks(
              project_id,
              30,
              fn(result) {
                client_state.pool_msg(
                  client_state.AdminMetricsProjectTasksFetched(result),
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
                client_state.admin_msg(client_state.CapabilitiesFetched(result))
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
              client_state.AdminModel(
                ..admin,
                members: client_state.Loading,
                members_project_id: opt.Some(project_id),
                org_users_cache: client_state.Loading,
              )
            })
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_projects.list_project_members(project_id, fn(result) {
                client_state.admin_msg(client_state.MembersFetched(result))
              }),
              api_org.list_org_users("", fn(result) {
                client_state.admin_msg(client_state.OrgUsersCacheFetched(result))
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
              client_state.AdminModel(
                ..admin,
                task_types: client_state.Loading,
                task_types_project_id: opt.Some(project_id),
              )
            })
          let #(model, right_panel_fx) = fetch_right_panel_data(model)
          #(
            model,
            effect.batch([
              api_tasks.list_task_types(project_id, fn(result) {
                client_state.admin_msg(client_state.TaskTypesFetched(result))
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
        opt.Some(project_id), client_state.NotAsked ->
          api_tasks.list_task_types(project_id, fn(result) {
            client_state.admin_msg(client_state.TaskTypesFetched(result))
          })
        opt.Some(project_id), client_state.Failed(_) ->
          api_tasks.list_task_types(project_id, fn(result) {
            client_state.admin_msg(client_state.TaskTypesFetched(result))
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
          ),
          fn(result) {
            client_state.pool_msg(client_state.MemberProjectTasksFetched(
              project_id,
              result,
            ))
          },
        )

      // Fetch cards for "My Cards" section
      let cards_effect =
        api_cards.list_cards(project_id, fn(result) {
          client_state.pool_msg(client_state.CardsFetched(result))
        })

      // Update model with pending counter and loading state
      let model =
        client_state.update_admin(
          client_state.update_member(model, fn(member) {
            client_state.MemberModel(
              ..member,
              member_tasks_pending: 1,
              member_tasks_by_project: dict.new(),
            )
          }),
          fn(admin) {
            client_state.AdminModel(
              ..admin,
              cards: client_state.Loading,
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
/// - client_state.Member metrics
///
/// The batched fetching logic and state updates are tightly coupled
/// and splitting would complicate the refresh coordination.
fn member_refresh(
  model: client_state.Model,
) -> #(client_state.Model, Effect(client_state.Msg)) {
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
          client_state.update_member(model, fn(member) {
            client_state.MemberModel(
              ..member,
              member_tasks: client_state.NotAsked,
              member_tasks_pending: 0,
              member_tasks_by_project: dict.new(),
              member_task_types: client_state.NotAsked,
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
              fn(result) {
                client_state.pool_msg(client_state.MemberPositionsFetched(
                  result,
                ))
              },
            )

          let task_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_project_tasks(project_id, filters, fn(result) {
                client_state.pool_msg(client_state.MemberProjectTasksFetched(
                  project_id,
                  result,
                ))
              })
            })

          let task_type_effects =
            list.map(project_ids, fn(project_id) {
              api_tasks.list_task_types(project_id, fn(result) {
                client_state.pool_msg(client_state.MemberTaskTypesFetched(
                  project_id,
                  result,
                ))
              })
            })

          // Story 4.8 UX: Fetch cards for ALL views (Lista, Kanban need them too)
          let #(cards_effects, cards_model_update) = case
            model.core.selected_project_id
          {
            opt.Some(project_id) -> #(
              [
                api_cards.list_cards(project_id, fn(result) {
                  client_state.pool_msg(client_state.CardsFetched(result))
                }),
              ],
              fn(m: client_state.Model) {
                client_state.update_admin(m, fn(admin) {
                  client_state.AdminModel(
                    ..admin,
                    cards: client_state.Loading,
                    cards_project_id: opt.Some(project_id),
                  )
                })
              },
            )
            opt.None -> #([], fn(m: client_state.Model) { m })
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
            client_state.update_member(model, fn(member) {
              client_state.MemberModel(
                ..member,
                member_tasks: client_state.Loading,
                member_tasks_pending: list.length(project_ids),
                member_tasks_by_project: dict.new(),
                member_task_types: client_state.Loading,
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
pub fn update(
  model: client_state.Model,
  msg: client_state.Msg,
) -> #(client_state.Model, Effect(client_state.Msg)) {
  case msg {
    // No operation - used for placeholder handlers
    client_state.NoOp -> #(model, effect.none())

    client_state.UrlChanged -> handle_url_changed(model)

    client_state.NavigateTo(route, mode) ->
      handle_navigate_to(model, route, mode)

    client_state.MeFetched(Ok(user)) -> {
      let default_page = case user.org_role {
        org_role.Admin -> client_state.Admin
        _ -> client_state.Member
      }

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
                client_state.AuthModel(
                  ..auth,
                  login_error: opt.Some(err.message),
                )
              },
            )

          #(model, replace_url(model))
        }
      }
    }

    client_state.AcceptInviteMsg(inner) -> {
      let #(next_accept, action) =
        accept_invite.update(model.auth.accept_invite, inner)
      let model =
        client_state.update_auth(model, fn(auth) {
          client_state.AuthModel(..auth, accept_invite: next_accept)
        })

      case action {
        accept_invite.NoOp -> #(model, effect.none())

        accept_invite.ValidateToken(_) -> #(model, accept_invite_effect(action))

        accept_invite.Register(token: token, password: password) -> #(
          model,
          api_auth.register_with_invite_link(token, password, fn(result) {
            client_state.AcceptInviteMsg(accept_invite.Registered(result))
          }),
        )

        accept_invite.Authed(user) -> {
          let page = case user.org_role {
            org_role.Admin -> client_state.Admin
            _ -> client_state.Member
          }

          let model =
            client_state.update_core(model, fn(core) {
              client_state.CoreModel(
                ..core,
                page: page,
                user: opt.Some(user),
                auth_checked: True,
              )
            })
          let toast_fx =
            update_helpers.toast_success(update_helpers.i18n_t(
              model,
              i18n_text.Welcome,
            ))

          let #(model, boot) = bootstrap_admin(model)
          let #(model, hyd_fx) = hydrate_model(model)
          #(
            model,
            effect.batch([
              boot,
              hyd_fx,
              replace_url(model),
              toast_fx,
            ]),
          )
        }
      }
    }

    client_state.ResetPasswordMsg(inner) -> {
      let #(next_reset, action) =
        reset_password.update(model.auth.reset_password, inner)

      let model =
        client_state.update_auth(model, fn(auth) {
          client_state.AuthModel(..auth, reset_password: next_reset)
        })

      case action {
        reset_password.NoOp -> #(model, effect.none())

        reset_password.ValidateToken(_) -> #(
          model,
          reset_password_effect(action),
        )

        reset_password.Consume(token: token, password: password) -> #(
          model,
          api_auth.consume_password_reset_token(token, password, fn(result) {
            client_state.ResetPasswordMsg(reset_password.Consumed(result))
          }),
        )

        reset_password.GoToLogin -> {
          let model =
            client_state.update_auth(
              client_state.update_core(model, fn(core) {
                client_state.CoreModel(..core, page: client_state.Login)
              }),
              fn(auth) {
                client_state.AuthModel(
                  ..auth,
                  login_password: "",
                  login_error: opt.None,
                )
              },
            )
          let toast_fx =
            update_helpers.toast_success(update_helpers.i18n_t(
              model,
              i18n_text.PasswordUpdated,
            ))

          #(model, effect.batch([replace_url(model), toast_fx]))
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
          client_state.UiModel(..ui, toast_state: next_state)
        }),
        tick_effect,
      )
    }

    client_state.ToastDismiss(id) -> {
      let next_state = toast.dismiss(model.ui.toast_state, id)
      #(
        client_state.update_ui(model, fn(ui) {
          client_state.UiModel(..ui, toast_state: next_state)
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
          client_state.UiModel(..ui, toast_state: next_state)
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
            client_state.UiModel(..ui, theme: next_theme)
          }),
          effect.from(fn(_dispatch) { theme.save_to_storage(next_theme) }),
        )
      }
    }

    client_state.LocaleSelected(value) ->
      i18n_workflow.handle_locale_selected(model, value)

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
              client_state.MemberModel(
                ..member,
                member_filters_type_id: "",
                member_task_types: client_state.NotAsked,
              )
            },
          )
        _ ->
          client_state.update_core(model, fn(core) {
            client_state.CoreModel(..core, selected_project_id: selected)
          })
      }

      case model.core.page {
        client_state.Member -> {
          let #(model, fx) = member_refresh(model)

          let pause_fx = case should_pause {
            True ->
              api_tasks.pause_me_active_task(fn(result) {
                client_state.pool_msg(client_state.MemberActiveTaskPaused(
                  result,
                ))
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

    client_state.AdminMsg(inner) ->
      update_dispatch.handle_admin(
        model,
        inner,
        update_dispatch.AdminContext(
          member_refresh: member_refresh,
          refresh_section_for_test: refresh_section_for_test,
          hydrate_model: hydrate_model,
          replace_url: replace_url,
        ),
      )

    client_state.PoolMsg(inner) ->
      update_dispatch.handle_pool(
        model,
        inner,
        update_dispatch.PoolContext(member_refresh: member_refresh),
      )
  }
}
// =============================================================================
// Card Add Task Handler
// Card add task functionality moved to card_detail_modal component
