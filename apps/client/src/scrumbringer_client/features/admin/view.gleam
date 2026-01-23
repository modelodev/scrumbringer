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
import gleam/json
import gleam/list
import gleam/option as opt
import gleam/result
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  a, button, div, form, h2, h3, hr, img, input, label, option, p, select, span,
  table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import gleam/dynamic/decode

import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/project.{type Project, type ProjectMember}
import domain/task_type.{type TaskType}
import domain/workflow.{type Rule, type TaskTemplate, type Workflow, Workflow}
import domain/project_role.{Manager, Member}
import domain/org_role

import scrumbringer_client/api/workflows as api_workflows
import scrumbringer_client/client_ffi
import scrumbringer_client/features/admin/cards as admin_cards
import scrumbringer_client/i18n/locale
import scrumbringer_client/client_state.{
  type Model, type Msg, type Remote,
  AdminRuleMetricsDrilldownClicked, AdminRuleMetricsDrilldownClosed,
  AdminRuleMetricsExecPageChanged,
  AdminRuleMetricsFromChangedAndRefresh, AdminRuleMetricsQuickRangeClicked,
  AdminRuleMetricsToChangedAndRefresh,
  AdminRuleMetricsWorkflowExpanded, CapabilityCreateDialogClosed,
  CapabilityCreateDialogOpened, CapabilityCreateNameChanged,
  CapabilityCreateSubmitted, CapabilityDeleteDialogClosed,
  CapabilityDeleteDialogOpened, CapabilityDeleteSubmitted,
  CardCrudCreated, CardCrudDeleted, CardCrudUpdated,
  CardDialogCreate, CardDialogDelete, CardDialogEdit,
  CardsSearchChanged, CardsShowCompletedToggled, CardsShowEmptyToggled, CardsStateFilterChanged,
  CloseCardDialog,
  CloseRuleDialog, CloseTaskTemplateDialog, Failed, Loaded,
  Loading, MemberAddDialogClosed, MemberAddDialogOpened, MemberAddRoleChanged,
  MemberAddSubmitted, MemberAddUserSelected, MemberRemoveCancelled,
  MemberRemoveClicked, MemberRemoveConfirmed, MemberRoleChangeRequested,
  NotAsked, OpenCardDialog,
  OpenRuleDialog, OpenTaskTemplateDialog, OrgSettingsRoleChanged,
  OrgSettingsSaveAllClicked, OrgUsersSearchChanged, OrgUsersSearchDebounced,
  RuleCrudCreated, RuleCrudDeleted, RuleCrudUpdated, RuleDialogCreate,
  RuleDialogDelete, RuleDialogEdit, RulesBackClicked, TaskTemplateCrudCreated,
  TaskTemplateCrudDeleted, TaskTemplateCrudUpdated, TaskTemplateDialogCreate,
  TaskTemplateDialogDelete, TaskTemplateDialogEdit,
  OpenTaskTypeDialog, CloseTaskTypeDialog,
  TaskTypeCrudCreated, TaskTypeCrudUpdated, TaskTypeCrudDeleted,
  TaskTypeDialogCreate, TaskTypeDialogDelete, TaskTypeDialogEdit,
  UserProjectRemoveClicked, UserProjectsAddProjectChanged, UserProjectsAddRoleChanged,
  UserProjectsAddSubmitted, UserProjectsDialogClosed, UserProjectsDialogOpened,
  UserProjectRoleChangeRequested,
  WorkflowCrudCreated, WorkflowCrudDeleted, WorkflowCrudUpdated,
  WorkflowDialogCreate, WorkflowDialogDelete, WorkflowDialogEdit,
  WorkflowRulesClicked,
  CloseWorkflowDialog, OpenWorkflowDialog,
  MemberCapabilitiesDialogClosed, MemberCapabilitiesDialogOpened,
  MemberCapabilitiesSaveClicked, MemberCapabilitiesToggled,
  CapabilityMembersDialogClosed, CapabilityMembersDialogOpened,
  CapabilityMembersSaveClicked, CapabilityMembersToggled,
}

// Workflows
// Task Templates
// Rule Metrics Tab
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/icon_catalog
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/format_date

// =============================================================================
// =============================================================================
// Public API
// =============================================================================

/// Organization settings view - manage user roles.
pub fn view_org_settings(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  div([attribute.class("section")], [
    // Section header with subtitle (Story 4.8: consistent icons + help text)
    section_header.view_with_subtitle(
      icons.OrgUsers,
      t(i18n_text.OrgUsers),
      t(i18n_text.OrgSettingsHelp),
    ),
    // Users table
    view_org_settings_table(model),
    // User projects dialog
    view_user_projects_dialog(model),
  ])
}

fn view_org_settings_table(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  case model.org_settings_users {
    NotAsked ->
      div([attribute.class("empty")], [
        text(t(i18n_text.OpenThisSectionToLoadUsers)),
      ])

    Loading ->
      div([attribute.class("empty")], [text(t(i18n_text.LoadingUsers))])

    Failed(err) ->
      div([attribute.class("error")], [text(err.message)])

    Loaded(users) -> {
      let pending_count = dict.size(model.org_settings_role_drafts)
      let has_pending = pending_count > 0

      div([], [
        // Table using data_table
        data_table.new()
        |> data_table.with_columns([
          // Email
          data_table.column(t(i18n_text.EmailLabel), fn(u: OrgUser) {
            text(u.email)
          }),
          // Org Role (dropdown with change indicator)
          data_table.column(t(i18n_text.OrgRole), fn(u: OrgUser) {
            view_org_role_cell(model, u)
          }),
          // Projects summary
          data_table.column(t(i18n_text.AdminProjects), fn(u: OrgUser) {
            text(format_projects_summary(model, u.id))
          }),
          // Actions
          data_table.column_with_class(
            t(i18n_text.Actions),
            fn(u: OrgUser) {
              button(
                [
                  attribute.class("btn-xs btn-icon"),
                  attribute.attribute("title", t(i18n_text.Manage)),
                  attribute.attribute("aria-label", t(i18n_text.Manage)),
                  event.on_click(UserProjectsDialogOpened(u)),
                ],
                [icons.nav_icon(icons.Cog, icons.Small)],
              )
            },
            "col-actions",
            "cell-actions",
          ),
        ])
        |> data_table.with_rows(users, fn(u: OrgUser) { int.to_string(u.id) })
        |> data_table.view(),
        // Save all button at bottom
        div([attribute.class("save-all-row")], [
          case has_pending {
            True ->
              span([attribute.class("pending-count")], [
                text(
                  int.to_string(pending_count)
                  <> " "
                  <> t(i18n_text.PendingChanges),
                ),
              ])
            False -> element.none()
          },
          button(
            [
              attribute.disabled(!has_pending || model.org_settings_save_in_flight),
              event.on_click(OrgSettingsSaveAllClicked),
            ],
            [text(t(i18n_text.SaveOrgRoleChanges))],
          ),
        ]),
      ])
    }
  }
}

fn view_org_role_cell(model: Model, u: OrgUser) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  let draft = case dict.get(model.org_settings_role_drafts, u.id) {
    Ok(role) -> role
    Error(_) -> u.org_role
  }

  let has_change = dict.has_key(model.org_settings_role_drafts, u.id)

  let inline_error = case
    model.org_settings_error_user_id,
    model.org_settings_error
  {
    opt.Some(id), opt.Some(message) if id == u.id -> message
    _, _ -> ""
  }

  div([], [
    select(
      [
        attribute.value(draft),
        attribute.disabled(model.org_settings_save_in_flight),
        event.on_input(fn(value) { OrgSettingsRoleChanged(u.id, value) }),
      ],
      [
        option([attribute.value("admin")], t(i18n_text.RoleAdmin)),
        option([attribute.value("member")], t(i18n_text.RoleMember)),
      ],
    ),
    // Pending change indicator
    case has_change {
      True -> span([attribute.class("pending-indicator")], [text(" *")])
      False -> element.none()
    },
    // Inline error
    case inline_error == "" {
      True -> element.none()
      False -> div([attribute.class("error")], [text(inline_error)])
    },
  ])
}

/// Dialog for viewing/managing user's project memberships.
fn view_user_projects_dialog(model: Model) -> Element(Msg) {
  case model.user_projects_dialog_open, model.user_projects_dialog_user {
    True, opt.Some(user) -> {
      dialog.view(
        dialog.DialogConfig(
          title: update_helpers.i18n_t(
            model,
            i18n_text.UserProjectsTitle(user.email),
          ),
          icon: opt.None,
          size: dialog.DialogMd,
          on_close: UserProjectsDialogClosed,
        ),
        True,
        model.user_projects_error,
        // Content: project list and add form
        [
          // Current projects list
          case model.user_projects_list {
            NotAsked | Loading ->
              p([attribute.class("loading")], [
                text(update_helpers.i18n_t(model, i18n_text.Loading)),
              ])

            Failed(err) ->
              div([attribute.class("error")], [text(err.message)])

            Loaded(projects) ->
              case list.is_empty(projects) {
                True ->
                  p([attribute.class("empty")], [
                    text(update_helpers.i18n_t(model, i18n_text.UserProjectsEmpty)),
                  ])

                False ->
                  div([attribute.class("user-projects-list")], [
                    table([attribute.class("table")], [
                      thead([], [
                        tr([], [
                          th([], [
                            text(update_helpers.i18n_t(model, i18n_text.Name)),
                          ]),
                          th([], [
                            text(update_helpers.i18n_t(model, i18n_text.RoleInProject)),
                          ]),
                          th([], [
                            text(update_helpers.i18n_t(model, i18n_text.Actions)),
                          ]),
                        ]),
                      ]),
                      keyed.tbody(
                        [],
                        list.map(projects, fn(p) {
                          #(
                            int.to_string(p.id),
                            tr([], [
                              td([], [text(p.name)]),
                              td([], [
                                // Editable role dropdown
                                select(
                                  [
                                    attribute.value(project_role.to_string(p.my_role)),
                                    attribute.disabled(model.user_projects_in_flight),
                                    event.on_input(fn(value) {
                                      UserProjectRoleChangeRequested(p.id, value)
                                    }),
                                  ],
                                  [
                                    option(
                                      [attribute.value("manager")],
                                      update_helpers.i18n_t(model, i18n_text.RoleManager),
                                    ),
                                    option(
                                      [attribute.value("member")],
                                      update_helpers.i18n_t(model, i18n_text.RoleMember),
                                    ),
                                  ],
                                ),
                              ]),
                              td([], [
                                button(
                                  [
                                    attribute.class("btn-danger btn-sm"),
                                    attribute.disabled(
                                      model.user_projects_in_flight,
                                    ),
                                    event.on_click(UserProjectRemoveClicked(p.id)),
                                  ],
                                  [
                                    text(update_helpers.i18n_t(
                                      model,
                                      i18n_text.UserProjectRemove,
                                    )),
                                  ],
                                ),
                              ]),
                            ]),
                          )
                        }),
                      ),
                    ]),
                  ])
              }
          },
          // Add to project form
          hr([]),
          div([attribute.class("add-project-form")], [
            h3([], [
              text(update_helpers.i18n_t(model, i18n_text.UserProjectsAdd)),
            ]),
            div([attribute.class("field-row")], [
              // Project selector
              select(
                [
                  attribute.value(
                    case model.user_projects_add_project_id {
                      opt.Some(id) -> int.to_string(id)
                      opt.None -> ""
                    },
                  ),
                  attribute.disabled(model.user_projects_in_flight),
                  event.on_input(UserProjectsAddProjectChanged),
                ],
                [
                  option([attribute.value("")], update_helpers.i18n_t(
                    model,
                    i18n_text.SelectProject,
                  )),
                  ..view_available_projects_options(model),
                ],
              ),
              // Role selector
              select(
                [
                  attribute.value(model.user_projects_add_role),
                  attribute.disabled(model.user_projects_in_flight),
                  event.on_input(UserProjectsAddRoleChanged),
                ],
                [
                  option(
                    [attribute.value("member")],
                    update_helpers.i18n_t(model, i18n_text.RoleMember),
                  ),
                  option(
                    [attribute.value("manager")],
                    update_helpers.i18n_t(model, i18n_text.RoleManager),
                  ),
                ],
              ),
              button(
                [
                  attribute.disabled(
                    model.user_projects_in_flight
                    || opt.is_none(model.user_projects_add_project_id),
                  ),
                  event.on_click(UserProjectsAddSubmitted),
                ],
                [text(update_helpers.i18n_t(model, i18n_text.Add))],
              ),
            ]),
          ]),
        ],
        // Footer: close button
        [
          button([event.on_click(UserProjectsDialogClosed)], [
            text(update_helpers.i18n_t(model, i18n_text.Close)),
          ]),
        ],
      )
    }

    _, _ -> element.none()
  }
}

/// Get available projects to add user to (exclude projects user is already in).
fn view_available_projects_options(model: Model) -> List(Element(Msg)) {
  // Get all org projects
  let all_projects = case model.projects {
    Loaded(projects) -> projects
    _ -> []
  }

  // Get user's current projects
  let user_project_ids = case model.user_projects_list {
    Loaded(user_projects) -> list.map(user_projects, fn(p) { p.id })
    _ -> []
  }

  // Filter to projects user is not already in
  all_projects
  |> list.filter(fn(p) { !list.contains(user_project_ids, p.id) })
  |> list.map(fn(p) { option([attribute.value(int.to_string(p.id))], p.name) })
}

/// Format projects summary for a user (lazy loaded).
/// Shows "..." if not yet loaded, otherwise "count: name1, name2 (mgr), ..."
fn format_projects_summary(model: Model, user_id: Int) -> String {
  // Check if this is the user whose dialog is open and projects are loaded
  case model.user_projects_dialog_user, model.user_projects_list {
    opt.Some(dialog_user), Loaded(projects) if dialog_user.id == user_id -> {
      let count = list.length(projects)
      case count {
        0 -> update_helpers.i18n_t(model, i18n_text.ProjectsSummary(0, ""))
        _ -> {
          let names = projects
            |> list.take(3)
            |> list.map(fn(p) {
              case p.my_role {
                Manager -> p.name <> " (mgr)"
                Member -> p.name
              }
            })
            |> string.join(", ")

          let suffix = case list.length(projects) > 3 {
            True -> ", +" <> int.to_string(list.length(projects) - 3)
            False -> ""
          }

          update_helpers.i18n_t(model, i18n_text.ProjectsSummary(count, names <> suffix))
        }
      }
    }
    _, _ -> "..."
  }
}

/// Capabilities management view.
pub fn view_capabilities(model: Model) -> Element(Msg) {
  // Get project name for dialog titles (Story 4.8 AC24)
  let project_name = case update_helpers.selected_project(model) {
    opt.Some(project) -> project.name
    opt.None -> ""
  }

  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Crosshairs,
      update_helpers.i18n_t(model, i18n_text.Capabilities),
      dialog.add_button(
        model,
        i18n_text.CreateCapability,
        CapabilityCreateDialogOpened,
      ),
    ),
    // Capabilities list
    view_capabilities_list(model, model.capabilities),
    // Create capability dialog
    view_capabilities_create_dialog(model),
    // Capability members dialog (AC17, Story 4.8 AC24)
    case model.capability_members_dialog_capability_id {
      opt.Some(capability_id) ->
        view_capability_members_dialog(model, capability_id, project_name)
      opt.None -> element.none()
    },
    // Delete capability dialog (Story 4.9 AC9)
    view_capability_delete_dialog(model),
  ])
}

/// Dialog for creating a new capability.
fn view_capabilities_create_dialog(model: Model) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.CreateCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: CapabilityCreateDialogClosed,
    ),
    model.capabilities_create_dialog_open,
    model.capabilities_create_error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { CapabilityCreateSubmitted }),
          attribute.id("capability-create-form"),
        ],
        [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
            input([
              attribute.type_("text"),
              attribute.value(model.capabilities_create_name),
              event.on_input(CapabilityCreateNameChanged),
              attribute.required(True),
              attribute.placeholder(
                update_helpers.i18n_t(model, i18n_text.CapabilityNamePlaceholder),
              ),
              attribute.attribute("aria-label", "Capability name"),
            ]),
          ]),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, CapabilityCreateDialogClosed),
      button(
        [
          attribute.type_("submit"),
          attribute.form("capability-create-form"),
          attribute.disabled(model.capabilities_create_in_flight),
          attribute.class(case model.capabilities_create_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.capabilities_create_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Creating)
            False -> update_helpers.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

/// Dialog for deleting a capability (Story 4.9 AC9).
fn view_capability_delete_dialog(model: Model) -> Element(Msg) {
  // Get capability name for the confirmation message
  let capability_name = case model.capability_delete_dialog_id {
    opt.Some(id) ->
      case model.capabilities {
        Loaded(caps) ->
          caps
          |> list.find(fn(c) { c.id == id })
          |> result.map(fn(c) { c.name })
          |> result.unwrap("")
        _ -> ""
      }
    opt.None -> ""
  }

  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.DeleteCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: CapabilityDeleteDialogClosed,
    ),
    opt.is_some(model.capability_delete_dialog_id),
    model.capability_delete_error,
    // Confirmation content
    [
      p([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.ConfirmDeleteCapability(capability_name),
        )),
      ]),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, CapabilityDeleteDialogClosed),
      button(
        [
          attribute.type_("button"),
          attribute.class("btn btn-danger"),
          attribute.disabled(model.capability_delete_in_flight),
          event.on_click(CapabilityDeleteSubmitted),
        ],
        [
          text(case model.capability_delete_in_flight {
            True -> update_helpers.i18n_t(model, i18n_text.Deleting)
            False -> update_helpers.i18n_t(model, i18n_text.Delete)
          }),
        ],
      ),
    ],
  )
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
        // Section header with subtitle and action (Story 4.8: consistent icons + help text)
        section_header.view_full(
          icons.Team,
          update_helpers.i18n_t(model, i18n_text.MembersTitle(project.name)),
          update_helpers.i18n_t(model, i18n_text.MembersHelp),
          dialog.add_button(model, i18n_text.AddMember, MemberAddDialogOpened),
        ),
        // Members list
        case model.members_remove_error {
          opt.Some(err) -> div([attribute.class("error")], [text(err)])
          opt.None -> element.none()
        },
        view_members_table(model, model.members, model.org_users_cache),
        // Add member dialog
        case model.members_add_dialog_open {
          True -> view_add_member_dialog(model)
          False -> element.none()
        },
        // Remove member confirmation dialog
        case model.members_remove_confirm {
          opt.Some(user) -> view_remove_member_dialog(model, project.name, user)
          opt.None -> element.none()
        },
        // Member capabilities dialog (AC11-14, Story 4.8 AC23)
        case model.member_capabilities_dialog_user_id {
          opt.Some(user_id) ->
            view_member_capabilities_dialog(model, user_id, project.name)
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
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.TaskTypes,
          update_helpers.i18n_t(model, i18n_text.TaskTypesTitle(project.name)),
          dialog.add_button(
            model,
            i18n_text.CreateTaskType,
            OpenTaskTypeDialog(TaskTypeDialogCreate),
          ),
        ),
        // Task types list
        view_task_types_list(model, model.task_types, model.theme),
        // Task type CRUD dialog component (handles create, edit, delete)
        view_task_type_crud_dialog(model, project.id),
      ])
  }
}

/// Render the task-type-crud-dialog Lustre component.
fn view_task_type_crud_dialog(model: Model, project_id: Int) -> Element(Msg) {
  case model.task_types_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, type_json) = case mode {
        TaskTypeDialogCreate -> #("create", attribute.none())
        TaskTypeDialogEdit(task_type) ->
          #("edit", attribute.property("task-type", task_type_to_property_json(task_type, "edit")))
        TaskTypeDialogDelete(task_type) ->
          #("delete", attribute.property("task-type", task_type_to_property_json(task_type, "delete")))
      }

      element.element(
        "task-type-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.locale)),
          attribute.attribute("project-id", int.to_string(project_id)),
          attribute.attribute("mode", mode_str),
          // Property for task type data (edit/delete modes)
          type_json,
          // Event listeners for component events
          event.on("type-created", decode_task_type_created_event()),
          event.on("type-updated", decode_task_type_updated_event()),
          event.on("type-deleted", decode_task_type_deleted_event()),
          event.on("close-requested", decode_task_type_close_event()),
        ],
        [],
      )
    }
  }
}

/// Convert TaskType to JSON for property passing.
fn task_type_to_property_json(task_type: TaskType, mode: String) -> json.Json {
  json.object([
    #("id", json.int(task_type.id)),
    #("name", json.string(task_type.name)),
    #("icon", json.string(task_type.icon)),
    #("capability_id", case task_type.capability_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("tasks_count", json.int(task_type.tasks_count)),
    #("_mode", json.string(mode)),
  ])
}

/// Decoder for type-created event.
fn decode_task_type_created_event() -> decode.Decoder(Msg) {
  use task_type <- decode.field("detail", task_type_decoder())
  decode.success(TaskTypeCrudCreated(task_type))
}

/// Decoder for type-updated event.
fn decode_task_type_updated_event() -> decode.Decoder(Msg) {
  use task_type <- decode.field("detail", task_type_decoder())
  decode.success(TaskTypeCrudUpdated(task_type))
}

/// Decoder for type-deleted event.
fn decode_task_type_deleted_event() -> decode.Decoder(Msg) {
  use id <- decode.field("detail", decode.field("id", decode.int, decode.success))
  decode.success(TaskTypeCrudDeleted(id))
}

/// Decoder for close-requested event.
fn decode_task_type_close_event() -> decode.Decoder(Msg) {
  decode.success(CloseTaskTypeDialog)
}

/// Decoder for TaskType from JSON (used in custom events).
fn task_type_decoder() -> decode.Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  use capability_id <- decode.optional_field("capability_id", opt.None, decode.optional(decode.int))
  use tasks_count <- decode.optional_field("tasks_count", 0, decode.int)
  decode.success(task_type.TaskType(id: id, name: name, icon: icon, capability_id: capability_id, tasks_count: tasks_count))
}

// =============================================================================
// Capabilities Helpers
// =============================================================================

fn view_capabilities_list(
  model: Model,
  capabilities: Remote(List(Capability)),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  // Helper to get member count from cache
  let get_member_count = fn(cap_id: Int) -> Int {
    case dict.get(model.capability_members_cache, cap_id) {
      Ok(ids) -> list.length(ids)
      Error(_) -> 0
    }
  }

  data_table.view_remote_with_forbidden(
    capabilities,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoCapabilitiesYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(t(i18n_text.Name), fn(c: Capability) {
          text(c.name)
        }),
        // Members count (AC16)
        data_table.column_with_class(
          t(i18n_text.AdminMembers),
          fn(c: Capability) {
            span([attribute.class("count-badge")], [
              text(int.to_string(get_member_count(c.id))),
            ])
          },
          "col-number",
          "cell-number",
        ),
        // Actions (Story 4.8 UX, Story 4.9 AC9)
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(c: Capability) {
            div([attribute.class("btn-group")], [
              // Manage members button
              button(
                [
                  attribute.class("btn-icon btn-xs"),
                  attribute.attribute("title", t(i18n_text.ManageMembers)),
                  attribute.attribute("data-testid", "capability-members-btn"),
                  event.on_click(CapabilityMembersDialogOpened(c.id)),
                ],
                [icons.nav_icon(icons.OrgUsers, icons.Small)],
              ),
              // Delete button (Story 4.9 AC9)
              action_buttons.delete_button_with_testid(
                t(i18n_text.Delete),
                CapabilityDeleteDialogOpened(c.id),
                "capability-delete-btn",
              ),
            ])
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(c: Capability) { int.to_string(c.id) }),
  )
}

// =============================================================================
// Members Helpers
// =============================================================================

fn view_members_table(
  model: Model,
  members: Remote(List(ProjectMember)),
  cache: Remote(List(OrgUser)),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  // Check if current user is org admin (can change roles)
  let is_org_admin = case model.user {
    opt.Some(user) -> user.org_role == org_role.Admin
    opt.None -> False
  }

  // Helper to resolve user email from cache
  let resolve_email = fn(user_id: Int) -> String {
    case update_helpers.resolve_org_user(cache, user_id) {
      opt.Some(user) -> user.email
      opt.None -> t(i18n_text.UserNumber(user_id))
    }
  }

  // Helper to get capability count from cache
  let get_cap_count = fn(user_id: Int) -> Int {
    case dict.get(model.member_capabilities_cache, user_id) {
      Ok(ids) -> list.length(ids)
      Error(_) -> 0
    }
  }

  data_table.view_remote_with_forbidden(
    members,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoMembersYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // User email
        data_table.column(t(i18n_text.User), fn(m: ProjectMember) {
          text(resolve_email(m.user_id))
        }),
        // User ID
        data_table.column(t(i18n_text.UserId), fn(m: ProjectMember) {
          text(int.to_string(m.user_id))
        }),
        // Role (dropdown for admins, text for others)
        data_table.column(t(i18n_text.Role), fn(m: ProjectMember) {
          view_member_role_cell(model, m, is_org_admin)
        }),
        // Capabilities count (AC15)
        data_table.column_with_class(
          t(i18n_text.Capabilities),
          fn(m: ProjectMember) {
            span([attribute.class("count-badge")], [
              text(int.to_string(get_cap_count(m.user_id))),
            ])
          },
          "col-number",
          "cell-number",
        ),
        // Created date
        data_table.column(t(i18n_text.CreatedAt), fn(m: ProjectMember) {
          text(format_date.date_only(m.created_at))
        }),
        // Actions (Story 4.8 UX)
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(m: ProjectMember) { view_member_actions(model, m) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(m: ProjectMember) { int.to_string(m.user_id) }),
  )
}

fn view_member_actions(model: Model, m: ProjectMember) -> Element(Msg) {
  div([attribute.class("actions-row")], [
    // Manage capabilities button
    button(
      [
        attribute.class("btn-icon btn-xs"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.ManageCapabilities),
        ),
        attribute.attribute("data-testid", "member-capabilities-btn"),
        event.on_click(MemberCapabilitiesDialogOpened(m.user_id)),
      ],
      [icons.nav_icon(icons.Cog, icons.Small)],
    ),
    // Remove button
    button(
      [
        attribute.class("btn-icon btn-xs btn-danger-icon"),
        attribute.attribute(
          "title",
          update_helpers.i18n_t(model, i18n_text.Remove),
        ),
        event.on_click(MemberRemoveClicked(m.user_id)),
      ],
      [icons.nav_icon(icons.Trash, icons.Small)],
    ),
  ])
}

/// Render role cell - dropdown for org admins, text for project managers.
fn view_member_role_cell(
  model: Model,
  member: ProjectMember,
  is_org_admin: Bool,
) -> Element(Msg) {
  case is_org_admin {
    True ->
      // Org Admin: show dropdown to change role
      select(
        [
          attribute.value(project_role.to_string(member.role)),
          event.on_input(fn(value) {
            let new_role = case value {
              "manager" -> Manager
              _ -> Member
            }
            MemberRoleChangeRequested(member.user_id, new_role)
          }),
        ],
        [
          option(
            [
              attribute.value("member"),
              attribute.selected(member.role == Member),
            ],
            update_helpers.i18n_t(model, i18n_text.RoleMember),
          ),
          option(
            [
              attribute.value("manager"),
              attribute.selected(member.role == Manager),
            ],
            update_helpers.i18n_t(model, i18n_text.RoleManager),
          ),
        ],
      )
    False ->
      // Project Manager: show text only (view only)
      text(project_role.to_string(member.role))
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
            attribute.value(project_role.to_string(model.members_add_role)),
            event.on_input(MemberAddRoleChanged),
          ],
          [
            option(
              [attribute.value("member")],
              update_helpers.i18n_t(model, i18n_text.RoleMember),
            ),
            option(
              [attribute.value("manager")],
              update_helpers.i18n_t(model, i18n_text.RoleManager),
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
                #(
                  int.to_string(u.id),
                  tr([], [
                    td([], [text(u.email)]),
                    td([], [text(u.org_role)]),
                    td([], [text(u.created_at)]),
                    td([], [
                      button([event.on_click(MemberAddUserSelected(u.id))], [
                        text(update_helpers.i18n_t(model, i18n_text.Select)),
                      ]),
                    ]),
                  ]),
                )
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

/// Member capabilities dialog (AC11-14).
/// Shows checkboxes for all project capabilities, allowing assignment.
fn view_member_capabilities_dialog(
  model: Model,
  user_id: Int,
  project_name: String,
) -> Element(Msg) {
  // Get user email for display
  let user_email = case
    update_helpers.resolve_org_user(model.org_users_cache, user_id)
  {
    opt.Some(user) -> user.email
    opt.None ->
      update_helpers.i18n_t(model, i18n_text.UserNumber(user_id))
  }

  // Get all capabilities for the project
  let capabilities = case model.capabilities {
    Loaded(caps) -> caps
    _ -> []
  }

  div([attribute.class("modal")], [
    div([attribute.class("modal-content capabilities-dialog")], [
      h3([], [
        text(
          update_helpers.i18n_t(
            model,
            i18n_text.CapabilitiesForUser(user_email, project_name),
          ),
        ),
      ]),
      // Error display
      case model.member_capabilities_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      // Loading state
      case model.member_capabilities_loading {
        True ->
          div([attribute.class("loading")], [
            text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
          ])
        False ->
          // Capabilities checkbox list (AC12)
          case capabilities {
            [] ->
              div([attribute.class("empty")], [
                text(
                  update_helpers.i18n_t(model, i18n_text.NoCapabilitiesDefined),
                ),
              ])
            _ ->
              div(
                [
                  attribute.class("capabilities-checklist"),
                  attribute.attribute("data-testid", "capabilities-checklist"),
                ],
                list.map(capabilities, fn(cap) {
                  let is_selected =
                    list.contains(model.member_capabilities_selected, cap.id)
                  label(
                    [
                      attribute.class("checkbox-label"),
                      attribute.attribute(
                        "data-capability-id",
                        int.to_string(cap.id),
                      ),
                    ],
                    [
                      input([
                        attribute.type_("checkbox"),
                        attribute.checked(is_selected),
                        event.on_check(fn(_) {
                          MemberCapabilitiesToggled(cap.id)
                        }),
                      ]),
                      span([attribute.class("capability-name")], [
                        text(cap.name),
                      ]),
                    ],
                  )
                }),
              )
          }
      },
      // Actions
      div([attribute.class("actions")], [
        button([event.on_click(MemberCapabilitiesDialogClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            attribute.class("btn-primary"),
            event.on_click(MemberCapabilitiesSaveClicked),
            attribute.disabled(
              model.member_capabilities_saving
              || model.member_capabilities_loading,
            ),
          ],
          [
            text(case model.member_capabilities_saving {
              True -> update_helpers.i18n_t(model, i18n_text.Saving)
              False -> update_helpers.i18n_t(model, i18n_text.Save)
            }),
          ],
        ),
      ]),
    ]),
  ])
}

// =============================================================================
// Capability Members Dialog (Story 4.7 AC16-17)
// =============================================================================

fn view_capability_members_dialog(
  model: Model,
  capability_id: Int,
  project_name: String,
) -> Element(Msg) {
  // Get capability name for display
  let capability_name = case model.capabilities {
    Loaded(caps) ->
      case list.find(caps, fn(c) { c.id == capability_id }) {
        Ok(cap) -> cap.name
        Error(_) -> "Capability #" <> int.to_string(capability_id)
      }
    _ -> "Capability #" <> int.to_string(capability_id)
  }

  // Get project members for the checkbox list
  let members = case model.members {
    Loaded(ms) -> ms
    _ -> []
  }

  div([attribute.class("modal")], [
    div([attribute.class("modal-content members-dialog")], [
      h3([], [
        text(
          update_helpers.i18n_t(
            model,
            i18n_text.MembersForCapability(capability_name, project_name),
          ),
        ),
      ]),
      // Error display
      case model.capability_members_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      // Loading state
      case model.capability_members_loading {
        True ->
          div([attribute.class("loading")], [
            text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
          ])
        False ->
          // Members checkbox list (AC17)
          case members {
            [] ->
              div([attribute.class("empty")], [
                text(update_helpers.i18n_t(model, i18n_text.NoMembersDefined)),
              ])
            _ ->
              div(
                [
                  attribute.class("members-checklist"),
                  attribute.attribute("data-testid", "members-checklist"),
                ],
                list.map(members, fn(member) {
                  // Get member email from cache
                  let email = case
                    update_helpers.resolve_org_user(
                      model.org_users_cache,
                      member.user_id,
                    )
                  {
                    opt.Some(user) -> user.email
                    opt.None ->
                      update_helpers.i18n_t(
                        model,
                        i18n_text.UserNumber(member.user_id),
                      )
                  }
                  let is_selected =
                    list.contains(
                      model.capability_members_selected,
                      member.user_id,
                    )
                  label(
                    [
                      attribute.class("checkbox-label"),
                      attribute.attribute(
                        "data-member-id",
                        int.to_string(member.user_id),
                      ),
                    ],
                    [
                      input([
                        attribute.type_("checkbox"),
                        attribute.checked(is_selected),
                        event.on_check(fn(_) {
                          CapabilityMembersToggled(member.user_id)
                        }),
                      ]),
                      span([attribute.class("member-email")], [text(email)]),
                    ],
                  )
                }),
              )
          }
      },
      // Actions
      div([attribute.class("actions")], [
        button([event.on_click(CapabilityMembersDialogClosed)], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            attribute.class("btn-primary"),
            event.on_click(CapabilityMembersSaveClicked),
            attribute.disabled(
              model.capability_members_saving
              || model.capability_members_loading,
            ),
          ],
          [
            text(case model.capability_members_saving {
              True -> update_helpers.i18n_t(model, i18n_text.Saving)
              False -> update_helpers.i18n_t(model, i18n_text.Save)
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

/// Render a task type icon using the icon catalog.
/// Falls back to CDN for icons not in catalog, or text for non-heroicons.
/// Exported for use in pool/task card views.
pub fn view_task_type_icon_inline(
  icon: String,
  size: Int,
  theme: theme.Theme,
) -> Element(Msg) {
  case string.is_empty(icon) {
    True -> element.none()
    False ->
      case icon_catalog.exists(icon) {
        True -> {
          let class = case theme {
            theme.Dark -> "icon-theme-dark"
            theme.Default -> ""
          }
          icon_catalog.render_with_class(icon, size, class)
        }
        False ->
          // Fallback: try CDN if looks like heroicon, otherwise show as text
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
  }
}

fn view_task_types_list(
  model: Model,
  task_types: Remote(List(TaskType)),
  theme: theme.Theme,
) -> Element(Msg) {
  // Story 4.9: Refactored to use data_table.view_remote_with_forbidden
  let empty_state =
    div([attribute.class("empty")], [
      h2([], [text(update_helpers.i18n_t(model, i18n_text.NoTaskTypesYet))]),
      p([], [text(update_helpers.i18n_t(model, i18n_text.TaskTypesExplain))]),
      p([], [text(update_helpers.i18n_t(model, i18n_text.CreateFirstTaskTypeHint))]),
    ])

  data_table.view_remote_with_forbidden(
    task_types,
    loading_msg: update_helpers.i18n_t(model, i18n_text.LoadingEllipsis),
    empty_msg: "",
    forbidden_msg: update_helpers.i18n_t(model, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_empty_state(empty_state)
      |> data_table.with_columns([
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.Name),
          fn(tt: TaskType) { text(tt.name) },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.Icon),
          fn(tt: TaskType) { view_task_type_icon_inline(tt.icon, 20, theme) },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.CapabilityLabel),
          fn(tt: TaskType) {
            case tt.capability_id {
              opt.Some(id) -> text(int.to_string(id))
              opt.None -> text("-")
            }
          },
        ),
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.CardTasks),
          fn(tt: TaskType) { text(int.to_string(tt.tasks_count)) },
        ),
        data_table.column_with_class(
          update_helpers.i18n_t(model, i18n_text.Actions),
          fn(tt: TaskType) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: update_helpers.i18n_t(model, i18n_text.EditTaskType),
              edit_click: OpenTaskTypeDialog(TaskTypeDialogEdit(tt)),
              edit_testid: "task-type-edit-btn",
              delete_title: update_helpers.i18n_t(model, i18n_text.DeleteTaskType),
              delete_click: OpenTaskTypeDialog(TaskTypeDialogDelete(tt)),
              delete_testid: "task-type-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(tt) { int.to_string(tt.id) }),
  )
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
        text(update_helpers.i18n_t(model, i18n_text.SelectProjectToManageCards)),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.Cards,
          update_helpers.i18n_t(model, i18n_text.CardsTitle(project.name)),
          dialog.add_button(
            model,
            i18n_text.CreateCard,
            OpenCardDialog(CardDialogCreate),
          ),
        ),
        // Story 4.9 AC7-8: Filters bar
        view_cards_filters(model),
        // Cards list (filtered)
        view_cards_list(model, filter_cards(model)),
        // Card CRUD dialog component (handles create, edit, delete)
        view_card_crud_dialog(model, project.id),
      ])
  }
}

/// Render the card-crud-dialog Lustre component.
/// Made public for use in client_view.gleam (Story 4.8 UX: global dialog rendering)
pub fn view_card_crud_dialog(model: Model, project_id: Int) -> Element(Msg) {
  case model.cards_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, card_json) = case mode {
        CardDialogCreate -> #("create", attribute.none())
        CardDialogEdit(card_id) ->
          case admin_cards.find_card(model, card_id) {
            opt.Some(card) -> #("edit", attribute.property("card", card_to_property_json(card, "edit")))
            opt.None -> #("edit", attribute.none())
          }
        CardDialogDelete(card_id) ->
          case admin_cards.find_card(model, card_id) {
            opt.Some(card) -> #("delete", attribute.property("card", card_to_property_json(card, "delete")))
            opt.None -> #("delete", attribute.none())
          }
      }

      element.element(
        "card-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.locale)),
          attribute.attribute("project-id", int.to_string(project_id)),
          attribute.attribute("mode", mode_str),
          // Property for card data (edit/delete modes)
          card_json,
          // Event listeners for component events
          event.on("card-created", decode_card_created_event()),
          event.on("card-updated", decode_card_updated_event()),
          event.on("card-deleted", decode_card_deleted_event()),
          event.on("close-requested", decode_close_requested_event()),
        ],
        [],
      )
    }
  }
}

/// Decoder for card-created event.
fn decode_card_created_event() -> decode.Decoder(Msg) {
  use card <- decode.field("detail", card_decoder())
  decode.success(CardCrudCreated(card))
}

/// Decoder for card-updated event.
fn decode_card_updated_event() -> decode.Decoder(Msg) {
  use card <- decode.field("detail", card_decoder())
  decode.success(CardCrudUpdated(card))
}

/// Decoder for card-deleted event.
fn decode_card_deleted_event() -> decode.Decoder(Msg) {
  use id <- decode.field("detail", decode.field("id", decode.int, decode.success))
  decode.success(CardCrudDeleted(id))
}

/// Decoder for close-requested event.
fn decode_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(CloseCardDialog)
}

/// Decoder for Card from JSON (used in custom events).
fn card_decoder() -> decode.Decoder(Card) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", decode.optional(decode.string))
  use state <- decode.field("state", card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(card.Card(
    id: id,
    project_id: project_id,
    title: title,
    description: description,
    color: color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
  ))
}

fn card_state_decoder() -> decode.Decoder(card.CardState) {
  use state_str <- decode.then(decode.string)
  case state_str {
    "en_curso" -> decode.success(card.EnCurso)
    "cerrada" -> decode.success(card.Cerrada)
    _ -> decode.success(card.Pendiente)
  }
}

/// Convert a Card to JSON for passing as a property to the component.
fn card_to_property_json(c: Card, mode: String) -> json.Json {
  let state_str = case c.state {
    card.Pendiente -> "pendiente"
    card.EnCurso -> "en_curso"
    card.Cerrada -> "cerrada"
  }
  let color_field = case c.color {
    opt.Some(color) -> json.string(color)
    opt.None -> json.null()
  }
  json.object([
    #("id", json.int(c.id)),
    #("project_id", json.int(c.project_id)),
    #("title", json.string(c.title)),
    #("description", json.string(c.description)),
    #("color", color_field),
    #("state", json.string(state_str)),
    #("task_count", json.int(c.task_count)),
    #("completed_count", json.int(c.completed_count)),
    #("created_by", json.int(c.created_by)),
    #("created_at", json.string(c.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Story 4.9 AC7-8: Filter bar for cards (UX improved - inline layout)
fn view_cards_filters(model: Model) -> Element(Msg) {
  div(
    [
      attribute.class("filters-bar filters-inline"),
      attribute.attribute("data-testid", "cards-filters"),
    ],
    [
      // Search input first (with icon placeholder)
      div([attribute.class("filter-group filter-search")], [
        input([
          attribute.type_("search"),
          attribute.placeholder(update_helpers.i18n_t(model, i18n_text.SearchPlaceholder)),
          attribute.value(model.cards_search),
          event.on_input(CardsSearchChanged),
        ]),
      ]),
      // State filter dropdown (AC8)
      div([attribute.class("filter-group")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.CardState))]),
        select(
          [
            attribute.class("filter-select"),
            attribute.attribute("data-testid", "cards-state-filter"),
            event.on_input(CardsStateFilterChanged),
          ],
          [
            option(
              [attribute.value(""), attribute.selected(model.cards_state_filter == opt.None)],
              update_helpers.i18n_t(model, i18n_text.AllOption),
            ),
            option(
              [
                attribute.value("pendiente"),
                attribute.selected(model.cards_state_filter == opt.Some(card.Pendiente)),
              ],
              update_helpers.i18n_t(model, i18n_text.CardStatePendiente),
            ),
            option(
              [
                attribute.value("en_curso"),
                attribute.selected(model.cards_state_filter == opt.Some(card.EnCurso)),
              ],
              update_helpers.i18n_t(model, i18n_text.CardStateEnCurso),
            ),
            option(
              [
                attribute.value("cerrada"),
                attribute.selected(model.cards_state_filter == opt.Some(card.Cerrada)),
              ],
              update_helpers.i18n_t(model, i18n_text.CardStateCerrada),
            ),
          ],
        ),
      ]),
      // Show empty checkbox (AC7) - unchecked by default
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.cards_show_empty),
            attribute.attribute("data-testid", "show-empty-cards"),
            event.on_check(fn(_) { CardsShowEmptyToggled }),
          ]),
          text(update_helpers.i18n_t(model, i18n_text.ShowEmptyCards)),
        ]),
      ]),
      // Show completed checkbox - unchecked by default
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.cards_show_completed),
            attribute.attribute("data-testid", "show-completed-cards"),
            event.on_check(fn(_) { CardsShowCompletedToggled }),
          ]),
          text(update_helpers.i18n_t(model, i18n_text.ShowCompletedCards)),
        ]),
      ]),
    ],
  )
}

/// Story 4.9: Filter cards based on model filters (UX improved)
fn filter_cards(model: Model) -> Remote(List(Card)) {
  case model.cards {
    Loaded(cards) -> {
      let filtered =
        cards
        |> list.filter(fn(c) {
          // Filter by state dropdown
          let state_match = case model.cards_state_filter {
            opt.None -> True
            opt.Some(state) -> c.state == state
          }
          // Filter by empty (show_empty = False by default = hide cards with 0 tasks)
          let empty_match = case model.cards_show_empty {
            True -> True
            False -> c.task_count > 0
          }
          // Filter by completed (show_completed = False by default = hide Cerrada cards)
          let completed_match = case model.cards_show_completed {
            True -> True
            False -> c.state != card.Cerrada
          }
          // Filter by search
          let search_match = case string.is_empty(model.cards_search) {
            True -> True
            False ->
              string.contains(
                string.lowercase(c.title),
                string.lowercase(model.cards_search),
              )
          }
          state_match && empty_match && completed_match && search_match
        })
      Loaded(filtered)
    }
    other -> other
  }
}

fn view_cards_list(model: Model, cards: Remote(List(Card))) -> Element(Msg) {
  // E08: Improved empty state with guidance - using data_table.view_remote_with_forbidden
  let empty_state =
    div([attribute.class("empty-state")], [
      div([attribute.class("empty-state-icon")], [icons.nav_icon(icons.ClipboardDoc, icons.Large)]),
      div([attribute.class("empty-state-title")], [
        text(update_helpers.i18n_t(model, i18n_text.NoCardsYet)),
      ]),
      div([attribute.class("empty-state-description")], [
        text("Las tarjetas agrupan tareas relacionadas. Crea tu primera tarjeta para organizar el trabajo."),
      ]),
    ])

  data_table.view_remote_with_forbidden(
    cards,
    loading_msg: update_helpers.i18n_t(model, i18n_text.LoadingEllipsis),
    empty_msg: "",
    forbidden_msg: update_helpers.i18n_t(model, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_empty_state(empty_state)
      |> data_table.with_columns([
        // UX: Título con indicador de color (círculo)
        data_table.column_with_class(
          update_helpers.i18n_t(model, i18n_text.CardTitle),
          fn(c: Card) {
            let color_style = case c.color {
              opt.Some(hex) -> "background-color: " <> hex <> ";"
              opt.None -> "background-color: var(--sb-muted);"
            }
            div([attribute.class("card-title-with-color")], [
              span([
                attribute.class("card-color-dot"),
                attribute.attribute("style", color_style),
              ], []),
              text(c.title),
            ])
          },
          "",
          "card-title-cell",
        ),
        // UX: Estado con badge de color semántico
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.CardState),
          fn(c: Card) { view_card_state_badge(model, c.state) },
        ),
        // UX: Progreso con mini barra + texto
        data_table.column(
          update_helpers.i18n_t(model, i18n_text.CardTasks),
          fn(c: Card) { view_card_progress(c.completed_count, c.task_count) },
        ),
        // UX: Acciones con iconos (como Task Types)
        data_table.column_with_class(
          update_helpers.i18n_t(model, i18n_text.Actions),
          fn(c: Card) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: update_helpers.i18n_t(model, i18n_text.EditCard),
              edit_click: OpenCardDialog(CardDialogEdit(c.id)),
              edit_testid: "card-edit-btn",
              delete_title: update_helpers.i18n_t(model, i18n_text.DeleteCard),
              delete_click: OpenCardDialog(CardDialogDelete(c.id)),
              delete_testid: "card-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(c) { int.to_string(c.id) }),
  )
}

/// UX: State badge with semantic color
fn view_card_state_badge(model: Model, state: card.CardState) -> Element(Msg) {
  let #(label, class) = case state {
    card.Pendiente -> #(update_helpers.i18n_t(model, i18n_text.CardStatePendiente), "state-badge state-pending")
    card.EnCurso -> #(update_helpers.i18n_t(model, i18n_text.CardStateEnCurso), "state-badge state-active")
    card.Cerrada -> #(update_helpers.i18n_t(model, i18n_text.CardStateCerrada), "state-badge state-completed")
  }
  span([attribute.class(class)], [text(label)])
}

/// UX: Progress bar + count
fn view_card_progress(completed: Int, total: Int) -> Element(Msg) {
  let percent = case total {
    0 -> 0
    _ -> { completed * 100 } / total
  }
  let width_style = "width: " <> int.to_string(percent) <> "%;"
  div([attribute.class("card-progress-cell")], [
    div([attribute.class("progress-bar-mini")], [
      div([
        attribute.class("progress-fill-mini"),
        attribute.attribute("style", width_style),
      ], []),
    ]),
    span([attribute.class("progress-text-mini")], [
      text(int.to_string(completed) <> "/" <> int.to_string(total)),
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
  // Workflows are project-scoped, so require a project to be selected (AC22)
  case selected_project {
    opt.None ->
      div([attribute.class("section")], [
        div([attribute.class("empty")], [
          text(update_helpers.i18n_t(model, i18n_text.SelectProjectForWorkflows)),
        ]),
      ])
    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.Workflows,
          update_helpers.i18n_t(model, i18n_text.WorkflowsProjectTitle(project.name)),
          dialog.add_button(
            model,
            i18n_text.CreateWorkflow,
            OpenWorkflowDialog(WorkflowDialogCreate),
          ),
        ),
        // Story 4.9 AC21: Contextual hint with link to Templates
        view_rules_hint(model),
        // Project workflows table (AC23)
        view_workflows_table(model, model.workflows_project, opt.Some(project)),
        // Workflow CRUD dialog component (handles create, edit, delete)
        view_workflow_crud_dialog(model),
      ])
  }
}

/// Story 4.9 AC21: Contextual hint linking Rules to Templates.
fn view_rules_hint(model: Model) -> Element(Msg) {
  div([attribute.class("info-callout")], [
    span([attribute.class("info-callout-icon")], [text("\u{1F4A1}")]),
    span([attribute.class("info-callout-text")], [
      text(update_helpers.i18n_t(model, i18n_text.RulesHintTemplates)),
      a(
        [
          attribute.href("/config/templates"),
          attribute.class("info-callout-link"),
        ],
        [text(update_helpers.i18n_t(model, i18n_text.RulesHintTemplatesLink) <> " \u{2192}")],
      ),
    ]),
  ])
}

/// Render the workflow-crud-dialog Lustre component.
fn view_workflow_crud_dialog(model: Model) -> Element(Msg) {
  case model.workflows_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, workflow_json, project_id_attr) = case mode {
        WorkflowDialogCreate -> #(
          "create",
          attribute.none(),
          case model.selected_project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        WorkflowDialogEdit(workflow) -> #(
          "edit",
          attribute.property("workflow", workflow_to_property_json(workflow, "edit")),
          case workflow.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        WorkflowDialogDelete(workflow) -> #(
          "delete",
          attribute.property("workflow", workflow_to_property_json(workflow, "delete")),
          case workflow.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
      }

      element.element(
        "workflow-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          // Property for workflow data (edit/delete modes)
          workflow_json,
          // Event listeners for component events
          event.on("workflow-created", decode_workflow_created_event()),
          event.on("workflow-updated", decode_workflow_updated_event()),
          event.on("workflow-deleted", decode_workflow_deleted_event()),
          event.on("close-requested", decode_workflow_close_requested_event()),
        ],
        [],
      )
    }
  }
}

/// Convert workflow to JSON for property passing to component.
fn workflow_to_property_json(workflow: Workflow, mode: String) -> json.Json {
  json.object([
    #("id", json.int(workflow.id)),
    #("org_id", json.int(workflow.org_id)),
    #("project_id", case workflow.project_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("name", json.string(workflow.name)),
    #("description", case workflow.description {
      opt.Some(desc) -> json.string(desc)
      opt.None -> json.null()
    }),
    #("active", json.bool(workflow.active)),
    #("rule_count", json.int(workflow.rule_count)),
    #("created_by", json.int(workflow.created_by)),
    #("created_at", json.string(workflow.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Decoder for workflow-created event.
fn decode_workflow_created_event() -> decode.Decoder(Msg) {
  use workflow <- decode.field("detail", workflow_decoder())
  decode.success(WorkflowCrudCreated(workflow))
}

/// Decoder for workflow-updated event.
fn decode_workflow_updated_event() -> decode.Decoder(Msg) {
  use workflow <- decode.field("detail", workflow_decoder())
  decode.success(WorkflowCrudUpdated(workflow))
}

/// Decoder for workflow-deleted event.
fn decode_workflow_deleted_event() -> decode.Decoder(Msg) {
  use id <- decode.field("detail", decode.field("id", decode.int, decode.success))
  decode.success(WorkflowCrudDeleted(id))
}

/// Decoder for Workflow from JSON (used in custom events).
fn workflow_decoder() -> decode.Decoder(Workflow) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use active <- decode.field("active", decode.bool)
  use rule_count <- decode.field("rule_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  decode.success(Workflow(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    active: active,
    rule_count: rule_count,
    created_by: created_by,
    created_at: created_at,
  ))
}

/// Decoder for close-requested event from workflow dialog.
fn decode_workflow_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(CloseWorkflowDialog)
}

fn view_workflows_table(
  model: Model,
  workflows: Remote(List(Workflow)),
  _project: opt.Option(Project),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote_with_forbidden(
    workflows,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoWorkflowsYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(t(i18n_text.WorkflowName), fn(w: Workflow) {
          text(w.name)
        }),
        // Active status
        data_table.column(t(i18n_text.WorkflowActive), fn(w: Workflow) {
          text(case w.active {
            True -> "✓"
            False -> "✗"
          })
        }),
        // Rules count
        data_table.column(t(i18n_text.WorkflowRules), fn(w: Workflow) {
          text(int.to_string(w.rule_count))
        }),
        // Actions
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(w: Workflow) { view_workflow_actions(model, w) },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(w: Workflow) { int.to_string(w.id) }),
  )
}

fn view_workflow_actions(model: Model, w: Workflow) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  div([attribute.class("btn-group")], [
    // Rules button - navigate to rules view
    button(
      [
        attribute.class("btn-icon btn-xs"),
        attribute.attribute("title", t(i18n_text.WorkflowRules)),
        event.on_click(WorkflowRulesClicked(w.id)),
      ],
      [icons.nav_icon(icons.Cog, icons.Small)],
    ),
    // Edit button
    action_buttons.edit_button(t(i18n_text.EditWorkflow), OpenWorkflowDialog(WorkflowDialogEdit(w))),
    // Delete button
    action_buttons.delete_button(t(i18n_text.DeleteWorkflow), OpenWorkflowDialog(WorkflowDialogDelete(w))),
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
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Rules,
      update_helpers.i18n_t(model, i18n_text.RulesTitle(workflow_name)),
      dialog.add_button(model, i18n_text.CreateRule, OpenRuleDialog(RuleDialogCreate)),
    ),
    view_rules_table(model, model.rules, model.rules_metrics),
    // Rule CRUD dialog component (handles create/edit/delete internally)
    view_rule_crud_dialog(model, workflow_id),
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
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  // We need to pass metrics to the row renderer, so we create a wrapper type
  let rules_with_metrics = case rules {
    Loaded(rs) -> Loaded(list.map(rs, fn(r) { #(r, get_rule_metrics(metrics, r.id)) }))
    Loading -> Loading
    NotAsked -> NotAsked
    Failed(err) -> Failed(err)
  }

  data_table.view_remote_with_forbidden(
    rules_with_metrics,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoRulesYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name
        data_table.column(t(i18n_text.RuleName), fn(item: #(Rule, #(Int, Int))) {
          let #(r, _) = item
          text(r.name)
        }),
        // Resource type
        data_table.column(t(i18n_text.RuleResourceType), fn(item: #(Rule, #(Int, Int))) {
          let #(r, _) = item
          text(r.resource_type)
        }),
        // To state
        data_table.column(t(i18n_text.RuleToState), fn(item: #(Rule, #(Int, Int))) {
          let #(r, _) = item
          text(r.to_state)
        }),
        // Active
        data_table.column(t(i18n_text.RuleActive), fn(item: #(Rule, #(Int, Int))) {
          let #(r, _) = item
          text(case r.active {
            True -> "✓"
            False -> "✗"
          })
        }),
        // Applied metrics
        data_table.column(t(i18n_text.RuleMetricsApplied), fn(item: #(Rule, #(Int, Int))) {
          let #(_, #(applied, _)) = item
          span([attribute.class("metric applied")], [text(int.to_string(applied))])
        }),
        // Suppressed metrics
        data_table.column(t(i18n_text.RuleMetricsSuppressed), fn(item: #(Rule, #(Int, Int))) {
          let #(_, #(_, suppressed)) = item
          span([attribute.class("metric suppressed")], [text(int.to_string(suppressed))])
        }),
        // Actions
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(item: #(Rule, #(Int, Int))) {
            let #(r, _) = item
            action_buttons.edit_delete_row(
              edit_title: t(i18n_text.EditRule),
              edit_click: OpenRuleDialog(RuleDialogEdit(r)),
              delete_title: t(i18n_text.DeleteRule),
              delete_click: OpenRuleDialog(RuleDialogDelete(r)),
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(item: #(Rule, #(Int, Int))) {
        let #(r, _) = item
        int.to_string(r.id)
      }),
  )
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

/// Renders the rule-crud-dialog component.
/// The component handles create/edit/delete internally and emits events.
fn view_rule_crud_dialog(model: Model, workflow_id: Int) -> Element(Msg) {
  // Build mode attribute based on dialog mode
  let mode_attr = case model.rules_dialog_mode {
    opt.None -> "closed"
    opt.Some(RuleDialogCreate) -> "create"
    opt.Some(RuleDialogEdit(_)) -> "edit"
    opt.Some(RuleDialogDelete(_)) -> "delete"
  }

  // Build rule property for edit/delete modes (includes _mode field for component)
  let rule_prop = case model.rules_dialog_mode {
    opt.Some(RuleDialogEdit(rule)) -> attribute.property("rule", rule_to_json(rule, "edit"))
    opt.Some(RuleDialogDelete(rule)) -> attribute.property("rule", rule_to_json(rule, "delete"))
    _ -> attribute.none()
  }

  // Build task types property (include icon for decoder)
  let task_types_json = case model.task_types {
    Loaded(types) ->
      json.array(types, fn(tt) {
        json.object([
          #("id", json.int(tt.id)),
          #("name", json.string(tt.name)),
          #("icon", json.string(tt.icon)),
        ])
      })
    _ -> json.array([], fn(_: Nil) { json.null() })
  }

  element.element(
    "rule-crud-dialog",
    [
      attribute.attribute("locale", locale.serialize(model.locale)),
      attribute.attribute("workflow-id", int.to_string(workflow_id)),
      attribute.attribute("mode", mode_attr),
      rule_prop,
      attribute.property("task-types", task_types_json),
      // Event handlers
      event.on("rule-created", decode_rule_event(RuleCrudCreated)),
      event.on("rule-updated", decode_rule_event(RuleCrudUpdated)),
      event.on("rule-deleted", decode_rule_id_event(RuleCrudDeleted)),
      event.on("close-requested", decode_close_event(CloseRuleDialog)),
    ],
    [],
  )
}

/// Convert a Rule to JSON for property passing to component.
/// Includes _mode field to indicate edit or delete operation.
fn rule_to_json(rule: Rule, mode: String) -> json.Json {
  json.object([
    #("id", json.int(rule.id)),
    #("workflow_id", json.int(rule.workflow_id)),
    #("name", json.string(rule.name)),
    #("goal", json.nullable(rule.goal, json.string)),
    #("resource_type", json.string(rule.resource_type)),
    #("task_type_id", json.nullable(rule.task_type_id, json.int)),
    #("to_state", json.string(rule.to_state)),
    #("active", json.bool(rule.active)),
    #("created_at", json.string(rule.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Decode rule event from component custom event.
fn decode_rule_event(to_msg: fn(Rule) -> Msg) -> decode.Decoder(Msg) {
  decode.at(
    ["detail"],
    {
      use id <- decode.field("id", decode.int)
      use workflow_id <- decode.field("workflow_id", decode.int)
      use name <- decode.field("name", decode.string)
      use goal <- decode.field("goal", decode.optional(decode.string))
      use resource_type <- decode.field("resource_type", decode.string)
      use task_type_id <- decode.field("task_type_id", decode.optional(decode.int))
      use to_state <- decode.field("to_state", decode.string)
      use active <- decode.field("active", decode.bool)
      use created_at <- decode.field("created_at", decode.string)
      decode.success(to_msg(workflow.Rule(
        id: id,
        workflow_id: workflow_id,
        name: name,
        goal: goal,
        resource_type: resource_type,
        task_type_id: task_type_id,
        to_state: to_state,
        active: active,
        created_at: created_at,
      )))
    },
  )
}

/// Decode rule ID from delete event.
fn decode_rule_id_event(to_msg: fn(Int) -> Msg) -> decode.Decoder(Msg) {
  decode.at(["detail", "rule_id"], decode.int)
  |> decode.map(to_msg)
}

/// Decode close event (no payload).
fn decode_close_event(msg: Msg) -> decode.Decoder(Msg) {
  decode.success(msg)
}

// =============================================================================
// Task Templates Views
// =============================================================================

/// Task templates management view (project-scoped only).
pub fn view_task_templates(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  // Get title with project name
  let title = case selected_project {
    opt.Some(project) ->
      update_helpers.i18n_t(model, i18n_text.TaskTemplatesProjectTitle(project.name))
    opt.None ->
      update_helpers.i18n_t(model, i18n_text.TaskTemplatesTitle)
  }

  div([attribute.class("section")], [
    // Section header with action button
    section_header.view_with_action(
      icons.TaskTemplates,
      title,
      dialog.add_button(
        model,
        i18n_text.CreateTaskTemplate,
        OpenTaskTemplateDialog(TaskTemplateDialogCreate),
      ),
    ),
    // Story 4.9: Unified hint with rules link and variables info
    view_templates_hint(model),
    // Templates table (project-scoped)
    view_task_templates_table(model, model.task_templates_project),
    // Task template CRUD dialog component
    view_task_template_crud_dialog(model),
  ])
}

/// Story 4.9: Unified hint with rules link and variables documentation.
fn view_templates_hint(model: Model) -> Element(Msg) {
  div([attribute.class("info-callout")], [
    span([attribute.class("info-callout-icon")], [text("\u{1F4A1}")]),
    div([attribute.class("info-callout-content")], [
      span([attribute.class("info-callout-text")], [
        text(update_helpers.i18n_t(model, i18n_text.TemplatesHintRules)),
        a(
          [
            attribute.href("/config/workflows"),
            attribute.class("info-callout-link"),
          ],
          [text(update_helpers.i18n_t(model, i18n_text.TemplatesHintRulesLink) <> " \u{2192}")],
        ),
      ]),
      div([attribute.class("info-callout-variables")], [
        text(update_helpers.i18n_t(model, i18n_text.TaskTemplateVariablesHelp)),
      ]),
    ]),
  ])
}

/// Render the task-template-crud-dialog Lustre component.
fn view_task_template_crud_dialog(model: Model) -> Element(Msg) {
  case model.task_templates_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, template_json, project_id_attr) = case mode {
        TaskTemplateDialogCreate -> #(
          "create",
          attribute.none(),
          case model.selected_project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        TaskTemplateDialogEdit(template) -> #(
          "edit",
          attribute.property("template", task_template_to_property_json(template, "edit")),
          case template.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
        TaskTemplateDialogDelete(template) -> #(
          "delete",
          attribute.property("template", task_template_to_property_json(template, "delete")),
          case template.project_id {
            opt.Some(id) -> attribute.attribute("project-id", int.to_string(id))
            opt.None -> attribute.none()
          },
        )
      }

      element.element(
        "task-template-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.locale)),
          project_id_attr,
          attribute.attribute("mode", mode_str),
          // Property for template data (edit/delete modes)
          template_json,
          // Property for task types list
          attribute.property("task-types", task_types_to_property_json(model.task_types)),
          // Event listeners for component events
          event.on("task-template-created", decode_task_template_created_event()),
          event.on("task-template-updated", decode_task_template_updated_event()),
          event.on("task-template-deleted", decode_task_template_deleted_event()),
          event.on("close-requested", decode_task_template_close_requested_event()),
        ],
        [],
      )
    }
  }
}

/// Convert task template to JSON for property passing to component.
fn task_template_to_property_json(template: TaskTemplate, mode: String) -> json.Json {
  json.object([
    #("id", json.int(template.id)),
    #("org_id", json.int(template.org_id)),
    #("project_id", case template.project_id {
      opt.Some(id) -> json.int(id)
      opt.None -> json.null()
    }),
    #("name", json.string(template.name)),
    #("description", case template.description {
      opt.Some(desc) -> json.string(desc)
      opt.None -> json.null()
    }),
    #("type_id", json.int(template.type_id)),
    #("type_name", json.string(template.type_name)),
    #("priority", json.int(template.priority)),
    #("created_by", json.int(template.created_by)),
    #("created_at", json.string(template.created_at)),
    #("_mode", json.string(mode)),
  ])
}

/// Convert task types to JSON for property passing to component.
fn task_types_to_property_json(task_types: Remote(List(TaskType))) -> json.Json {
  case task_types {
    Loaded(types) ->
      json.array(types, fn(tt: TaskType) {
        json.object([
          #("id", json.int(tt.id)),
          #("name", json.string(tt.name)),
          #("icon", json.string(tt.icon)),
        ])
      })
    _ -> json.array([], fn(_) { json.null() })
  }
}

/// Decoder for task-template-created event.
fn decode_task_template_created_event() -> decode.Decoder(Msg) {
  use template <- decode.field("detail", task_template_decoder())
  decode.success(TaskTemplateCrudCreated(template))
}

/// Decoder for task-template-updated event.
fn decode_task_template_updated_event() -> decode.Decoder(Msg) {
  use template <- decode.field("detail", task_template_decoder())
  decode.success(TaskTemplateCrudUpdated(template))
}

/// Decoder for task-template-deleted event.
fn decode_task_template_deleted_event() -> decode.Decoder(Msg) {
  use id <- decode.field("detail", decode.field("id", decode.int, decode.success))
  decode.success(TaskTemplateCrudDeleted(id))
}

/// Decoder for close-requested event from task template component.
fn decode_task_template_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(CloseTaskTemplateDialog)
}

/// Decoder for TaskTemplate from JSON (used in custom events).
/// Story 4.9 AC20: Added rules_count field.
fn task_template_decoder() -> decode.Decoder(TaskTemplate) {
  use id <- decode.field("id", decode.int)
  use org_id <- decode.field("org_id", decode.int)
  use project_id <- decode.field("project_id", decode.optional(decode.int))
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use type_id <- decode.field("type_id", decode.int)
  use type_name <- decode.field("type_name", decode.string)
  use priority <- decode.field("priority", decode.int)
  use _created_by <- decode.field("created_by", decode.int)
  use _created_at <- decode.field("created_at", decode.string)
  use rules_count <- decode.optional_field("rules_count", 0, decode.int)
  decode.success(workflow.TaskTemplate(
    id: id,
    org_id: org_id,
    project_id: project_id,
    name: name,
    description: description,
    type_id: type_id,
    type_name: type_name,
    priority: priority,
    created_by: 0,
    created_at: "",
    rules_count: rules_count,
  ))
}

fn view_task_templates_table(
  model: Model,
  templates: Remote(List(TaskTemplate)),
) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote_with_forbidden(
    templates,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoTaskTemplatesYet),
    forbidden_msg: t(i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_columns([
        // Name column
        data_table.column(t(i18n_text.TaskTemplateName), fn(tmpl: TaskTemplate) {
          text(tmpl.name)
        }),
        // Type column (task type)
        data_table.column(t(i18n_text.TaskTemplateType), fn(tmpl: TaskTemplate) {
          text(tmpl.type_name)
        }),
        // Priority column
        data_table.column_with_class(
          t(i18n_text.TaskTemplatePriority),
          fn(tmpl: TaskTemplate) {
            span([attribute.class("priority-badge")], [
              text(int.to_string(tmpl.priority)),
            ])
          },
          "col-number",
          "cell-number",
        ),
        // Actions column with icon buttons
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(tmpl: TaskTemplate) {
            action_buttons.edit_delete_row_with_testid(
              edit_title: t(i18n_text.EditTaskTemplate),
              edit_click: OpenTaskTemplateDialog(TaskTemplateDialogEdit(tmpl)),
              edit_testid: "template-edit-btn",
              delete_title: t(i18n_text.Delete),
              delete_click: OpenTaskTemplateDialog(TaskTemplateDialogDelete(tmpl)),
              delete_testid: "template-delete-btn",
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(tmpl) { int.to_string(tmpl.id) }),
  )
}

// =============================================================================
// Rule Metrics Tab Views
// =============================================================================

/// Rule metrics tab view.
pub fn view_rule_metrics(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }
  let is_loading = case model.admin_rule_metrics {
    Loading -> True
    _ -> False
  }

  div([attribute.class("section")], [
    // Header with icon (Story 4.8: consistent icons via section_header)
    section_header.view(icons.Metrics, t(i18n_text.RuleMetricsTitle)),
    // Description tooltip
    div([attribute.class("section-description")], [
      icons.nav_icon(icons.Info, icons.Small),
      text(" " <> t(i18n_text.RuleMetricsDescription)),
    ]),
    // Card wrapper
    div([attribute.class("admin-card")], [
      // Quick range buttons with active state
      div([attribute.class("quick-ranges")], [
        span([attribute.class("quick-ranges-label")], [
          text(t(i18n_text.RuleMetricsQuickRange)),
        ]),
        view_quick_range_button(model, t(i18n_text.RuleMetrics7Days), 7),
        view_quick_range_button(model, t(i18n_text.RuleMetrics30Days), 30),
        view_quick_range_button(model, t(i18n_text.RuleMetrics90Days), 90),
      ]),
      // Date range inputs - auto-refresh on change
      div([attribute.class("filters-row")], [
        div([attribute.class("field")], [
          label([attribute.class("filter-label")], [
            text(t(i18n_text.RuleMetricsFrom)),
          ]),
          input([
            attribute.type_("date"),
            attribute.value(model.admin_rule_metrics_from),
            // Auto-refresh on date change
            event.on_input(AdminRuleMetricsFromChangedAndRefresh),
            attribute.attribute("aria-label", t(i18n_text.RuleMetricsFrom)),
          ]),
        ]),
        div([attribute.class("field")], [
          label([attribute.class("filter-label")], [
            text(t(i18n_text.RuleMetricsTo)),
          ]),
          input([
            attribute.type_("date"),
            attribute.value(model.admin_rule_metrics_to),
            // Auto-refresh on date change
            event.on_input(AdminRuleMetricsToChangedAndRefresh),
            attribute.attribute("aria-label", t(i18n_text.RuleMetricsTo)),
          ]),
        ]),
        // Loading indicator (replaces manual refresh button)
        case is_loading {
          True ->
            div([attribute.class("field loading-indicator")], [
              span([attribute.class("btn-spinner")], []),
              text(" " <> t(i18n_text.LoadingEllipsis)),
            ])
          False -> element.none()
        },
      ]),
    ]),
    // Results
    view_rule_metrics_results(model),
  ])
}

/// Quick range button helper with active state.
fn view_quick_range_button(model: Model, label: String, days: Int) -> Element(Msg) {
  let today = client_ffi.date_today()
  let from = client_ffi.date_days_ago(days)

  // Check if this range is currently active
  let is_active =
    model.admin_rule_metrics_from == from && model.admin_rule_metrics_to == today

  let class = case is_active {
    True -> "btn-chip btn-chip-active"
    False -> "btn-chip"
  }

  button(
    [
      attribute.class(class),
      event.on_click(AdminRuleMetricsQuickRangeClicked(from, today)),
      attribute.attribute("aria-pressed", case is_active {
        True -> "true"
        False -> "false"
      }),
    ],
    [text(label)],
  )
}

/// Results section with improved empty state (T5).
fn view_rule_metrics_results(model: Model) -> Element(Msg) {
  case model.admin_rule_metrics {
    NotAsked ->
      // Empty state with icon and action hint (T5)
      div([attribute.class("empty-state")], [
        div([attribute.class("empty-state-icon")], [icons.nav_icon(icons.ChartUp, icons.Large)]),
        div([attribute.class("empty-state-title")], [
          text("Sin datos que mostrar"),
        ]),
        div([attribute.class("empty-state-description")], [
          text(
            "Selecciona un rango de fechas o usa los botones de rango rápido para ver las métricas de tus automatizaciones.",
          ),
        ]),
      ])

    Loading ->
      div([attribute.class("loading-state")], [
        div([attribute.class("loading-spinner")], []),
        text("Cargando métricas..."),
      ])

    Failed(err) ->
      div([attribute.class("error-state")], [
        span([attribute.class("error-icon")], [icons.nav_icon(icons.Warning, icons.Small)]),
        text(err.message),
      ])

    Loaded(workflows) ->
      case workflows {
        [] ->
          div([attribute.class("empty-state")], [
            div([attribute.class("empty-state-icon")], [icons.nav_icon(icons.EmptyMailbox, icons.Large)]),
            div([attribute.class("empty-state-title")], [
              text("No hay ejecuciones"),
            ]),
            div([attribute.class("empty-state-description")], [
              text(
                "No se encontraron ejecuciones de automatizaciones en el rango seleccionado.",
              ),
            ]),
          ])
        _ ->
          div([attribute.class("admin-card")], [
            div([attribute.class("admin-card-header")], [
              span([], [icons.nav_icon(icons.ClipboardDoc, icons.Small)]),
              text(" Resultados"),
            ]),
            view_rule_metrics_table(model, model.admin_rule_metrics),
          ])
      }
  }
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

    Failed(err) -> div([attribute.class("error")], [text(err.message)])

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
                  th([], [
                    text(update_helpers.i18n_t(model, i18n_text.WorkflowName)),
                  ]),
                  th([], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.RuleMetricsRuleCount,
                    )),
                  ]),
                  th([], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.RuleMetricsEvaluated,
                    )),
                  ]),
                  th([], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.RuleMetricsApplied,
                    )),
                  ]),
                  th([], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.RuleMetricsSuppressed,
                    )),
                  ]),
                ]),
              ]),
              keyed.tbody(
                [],
                list.flat_map(workflows, fn(w) { view_workflow_row(model, w) }),
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

  let main_row = #(
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
                th([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.RuleMetricsEvaluated,
                  )),
                ]),
                th([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.RuleMetricsApplied,
                  )),
                ]),
                th([], [
                  text(update_helpers.i18n_t(
                    model,
                    i18n_text.RuleMetricsSuppressed,
                  )),
                ]),
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
                      span([attribute.class("metric suppressed")], [
                        text(int.to_string(r.suppressed_count)),
                      ]),
                    ]),
                    td([], [
                      button(
                        [
                          attribute.class("btn-small"),
                          event.on_click(AdminRuleMetricsDrilldownClicked(
                            r.rule_id,
                          )),
                        ],
                        [
                          text(update_helpers.i18n_t(
                            model,
                            i18n_text.ViewDetails,
                          )),
                        ],
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
              text(update_helpers.i18n_t(model, i18n_text.RuleMetricsDrilldown)),
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
              text(update_helpers.i18n_t(
                model,
                i18n_text.SuppressionNotUserTriggered,
              )),
            ]),
            span([attribute.class("breakdown-value")], [
              text(int.to_string(
                details.suppression_breakdown.not_user_triggered,
              )),
            ]),
          ]),
          div([attribute.class("breakdown-item")], [
            span([attribute.class("breakdown-label")], [
              text(update_helpers.i18n_t(
                model,
                i18n_text.SuppressionNotMatching,
              )),
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
                    th([], [
                      text(update_helpers.i18n_t(model, i18n_text.Origin)),
                    ]),
                    th([], [
                      text(update_helpers.i18n_t(model, i18n_text.Outcome)),
                    ]),
                    th([], [text(update_helpers.i18n_t(model, i18n_text.User))]),
                    th([], [
                      text(update_helpers.i18n_t(model, i18n_text.Timestamp)),
                    ]),
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
                        update_helpers.i18n_t(
                          model,
                          i18n_text.OutcomeSuppressed,
                        )
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
                          text(
                            exec.origin_type
                            <> " #"
                            <> int.to_string(exec.origin_id),
                          ),
                        ]),
                        td([attribute.class(outcome_class)], [
                          text(outcome_text),
                        ]),
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
  let total_pages =
    { pagination.total + pagination.limit - 1 } / pagination.limit

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
            event.on_click(
              AdminRuleMetricsExecPageChanged(int.max(
                0,
                pagination.offset - pagination.limit,
              )),
            ),
          ],
          [text("<")],
        ),
        span([attribute.class("page-info")], [
          text(
            int.to_string(current_page) <> " / " <> int.to_string(total_pages),
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
