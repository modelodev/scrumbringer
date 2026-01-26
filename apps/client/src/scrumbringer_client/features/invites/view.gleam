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
import lustre/element/html.{button, div, form, h3, input, label, span, text}
import lustre/event

import domain/org.{type InviteLink}
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, InviteCreateDialogClosed, InviteCreateDialogOpened,
  InviteLinkCopyClicked, InviteLinkCreateSubmitted, InviteLinkEmailChanged,
  InviteLinkRegenerateClicked, admin_msg,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/attrs
import scrumbringer_client/ui/data_table
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers
import scrumbringer_client/utils/format_date

// =============================================================================
// Public API
// =============================================================================

/// Main invite links section view.
pub fn view_invites(model: Model) -> Element(Msg) {
  let origin = client_ffi.location_origin()

  div([attrs.section()], [
    // Section header with add button (Story 4.8: consistent icons)
    section_header.view_with_action(
      icons.Invites,
      update_helpers.i18n_t(model, i18n_text.InvitesTitle),
      dialog.add_button(
        model,
        i18n_text.CreateInviteLink,
        admin_msg(InviteCreateDialogOpened),
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
  case model.admin.invite_link_last {
    opt.None -> element.none()

    opt.Some(link) -> {
      let full = build_full_url(origin, link.url_path)

      div([attribute.class("invite-result")], [
        h3([], [
          text(update_helpers.i18n_t(model, i18n_text.LatestInviteLink)),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
          input([
            attribute.type_("text"),
            attribute.value(link.email),
            attribute.readonly(True),
          ]),
        ]),
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.Link))]),
          input([
            attribute.type_("text"),
            attribute.value(full),
            attribute.readonly(True),
          ]),
        ]),
        button([event.on_click(admin_msg(InviteLinkCopyClicked(full)))], [
          text(update_helpers.i18n_t(model, i18n_text.Copy)),
        ]),
        case model.admin.invite_link_copy_status {
          opt.Some(status) -> div([attribute.class("hint")], [text(status)])
          opt.None -> element.none()
        },
      ])
    }
  }
}

fn view_invite_links_list(model: Model, origin: String) -> Element(Msg) {
  let t = fn(key) { update_helpers.i18n_t(model, key) }

  data_table.view_remote(
    model.admin.invite_links,
    loading_msg: t(i18n_text.LoadingEllipsis),
    empty_msg: t(i18n_text.NoInviteLinksYet),
    config: data_table.new()
      |> data_table.with_error_prefix(t(i18n_text.FailedToLoadInviteLinksPrefix))
      |> data_table.with_columns([
        data_table.column(t(i18n_text.EmailLabel), fn(link: InviteLink) {
          text(link.email)
        }),
        data_table.column(t(i18n_text.State), fn(link: InviteLink) {
          span(
            [
              attribute.class("badge badge-" <> state_badge_class(link.state)),
            ],
            [text(translate_invite_state(model, link.state))],
          )
        }),
        data_table.column(t(i18n_text.CreatedAt), fn(link: InviteLink) {
          text(format_date.date_only(link.created_at))
        }),
        data_table.column_with_class(
          t(i18n_text.Link),
          fn(link: InviteLink) {
            let full = build_full_url(origin, link.url_path)
            button(
              [
                attribute.class("btn-xs btn-icon"),
                attribute.attribute("title", t(i18n_text.CopyLink)),
                attribute.attribute("aria-label", t(i18n_text.CopyLink)),
                attribute.disabled(model.admin.invite_link_in_flight),
                event.on_click(admin_msg(InviteLinkCopyClicked(full))),
              ],
              [icons.nav_icon(icons.Copy, icons.Small)],
            )
          },
          "col-actions",
          "cell-actions",
        ),
        data_table.column_with_class(
          t(i18n_text.Actions),
          fn(link: InviteLink) {
            button(
              [
                attribute.class("btn-xs btn-icon"),
                attribute.attribute("title", t(i18n_text.Regenerate)),
                attribute.attribute("aria-label", t(i18n_text.Regenerate)),
                attribute.disabled(model.admin.invite_link_in_flight),
                event.on_click(
                  admin_msg(InviteLinkRegenerateClicked(link.email)),
                ),
              ],
              [icons.nav_icon(icons.Refresh, icons.Small)],
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
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.CreateInviteLink),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: admin_msg(InviteCreateDialogClosed),
    ),
    model.admin.invite_create_dialog_open,
    model.admin.invite_link_error,
    [
      form([event.on_submit(fn(_) { admin_msg(InviteLinkCreateSubmitted) })], [
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
          input([
            attribute.type_("email"),
            attribute.value(model.admin.invite_link_email),
            event.on_input(fn(value) {
              admin_msg(InviteLinkEmailChanged(value))
            }),
            attribute.required(True),
            attribute.placeholder(update_helpers.i18n_t(
              model,
              i18n_text.EmailPlaceholderExample,
            )),
          ]),
        ]),
        div([attribute.class("dialog-footer")], [
          dialog.cancel_button(model, admin_msg(InviteCreateDialogClosed)),
          dialog.submit_button(
            model,
            model.admin.invite_link_in_flight,
            False,
            i18n_text.Create,
            i18n_text.Creating,
          ),
        ]),
      ]),
    ],
    [],
  )
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
    "active" -> update_helpers.i18n_t(model, i18n_text.InviteStateActive)
    "used" -> update_helpers.i18n_t(model, i18n_text.InviteStateUsed)
    "invalidated" | "expired" ->
      update_helpers.i18n_t(model, i18n_text.InviteStateExpired)
    _ -> state
  }
}

/// Get badge class variant based on state.
fn state_badge_class(state: String) -> String {
  case string.lowercase(state) {
    "active" -> "warning"
    "used" -> "success"
    "invalidated" | "expired" -> "neutral"
    _ -> "neutral"
  }
}
