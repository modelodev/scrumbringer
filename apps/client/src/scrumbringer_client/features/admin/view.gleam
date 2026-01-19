//// Admin section views.
////
//// ## Mission
////
//// Renders admin panel views for organization and project administration.
////
//// ## Responsibilities
////
//// - Organization settings view (role management)
//// - Capabilities management view
//// - Project members management view
//// - Task types management view
////
//// ## Line Count Justification
////
//// ~780 lines: Consolidates all admin panel views that share a common admin
//// context (permissions, project selection, CRUD patterns). These views are
//// tightly coupled through shared UI patterns and state dependencies. Splitting
//// further would fragment the cohesive admin experience. Each sub-view (members,
//// capabilities, task_types, org_settings) requires similar imports and patterns.
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to admin views from view_section
//// - **features/admin/update.gleam**: Handles admin-related messages
//// - **client_state.gleam**: Provides Model, Msg, Remote types

import gleam/dict
import gleam/int
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h2, h3, hr, img, input, label, option, p, select, span,
  table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import gleam/dynamic/decode

import domain/card.{type Card}
import domain/capability.{type Capability}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember}
import domain/task_type.{type TaskType}
import domain/workflow.{type Rule, type TaskTemplate, type Workflow}

import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_state.{
  type Model, type Msg, type Remote, CapabilityCreateNameChanged,
  CapabilityCreateSubmitted, CardCreateDescriptionChanged,
  CardCreateSubmitted, CardCreateTitleChanged, CardDeleteCancelled,
  CardDeleteClicked, CardDeleteConfirmed, CardEditCancelled, CardEditClicked,
  CardEditDescriptionChanged, CardEditSubmitted, CardEditTitleChanged, Failed,
  IconError, IconOk, Loaded, Loading, MemberAddDialogClosed,
  MemberAddDialogOpened, MemberAddRoleChanged, MemberAddSubmitted,
  MemberAddUserSelected, MemberRemoveCancelled, MemberRemoveClicked,
  MemberRemoveConfirmed, NotAsked, OrgSettingsRoleChanged, OrgSettingsSaveClicked,
  OrgUsersSearchChanged, OrgUsersSearchDebounced, TaskTypeCreateCapabilityChanged,
  TaskTypeCreateIconChanged, TaskTypeCreateNameChanged, TaskTypeCreateSubmitted,
  TaskTypeIconErrored, TaskTypeIconLoaded,
  // Workflows
  RuleCreateActiveChanged, RuleCreateGoalChanged, RuleCreateNameChanged,
  RuleCreateResourceTypeChanged, RuleCreateSubmitted,
  RuleCreateToStateChanged, RuleDeleteCancelled, RuleDeleteClicked,
  RuleDeleteConfirmed, RuleEditActiveChanged, RuleEditCancelled, RuleEditClicked,
  RuleEditGoalChanged, RuleEditNameChanged, RuleEditResourceTypeChanged,
  RuleEditSubmitted, RuleEditToStateChanged,
  RulesBackClicked, WorkflowCreateActiveChanged, WorkflowCreateDescriptionChanged,
  WorkflowCreateNameChanged, WorkflowCreateSubmitted, WorkflowDeleteCancelled,
  WorkflowDeleteClicked, WorkflowDeleteConfirmed, WorkflowEditActiveChanged,
  WorkflowEditCancelled, WorkflowEditClicked, WorkflowEditDescriptionChanged,
  WorkflowEditNameChanged, WorkflowEditSubmitted, WorkflowRulesClicked,
  // Task Templates
  TaskTemplateCreateDescriptionChanged, TaskTemplateCreateNameChanged,
  TaskTemplateCreatePriorityChanged, TaskTemplateCreateSubmitted,
  TaskTemplateCreateTypeIdChanged, TaskTemplateDeleteCancelled,
  TaskTemplateDeleteClicked, TaskTemplateDeleteConfirmed, TaskTemplateEditCancelled,
  TaskTemplateEditClicked, TaskTemplateEditDescriptionChanged,
  TaskTemplateEditNameChanged, TaskTemplateEditPriorityChanged,
  TaskTemplateEditSubmitted, TaskTemplateEditTypeIdChanged,
  // Rule Metrics Tab
  AdminRuleMetricsDrilldownClicked, AdminRuleMetricsDrilldownClosed,
  AdminRuleMetricsExecPageChanged, AdminRuleMetricsFromChanged,
  AdminRuleMetricsRefreshClicked, AdminRuleMetricsToChanged,
  AdminRuleMetricsWorkflowExpanded,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme
import scrumbringer_client/update_helpers

// =============================================================================
// Public API
// =============================================================================

/// Organization settings view - manage user roles.
pub fn view_org_settings(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.OrgSettingsHelp))]),
    case model.org_settings_users {
      NotAsked ->
        div([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.OpenThisSectionToLoadUsers,
          )),
        ])
      Loading ->
        div(
          [
            attribute.class("loading"),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.LoadingUsers))],
        )

      Failed(err) -> div([attribute.class("error")], [text(err.message)])

      Loaded(users) -> {
        table([attribute.class("table")], [
          thead([], [
            tr([], [
              th([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Role))]),
              th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
            ]),
          ]),
          keyed.tbody(
            [],
            list.map(users, fn(u) {
              let draft = case dict.get(model.org_settings_role_drafts, u.id) {
                Ok(role) -> role
                Error(_) -> u.org_role
              }

              let inline_error = case
                model.org_settings_error_user_id,
                model.org_settings_error
              {
                opt.Some(id), opt.Some(message) if id == u.id -> message
                _, _ -> ""
              }

              #(int.to_string(u.id), tr([], [
                td([], [text(u.email)]),
                td([], [
                  select(
                    [
                      attribute.value(draft),
                      attribute.disabled(model.org_settings_save_in_flight),
                      event.on_input(fn(value) {
                        OrgSettingsRoleChanged(u.id, value)
                      }),
                    ],
                    [
                      option(
                        [attribute.value("admin")],
                        update_helpers.i18n_t(model, i18n_text.RoleAdmin),
                      ),
                      option(
                        [attribute.value("member")],
                        update_helpers.i18n_t(model, i18n_text.RoleMember),
                      ),
                    ],
                  ),
                  case inline_error == "" {
                    True -> element.none()
                    False ->
                      div([attribute.class("error")], [text(inline_error)])
                  },
                ]),
                td([], [
                  button(
                    [
                      attribute.disabled(model.org_settings_save_in_flight),
                      event.on_click(OrgSettingsSaveClicked(u.id)),
                    ],
                    [text(update_helpers.i18n_t(model, i18n_text.Save))],
                  ),
                ]),
              ]))
            }),
          ),
        ])
      }
    },
  ])
}

/// Capabilities management view.
pub fn view_capabilities(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.Capabilities))]),
    view_capabilities_list(model, model.capabilities),
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateCapability))]),
    case model.capabilities_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { CapabilityCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
        input([
          attribute.type_("text"),
          attribute.value(model.capabilities_create_name),
          event.on_input(CapabilityCreateNameChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.capabilities_create_in_flight),
        ],
        [
          text(case model.capabilities_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ]),
  ])
}

/// Project members management view.
pub fn view_members(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageMembers,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.MembersTitle(project.name),
          )),
        ]),
        button([event.on_click(MemberAddDialogOpened)], [
          text(update_helpers.i18n_t(model, i18n_text.AddMember)),
        ]),
        case model.members_remove_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
        },
        view_members_table(model, model.members, model.org_users_cache),
        case model.members_add_dialog_open {
          True -> view_add_member_dialog(model)
          False -> element.none()
        },
        case model.members_remove_confirm {
          opt.Some(user) -> view_remove_member_dialog(model, project.name, user)
          opt.None -> element.none()
        },
      ])
  }
}

/// Task types management view.
pub fn view_task_types(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageTaskTypes,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.TaskTypesTitle(project.name),
          )),
        ]),
        view_task_types_list(model, model.task_types, model.theme),
        hr([]),
        h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateTaskType))]),
        case model.task_types_create_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
        },
        form([event.on_submit(fn(_) { TaskTypeCreateSubmitted })], [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
            input([
              attribute.type_("text"),
              attribute.value(model.task_types_create_name),
              event.on_input(TaskTypeCreateNameChanged),
              attribute.required(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Icon))]),
            div([attribute.class("icon-row")], [
              input([
                attribute.type_("text"),
                attribute.value(model.task_types_create_icon),
                event.on_input(TaskTypeCreateIconChanged),
                attribute.required(True),
                attribute.placeholder(update_helpers.i18n_t(
                  model,
                  i18n_text.HeroiconSearchPlaceholder,
                )),
              ]),
              view_icon_preview(model.task_types_create_icon),
            ]),
            view_icon_picker(model.task_types_create_icon),
            case model.task_types_icon_preview {
              IconError ->
                div([attribute.class("error")], [
                  text(update_helpers.i18n_t(model, i18n_text.UnknownIcon)),
                ])
              _ -> element.none()
            },
          ]),
          div([attribute.class("field")], [
            label([], [
              text(update_helpers.i18n_t(model, i18n_text.CapabilityOptional)),
            ]),
            view_capability_selector(
              model,
              model.capabilities,
              model.task_types_create_capability_id,
            ),
          ]),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(
                model.task_types_create_in_flight
                || model.task_types_icon_preview != IconOk,
              ),
            ],
            [
              text(case model.task_types_create_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Creating)
                False -> update_helpers.i18n_t(model, i18n_text.Create)
              }),
            ],
          ),
        ]),
      ])
  }
}

// =============================================================================
// Capabilities Helpers
// =============================================================================

fn view_capabilities_list(
  model: Model,
  capabilities: Remote(List(Capability)),
) -> Element(Msg) {
  case capabilities {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(capabilities) ->
      case capabilities {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoCapabilitiesYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(capabilities, fn(c) {
                #(int.to_string(c.id), tr([], [td([], [text(c.name)])]))
              }),
            ),
          ])
      }
  }
}

// =============================================================================
// Members Helpers
// =============================================================================

fn view_members_table(
  model: Model,
  members: Remote(List(ProjectMember)),
  cache: Remote(List(OrgUser)),
) -> Element(Msg) {
  case members {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(members) ->
      case members {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoMembersYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.User))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.UserId))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Role))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CreatedAt))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(members, fn(m) {
                let email = case
                  update_helpers.resolve_org_user(cache, m.user_id)
                {
                  opt.Some(user) -> user.email
                  opt.None ->
                    update_helpers.i18n_t(
                      model,
                      i18n_text.UserNumber(m.user_id),
                    )
                }

                #(int.to_string(m.user_id), tr([], [
                  td([], [text(email)]),
                  td([], [text(int.to_string(m.user_id))]),
                  td([], [text(m.role)]),
                  td([], [text(m.created_at)]),
                  td([], [
                    button([event.on_click(MemberRemoveClicked(m.user_id))], [
                      text(update_helpers.i18n_t(model, i18n_text.Remove)),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_add_member_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.AddMember))]),
      case model.members_add_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.SearchByEmail))]),
        input([
          attribute.type_("text"),
          attribute.value(model.org_users_search_query),
          event.on_input(OrgUsersSearchChanged),
          event.debounce(event.on_input(OrgUsersSearchDebounced), 350),
          attribute.placeholder(update_helpers.i18n_t(
            model,
            i18n_text.EmailPlaceholderExample,
          )),
        ]),
      ]),
      view_org_users_search_results(model, model.org_users_search_results),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.Role))]),
        select(
          [
            attribute.value(model.members_add_role),
            event.on_input(MemberAddRoleChanged),
          ],
          [
            option(
              [attribute.value("member")],
              update_helpers.i18n_t(model, i18n_text.RoleMember),
            ),
            option(
              [attribute.value("admin")],
              update_helpers.i18n_t(model, i18n_text.RoleAdmin),
            ),
          ],
        ),
      ]),
      div([attribute.class("actions")], [
        button([event.on_click(MemberAddDialogClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberAddSubmitted),
            attribute.disabled(
              model.members_add_in_flight
              || model.members_add_selected_user == opt.None,
            ),
          ],
          [
            text(case model.members_add_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Working)
              False -> update_helpers.i18n_t(model, i18n_text.AddMember)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

fn view_org_users_search_results(
  model: Model,
  results: Remote(List(OrgUser)),
) -> Element(Msg) {
  case results {
    NotAsked ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.TypeAnEmailToSearch)),
      ])

    Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.Searching)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(users) ->
      case users {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoResults)),
          ])

        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.EmailLabel)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.OrgRole))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Created))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Select))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(users, fn(u) {
                #(int.to_string(u.id), tr([], [
                  td([], [text(u.email)]),
                  td([], [text(u.org_role)]),
                  td([], [text(u.created_at)]),
                  td([], [
                    button([event.on_click(MemberAddUserSelected(u.id))], [
                      text(update_helpers.i18n_t(model, i18n_text.Select)),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_remove_member_dialog(
  model: Model,
  project_name: String,
  user: OrgUser,
) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.RemoveMemberTitle))]),
      p([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.RemoveMemberConfirm(user.email, project_name),
        )),
      ]),
      case model.members_remove_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("actions")], [
        button([event.on_click(MemberRemoveCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(MemberRemoveConfirmed),
            attribute.disabled(model.members_remove_in_flight),
          ],
          [
            text(case model.members_remove_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.Remove)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Task Types Helpers
// =============================================================================

fn heroicon_outline_url(name: String) -> String {
  "https://unpkg.com/heroicons@2.1.0/24/outline/" <> name <> ".svg"
}

fn view_heroicon_inline(
  name: String,
  size: Int,
  theme: theme.Theme,
) -> Element(Msg) {
  let url = heroicon_outline_url(name)

  let style = case theme {
    theme.Dark ->
      "vertical-align:middle; opacity:0.9; filter: invert(1) brightness(1.2);"
    theme.Default -> "vertical-align:middle; opacity:0.85;"
  }

  img([
    attribute.attribute("src", url),
    attribute.attribute("alt", name <> " icon"),
    attribute.attribute("width", int.to_string(size)),
    attribute.attribute("height", int.to_string(size)),
    attribute.attribute("style", style),
  ])
}

/// Render a task type icon - either heroicon or emoji.
/// Exported for use in pool/task card views.
pub fn view_task_type_icon_inline(
  icon: String,
  size: Int,
  theme: theme.Theme,
) -> Element(Msg) {
  case string.contains(icon, "-") {
    True -> view_heroicon_inline(icon, size, theme)
    False ->
      span(
        [
          attribute.attribute(
            "style",
            "font-size:" <> int.to_string(size) <> "px;",
          ),
        ],
        [text(icon)],
      )
  }
}

fn view_icon_preview(icon_name: String) -> Element(Msg) {
  let name = string.trim(icon_name)

  case name == "" {
    True -> div([attribute.class("icon-preview")], [text("-")])

    False -> {
      let url = heroicon_outline_url(name)

      div([attribute.class("icon-preview")], [
        img([
          attribute.attribute("src", url),
          attribute.attribute("alt", name <> " icon"),
          attribute.attribute("width", "24"),
          attribute.attribute("height", "24"),
          event.on("load", decode.success(TaskTypeIconLoaded)),
          event.on("error", decode.success(TaskTypeIconErrored)),
        ]),
      ])
    }
  }
}

fn view_icon_picker(current_icon: String) -> Element(Msg) {
  let current = string.trim(current_icon)

  let icons = [
    "bug-ant",
    "sparkles",
    "wrench-screwdriver",
    "clipboard-document-check",
    "light-bulb",
    "bolt",
    "beaker",
    "chat-bubble-left-right",
    "document-text",
    "flag",
    "exclamation-triangle",
    "check-circle",
    "arrow-path",
    "rocket-launch",
    "pencil-square",
    "cog-6-tooth",
  ]

  let has_current = current != "" && list.contains(icons, current)

  let options = [option([attribute.value("")], "Pick a common icon…")]

  let options = case current != "" && !has_current {
    True -> [
      option([attribute.value(current)], "Custom: " <> current),
      ..options
    ]
    False -> options
  }

  let options =
    list.append(
      options,
      list.map(icons, fn(name) { option([attribute.value(name)], name) }),
    )

  let selected = case current != "" && !has_current {
    True -> current
    False ->
      case has_current {
        True -> current
        False -> ""
      }
  }

  div([attribute.class("icon-picker")], [
    select(
      [
        attribute.value(selected),
        event.on_input(TaskTypeCreateIconChanged),
      ],
      options,
    ),
  ])
}

fn view_capability_selector(
  model: Model,
  capabilities: Remote(List(Capability)),
  selected: opt.Option(String),
) -> Element(Msg) {
  case capabilities {
    Loaded(capabilities) -> {
      let selected_value = opt.unwrap(selected, "")

      select(
        [
          attribute.value(selected_value),
          event.on_input(TaskTypeCreateCapabilityChanged),
        ],
        [
          option(
            [attribute.value("")],
            update_helpers.i18n_t(model, i18n_text.NoneOption),
          ),
          ..list.map(capabilities, fn(c) {
            option([attribute.value(int.to_string(c.id))], c.name)
          })
        ],
      )
    }

    _ ->
      div(
        [
          attribute.class("empty"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.LoadingCapabilities))],
      )
  }
}

fn view_task_types_list(
  model: Model,
  task_types: Remote(List(TaskType)),
  theme: theme.Theme,
) -> Element(Msg) {
  case task_types {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div(
            [
              attribute.class("not-permitted"),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.NotPermitted))],
          )
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(task_types) ->
      case task_types {
        [] ->
          div([attribute.class("empty")], [
            h2([], [
              text(update_helpers.i18n_t(model, i18n_text.NoTaskTypesYet)),
            ]),
            p([], [
              text(update_helpers.i18n_t(model, i18n_text.TaskTypesExplain)),
            ]),
            p([], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.CreateFirstTaskTypeHint,
              )),
            ]),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Icon))]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.CapabilityLabel)),
                ]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(task_types, fn(tt) {
                #(int.to_string(tt.id), tr([], [
                  td([], [text(tt.name)]),
                  td([], [view_task_type_icon_inline(tt.icon, 20, theme)]),
                  td([], [
                    case tt.capability_id {
                      opt.Some(id) -> text(int.to_string(id))
                      opt.None -> text("-")
                    },
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

// =============================================================================
// Cards (Fichas) Views
// =============================================================================

/// Cards management view.
pub fn view_cards(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  case selected_project {
    opt.None ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.SelectProjectToManageCards,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        h2([], [
          text(update_helpers.i18n_t(
            model,
            i18n_text.CardsTitle(project.name),
          )),
        ]),
        view_cards_list(model, model.cards),
        hr([]),
        h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateCard))]),
        case model.cards_create_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
        },
        form([event.on_submit(fn(_) { CardCreateSubmitted })], [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.CardTitle))]),
            input([
              attribute.type_("text"),
              attribute.value(model.cards_create_title),
              event.on_input(CardCreateTitleChanged),
              attribute.required(True),
            ]),
          ]),
          div([attribute.class("field")], [
            label([], [
              text(update_helpers.i18n_t(model, i18n_text.CardDescription)),
            ]),
            input([
              attribute.type_("text"),
              attribute.value(model.cards_create_description),
              event.on_input(CardCreateDescriptionChanged),
            ]),
          ]),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.cards_create_in_flight),
            ],
            [
              text(case model.cards_create_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Creating)
                False -> update_helpers.i18n_t(model, i18n_text.Create)
              }),
            ],
          ),
        ]),
        case model.cards_edit_id {
          opt.Some(_) -> view_edit_card_dialog(model)
          opt.None -> element.none()
        },
        case model.cards_delete_confirm {
          opt.Some(card) -> view_delete_card_dialog(model, card)
          opt.None -> element.none()
        },
      ])
  }
}

fn view_cards_list(model: Model, cards: Remote(List(Card))) -> Element(Msg) {
  case cards {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(cards) ->
      case cards {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoCardsYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.CardTitle)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.CardState)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CardTasks))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(cards, fn(c) {
                #(int.to_string(c.id), tr([], [
                  td([], [text(c.title)]),
                  td([], [text(view_card_state_label(model, c.state))]),
                  td([], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.CardTaskCount(c.completed_count, c.task_count),
                    )),
                  ]),
                  td([], [
                    button([event.on_click(CardEditClicked(c))], [
                      text(update_helpers.i18n_t(model, i18n_text.EditCard)),
                    ]),
                    button([event.on_click(CardDeleteClicked(c))], [
                      text(update_helpers.i18n_t(model, i18n_text.DeleteCard)),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_card_state_label(model: Model, state: card.CardState) -> String {
  case state {
    card.Pendiente ->
      update_helpers.i18n_t(model, i18n_text.CardStatePendiente)
    card.EnCurso -> update_helpers.i18n_t(model, i18n_text.CardStateEnCurso)
    card.Cerrada -> update_helpers.i18n_t(model, i18n_text.CardStateCerrada)
  }
}

fn view_edit_card_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditCard))]),
      case model.cards_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      form([event.on_submit(fn(_) { CardEditSubmitted })], [
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.CardTitle))]),
          input([
            attribute.type_("text"),
            attribute.value(model.cards_edit_title),
            event.on_input(CardEditTitleChanged),
            attribute.required(True),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.CardDescription)),
          ]),
          input([
            attribute.type_("text"),
            attribute.value(model.cards_edit_description),
            event.on_input(CardEditDescriptionChanged),
          ]),
        ]),
        div([attribute.class("actions")], [
          button(
            [attribute.type_("button"), event.on_click(CardEditCancelled)],
            [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.cards_edit_in_flight),
            ],
            [
              text(case model.cards_edit_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Working)
                False -> update_helpers.i18n_t(model, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_delete_card_dialog(model: Model, card: Card) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.DeleteCard))]),
      p([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.CardDeleteConfirm(card.title),
        )),
      ]),
      case model.cards_delete_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("actions")], [
        button([event.on_click(CardDeleteCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(CardDeleteConfirmed),
            attribute.disabled(model.cards_delete_in_flight),
          ],
          [
            text(case model.cards_delete_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.DeleteCard)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Workflows Views
// =============================================================================

/// Workflows management view.
pub fn view_workflows(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  // If we're viewing rules for a specific workflow, show rules view
  case model.rules_workflow_id {
    opt.Some(workflow_id) -> view_workflow_rules(model, workflow_id)
    opt.None -> view_workflows_list(model, selected_project)
  }
}

fn view_workflows_list(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  div([attribute.class("section")], [
    // Org workflows section
    h2([], [text(update_helpers.i18n_t(model, i18n_text.WorkflowsOrgTitle))]),
    view_workflows_table(model, model.workflows_org, opt.None),
    // Project workflows section (if project selected)
    case selected_project {
      opt.Some(project) ->
        div([], [
          hr([]),
          h2([], [
            text(update_helpers.i18n_t(
              model,
              i18n_text.WorkflowsProjectTitle(project.name),
            )),
          ]),
          view_workflows_table(model, model.workflows_project, opt.Some(project)),
        ])
      opt.None -> element.none()
    },
    // Create workflow form
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateWorkflow))]),
    case model.workflows_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { WorkflowCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.WorkflowName))]),
        input([
          attribute.type_("text"),
          attribute.value(model.workflows_create_name),
          event.on_input(WorkflowCreateNameChanged),
          attribute.required(True),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [
          text(update_helpers.i18n_t(model, i18n_text.WorkflowDescription)),
        ]),
        input([
          attribute.type_("text"),
          attribute.value(model.workflows_create_description),
          event.on_input(WorkflowCreateDescriptionChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.workflows_create_active),
            event.on_check(WorkflowCreateActiveChanged),
          ]),
          text(" " <> update_helpers.i18n_t(model, i18n_text.WorkflowActive)),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.workflows_create_in_flight),
        ],
        [
          text(case model.workflows_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ]),
    // Edit dialog
    case model.workflows_edit_id {
      opt.Some(_) -> view_edit_workflow_dialog(model)
      opt.None -> element.none()
    },
    // Delete dialog
    case model.workflows_delete_confirm {
      opt.Some(workflow) -> view_delete_workflow_dialog(model, workflow)
      opt.None -> element.none()
    },
  ])
}

fn view_workflows_table(
  model: Model,
  workflows: Remote(List(Workflow)),
  _project: opt.Option(Project),
) -> Element(Msg) {
  case workflows {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(workflows) ->
      case workflows {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoWorkflowsYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.WorkflowName)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.WorkflowActive)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.WorkflowRules)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(workflows, fn(w) {
                #(int.to_string(w.id), tr([], [
                  td([], [text(w.name)]),
                  td([], [
                    text(case w.active {
                      True -> "✓"
                      False -> "✗"
                    }),
                  ]),
                  td([], [text(int.to_string(w.rule_count))]),
                  td([], [
                    button([event.on_click(WorkflowRulesClicked(w.id))], [
                      text(update_helpers.i18n_t(model, i18n_text.WorkflowRules)),
                    ]),
                    button([event.on_click(WorkflowEditClicked(w))], [
                      text(update_helpers.i18n_t(model, i18n_text.EditWorkflow)),
                    ]),
                    button([event.on_click(WorkflowDeleteClicked(w))], [
                      text(update_helpers.i18n_t(
                        model,
                        i18n_text.DeleteWorkflow,
                      )),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_edit_workflow_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditWorkflow))]),
      case model.workflows_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      form([event.on_submit(fn(_) { WorkflowEditSubmitted })], [
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.WorkflowName)),
          ]),
          input([
            attribute.type_("text"),
            attribute.value(model.workflows_edit_name),
            event.on_input(WorkflowEditNameChanged),
            attribute.required(True),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.WorkflowDescription)),
          ]),
          input([
            attribute.type_("text"),
            attribute.value(model.workflows_edit_description),
            event.on_input(WorkflowEditDescriptionChanged),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            input([
              attribute.type_("checkbox"),
              attribute.checked(model.workflows_edit_active),
              event.on_check(WorkflowEditActiveChanged),
            ]),
            text(" " <> update_helpers.i18n_t(model, i18n_text.WorkflowActive)),
          ]),
        ]),
        div([attribute.class("actions")], [
          button(
            [attribute.type_("button"), event.on_click(WorkflowEditCancelled)],
            [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.workflows_edit_in_flight),
            ],
            [
              text(case model.workflows_edit_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Working)
                False -> update_helpers.i18n_t(model, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_delete_workflow_dialog(model: Model, workflow: Workflow) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.DeleteWorkflow))]),
      p([], [text("Delete workflow \"" <> workflow.name <> "\"?")]),
      case model.workflows_delete_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("actions")], [
        button([event.on_click(WorkflowDeleteCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(WorkflowDeleteConfirmed),
            attribute.disabled(model.workflows_delete_in_flight),
          ],
          [
            text(case model.workflows_delete_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.DeleteWorkflow)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Rules Views
// =============================================================================

fn view_workflow_rules(model: Model, workflow_id: Int) -> Element(Msg) {
  // Find the workflow name
  let workflow_name =
    find_workflow_name(model.workflows_org, workflow_id)
    |> opt.lazy_or(fn() {
      find_workflow_name(model.workflows_project, workflow_id)
    })
    |> opt.unwrap("Workflow #" <> int.to_string(workflow_id))

  div([attribute.class("section")], [
    button([event.on_click(RulesBackClicked)], [text("← Back to Workflows")]),
    h2([], [
      text(update_helpers.i18n_t(model, i18n_text.RulesTitle(workflow_name))),
    ]),
    view_rules_table(model, model.rules, model.rules_metrics),
    // Create rule form
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateRule))]),
    case model.rules_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { RuleCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.RuleName))]),
        input([
          attribute.type_("text"),
          attribute.value(model.rules_create_name),
          event.on_input(RuleCreateNameChanged),
          attribute.required(True),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.RuleGoal))]),
        input([
          attribute.type_("text"),
          attribute.value(model.rules_create_goal),
          event.on_input(RuleCreateGoalChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [
          text(update_helpers.i18n_t(model, i18n_text.RuleResourceType)),
        ]),
        select(
          [
            attribute.value(model.rules_create_resource_type),
            event.on_input(RuleCreateResourceTypeChanged),
          ],
          [
            option(
              [attribute.value("task")],
              update_helpers.i18n_t(model, i18n_text.RuleResourceTypeTask),
            ),
            option(
              [attribute.value("card")],
              update_helpers.i18n_t(model, i18n_text.RuleResourceTypeCard),
            ),
          ],
        ),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.RuleToState))]),
        select(
          [
            attribute.value(model.rules_create_to_state),
            event.on_input(RuleCreateToStateChanged),
          ],
          [
            option([attribute.value("available")], "available"),
            option([attribute.value("claimed")], "claimed"),
            option([attribute.value("completed")], "completed"),
            option([attribute.value("pendiente")], "pendiente"),
            option([attribute.value("en_curso")], "en_curso"),
            option([attribute.value("cerrada")], "cerrada"),
          ],
        ),
      ]),
      div([attribute.class("field")], [
        label([], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.rules_create_active),
            event.on_check(RuleCreateActiveChanged),
          ]),
          text(" " <> update_helpers.i18n_t(model, i18n_text.RuleActive)),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.rules_create_in_flight),
        ],
        [
          text(case model.rules_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ]),
    // Edit dialog
    case model.rules_edit_id {
      opt.Some(_) -> view_edit_rule_dialog(model)
      opt.None -> element.none()
    },
    // Delete dialog
    case model.rules_delete_confirm {
      opt.Some(rule) -> view_delete_rule_dialog(model, rule)
      opt.None -> element.none()
    },
  ])
}

fn find_workflow_name(
  workflows: Remote(List(Workflow)),
  workflow_id: Int,
) -> opt.Option(String) {
  case workflows {
    Loaded(list) ->
      list
      |> list.find(fn(w) { w.id == workflow_id })
      |> result.map(fn(w) { w.name })
      |> opt.from_result
    _ -> opt.None
  }
}

fn view_rules_table(
  model: Model,
  rules: Remote(List(Rule)),
  metrics: Remote(api_workflows.WorkflowMetrics),
) -> Element(Msg) {
  case rules {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(rules) ->
      case rules {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoRulesYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.RuleName)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.RuleResourceType)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.RuleToState)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.RuleActive)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSuppressed)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(rules, fn(r) {
                let #(applied, suppressed) = get_rule_metrics(metrics, r.id)
                #(int.to_string(r.id), tr([], [
                  td([], [text(r.name)]),
                  td([], [text(r.resource_type)]),
                  td([], [text(r.to_state)]),
                  td([], [
                    text(case r.active {
                      True -> "✓"
                      False -> "✗"
                    }),
                  ]),
                  td([attribute.class("metric-cell")], [
                    span([attribute.class("metric applied")], [
                      text(int.to_string(applied)),
                    ]),
                  ]),
                  td([attribute.class("metric-cell")], [
                    span([attribute.class("metric suppressed")], [
                      text(int.to_string(suppressed)),
                    ]),
                  ]),
                  td([], [
                    button([event.on_click(RuleEditClicked(r))], [
                      text(update_helpers.i18n_t(model, i18n_text.EditRule)),
                    ]),
                    button([event.on_click(RuleDeleteClicked(r))], [
                      text(update_helpers.i18n_t(model, i18n_text.DeleteRule)),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

/// Get metrics for a specific rule from the workflow metrics.
fn get_rule_metrics(
  metrics: Remote(api_workflows.WorkflowMetrics),
  rule_id: Int,
) -> #(Int, Int) {
  case metrics {
    Loaded(wm) -> {
      case list.find(wm.rules, fn(rm) { rm.rule_id == rule_id }) {
        Ok(rm) -> #(rm.applied_count, rm.suppressed_count)
        Error(_) -> #(0, 0)
      }
    }
    _ -> #(0, 0)
  }
}

fn view_edit_rule_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditRule))]),
      case model.rules_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      form([event.on_submit(fn(_) { RuleEditSubmitted })], [
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.RuleName))]),
          input([
            attribute.type_("text"),
            attribute.value(model.rules_edit_name),
            event.on_input(RuleEditNameChanged),
            attribute.required(True),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.RuleGoal))]),
          input([
            attribute.type_("text"),
            attribute.value(model.rules_edit_goal),
            event.on_input(RuleEditGoalChanged),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.RuleResourceType)),
          ]),
          select(
            [
              attribute.value(model.rules_edit_resource_type),
              event.on_input(RuleEditResourceTypeChanged),
            ],
            [
              option(
                [attribute.value("task")],
                update_helpers.i18n_t(model, i18n_text.RuleResourceTypeTask),
              ),
              option(
                [attribute.value("card")],
                update_helpers.i18n_t(model, i18n_text.RuleResourceTypeCard),
              ),
            ],
          ),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.RuleToState))]),
          select(
            [
              attribute.value(model.rules_edit_to_state),
              event.on_input(RuleEditToStateChanged),
            ],
            [
              option([attribute.value("available")], "available"),
              option([attribute.value("claimed")], "claimed"),
              option([attribute.value("completed")], "completed"),
              option([attribute.value("pendiente")], "pendiente"),
              option([attribute.value("en_curso")], "en_curso"),
              option([attribute.value("cerrada")], "cerrada"),
            ],
          ),
        ]),
        div([attribute.class("field")], [
          label([], [
            input([
              attribute.type_("checkbox"),
              attribute.checked(model.rules_edit_active),
              event.on_check(RuleEditActiveChanged),
            ]),
            text(" " <> update_helpers.i18n_t(model, i18n_text.RuleActive)),
          ]),
        ]),
        div([attribute.class("actions")], [
          button(
            [attribute.type_("button"), event.on_click(RuleEditCancelled)],
            [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.rules_edit_in_flight),
            ],
            [
              text(case model.rules_edit_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Working)
                False -> update_helpers.i18n_t(model, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_delete_rule_dialog(model: Model, rule: Rule) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.DeleteRule))]),
      p([], [text("Delete rule \"" <> rule.name <> "\"?")]),
      case model.rules_delete_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("actions")], [
        button([event.on_click(RuleDeleteCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(RuleDeleteConfirmed),
            attribute.disabled(model.rules_delete_in_flight),
          ],
          [
            text(case model.rules_delete_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.DeleteRule)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Task Templates Views
// =============================================================================

/// Task templates management view.
pub fn view_task_templates(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  div([attribute.class("section")], [
    // Org templates section
    h2([], [text(update_helpers.i18n_t(model, i18n_text.TaskTemplatesOrgTitle))]),
    p([], [
      text(update_helpers.i18n_t(model, i18n_text.TaskTemplateVariablesHelp)),
    ]),
    view_task_templates_table(model, model.task_templates_org),
    // Project templates section (if project selected)
    case selected_project {
      opt.Some(project) ->
        div([], [
          hr([]),
          h2([], [
            text(update_helpers.i18n_t(
              model,
              i18n_text.TaskTemplatesProjectTitle(project.name),
            )),
          ]),
          view_task_templates_table(model, model.task_templates_project),
        ])
      opt.None -> element.none()
    },
    // Create template form
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.CreateTaskTemplate))]),
    case model.task_templates_create_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { TaskTemplateCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [
          text(update_helpers.i18n_t(model, i18n_text.TaskTemplateName)),
        ]),
        input([
          attribute.type_("text"),
          attribute.value(model.task_templates_create_name),
          event.on_input(TaskTemplateCreateNameChanged),
          attribute.required(True),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [
          text(update_helpers.i18n_t(model, i18n_text.TaskTemplateDescription)),
        ]),
        input([
          attribute.type_("text"),
          attribute.value(model.task_templates_create_description),
          event.on_input(TaskTemplateCreateDescriptionChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [
          text(update_helpers.i18n_t(model, i18n_text.TaskTemplateType)),
        ]),
        view_task_type_selector_for_templates(
          model,
          model.task_types,
          case model.task_templates_create_type_id {
            opt.Some(id) -> int.to_string(id)
            opt.None -> ""
          },
          TaskTemplateCreateTypeIdChanged,
        ),
      ]),
      div([attribute.class("field")], [
        label([], [
          text(update_helpers.i18n_t(model, i18n_text.TaskTemplatePriority)),
        ]),
        select(
          [
            attribute.value(model.task_templates_create_priority),
            event.on_input(TaskTemplateCreatePriorityChanged),
          ],
          [
            option([attribute.value("1")], "1"),
            option([attribute.value("2")], "2"),
            option([attribute.value("3")], "3"),
            option([attribute.value("4")], "4"),
            option([attribute.value("5")], "5"),
          ],
        ),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.task_templates_create_in_flight),
        ],
        [
          text(case model.task_templates_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ]),
    // Edit dialog
    case model.task_templates_edit_id {
      opt.Some(_) -> view_edit_task_template_dialog(model)
      opt.None -> element.none()
    },
    // Delete dialog
    case model.task_templates_delete_confirm {
      opt.Some(template) -> view_delete_task_template_dialog(model, template)
      opt.None -> element.none()
    },
  ])
}

fn view_task_templates_table(
  model: Model,
  templates: Remote(List(TaskTemplate)),
) -> Element(Msg) {
  case templates {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      case err.status == 403 {
        True ->
          div([attribute.class("not-permitted")], [
            text(update_helpers.i18n_t(model, i18n_text.NotPermitted)),
          ])
        False -> div([attribute.class("error")], [text(err.message)])
      }

    Loaded(templates) ->
      case templates {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoTaskTemplatesYet)),
          ])
        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.TaskTemplateName)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.TaskTemplateType)),
                ]),
                th([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.TaskTemplatePriority,
                  )),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(templates, fn(t) {
                #(int.to_string(t.id), tr([], [
                  td([], [text(t.name)]),
                  td([], [text(t.type_name)]),
                  td([], [text(int.to_string(t.priority))]),
                  td([], [
                    button([event.on_click(TaskTemplateEditClicked(t))], [
                      text(update_helpers.i18n_t(
                        model,
                        i18n_text.EditTaskTemplate,
                      )),
                    ]),
                    button([event.on_click(TaskTemplateDeleteClicked(t))], [
                      text(update_helpers.i18n_t(
                        model,
                        i18n_text.DeleteTaskTemplate,
                      )),
                    ]),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_task_type_selector_for_templates(
  model: Model,
  task_types: Remote(List(TaskType)),
  selected: String,
  on_change: fn(String) -> Msg,
) -> Element(Msg) {
  case task_types {
    Loaded(types) ->
      select(
        [attribute.value(selected), event.on_input(on_change)],
        [
          option(
            [attribute.value("")],
            update_helpers.i18n_t(model, i18n_text.SelectType),
          ),
          ..list.map(types, fn(tt) {
            option([attribute.value(int.to_string(tt.id))], tt.name)
          })
        ],
      )
    _ ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])
  }
}

fn view_edit_task_template_dialog(model: Model) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.EditTaskTemplate))]),
      case model.task_templates_edit_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      form([event.on_submit(fn(_) { TaskTemplateEditSubmitted })], [
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.TaskTemplateName)),
          ]),
          input([
            attribute.type_("text"),
            attribute.value(model.task_templates_edit_name),
            event.on_input(TaskTemplateEditNameChanged),
            attribute.required(True),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.TaskTemplateDescription)),
          ]),
          input([
            attribute.type_("text"),
            attribute.value(model.task_templates_edit_description),
            event.on_input(TaskTemplateEditDescriptionChanged),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.TaskTemplateType)),
          ]),
          view_task_type_selector_for_templates(
            model,
            model.task_types,
            case model.task_templates_edit_type_id {
              opt.Some(id) -> int.to_string(id)
              opt.None -> ""
            },
            TaskTemplateEditTypeIdChanged,
          ),
        ]),
        div([attribute.class("field")], [
          label([], [
            text(update_helpers.i18n_t(model, i18n_text.TaskTemplatePriority)),
          ]),
          select(
            [
              attribute.value(model.task_templates_edit_priority),
              event.on_input(TaskTemplateEditPriorityChanged),
            ],
            [
              option([attribute.value("1")], "1"),
              option([attribute.value("2")], "2"),
              option([attribute.value("3")], "3"),
              option([attribute.value("4")], "4"),
              option([attribute.value("5")], "5"),
            ],
          ),
        ]),
        div([attribute.class("actions")], [
          button(
            [
              attribute.type_("button"),
              event.on_click(TaskTemplateEditCancelled),
            ],
            [text(update_helpers.i18n_t(model, i18n_text.Cancel))],
          ),
          button(
            [
              attribute.type_("submit"),
              attribute.disabled(model.task_templates_edit_in_flight),
            ],
            [
              text(case model.task_templates_edit_in_flight {
                True -> update_helpers.i18n_t(model, i18n_text.Working)
                False -> update_helpers.i18n_t(model, i18n_text.Save)
              }),
            ],
          ),
        ]),
      ]),
    ]),
  ])
}

fn view_delete_task_template_dialog(
  model: Model,
  template: TaskTemplate,
) -> Element(Msg) {
  div([attribute.class("modal")], [
    div([attribute.class("modal-content")], [
      h3([], [text(update_helpers.i18n_t(model, i18n_text.DeleteTaskTemplate))]),
      p([], [text("Delete template \"" <> template.name <> "\"?")]),
      case model.task_templates_delete_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      div([attribute.class("actions")], [
        button([event.on_click(TaskTemplateDeleteCancelled)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            event.on_click(TaskTemplateDeleteConfirmed),
            attribute.disabled(model.task_templates_delete_in_flight),
          ],
          [
            text(case model.task_templates_delete_in_flight {
              True -> update_helpers.i18n_t(model, i18n_text.Removing)
              False -> update_helpers.i18n_t(model, i18n_text.DeleteTaskTemplate)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Rule Metrics Tab Views
// =============================================================================

/// Rule metrics tab view.
pub fn view_rule_metrics(model: Model) -> Element(Msg) {
  div([attribute.class("section")], [
    h2([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsTitle))]),
    p([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsHelp))]),
    // Date range inputs
    div([attribute.class("field-row")], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsFrom))]),
        input([
          attribute.type_("date"),
          attribute.value(model.admin_rule_metrics_from),
          event.on_input(AdminRuleMetricsFromChanged),
        ]),
      ]),
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsTo))]),
        input([
          attribute.type_("date"),
          attribute.value(model.admin_rule_metrics_to),
          event.on_input(AdminRuleMetricsToChanged),
        ]),
      ]),
      button(
        [
          event.on_click(AdminRuleMetricsRefreshClicked),
          attribute.disabled(
            model.admin_rule_metrics_from == ""
            || model.admin_rule_metrics_to == "",
          ),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsRefresh))],
      ),
    ]),
    hr([]),
    // Metrics table
    view_rule_metrics_table(model, model.admin_rule_metrics),
  ])
}

fn view_rule_metrics_table(
  model: Model,
  metrics: Remote(List(api_workflows.OrgWorkflowMetricsSummary)),
) -> Element(Msg) {
  case metrics {
    NotAsked ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSelectRange)),
      ])

    Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      div([attribute.class("error")], [text(err.message)])

    Loaded(workflows) ->
      case workflows {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.RuleMetricsNoData)),
          ])
        _ ->
          div([], [
            table([attribute.class("table")], [
              thead([], [
                tr([], [
                  th([], []),
                  th([], [text(update_helpers.i18n_t(model, i18n_text.WorkflowName))]),
                  th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsRuleCount))]),
                  th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsEvaluated))]),
                  th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied))]),
                  th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSuppressed))]),
                ]),
              ]),
              keyed.tbody(
                [],
                list.flat_map(workflows, fn(w) {
                  view_workflow_row(model, w)
                }),
              ),
            ]),
            // Drill-down modal
            view_rule_drilldown_modal(model),
          ])
      }
  }
}

/// Render a workflow row with optional expansion for per-rule metrics.
fn view_workflow_row(
  model: Model,
  w: api_workflows.OrgWorkflowMetricsSummary,
) -> List(#(String, Element(Msg))) {
  let is_expanded =
    model.admin_rule_metrics_expanded_workflow == opt.Some(w.workflow_id)
  let expand_icon = case is_expanded {
    True -> "[-]"
    False -> "[+]"
  }

  let main_row =
    #(
      "wf-" <> int.to_string(w.workflow_id),
      tr(
        [
          attribute.class("workflow-row clickable"),
          event.on_click(AdminRuleMetricsWorkflowExpanded(w.workflow_id)),
        ],
        [
          td([attribute.class("expand-col")], [text(expand_icon)]),
          td([], [text(w.workflow_name)]),
          td([], [text(int.to_string(w.rule_count))]),
          td([], [text(int.to_string(w.evaluated_count))]),
          td([attribute.class("metric-cell")], [
            span([attribute.class("metric applied")], [
              text(int.to_string(w.applied_count)),
            ]),
          ]),
          td([attribute.class("metric-cell")], [
            span([attribute.class("metric suppressed")], [
              text(int.to_string(w.suppressed_count)),
            ]),
          ]),
        ],
      ),
    )

  case is_expanded {
    False -> [main_row]
    True -> [main_row, view_workflow_rules_expansion(model, w.workflow_id)]
  }
}

/// Render the expansion row with per-rule metrics.
fn view_workflow_rules_expansion(
  model: Model,
  _workflow_id: Int,
) -> #(String, Element(Msg)) {
  let content = case model.admin_rule_metrics_workflow_details {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(details) ->
      case details.rules {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.RuleMetricsNoRules)),
          ])
        rules ->
          table([attribute.class("table nested-table")], [
            thead([], [
              tr([], [
                th([], [text(update_helpers.i18n_t(model, i18n_text.RuleName))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsEvaluated))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSuppressed))]),
                th([], []),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(rules, fn(r) {
                #(
                  "rule-" <> int.to_string(r.rule_id),
                  tr([], [
                    td([], [text(r.rule_name)]),
                    td([], [text(int.to_string(r.evaluated_count))]),
                    td([attribute.class("metric-cell")], [
                      span([attribute.class("metric applied")], [
                        text(int.to_string(r.applied_count)),
                      ]),
                    ]),
                    td([attribute.class("metric-cell")], [
                      button(
                        [
                          attribute.class("btn-link metric suppressed"),
                          event.on_click(
                            AdminRuleMetricsDrilldownClicked(r.rule_id),
                          ),
                        ],
                        [text(int.to_string(r.suppressed_count))],
                      ),
                    ]),
                    td([], [
                      button(
                        [
                          attribute.class("btn-small"),
                          event.on_click(
                            AdminRuleMetricsDrilldownClicked(r.rule_id),
                          ),
                        ],
                        [text(update_helpers.i18n_t(model, i18n_text.ViewDetails))],
                      ),
                    ]),
                  ]),
                )
              }),
            ),
          ])
      }
  }

  #(
    "expansion",
    tr([attribute.class("expansion-row")], [
      td([attribute.attribute("colspan", "6")], [
        div([attribute.class("expansion-content")], [content]),
      ]),
    ]),
  )
}

/// Render the drill-down modal for rule details and executions.
fn view_rule_drilldown_modal(model: Model) -> Element(Msg) {
  case model.admin_rule_metrics_drilldown_rule_id {
    opt.None -> element.none()
    opt.Some(_rule_id) ->
      div([attribute.class("modal drilldown-modal")], [
        div([attribute.class("modal-content")], [
          div([attribute.class("modal-header")], [
            h3([], [
              text(
                update_helpers.i18n_t(model, i18n_text.RuleMetricsDrilldown),
              ),
            ]),
            button(
              [
                attribute.class("btn-close"),
                event.on_click(AdminRuleMetricsDrilldownClosed),
              ],
              [text("X")],
            ),
          ]),
          div([attribute.class("modal-body")], [
            view_drilldown_details(model),
            hr([]),
            view_drilldown_executions(model),
          ]),
        ]),
      ])
  }
}

/// Render the suppression breakdown in the drill-down modal.
fn view_drilldown_details(model: Model) -> Element(Msg) {
  case model.admin_rule_metrics_rule_details {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(details) ->
      div([attribute.class("drilldown-details")], [
        h3([], [text(details.rule_name)]),
        div([attribute.class("metrics-summary")], [
          div([attribute.class("metric-box")], [
            span([attribute.class("metric-label")], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsEvaluated)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.evaluated_count)),
            ]),
          ]),
          div([attribute.class("metric-box applied")], [
            span([attribute.class("metric-label")], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsApplied)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.applied_count)),
            ]),
          ]),
          div([attribute.class("metric-box suppressed")], [
            span([attribute.class("metric-label")], [
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsSuppressed)),
            ]),
            span([attribute.class("metric-value")], [
              text(int.to_string(details.suppressed_count)),
            ]),
          ]),
        ]),
        // Suppression breakdown
        h3([], [
          text(update_helpers.i18n_t(model, i18n_text.SuppressionBreakdown)),
        ]),
        div([attribute.class("suppression-breakdown")], [
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(model, i18n_text.SuppressionIdempotent)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.idempotent)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(
                update_helpers.i18n_t(model, i18n_text.SuppressionNotUserTriggered),
              ),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.not_user_triggered)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(model, i18n_text.SuppressionNotMatching)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.not_matching)),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(model, i18n_text.SuppressionInactive)),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(details.suppression_breakdown.inactive)),
            ]),
          ]),
        ]),
      ])
  }
}

/// Render the executions list in the drill-down modal.
fn view_drilldown_executions(model: Model) -> Element(Msg) {
  case model.admin_rule_metrics_executions {
    NotAsked | Loading ->
      div([attribute.class("loading")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) -> div([attribute.class("error")], [text(err.message)])

    Loaded(response) ->
      div([attribute.class("drilldown-executions")], [
        h3([], [
          text(update_helpers.i18n_t(model, i18n_text.RecentExecutions)),
        ]),
        case response.executions {
          [] ->
            div([attribute.class("empty")], [
              text(update_helpers.i18n_t(model, i18n_text.NoExecutions)),
            ])
          executions ->
            div([], [
              table([attribute.class("table executions-table")], [
                thead([], [
                  tr([], [
                    th([], [text(update_helpers.i18n_t(model, i18n_text.Origin))]),
                    th([], [text(update_helpers.i18n_t(model, i18n_text.Outcome))]),
                    th([], [text(update_helpers.i18n_t(model, i18n_text.User))]),
                    th([], [text(update_helpers.i18n_t(model, i18n_text.Timestamp))]),
                  ]),
                ]),
                keyed.tbody(
                  [],
                  list.map(executions, fn(exec) {
                    let outcome_class = case exec.outcome {
                      "applied" -> "outcome-applied"
                      "suppressed" -> "outcome-suppressed"
                      _ -> ""
                    }
                    let outcome_text = case exec.outcome {
                      "applied" ->
                        update_helpers.i18n_t(model, i18n_text.OutcomeApplied)
                      "suppressed" ->
                        update_helpers.i18n_t(model, i18n_text.OutcomeSuppressed)
                          <> case exec.suppression_reason {
                            "" -> ""
                            reason -> " (" <> reason <> ")"
                          }
                      _ -> exec.outcome
                    }
                    #(
                      int.to_string(exec.id),
                      tr([], [
                        td([], [
                          text(exec.origin_type <> " #" <> int.to_string(exec.origin_id)),
                        ]),
                        td([attribute.class(outcome_class)], [text(outcome_text)]),
                        td([], [
                          text(case exec.user_email {
                            "" -> "-"
                            email -> email
                          }),
                        ]),
                        td([], [text(exec.created_at)]),
                      ]),
                    )
                  }),
                ),
              ]),
              // Pagination
              view_executions_pagination(model, response.pagination),
            ])
        },
      ])
  }
}

/// Render pagination controls for executions.
fn view_executions_pagination(
  _model: Model,
  pagination: api_workflows.Pagination,
) -> Element(Msg) {
  let current_page = pagination.offset / pagination.limit + 1
  let total_pages = { pagination.total + pagination.limit - 1 } / pagination.limit

  case total_pages <= 1 {
    True -> element.none()
    False ->
      div([attribute.class("pagination")], [
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(pagination.offset == 0),
            event.on_click(AdminRuleMetricsExecPageChanged(0)),
          ],
          [text("<<")],
        ),
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(pagination.offset == 0),
            event.on_click(AdminRuleMetricsExecPageChanged(
              int.max(0, pagination.offset - pagination.limit),
            )),
          ],
          [text("<")],
        ),
        span([attribute.class("page-info")], [
          text(
            int.to_string(current_page)
              <> " / "
              <> int.to_string(total_pages),
          ),
        ]),
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(
              pagination.offset + pagination.limit >= pagination.total,
            ),
            event.on_click(AdminRuleMetricsExecPageChanged(
              pagination.offset + pagination.limit,
            )),
          ],
          [text(">")],
        ),
        button(
          [
            attribute.class("btn-small"),
            attribute.disabled(
              pagination.offset + pagination.limit >= pagination.total,
            ),
            event.on_click(AdminRuleMetricsExecPageChanged(
              { total_pages - 1 } * pagination.limit,
            )),
          ],
          [text(">>")],
        ),
      ])
  }
}
