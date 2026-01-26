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
//// ## Structure Note
////
//// Members and workflow-related views live in `features/admin/views/*`.
//// This module keeps core admin views and delegates to those submodules.
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
  button, div, form, h2, h3, hr, img, input, label, option, p, select, span,
  table, td, text, th, thead, tr,
}
import lustre/element/keyed
import lustre/event

import gleam/dynamic/decode

import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/project.{type Project}
import domain/project_role.{Manager, Member}
import domain/task_type.{type TaskType}

import scrumbringer_client/client_state.{
  type Model, type Msg, type Remote, CapabilityCreateDialogClosed,
  CapabilityCreateDialogOpened, CapabilityCreateNameChanged,
  CapabilityCreateSubmitted, CapabilityDeleteDialogClosed,
  CapabilityDeleteDialogOpened, CapabilityDeleteSubmitted,
  CapabilityMembersDialogClosed, CapabilityMembersDialogOpened,
  CapabilityMembersSaveClicked, CapabilityMembersToggled, CardCrudCreated,
  CardCrudDeleted, CardCrudUpdated, CardDialogCreate, CardDialogDelete,
  CardDialogEdit, CardsSearchChanged, CardsShowCompletedToggled,
  CardsShowEmptyToggled, CardsStateFilterChanged, CloseCardDialog,
  CloseTaskTypeDialog, Failed, Loaded, Loading, NotAsked, OpenCardDialog,
  OpenTaskTypeDialog, OrgSettingsRoleChanged, OrgSettingsSaveAllClicked,
  TaskTypeCrudCreated, TaskTypeCrudDeleted, TaskTypeCrudUpdated,
  TaskTypeDialogCreate, TaskTypeDialogDelete, TaskTypeDialogEdit,
  UserProjectRemoveClicked, UserProjectRoleChangeRequested,
  UserProjectsAddProjectChanged, UserProjectsAddRoleChanged,
  UserProjectsAddSubmitted, UserProjectsDialogClosed, UserProjectsDialogOpened,
  admin_msg, pool_msg,
}
import scrumbringer_client/features/admin/cards as admin_cards
import scrumbringer_client/features/admin/views/members as members_view
import scrumbringer_client/features/admin/views/workflows as workflows_view
import scrumbringer_client/i18n/locale

// Story 4.10: Rule template attachment UI

// Workflows
// Task Templates
// Rule Metrics Tab
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/theme
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/icon_catalog
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/ui/status_block
import scrumbringer_client/update_helpers

// =============================================================================
// =============================================================================
// Public API
// =============================================================================

/// Organization settings view - manage user roles.
pub fn view_org_settings(model: Model) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  div([attrs.section()], [
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

  case model.admin.org_settings_users {
    NotAsked -> status_block.empty_text(t(i18n_text.OpenThisSectionToLoadUsers))

    Loading -> status_block.empty_text(t(i18n_text.LoadingUsers))

    Failed(err) -> status_block.error_text(err.message)

    Loaded(users) -> {
      let pending_count = dict.size(model.admin.org_settings_role_drafts)
      let has_pending = pending_count > 0

      element.fragment([
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
                    event.on_click(admin_msg(UserProjectsDialogOpened(u))),
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
              attribute.disabled(
                !has_pending || model.admin.org_settings_save_in_flight,
              ),
              event.on_click(admin_msg(OrgSettingsSaveAllClicked)),
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

  let draft = case dict.get(model.admin.org_settings_role_drafts, u.id) {
    Ok(role) -> role
    Error(_) -> u.org_role
  }

  let has_change = dict.has_key(model.admin.org_settings_role_drafts, u.id)

  let inline_error = case
    model.admin.org_settings_error_user_id,
    model.admin.org_settings_error
  {
    opt.Some(id), opt.Some(message) if id == u.id -> message
    _, _ -> ""
  }

  element.fragment([
    select(
      [
        attribute.value(draft),
        attribute.disabled(model.admin.org_settings_save_in_flight),
        event.on_input(fn(value) {
          admin_msg(OrgSettingsRoleChanged(u.id, value))
        }),
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
  case
    model.admin.user_projects_dialog_open,
    model.admin.user_projects_dialog_user
  {
    True, opt.Some(user) -> {
      dialog.view(
        dialog.DialogConfig(
          title: update_helpers.i18n_t(
            model,
            i18n_text.UserProjectsTitle(user.email),
          ),
          icon: opt.None,
          size: dialog.DialogMd,
          on_close: admin_msg(UserProjectsDialogClosed),
        ),
        True,
        model.admin.user_projects_error,
        // Content: project list and add form
        [
          // Current projects list
          case model.admin.user_projects_list {
            NotAsked | Loading ->
              p([attribute.class("loading")], [
                text(update_helpers.i18n_t(model, i18n_text.Loading)),
              ])

            Failed(err) -> div([attribute.class("error")], [text(err.message)])

            Loaded(projects) ->
              case list.is_empty(projects) {
                True ->
                  p([attribute.class("empty")], [
                    text(update_helpers.i18n_t(
                      model,
                      i18n_text.UserProjectsEmpty,
                    )),
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
                            text(update_helpers.i18n_t(
                              model,
                              i18n_text.RoleInProject,
                            )),
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
                                    attribute.value(project_role.to_string(
                                      p.my_role,
                                    )),
                                    attribute.disabled(
                                      model.admin.user_projects_in_flight,
                                    ),
                                    event.on_input(fn(value) {
                                      admin_msg(UserProjectRoleChangeRequested(
                                        p.id,
                                        value,
                                      ))
                                    }),
                                  ],
                                  [
                                    option(
                                      [attribute.value("manager")],
                                      update_helpers.i18n_t(
                                        model,
                                        i18n_text.RoleManager,
                                      ),
                                    ),
                                    option(
                                      [attribute.value("member")],
                                      update_helpers.i18n_t(
                                        model,
                                        i18n_text.RoleMember,
                                      ),
                                    ),
                                  ],
                                ),
                              ]),
                              td([], [
                                button(
                                  [
                                    attribute.class("btn-danger btn-sm"),
                                    attribute.disabled(
                                      model.admin.user_projects_in_flight,
                                    ),
                                    event.on_click(
                                      admin_msg(UserProjectRemoveClicked(p.id)),
                                    ),
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
                    case model.admin.user_projects_add_project_id {
                      opt.Some(id) -> int.to_string(id)
                      opt.None -> ""
                    },
                  ),
                  attribute.disabled(model.admin.user_projects_in_flight),
                  event.on_input(fn(value) {
                    admin_msg(UserProjectsAddProjectChanged(value))
                  }),
                ],
                [
                  option(
                    [attribute.value("")],
                    update_helpers.i18n_t(model, i18n_text.SelectProject),
                  ),
                  ..view_available_projects_options(model)
                ],
              ),
              // Role selector
              select(
                [
                  attribute.value(model.admin.user_projects_add_role),
                  attribute.disabled(model.admin.user_projects_in_flight),
                  event.on_input(fn(value) {
                    admin_msg(UserProjectsAddRoleChanged(value))
                  }),
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
                    model.admin.user_projects_in_flight
                    || opt.is_none(model.admin.user_projects_add_project_id),
                  ),
                  event.on_click(admin_msg(UserProjectsAddSubmitted)),
                ],
                [text(update_helpers.i18n_t(model, i18n_text.Add))],
              ),
            ]),
          ]),
        ],
        // Footer: close button
        [
          button([event.on_click(admin_msg(UserProjectsDialogClosed))], [
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
  let all_projects = case model.core.projects {
    Loaded(projects) -> projects
    _ -> []
  }

  // Get user's current projects
  let user_project_ids = case model.admin.user_projects_list {
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
  case model.admin.user_projects_dialog_user, model.admin.user_projects_list {
    opt.Some(dialog_user), Loaded(projects) if dialog_user.id == user_id -> {
      let count = list.length(projects)
      case count {
        0 -> update_helpers.i18n_t(model, i18n_text.ProjectsSummary(0, ""))
        _ -> {
          let names =
            projects
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

          update_helpers.i18n_t(
            model,
            i18n_text.ProjectsSummary(count, names <> suffix),
          )
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
        admin_msg(CapabilityCreateDialogOpened),
      ),
    ),
    // Capabilities list
    view_capabilities_list(model, model.admin.capabilities),
    // Create capability dialog
    view_capabilities_create_dialog(model),
    // Capability members dialog (AC17, Story 4.8 AC24)
    case model.admin.capability_members_dialog_capability_id {
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
      on_close: admin_msg(CapabilityCreateDialogClosed),
    ),
    model.admin.capabilities_create_dialog_open,
    model.admin.capabilities_create_error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) { admin_msg(CapabilityCreateSubmitted) }),
          attribute.id("capability-create-form"),
        ],
        [
          div([attribute.class("field")], [
            label([], [text(update_helpers.i18n_t(model, i18n_text.Name))]),
            input([
              attribute.type_("text"),
              attribute.value(model.admin.capabilities_create_name),
              event.on_input(fn(value) {
                admin_msg(CapabilityCreateNameChanged(value))
              }),
              attribute.required(True),
              attribute.placeholder(update_helpers.i18n_t(
                model,
                i18n_text.CapabilityNamePlaceholder,
              )),
              attribute.attribute("aria-label", "Capability name"),
            ]),
          ]),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(model, admin_msg(CapabilityCreateDialogClosed)),
      button(
        [
          attribute.type_("submit"),
          attribute.form("capability-create-form"),
          attribute.disabled(model.admin.capabilities_create_in_flight),
          attribute.class(case model.admin.capabilities_create_in_flight {
            True -> "btn-loading"
            False -> ""
          }),
        ],
        [
          text(case model.admin.capabilities_create_in_flight {
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
  let capability_name = case model.admin.capability_delete_dialog_id {
    opt.Some(id) ->
      case model.admin.capabilities {
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
      on_close: admin_msg(CapabilityDeleteDialogClosed),
    ),
    opt.is_some(model.admin.capability_delete_dialog_id),
    model.admin.capability_delete_error,
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
      dialog.cancel_button(model, admin_msg(CapabilityDeleteDialogClosed)),
      button(
        [
          attribute.type_("button"),
          attribute.class("btn btn-danger"),
          attribute.disabled(model.admin.capability_delete_in_flight),
          event.on_click(admin_msg(CapabilityDeleteSubmitted)),
        ],
        [
          text(case model.admin.capability_delete_in_flight {
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
  members_view.view_members(model, selected_project)
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
            admin_msg(OpenTaskTypeDialog(TaskTypeDialogCreate)),
          ),
        ),
        // Task types list
        view_task_types_list(model, model.admin.task_types, model.ui.theme),
        // Task type CRUD dialog component (handles create, edit, delete)
        view_task_type_crud_dialog(model, project.id),
      ])
  }
}

/// Render the task-type-crud-dialog Lustre component.
fn view_task_type_crud_dialog(model: Model, project_id: Int) -> Element(Msg) {
  case model.admin.task_types_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, type_json) = case mode {
        TaskTypeDialogCreate -> #("create", attribute.none())
        TaskTypeDialogEdit(task_type) -> #(
          "edit",
          attribute.property(
            "task-type",
            task_type_to_property_json(task_type, "edit"),
          ),
        )
        TaskTypeDialogDelete(task_type) -> #(
          "delete",
          attribute.property(
            "task-type",
            task_type_to_property_json(task_type, "delete"),
          ),
        )
      }

      element.element(
        "task-type-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.ui.locale)),
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
  decode.success(admin_msg(TaskTypeCrudCreated(task_type)))
}

/// Decoder for type-updated event.
fn decode_task_type_updated_event() -> decode.Decoder(Msg) {
  use task_type <- decode.field("detail", task_type_decoder())
  decode.success(admin_msg(TaskTypeCrudUpdated(task_type)))
}

/// Decoder for type-deleted event.
fn decode_task_type_deleted_event() -> decode.Decoder(Msg) {
  use id <- decode.field(
    "detail",
    decode.field("id", decode.int, decode.success),
  )
  decode.success(admin_msg(TaskTypeCrudDeleted(id)))
}

/// Decoder for close-requested event.
fn decode_task_type_close_event() -> decode.Decoder(Msg) {
  decode.success(admin_msg(CloseTaskTypeDialog))
}

/// Decoder for TaskType from JSON (used in custom events).
fn task_type_decoder() -> decode.Decoder(TaskType) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use icon <- decode.field("icon", decode.string)
  use capability_id <- decode.optional_field(
    "capability_id",
    opt.None,
    decode.optional(decode.int),
  )
  use tasks_count <- decode.optional_field("tasks_count", 0, decode.int)
  decode.success(task_type.TaskType(
    id: id,
    name: name,
    icon: icon,
    capability_id: capability_id,
    tasks_count: tasks_count,
  ))
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
    case dict.get(model.admin.capability_members_cache, cap_id) {
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
        data_table.column(t(i18n_text.Name), fn(c: Capability) { text(c.name) }),
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
                  event.on_click(admin_msg(CapabilityMembersDialogOpened(c.id))),
                ],
                [icons.nav_icon(icons.OrgUsers, icons.Small)],
              ),
              // Delete button (Story 4.9 AC9)
              action_buttons.delete_button_with_testid(
                t(i18n_text.Delete),
                admin_msg(CapabilityDeleteDialogOpened(c.id)),
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
// Capability Members Dialog (Story 4.7 AC16-17)
// =============================================================================

fn view_capability_members_dialog(
  model: Model,
  capability_id: Int,
  project_name: String,
) -> Element(Msg) {
  // Get capability name for display
  let capability_name = case model.admin.capabilities {
    Loaded(caps) ->
      case list.find(caps, fn(c) { c.id == capability_id }) {
        Ok(cap) -> cap.name
        Error(_) -> "Capability #" <> int.to_string(capability_id)
      }
    _ -> "Capability #" <> int.to_string(capability_id)
  }

  // Get project members for the checkbox list
  let members = case model.admin.members {
    Loaded(ms) -> ms
    _ -> []
  }

  div([attribute.class("modal")], [
    div([attribute.class("modal-content members-dialog")], [
      h3([], [
        text(update_helpers.i18n_t(
          model,
          i18n_text.MembersForCapability(capability_name, project_name),
        )),
      ]),
      // Error display
      case model.admin.capability_members_error {
        opt.Some(err) -> div([attribute.class("error")], [text(err)])
        opt.None -> element.none()
      },
      // Loading state
      case model.admin.capability_members_loading {
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
                      model.admin.org_users_cache,
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
                      model.admin.capability_members_selected,
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
                          admin_msg(CapabilityMembersToggled(member.user_id))
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
        button([event.on_click(admin_msg(CapabilityMembersDialogClosed))], [
          text(update_helpers.i18n_t(model, i18n_text.Cancel)),
        ]),
        button(
          [
            attribute.class("btn-primary"),
            event.on_click(admin_msg(CapabilityMembersSaveClicked)),
            attribute.disabled(
              model.admin.capability_members_saving
              || model.admin.capability_members_loading,
            ),
          ],
          [
            text(case model.admin.capability_members_saving {
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
      p([], [
        text(update_helpers.i18n_t(model, i18n_text.CreateFirstTaskTypeHint)),
      ]),
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
            let edit_click: Msg =
              admin_msg(OpenTaskTypeDialog(TaskTypeDialogEdit(tt)))
            let delete_click: Msg =
              admin_msg(OpenTaskTypeDialog(TaskTypeDialogDelete(tt)))
            action_buttons.edit_delete_row_with_testid(
              edit_title: update_helpers.i18n_t(model, i18n_text.EditTaskType),
              edit_click: edit_click,
              edit_testid: "task-type-edit-btn",
              delete_title: update_helpers.i18n_t(
                model,
                i18n_text.DeleteTaskType,
              ),
              delete_click: delete_click,
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
            pool_msg(OpenCardDialog(CardDialogCreate)),
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
  case model.admin.cards_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, card_json) = case mode {
        CardDialogCreate -> #("create", attribute.none())
        CardDialogEdit(card_id) ->
          case admin_cards.find_card(model, card_id) {
            opt.Some(card) -> #(
              "edit",
              attribute.property("card", card_to_property_json(card, "edit")),
            )
            opt.None -> #("edit", attribute.none())
          }
        CardDialogDelete(card_id) ->
          case admin_cards.find_card(model, card_id) {
            opt.Some(card) -> #(
              "delete",
              attribute.property("card", card_to_property_json(card, "delete")),
            )
            opt.None -> #("delete", attribute.none())
          }
      }

      element.element(
        "card-crud-dialog",
        [
          // Attributes (strings)
          attribute.attribute("locale", locale.serialize(model.ui.locale)),
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
  decode.success(pool_msg(CardCrudCreated(card)))
}

/// Decoder for card-updated event.
fn decode_card_updated_event() -> decode.Decoder(Msg) {
  use card <- decode.field("detail", card_decoder())
  decode.success(pool_msg(CardCrudUpdated(card)))
}

/// Decoder for card-deleted event.
fn decode_card_deleted_event() -> decode.Decoder(Msg) {
  use id <- decode.field(
    "detail",
    decode.field("id", decode.int, decode.success),
  )
  decode.success(pool_msg(CardCrudDeleted(id)))
}

/// Decoder for close-requested event.
fn decode_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(pool_msg(CloseCardDialog))
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
          attribute.placeholder(update_helpers.i18n_t(
            model,
            i18n_text.SearchPlaceholder,
          )),
          attribute.value(model.admin.cards_search),
          event.on_input(fn(value) { pool_msg(CardsSearchChanged(value)) }),
        ]),
      ]),
      // State filter dropdown (AC8)
      div([attribute.class("filter-group")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.CardState))]),
        select(
          [
            attribute.class("filter-select"),
            attribute.attribute("data-testid", "cards-state-filter"),
            event.on_input(fn(value) {
              pool_msg(CardsStateFilterChanged(value))
            }),
          ],
          [
            option(
              [
                attribute.value(""),
                attribute.selected(model.admin.cards_state_filter == opt.None),
              ],
              update_helpers.i18n_t(model, i18n_text.AllOption),
            ),
            option(
              [
                attribute.value("pendiente"),
                attribute.selected(
                  model.admin.cards_state_filter == opt.Some(card.Pendiente),
                ),
              ],
              update_helpers.i18n_t(model, i18n_text.CardStatePendiente),
            ),
            option(
              [
                attribute.value("en_curso"),
                attribute.selected(
                  model.admin.cards_state_filter == opt.Some(card.EnCurso),
                ),
              ],
              update_helpers.i18n_t(model, i18n_text.CardStateEnCurso),
            ),
            option(
              [
                attribute.value("cerrada"),
                attribute.selected(
                  model.admin.cards_state_filter == opt.Some(card.Cerrada),
                ),
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
            attribute.checked(model.admin.cards_show_empty),
            attribute.attribute("data-testid", "show-empty-cards"),
            event.on_check(fn(_) { pool_msg(CardsShowEmptyToggled) }),
          ]),
          text(update_helpers.i18n_t(model, i18n_text.ShowEmptyCards)),
        ]),
      ]),
      // Show completed checkbox - unchecked by default
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.admin.cards_show_completed),
            attribute.attribute("data-testid", "show-completed-cards"),
            event.on_check(fn(_) { pool_msg(CardsShowCompletedToggled) }),
          ]),
          text(update_helpers.i18n_t(model, i18n_text.ShowCompletedCards)),
        ]),
      ]),
    ],
  )
}

/// Story 4.9: Filter cards based on model filters (UX improved)
fn filter_cards(model: Model) -> Remote(List(Card)) {
  case model.admin.cards {
    Loaded(cards) -> {
      let filtered =
        cards
        |> list.filter(fn(c) {
          // Filter by state dropdown
          let state_match = case model.admin.cards_state_filter {
            opt.None -> True
            opt.Some(state) -> c.state == state
          }
          // Filter by empty (show_empty = False by default = hide cards with 0 tasks)
          let empty_match = case model.admin.cards_show_empty {
            True -> True
            False -> c.task_count > 0
          }
          // Filter by completed (show_completed = False by default = hide Cerrada cards)
          let completed_match = case model.admin.cards_show_completed {
            True -> True
            False -> c.state != card.Cerrada
          }
          // Filter by search
          let search_match = case string.is_empty(model.admin.cards_search) {
            True -> True
            False ->
              string.contains(
                string.lowercase(c.title),
                string.lowercase(model.admin.cards_search),
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
      div([attribute.class("empty-state-icon")], [
        icons.nav_icon(icons.ClipboardDoc, icons.Large),
      ]),
      div([attribute.class("empty-state-title")], [
        text(update_helpers.i18n_t(model, i18n_text.NoCardsYet)),
      ]),
      div([attribute.class("empty-state-description")], [
        text(
          "Las tarjetas agrupan tareas relacionadas. Crea tu primera tarjeta para organizar el trabajo.",
        ),
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
              span(
                [
                  attribute.class("card-color-dot"),
                  attribute.attribute("style", color_style),
                ],
                [],
              ),
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
              edit_click: pool_msg(OpenCardDialog(CardDialogEdit(c.id))),
              edit_testid: "card-edit-btn",
              delete_title: update_helpers.i18n_t(model, i18n_text.DeleteCard),
              delete_click: pool_msg(OpenCardDialog(CardDialogDelete(c.id))),
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
    card.Pendiente -> #(
      update_helpers.i18n_t(model, i18n_text.CardStatePendiente),
      "state-badge state-pending",
    )
    card.EnCurso -> #(
      update_helpers.i18n_t(model, i18n_text.CardStateEnCurso),
      "state-badge state-active",
    )
    card.Cerrada -> #(
      update_helpers.i18n_t(model, i18n_text.CardStateCerrada),
      "state-badge state-completed",
    )
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
      div(
        [
          attribute.class("progress-fill-mini"),
          attribute.attribute("style", width_style),
        ],
        [],
      ),
    ]),
    span([attribute.class("progress-text-mini")], [
      text(int.to_string(completed) <> "/" <> int.to_string(total)),
    ]),
  ])
}

// =============================================================================
// Workflows Views (delegated)
// =============================================================================

/// Workflows management view.
pub fn view_workflows(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  workflows_view.view_workflows(model, selected_project)
}

/// Task templates management view (project-scoped only).
pub fn view_task_templates(
  model: Model,
  selected_project: opt.Option(Project),
) -> Element(Msg) {
  workflows_view.view_task_templates(model, selected_project)
}

/// Rule metrics tab view.
pub fn view_rule_metrics(model: Model) -> Element(Msg) {
  workflows_view.view_rule_metrics(model)
}
