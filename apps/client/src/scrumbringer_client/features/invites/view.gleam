//// Invite links admin view.
////
//// ## Mission
////
//// Renders the invite links management UI for org admins.
////
//// ## Responsibilities
////
//// - Invite link creation form
//// - Latest invite link display with copy button
//// - Invite links list table with actions
////
//// ## Line Count Justification
////
//// ~150 lines: Groups create form, result display, and list table as a cohesive
//// admin feature. Splitting would fragment related invite link UI logic.
////
//// ## Relations
////
//// - **client_view.gleam**: Dispatches to view_invites from admin section
//// - **features/invites/update.gleam**: Handles invite link messages

import gleam/list
import gleam/option as opt

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html.{
  button, div, form, h3, hr, input, label, p, table, td, text, th, thead,
  tr,
}
import lustre/element/keyed
import lustre/event

import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, Failed, InviteLinkCopyClicked, InviteLinkCreateSubmitted,
  InviteLinkEmailChanged, InviteLinkRegenerateClicked, Loaded, Loading, NotAsked,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Public API
// =============================================================================

/// Main invite links section view.
pub fn view_invites(model: Model) -> Element(Msg) {
  let create_label = case model.invite_link_in_flight {
    True -> update_helpers.i18n_t(model, i18n_text.Working)
    False -> update_helpers.i18n_t(model, i18n_text.CreateInviteLink)
  }

  let origin = client_ffi.location_origin()

  div([attribute.class("section")], [
    p([], [text(update_helpers.i18n_t(model, i18n_text.InviteLinksHelp))]),
    case model.invite_link_error {
      opt.Some(err) -> div([attribute.class("error")], [text(err)])
      opt.None -> element.none()
    },
    form([event.on_submit(fn(_) { InviteLinkCreateSubmitted })], [
      div([attribute.class("field")], [
        label([], [text(update_helpers.i18n_t(model, i18n_text.EmailLabel))]),
        input([
          attribute.type_("email"),
          attribute.value(model.invite_link_email),
          event.on_input(InviteLinkEmailChanged),
          attribute.required(True),
        ]),
      ]),
      button(
        [
          attribute.type_("submit"),
          attribute.disabled(model.invite_link_in_flight),
        ],
        [text(create_label)],
      ),
    ]),
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
    },
    hr([]),
    h3([], [text(update_helpers.i18n_t(model, i18n_text.InviteLinks))]),
    view_invite_links_list(model, origin),
  ])
}

// =============================================================================
// Private Helpers
// =============================================================================

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

                #(link.email, tr([], [
                  td([], [text(link.email)]),
                  td([], [text(link.state)]),
                  td([], [text(link.created_at)]),
                  td([], [text(full)]),
                  td([], [
                    button(
                      [
                        attribute.disabled(model.invite_link_in_flight),
                        event.on_click(InviteLinkCopyClicked(full)),
                      ],
                      [text(update_helpers.i18n_t(model, i18n_text.Copy))],
                    ),
                    button(
                      [
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

fn build_full_url(origin: String, url_path: String) -> String {
  case origin {
    "" -> url_path
    _ -> origin <> url_path
  }
}
