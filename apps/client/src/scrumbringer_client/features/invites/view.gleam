//// Invite links admin view.
////
//// ## Mission
////
//// Renders the invite links management UI for org admins.
////
//// ## Responsibilities
////
//// - Invite link creation form via modal dialog
//// - Latest invite link display with copy button
//// - Invite links list table with actions
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to view_invites from admin section
//// - **features/invites/update.gleam**: Handles invite link messages

import gleam/option as opt
import gleam/string

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{div, form, h3, input, text}
import lustre/event

import domain/org.{type InviteLink}
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{type Model, type Msg, admin_msg}
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error, InFlight, InviteLinkForm,
}
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/action_buttons
import scrumbringer_client/ui/badge
import scrumbringer_client/ui/copyable_input
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/form_field
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/utils/format_date

// =============================================================================
// Public API
// =============================================================================

/// Main invite links section view.
pub fn view_invites(model: Model) -> Element(Msg) {
  let origin = client_ffi.location_origin()

  div([attribute.class("section")], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Invites,
      helpers_i18n.i18n_t(model, i18n_text.InvitesTitle),
      dialog.add_button(
        model,
        i18n_text.CreateInviteLink,
        admin_msg(admin_messages.InviteCreateDialogOpened),
      ),
    ),
    // Latest invite link result (if any)
    view_latest_invite(model, origin),
    // Invite links list
    view_invite_links_list(model, origin),
    // Create dialog
    view_create_dialog(model),
  ])
}

// =============================================================================
// Private Helpers
// =============================================================================

// Justification: nested case improves clarity for branching logic.
fn view_latest_invite(model: Model, origin: String) -> Element(Msg) {
  case model.admin.invites.invite_link_last {
    opt.None -> element.none()

    opt.Some(link) -> {
      let full = build_full_url(origin, link.url_path)

      div([attribute.class("invite-result")], [
        h3([], [
          text(helpers_i18n.i18n_t(model, i18n_text.LatestInviteLink)),
        ]),
        form_field.view_required(
          helpers_i18n.i18n_t(model, i18n_text.EmailLabel),
          input([
            attribute.type_("text"),
            attribute.value(link.email),
            attribute.readonly(True),
          ]),
        ),
        copyable_input.view(
          helpers_i18n.i18n_t(model, i18n_text.Link),
          full,
          admin_msg(admin_messages.InviteLinkCopyClicked(full)),
          helpers_i18n.i18n_t(model, i18n_text.Copy),
          model.admin.invites.invite_link_copy_status,
        ),
      ])
    }
  }
}

fn view_invite_links_list(model: Model, origin: String) -> Element(Msg) {
  let t = fn(key) { helpers_i18n.i18n_t(model, key) }
  let #(_open, _email, _error, in_flight) = invite_dialog_info(model)

  data_table.view_remote(
    model.admin.invites.invite_links,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoInviteLinksYet),
    config: data_table.new()
      |> data_table.with_error_prefix(t(i18n_text.FailedToLoadInviteLinksPrefix))
      |> data_table.with_columns([
        data_table.column(t(i18n_text.EmailLabel), fn(link: InviteLink) {
          text(link.email)
        }),
        data_table.column(t(i18n_text.State), fn(link: InviteLink) {
          badge.status(translate_invite_state(model, link.state))
        }),
        data_table.column(t(i18n_text.CreatedAt), fn(link: InviteLink) {
          text(format_date.date_only(link.created_at))
        }),
        data_table.column_with_class(
          t(i18n_text.Link),
          fn(link: InviteLink) {
            let full = build_full_url(origin, link.url_path)
            action_buttons.task_icon_button(
              t(i18n_text.CopyLink),
              admin_msg(admin_messages.InviteLinkCopyClicked(full)),
              icons.Copy,
              action_buttons.SizeXs,
              in_flight,
              "",
              opt.None,
              opt.None,
            )
          },
          "col-actions",
          "cell-actions",
        ),
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(link: InviteLink) {
            action_buttons.task_icon_button(
              t(i18n_text.Regenerate),
              admin_msg(admin_messages.InviteLinkRegenerateClicked(link.email)),
              icons.Refresh,
              action_buttons.SizeXs,
              in_flight,
              "",
              opt.None,
              opt.None,
            )
          },
          "col-actions",
          "cell-actions",
        ),
      ])
      |> data_table.with_key(fn(link: InviteLink) { link.email }),
  )
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  let #(open, email, error, in_flight) = invite_dialog_info(model)
  dialog.view(
    dialog.DialogConfig(
      title: helpers_i18n.i18n_t(model, i18n_text.CreateInviteLink),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(admin_messages.InviteCreateDialogClosed),
    ),
    open,
    error,
    [
      form(
        [
          event.on_submit(fn(_) {
            admin_msg(admin_messages.InviteLinkCreateSubmitted)
          }),
        ],
        [
          form_field.view(
            helpers_i18n.i18n_t(model, i18n_text.EmailLabel),
            input([
              attribute.type_("email"),
              attribute.value(email),
              event.on_input(fn(value) {
                admin_msg(admin_messages.InviteLinkEmailChanged(value))
              }),
              attribute.required(True),
              attribute.placeholder(helpers_i18n.i18n_t(
                model,
                i18n_text.EmailPlaceholderExample,
              )),
            ]),
          ),
          div([attribute.class("dialog-footer")], [
            dialog.cancel_button(
              model,
              admin_msg(admin_messages.InviteCreateDialogClosed),
            ),
            dialog.submit_button(
              model,
              in_flight,
              False,
              i18n_text.Create,
              i18n_text.Creating,
            ),
          ]),
        ],
      ),
    ],
    [],
  )
}

fn invite_dialog_info(model: Model) -> #(Bool, String, opt.Option(String), Bool) {
  let #(open, email, operation) = case model.admin.invites.invite_link_dialog {
    DialogOpen(form: InviteLinkForm(email: email), operation: operation) -> #(
      True,
      email,
      operation,
    )
    DialogClosed(operation: operation) -> #(False, "", operation)
  }

  let error = case operation {
    Error(message) -> opt.Some(message)
    _ -> opt.None
  }

  let in_flight = operation == InFlight

  #(open, email, error, in_flight)
}

fn build_full_url(origin: String, url_path: String) -> String {
  case origin {
    "" -> url_path
    _ -> origin <> url_path
  }
}

// =============================================================================
// Invite State Helpers (Story 4.8)
// =============================================================================

/// Translate invite link state to current locale.
fn translate_invite_state(model: Model, state: String) -> String {
  case string.lowercase(state) {
    "active" -> helpers_i18n.i18n_t(model, i18n_text.InviteStateActive)
    "used" -> helpers_i18n.i18n_t(model, i18n_text.InviteStateUsed)
    "invalidated" | "expired" ->
      helpers_i18n.i18n_t(model, i18n_text.InviteStateExpired)
    _ -> state
  }
}
/// Get badge class variant based on state.
