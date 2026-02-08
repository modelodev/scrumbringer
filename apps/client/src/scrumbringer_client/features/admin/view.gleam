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
  button, div, form, h2, img, input, label, option, p, select, span, text,
}
import lustre/event

import gleam/dynamic/decode

import domain/capability.{type Capability}
import domain/card.{type Card}
import domain/org.{type OrgUser}
import domain/org_role
import domain/project.{type Project}
import domain/remote.{type Remote, Failed, Loaded, Loading, NotAsked}
import domain/task_type.{type TaskType}

import scrumbringer_client/client_state.{
  type Model, type Msg, NoOp, admin_msg, pool_msg,
}
import scrumbringer_client/client_state/dialog_mode
import scrumbringer_client/client_state/types as state_types
import scrumbringer_client/decoders
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/admin/views/members as members_view
import scrumbringer_client/features/admin/views/workflows as workflows_view
import scrumbringer_client/features/cards/detail_modal_entry
import scrumbringer_client/features/pool/msg as pool_messages
import scrumbringer_client/i18n/locale
import scrumbringer_client/utils/card_queries

// Story 4.10: Rule template attachment UI

// Workflows
// Task Templates
// Rule Metrics Tab
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/lookup as helpers_lookup
import scrumbringer_client/helpers/selection as helpers_selection
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/permissions
import scrumbringer_client/theme
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/card_progress
import scrumbringer_client/ui/card_state
import scrumbringer_client/ui/card_state_badge
import scrumbringer_client/ui/card_title_meta
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/error_notice
import scrumbringer_client/ui/event_decoders
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icon_actions
import scrumbringer_client/ui/icon_catalog
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header

// =============================================================================
// =============================================================================
// Public API
// =============================================================================

/// Organization settings view - manage user roles.
pub fn view_org_settings(model: Model) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }

  div([attribute.class("section")], [
    // Section header with subtitle (Story 4.8: consistent icons + help text)
    section_header.view_with_subtitle(
      icons.OrgUsers,
      t(i18n_text.OrgUsers),
      t(i18n_text.OrgSettingsHelp),
    ),
    // Users table
    view_org_settings_table(model),
    view_org_settings_delete_dialog(model),
  ])
}

fn view_org_settings_table(model: Model) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }

  case model.admin.members.org_settings_users {
    NotAsked ->
      div([attribute.class("empty")], [
        text(t(i18n_text.OpenThisSectionToLoadUsers)),
      ])

    Loading ->
      div([attribute.class("empty")], [
        text(t(i18n_text.LoadingUsers)),
      ])

    Failed(err) -> error_notice.view(err.message)

    Loaded(users) -> {
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
          // Actions
          data_table.column_with_class(
            t(i18n_text.Actions),
            fn(u: OrgUser) {
              let is_self = case model.core.user {
                opt.Some(user) -> user.id == u.id
                opt.None -> False
              }
              action_buttons.task_icon_button_with_class(
                t(i18n_text.DeleteUser),
                admin_msg(admin_messages.OrgSettingsDeleteClicked(u.id)),
                icons.Trash,
                icons.Small,
                is_self || model.admin.members.org_settings_delete_in_flight,
                "btn-icon btn-xs btn-danger-icon",
                opt.None,
                opt.Some("org-user-delete-btn"),
              )
            },
            "col-actions",
            "cell-actions",
          ),
        ])
        |> data_table.with_rows(users, fn(u: OrgUser) { int.to_string(u.id) })
        |> data_table.view(),
      ])
    }
  }
}

/// Dialog for deleting an org user.
fn view_org_settings_delete_dialog(model: Model) -> Element(Msg) {
  case model.admin.members.org_settings_delete_confirm {
    opt.None -> element.none()
    opt.Some(user) ->
      dialog.view(
        dialog.DialogConfig(
          title: helpers_i18n.i18n_t(model, i18n_text.DeleteUser),
          icon: opt.None,
          size: dialog.DialogSm,
          on_close: admin_msg(admin_messages.OrgSettingsDeleteCancelled),
        ),
        True,
        model.admin.members.org_settings_delete_error,
        [
          p([], [
            text(helpers_i18n.i18n_t(
              model,
              i18n_text.ConfirmDeleteUser(user.email),
            )),
          ]),
        ],
        [
          dialog.cancel_button(
            model,
            admin_msg(admin_messages.OrgSettingsDeleteCancelled),
          ),
          button(
            [
              attribute.type_("button"),
              attribute.class("btn btn-danger"),
              attribute.disabled(
                model.admin.members.org_settings_delete_in_flight,
              ),
              event.on_click(admin_msg(
                admin_messages.OrgSettingsDeleteConfirmed,
              )),
            ],
            [
              text(case model.admin.members.org_settings_delete_in_flight {
                True -> helpers_i18n.i18n_t(model, i18n_text.Deleting)
                False -> helpers_i18n.i18n_t(model, i18n_text.Delete)
              }),
            ],
          ),
        ],
      )
  }
}

fn view_org_role_cell(model: Model, u: OrgUser) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }

  let current_role = u.org_role
  let current_role_string = org_role.to_string(current_role)

  let inline_error = case
    model.admin.members.org_settings_error_user_id,
    model.admin.members.org_settings_error
  {
    opt.Some(id), opt.Some(message) if id == u.id -> message
    _, _ -> ""
  }

  element.fragment([
    select(
      [
        attribute.value(current_role_string),
        attribute.disabled(model.admin.members.org_settings_save_in_flight),
        event.on_input(fn(value) {
          case org_role.parse(value) {
            Ok(role) ->
              admin_msg(admin_messages.OrgSettingsRoleChanged(u.id, role))
            Error(_) -> NoOp
          }
        }),
      ],
      [
        option(
          [
            attribute.value("admin"),
            attribute.selected(current_role == org_role.Admin),
          ],
          t(i18n_text.RoleAdmin),
        ),
        option(
          [
            attribute.value("member"),
            attribute.selected(current_role == org_role.Member),
          ],
          t(i18n_text.RoleMember),
        ),
      ],
    ),
    // Inline error
    case inline_error == "" {
      True -> element.none()
      False -> error_notice.view(inline_error)
    },
  ])
}

/// Capabilities management view.
pub fn view_capabilities(model: Model) -> Element(Msg) {
  // Get project name for dialog titles (Story 4.8 AC24)
  let project_name = case helpers_selection.selected_project(model) {
    opt.Some(project) -> project.name
    opt.None -> ""
  }

  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Crosshairs,
      helpers_i18n.i18n_t(model, i18n_text.Capabilities),
      dialog.add_button(
        model,
        i18n_text.CreateCapability,
        admin_msg(admin_messages.CapabilityCreateDialogOpened),
      ),
    ),
    // Capabilities list
    view_capabilities_list(model, model.admin.capabilities.capabilities),
    // Create capability dialog
    view_capabilities_create_dialog(model),
    // Capability members dialog (AC17, Story 4.8 AC24)
    case model.admin.capabilities.capability_members_dialog_capability_id {
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
  let is_open = case model.admin.capabilities.capabilities_dialog_mode {
    dialog_mode.DialogCreate -> True
    _ -> False
  }

  dialog.view(
    dialog.DialogConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.CreateCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: admin_msg(admin_messages.CapabilityCreateDialogClosed),
    ),
    is_open,
    model.admin.capabilities.capabilities_create_error,
    // Form content
    [
      form(
        [
          event.on_submit(fn(_) {
            admin_msg(admin_messages.CapabilityCreateSubmitted)
          }),
          attribute.id("capability-create-form"),
        ],
        [
          form_field.view(
            helpers_i18n.i18n_t(model, i18n_text.Name),
            input([
              attribute.type_("text"),
              attribute.value(model.admin.capabilities.capabilities_create_name),
              event.on_input(fn(value) {
                admin_msg(admin_messages.CapabilityCreateNameChanged(value))
              }),
              attribute.required(True),
              attribute.placeholder(helpers_i18n.i18n_t(
                model,
                i18n_text.CapabilityNamePlaceholder,
              )),
              attribute.attribute("aria-label", "Capability name"),
            ]),
          ),
        ],
      ),
    ],
    // Footer buttons
    [
      dialog.cancel_button(
        model,
        admin_msg(admin_messages.CapabilityCreateDialogClosed),
      ),
      button(
        [
          attribute.type_("submit"),
          attribute.form("capability-create-form"),
          attribute.disabled(
            model.admin.capabilities.capabilities_create_in_flight,
          ),
          attribute.class(
            case model.admin.capabilities.capabilities_create_in_flight {
              True -> "btn-loading"
              False -> ""
            },
          ),
        ],
        [
          text(case model.admin.capabilities.capabilities_create_in_flight {
            True -> helpers_i18n.i18n_t(model, i18n_text.Creating)
            False -> helpers_i18n.i18n_t(model, i18n_text.Create)
          }),
        ],
      ),
    ],
  )
}

/// Dialog for deleting a capability (Story 4.9 AC9).
fn view_capability_delete_dialog(model: Model) -> Element(Msg) {
  // Get capability name for the confirmation message
  let capability_name = case
    model.admin.capabilities.capability_delete_dialog_id
  {
    opt.Some(id) ->
      case model.admin.capabilities.capabilities {
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
      title: helpers_i18n.i18n_t(model, i18n_text.DeleteCapability),
      icon: opt.None,
      size: dialog.DialogSm,
      on_close: admin_msg(admin_messages.CapabilityDeleteDialogClosed),
    ),
    opt.is_some(model.admin.capabilities.capability_delete_dialog_id),
    model.admin.capabilities.capability_delete_error,
    // Confirmation content
    [
      p([], [
        text(helpers_i18n.i18n_t(
          model,
          i18n_text.ConfirmDeleteCapability(capability_name),
        )),
      ]),
    ],
    // Footer buttons
    [
      dialog.cancel_button(
        model,
        admin_msg(admin_messages.CapabilityDeleteDialogClosed),
      ),
      button(
        [
          attribute.type_("button"),
          attribute.class("btn btn-danger"),
          attribute.disabled(
            model.admin.capabilities.capability_delete_in_flight,
          ),
          event.on_click(admin_msg(admin_messages.CapabilityDeleteSubmitted)),
        ],
        [
          text(case model.admin.capabilities.capability_delete_in_flight {
            True -> helpers_i18n.i18n_t(model, i18n_text.Deleting)
            False -> helpers_i18n.i18n_t(model, i18n_text.Delete)
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
        text(helpers_i18n.i18n_t(
          model,
          i18n_text.SelectProjectToManageTaskTypes,
        )),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.TaskTypes,
          helpers_i18n.i18n_t(model, i18n_text.TaskTypesTitle(project.name)),
          dialog.add_button(
            model,
            i18n_text.CreateTaskType,
            admin_msg(admin_messages.OpenTaskTypeDialog(
              state_types.TaskTypeDialogCreate,
            )),
          ),
        ),
        // Task types list
        view_task_types_list(
          model,
          model.admin.task_types.task_types,
          model.ui.theme,
        ),
        // Task type CRUD dialog component (handles create, edit, delete)
        view_task_type_crud_dialog(model, project.id),
      ])
  }
}

/// Render the task-type-crud-dialog Lustre component.
fn view_task_type_crud_dialog(model: Model, project_id: Int) -> Element(Msg) {
  case model.admin.task_types.task_types_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let #(mode_str, type_json) = case mode {
        state_types.TaskTypeDialogCreate -> #("create", attribute.none())
        state_types.TaskTypeDialogEdit(task_type) -> #(
          "edit",
          attribute.property(
            "task-type",
            task_type_to_property_json(task_type, "edit"),
          ),
        )
        state_types.TaskTypeDialogDelete(task_type) -> #(
          "delete",
          attribute.property(
            "task-type",
            task_type_to_property_json(task_type, "delete"),
          ),
        )
      }

      // Convert capabilities to JSON for property passing
      let capabilities_json = case model.admin.capabilities.capabilities {
        Loaded(caps) ->
          attribute.property(
            "capabilities",
            json.array(caps, capability_to_json),
          )
        _ -> attribute.none()
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
          // Property for capabilities list
          capabilities_json,
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
  event_decoders.custom_detail(task_type_decoder(), fn(task_type) {
    decode.success(admin_msg(admin_messages.TaskTypeCrudCreated(task_type)))
  })
}

/// Decoder for type-updated event.
fn decode_task_type_updated_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(task_type_decoder(), fn(task_type) {
    decode.success(admin_msg(admin_messages.TaskTypeCrudUpdated(task_type)))
  })
}

/// Decoder for type-deleted event.
fn decode_task_type_deleted_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(admin_msg(admin_messages.TaskTypeCrudDeleted(id))) },
  )
}

/// Decoder for close-requested event.
fn decode_task_type_close_event() -> decode.Decoder(Msg) {
  decode.success(admin_msg(admin_messages.CloseTaskTypeDialog))
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

/// Convert Capability to JSON for property passing to task-type-crud-dialog.
fn capability_to_json(cap: Capability) -> json.Json {
  json.object([#("id", json.int(cap.id)), #("name", json.string(cap.name))])
}

// =============================================================================
// Capabilities Helpers
// =============================================================================

fn view_capabilities_list(
  model: Model,
  capabilities: Remote(List(Capability)),
) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }

  // Helper to get member count from cache
  let get_member_count = fn(cap_id: Int) -> Int {
    case dict.get(model.admin.capabilities.capability_members_cache, cap_id) {
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
            badge.new_unchecked(
              int.to_string(get_member_count(c.id)),
              badge.Neutral,
            )
            |> badge.view_with_class("count-badge")
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
              icon_actions.settings_with_testid(
                t(i18n_text.ManageMembers),
                admin_msg(admin_messages.CapabilityMembersDialogOpened(c.id)),
                "capability-members-btn",
              ),
              // Delete button (Story 4.9 AC9)
              action_buttons.delete_button_with_testid(
                t(i18n_text.Delete),
                admin_msg(admin_messages.CapabilityDeleteDialogOpened(c.id)),
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

// Justification: large function kept intact to preserve cohesive UI logic.
fn view_capability_members_dialog(
  model: Model,
  capability_id: Int,
  project_name: String,
) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  // Get capability name for display
  let capability_name = case model.admin.capabilities.capabilities {
    Loaded(caps) ->
      case list.find(caps, fn(c) { c.id == capability_id }) {
        Ok(cap) -> cap.name
        Error(_) -> "Capability #" <> int.to_string(capability_id)
      }
    _ -> "Capability #" <> int.to_string(capability_id)
  }

  // Get project members for the checkbox list
  let members = case model.admin.members.members {
    Loaded(ms) -> ms
    _ -> []
  }

  dialog.view(
    dialog.DialogConfig(
      title: t(i18n_text.MembersForCapability(capability_name, project_name)),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(admin_messages.CapabilityMembersDialogClosed),
    ),
    True,
    model.admin.capabilities.capability_members_error,
    [
      div([attribute.class("members-dialog")], [
        case model.admin.capabilities.capability_members_loading {
          True ->
            div([attribute.class("loading")], [
              text(t(i18n_text.LoadingEllipsis)),
            ])
          False ->
            // Members checkbox list (AC17)
            case members {
              [] ->
                div([attribute.class("empty")], [
                  text(t(i18n_text.NoMembersDefined)),
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
                      helpers_lookup.resolve_org_user(
                        model.admin.members.org_users_cache,
                        member.user_id,
                      )
                    {
                      opt.Some(user) -> user.email
                      opt.None -> t(i18n_text.UserNumber(member.user_id))
                    }
                    let is_selected =
                      list.contains(
                        model.admin.capabilities.capability_members_selected,
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
                            admin_msg(admin_messages.CapabilityMembersToggled(
                              member.user_id,
                            ))
                          }),
                        ]),
                        span([attribute.class("member-email")], [text(email)]),
                      ],
                    )
                  }),
                )
            }
        },
      ]),
    ],
    [
      dialog.cancel_button(
        model,
        admin_msg(admin_messages.CapabilityMembersDialogClosed),
      ),
      button(
        [
          attribute.class("btn-primary"),
          event.on_click(admin_msg(admin_messages.CapabilityMembersSaveClicked)),
          attribute.disabled(
            model.admin.capabilities.capability_members_saving
            || model.admin.capabilities.capability_members_loading,
          ),
        ],
        [
          text(case model.admin.capabilities.capability_members_saving {
            True -> t(i18n_text.Saving)
            False -> t(i18n_text.Save)
          }),
        ],
      ),
    ],
  )
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

// Justification: nested case improves clarity for branching logic.
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
      h2([], [text(helpers_i18n.i18n_t(model, i18n_text.NoTaskTypesYet))]),
      p([], [text(helpers_i18n.i18n_t(model, i18n_text.TaskTypesExplain))]),
      p([], [
        text(helpers_i18n.i18n_t(model, i18n_text.CreateFirstTaskTypeHint)),
      ]),
    ])

  data_table.view_remote_with_forbidden(
    task_types,
    loading_msg: helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis),
    empty_msg: "",
    forbidden_msg: helpers_i18n.i18n_t(model, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_empty_state(empty_state)
      |> data_table.with_columns([
        data_table.column(
          helpers_i18n.i18n_t(model, i18n_text.Name),
          fn(tt: TaskType) { text(tt.name) },
        ),
        data_table.column(
          helpers_i18n.i18n_t(model, i18n_text.Icon),
          fn(tt: TaskType) { view_task_type_icon_inline(tt.icon, 20, theme) },
        ),
        data_table.column(
          helpers_i18n.i18n_t(model, i18n_text.CapabilityLabel),
          fn(tt: TaskType) {
            case tt.capability_id {
              opt.Some(id) ->
                case resolve_capability_name(model, id) {
                  opt.Some(name) -> text(name)
                  opt.None -> text("-")
                }
              opt.None -> text(helpers_i18n.i18n_t(model, i18n_text.NoneOption))
            }
          },
        ),
        data_table.column_with_class(
          helpers_i18n.i18n_t(model, i18n_text.CardTasks),
          fn(tt: TaskType) { text(int.to_string(tt.tasks_count)) },
          "col-number",
          "cell-number",
        ),
        data_table.column_with_class(
          helpers_i18n.i18n_t(model, i18n_text.Actions),
          fn(tt: TaskType) {
            let edit_click: Msg =
              admin_msg(
                admin_messages.OpenTaskTypeDialog(
                  state_types.TaskTypeDialogEdit(tt),
                ),
              )
            let delete_click: Msg =
              admin_msg(
                admin_messages.OpenTaskTypeDialog(
                  state_types.TaskTypeDialogDelete(tt),
                ),
              )
            action_buttons.edit_delete_row_with_testid(
              edit_title: helpers_i18n.i18n_t(model, i18n_text.EditTaskType),
              edit_click: edit_click,
              edit_testid: "task-type-edit-btn",
              delete_title: helpers_i18n.i18n_t(model, i18n_text.DeleteTaskType),
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

fn resolve_capability_name(
  model: Model,
  capability_id: Int,
) -> opt.Option(String) {
  case model.admin.capabilities.capabilities {
    Loaded(caps) ->
      list.find(caps, fn(cap: Capability) { cap.id == capability_id })
      |> opt.from_result
      |> opt.map(fn(cap) { cap.name })

    _ -> opt.None
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
        text(helpers_i18n.i18n_t(model, i18n_text.SelectProjectToManageCards)),
      ])

    opt.Some(project) ->
      div([attribute.class("section")], [
        // Section header with add button (Story 4.8: consistent icons)
        section_header.view_with_action(
          icons.Cards,
          helpers_i18n.i18n_t(model, i18n_text.CardsTitle(project.name)),
          dialog.add_button(
            model,
            i18n_text.CreateCard,
            pool_msg(pool_messages.OpenCardDialog(state_types.CardDialogCreate)),
          ),
        ),
        // Story 4.9 AC7-8: Filters bar
        view_cards_filters(model),
        // Cards list (filtered)
        view_cards_list(model, filter_cards(model)),
        // Card CRUD dialog component (handles create, edit, delete)
        view_card_crud_dialog(model, project.id),
        view_card_detail_modal(model, project),
      ])
  }
}

// Justification: nested case improves clarity for branching logic.
/// Render the card-crud-dialog Lustre component.
/// Made public for use in client_view.gleam (Story 4.8 UX: global dialog rendering)
pub fn view_card_crud_dialog(model: Model, project_id: Int) -> Element(Msg) {
  case model.admin.cards.cards_dialog_mode {
    opt.None -> element.none()
    opt.Some(mode) -> {
      let milestone_name =
        resolve_create_milestone_name(model)
        |> opt.unwrap("")

      let #(mode_str, card_json) = case mode {
        state_types.CardDialogCreate -> #("create", attribute.none())
        state_types.CardDialogEdit(card_id) ->
          case card_queries.find_card(model, card_id) {
            opt.Some(card) -> #(
              "edit",
              attribute.property("card", card_to_property_json(card, "edit")),
            )
            opt.None -> #("edit", attribute.none())
          }
        state_types.CardDialogDelete(card_id) ->
          case card_queries.find_card(model, card_id) {
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
          attribute.attribute(
            "milestone-id",
            case model.admin.cards.cards_create_milestone_id {
              opt.Some(id) -> int.to_string(id)
              opt.None -> ""
            },
          ),
          attribute.attribute("milestone-name", milestone_name),
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

fn resolve_create_milestone_name(model: Model) -> opt.Option(String) {
  case
    model.admin.cards.cards_create_milestone_id,
    model.member.pool.member_milestones
  {
    opt.Some(milestone_id), Loaded(items) ->
      list.find_map(items, fn(progress) {
        case progress.milestone.id == milestone_id {
          True -> Ok(progress.milestone.name)
          False -> Error(Nil)
        }
      })
      |> opt.from_result
    _, _ -> opt.None
  }
}

/// Decoder for card-created event.
fn decode_card_created_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(card_decoder(), fn(card) {
    decode.success(pool_msg(pool_messages.CardCrudCreated(card)))
  })
}

/// Decoder for card-updated event.
fn decode_card_updated_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(card_decoder(), fn(card) {
    decode.success(pool_msg(pool_messages.CardCrudUpdated(card)))
  })
}

/// Decoder for card-deleted event.
fn decode_card_deleted_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(
    decode.field("id", decode.int, decode.success),
    fn(id) { decode.success(pool_msg(pool_messages.CardCrudDeleted(id))) },
  )
}

/// Decoder for close-requested event.
fn decode_close_requested_event() -> decode.Decoder(Msg) {
  decode.success(pool_msg(pool_messages.CloseCardDialog))
}

/// Decoder for Card from JSON (used in custom events).
fn card_decoder() -> decode.Decoder(Card) {
  use id <- decode.field("id", decode.int)
  use project_id <- decode.field("project_id", decode.int)
  use milestone_id <- decode.optional_field(
    "milestone_id",
    opt.None,
    decode.optional(decode.int),
  )
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use color <- decode.field("color", decode.optional(decode.string))
  use state <- decode.field("state", decoders.card_state_decoder())
  use task_count <- decode.field("task_count", decode.int)
  use completed_count <- decode.field("completed_count", decode.int)
  use created_by <- decode.field("created_by", decode.int)
  use created_at <- decode.field("created_at", decode.string)
  use has_new_notes <- decode.optional_field(
    "has_new_notes",
    False,
    decode.bool,
  )
  decode.success(card.Card(
    id: id,
    project_id: project_id,
    milestone_id: milestone_id,
    title: title,
    description: description,
    color: color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
    has_new_notes: has_new_notes,
  ))
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
  let milestone_field = case c.milestone_id {
    opt.Some(id) -> json.int(id)
    opt.None -> json.null()
  }
  json.object([
    #("id", json.int(c.id)),
    #("project_id", json.int(c.project_id)),
    #("milestone_id", milestone_field),
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
          attribute.placeholder(helpers_i18n.i18n_t(
            model,
            i18n_text.SearchPlaceholder,
          )),
          attribute.value(model.admin.cards.cards_search),
          event.on_input(fn(value) {
            pool_msg(pool_messages.CardsSearchChanged(value))
          }),
        ]),
      ]),
      // State filter dropdown (AC8)
      div([attribute.class("filter-group")], [
        label([], [text(helpers_i18n.i18n_t(model, i18n_text.CardState))]),
        select(
          [
            attribute.class("filter-select"),
            attribute.attribute("data-testid", "cards-state-filter"),
            event.on_input(fn(value) {
              pool_msg(pool_messages.CardsStateFilterChanged(value))
            }),
          ],
          [
            option(
              [
                attribute.value(""),
                attribute.selected(
                  model.admin.cards.cards_state_filter == opt.None,
                ),
              ],
              helpers_i18n.i18n_t(model, i18n_text.AllOption),
            ),
            option(
              [
                attribute.value("pendiente"),
                attribute.selected(
                  model.admin.cards.cards_state_filter
                  == opt.Some(card.Pendiente),
                ),
              ],
              helpers_i18n.i18n_t(model, i18n_text.CardStatePendiente),
            ),
            option(
              [
                attribute.value("en_curso"),
                attribute.selected(
                  model.admin.cards.cards_state_filter == opt.Some(card.EnCurso),
                ),
              ],
              helpers_i18n.i18n_t(model, i18n_text.CardStateEnCurso),
            ),
            option(
              [
                attribute.value("cerrada"),
                attribute.selected(
                  model.admin.cards.cards_state_filter == opt.Some(card.Cerrada),
                ),
              ],
              helpers_i18n.i18n_t(model, i18n_text.CardStateCerrada),
            ),
          ],
        ),
      ]),
      // Show empty checkbox (AC7) - unchecked by default
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.admin.cards.cards_show_empty),
            attribute.attribute("data-testid", "show-empty-cards"),
            event.on_check(fn(_) {
              pool_msg(pool_messages.CardsShowEmptyToggled)
            }),
          ]),
          text(helpers_i18n.i18n_t(model, i18n_text.ShowEmptyCards)),
        ]),
      ]),
      // Show completed checkbox - unchecked by default
      div([attribute.class("filter-group")], [
        label([attribute.class("checkbox-label")], [
          input([
            attribute.type_("checkbox"),
            attribute.checked(model.admin.cards.cards_show_completed),
            attribute.attribute("data-testid", "show-completed-cards"),
            event.on_check(fn(_) {
              pool_msg(pool_messages.CardsShowCompletedToggled)
            }),
          ]),
          text(helpers_i18n.i18n_t(model, i18n_text.ShowCompletedCards)),
        ]),
      ]),
    ],
  )
}

/// Story 4.9: Filter cards based on model filters (UX improved)
fn filter_cards(model: Model) -> Remote(List(Card)) {
  case model.admin.cards.cards {
    Loaded(cards) -> {
      let filtered =
        cards
        |> list.filter(fn(c) {
          // Filter by state dropdown
          let state_match = case model.admin.cards.cards_state_filter {
            opt.None -> True
            opt.Some(state) -> c.state == state
          }
          // Filter by empty (show_empty = False by default = hide cards with 0 tasks)
          let empty_match = case model.admin.cards.cards_show_empty {
            True -> True
            False -> c.task_count > 0
          }
          // Filter by completed (show_completed = False by default = hide Cerrada cards)
          let completed_match = case model.admin.cards.cards_show_completed {
            True -> True
            False -> c.state != card.Cerrada
          }
          // Filter by search
          let search_match = case
            string.is_empty(model.admin.cards.cards_search)
          {
            True -> True
            False ->
              string.contains(
                string.lowercase(c.title),
                string.lowercase(model.admin.cards.cards_search),
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
        text(helpers_i18n.i18n_t(model, i18n_text.NoCardsYet)),
      ]),
      div([attribute.class("empty-state-description")], [
        text(
          "Las tarjetas agrupan tareas relacionadas. Crea tu primera tarjeta para organizar el trabajo.",
        ),
      ]),
    ])

  data_table.view_remote_with_forbidden(
    cards,
    loading_msg: helpers_i18n.i18n_t(model, i18n_text.LoadingEllipsis),
    empty_msg: "",
    forbidden_msg: helpers_i18n.i18n_t(model, i18n_text.NotPermitted),
    config: data_table.new()
      |> data_table.with_empty_state(empty_state)
      |> data_table.with_columns([
        // UX: Título con indicador de color (círculo) y [!] para notas nuevas
        data_table.column_with_class(
          helpers_i18n.i18n_t(model, i18n_text.CardTitle),
          fn(c: Card) {
            let tooltip = helpers_i18n.i18n_t(model, i18n_text.NewNotesTooltip)
            card_title_meta.view_with_class(
              "card-title-with-color",
              button(
                [
                  attribute.class("card-title-button"),
                  attribute.attribute("data-testid", "card-detail-open"),
                  event.on_click(pool_msg(pool_messages.OpenCardDetail(c.id))),
                ],
                [text(c.title)],
              ),
              c.color,
              opt.Some("var(--sb-muted)"),
              c.has_new_notes,
              tooltip,
              card_title_meta.ColorTitleNotes,
            )
          },
          "",
          "card-title-cell",
        ),
        // UX: Estado con badge de color semántico
        data_table.column(
          helpers_i18n.i18n_t(model, i18n_text.CardState),
          fn(c: Card) {
            card_state_badge.view(
              c.state,
              card_state.label(model.ui.locale, c.state),
              card_state_badge.Table,
            )
          },
        ),
        // UX: Progreso con mini barra + texto
        data_table.column(
          helpers_i18n.i18n_t(model, i18n_text.CardTasks),
          fn(c: Card) {
            card_progress.view(
              c.completed_count,
              c.task_count,
              card_progress.Compact,
            )
          },
        ),
        // UX: Acciones con iconos (como Task Types)
        // Story 4.12: Añadido botón [+] para crear tarea en tarjeta
        data_table.column_with_class(
          helpers_i18n.i18n_t(model, i18n_text.Actions),
          fn(c: Card) {
            div([], [
              // [+] Nueva tarea
              action_buttons.create_task_in_card_button(
                helpers_i18n.i18n_t(model, i18n_text.NewTaskInCard(c.title)),
                pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(c.id)),
              ),
              action_buttons.edit_button_with_testid(
                helpers_i18n.i18n_t(model, i18n_text.EditCard),
                pool_msg(
                  pool_messages.OpenCardDialog(state_types.CardDialogEdit(c.id)),
                ),
                "card-edit-btn",
              ),
              action_buttons.delete_button_with_testid(
                helpers_i18n.i18n_t(model, i18n_text.DeleteCard),
                pool_msg(
                  pool_messages.OpenCardDialog(state_types.CardDialogDelete(
                    c.id,
                  )),
                ),
                "card-delete-btn",
              ),
            ])
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(c) { int.to_string(c.id) }),
  )
}

// =============================================================================
// Card Detail Modal (Config Cards)
// =============================================================================

fn view_card_detail_modal(model: Model, project: Project) -> Element(Msg) {
  let is_org_admin = case model.core.user {
    opt.Some(user) -> permissions.is_org_admin(user.org_role)
    opt.None -> False
  }

  detail_modal_entry.view(
    model,
    detail_modal_entry.Config(
      can_manage_notes: is_org_admin || permissions.is_project_manager(project),
      on_create_task: decode_create_task_event(),
      on_close: decode_card_detail_close_event(),
    ),
  )
}

/// Decoder for create-task-requested event.
fn decode_create_task_event() -> decode.Decoder(Msg) {
  event_decoders.custom_detail(
    decode.field("card_id", decode.int, decode.success),
    fn(card_id) {
      decode.success(
        pool_msg(pool_messages.MemberCreateDialogOpenedWithCard(card_id)),
      )
    },
  )
}

/// Decoder for close-requested event.
fn decode_card_detail_close_event() -> decode.Decoder(Msg) {
  decode.success(pool_msg(pool_messages.CloseCardDetail))
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
