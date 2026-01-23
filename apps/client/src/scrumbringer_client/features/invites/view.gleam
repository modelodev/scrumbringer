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
//// ## Line Count Justification
////
//// ~200 lines: Groups create dialog, result display, and list table as a cohesive
//// admin feature. Splitting would fragment related invite link UI logic.
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to view_invites from admin section
//// - **features/invites/update.gleam**: Handles invite link messages

import gleam/list
import gleam/option as opt

import lustre/attribute

import scrumbringer_client/utils/format_date
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h3, input, label, span, table, td, text, th, thead,
  tr,
}
import lustre/element/keyed
import lustre/event

import gleam/string

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, InviteCreateDialogClosed,
  InviteCreateDialogOpened, InviteLinkCopyClicked, InviteLinkCreateSubmitted,
  InviteLinkEmailChanged, InviteLinkRegenerateClicked, Loaded, Loading, NotAsked,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/ui/dialog
import scrumbringer_client/ui/icons
import scrumbringer_client/ui/section_header
import scrumbringer_client/update_helpers

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
      update_helpers.i18n_t(model, i18n_text.InvitesTitle),
      dialog.add_button(
        model,
        i18n_text.CreateInviteLink,
        InviteCreateDialogOpened,
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

fn view_latest_invite(model: Model, origin: String) -> Element(Msg) {
  case model.invite_link_last {
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
        button([event.on_click(InviteLinkCopyClicked(full))], [
          text(update_helpers.i18n_t(model, i18n_text.Copy)),
        ]),
        case model.invite_link_copy_status {
          opt.Some(status) -> div([attribute.class("hint")], [text(status)])
          opt.None -> element.none()
        },
      ])
    }
  }
}

fn view_invite_links_list(model: Model, origin: String) -> Element(Msg) {
  case model.invite_links {
    NotAsked | Loading ->
      div([attribute.class("empty")], [
        text(update_helpers.i18n_t(model, i18n_text.LoadingEllipsis)),
      ])

    Failed(err) ->
      div([attribute.class("error")], [
        text(
          update_helpers.i18n_t(model, i18n_text.FailedToLoadInviteLinksPrefix)
          <> err.message,
        ),
      ])

    Loaded(links) ->
      case links {
        [] ->
          div([attribute.class("empty")], [
            text(update_helpers.i18n_t(model, i18n_text.NoInviteLinksYet)),
          ])

        _ ->
          table([attribute.class("table")], [
            thead([], [
              tr([], [
                th([], [
                  text(update_helpers.i18n_t(model, i18n_text.EmailLabel)),
                ]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.State))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.CreatedAt))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Link))]),
                th([], [text(update_helpers.i18n_t(model, i18n_text.Actions))]),
              ]),
            ]),
            keyed.tbody(
              [],
              list.map(links, fn(link) {
                let full = build_full_url(origin, link.url_path)
                let state_label = translate_invite_state(model, link.state)

                #(link.email, tr([], [
                  td([], [text(link.email)]),
                  td([], [
                    span(
                      [attribute.class("badge badge-" <> state_badge_class(link.state))],
                      [text(state_label)],
                    ),
                  ]),
                  td([], [text(format_date.date_only(link.created_at))]),
                  // Story 4.8: Copy button instead of full URL text
                  td([attribute.class("link-cell")], [
                    button(
                      [
                        attribute.class("btn-xs btn-icon"),
                        attribute.attribute(
                          "title",
                          update_helpers.i18n_t(model, i18n_text.CopyLink),
                        ),
                        attribute.attribute(
                          "aria-label",
                          update_helpers.i18n_t(model, i18n_text.CopyLink),
                        ),
                        attribute.disabled(model.invite_link_in_flight),
                        event.on_click(InviteLinkCopyClicked(full)),
                      ],
                      [icons.nav_icon(icons.Copy, icons.Small)],
                    ),
                  ]),
                  td([], [
                    button(
                      [
                        attribute.class("btn-xs"),
                        attribute.disabled(model.invite_link_in_flight),
                        event.on_click(InviteLinkRegenerateClicked(link.email)),
                      ],
                      [text(update_helpers.i18n_t(model, i18n_text.Regenerate))],
                    ),
                  ]),
                ]))
              }),
            ),
          ])
      }
  }
}

fn view_create_dialog(model: Model) -> Element(Msg) {
  dialog.view(
    dialog.DialogConfig(
      title: update_helpers.i18n_t(model, i18n_text.CreateInviteLink),
      icon: opt.None,
      size: dialog.DialogMd,
      on_close: InviteCreateDialogClosed,
    ),
    model.invite_create_dialog_open,
    model.invite_link_error,
    [
      form([event.on_submit(fn(_) { InviteLinkCreateSubmitted })], [
        div([attribute.class("field")], [
          label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
          input([
            attribute.type_("email"),
            attribute.value(model.invite_link_email),
            event.on_input(InviteLinkEmailChanged),
            attribute.required(True),
            attribute.placeholder(
              update_helpers.i18n_t(model, i18n_text.EmailPlaceholderExample),
            ),
          ]),
        ]),
        div([attribute.class("dialog-footer")], [
          dialog.cancel_button(model, InviteCreateDialogClosed),
          dialog.submit_button(
            model,
            model.invite_link_in_flight,
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
