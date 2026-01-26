//// Invites feature update handlers.
////
//// ## Mission
////
//// Handles invite link creation, regeneration, and copy flows.
////
//// ## Responsibilities
////
//// - Invite link create form state and submission
//// - Invite link regeneration
//// - Copy to clipboard functionality
////
//// ## Non-responsibilities
////
//// - API calls (see `api/org.gleam`)
//// - User permissions (see `permissions.gleam`)
////
//// ## Relations
////
//// - **client_update.gleam**: Dispatches invite messages to handlers here
//// - **api/org.gleam**: Provides API effects for invite operations

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

// API modules
import scrumbringer_client/api/org as api_org

// Domain types
import domain/api_error.{type ApiError}
import domain/org.{type InviteLink}
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state.{
  type Model, type Msg, AdminModel, Failed, InviteLinkCopyFinished,
  InviteLinkCreated, InviteLinkRegenerated, InviteLinksFetched, Loaded,
  admin_msg, update_admin,
}
import scrumbringer_client/i18n/text as i18n_text
import scrumbringer_client/update_helpers

// =============================================================================
// Invite Links Fetch Handlers
// =============================================================================

/// Handle invite links fetch success.
pub fn handle_invite_links_fetched_ok(
  model: Model,
  links: List(InviteLink),
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, invite_links: Loaded(links))
    }),
    effect.none(),
  )
}

/// Handle invite links fetch error.
pub fn handle_invite_links_fetched_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status == 401 {
    True -> update_helpers.reset_to_login(model)
    False -> #(
      update_admin(model, fn(admin) {
        AdminModel(..admin, invite_links: Failed(err))
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Invite Link Dialog Handlers
// =============================================================================

/// Handle invite create dialog opened.
pub fn handle_invite_create_dialog_opened(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        invite_create_dialog_open: True,
        invite_link_email: "",
        invite_link_error: opt.None,
      )
    }),
    effect.none(),
  )
}

/// Handle invite create dialog closed.
pub fn handle_invite_create_dialog_closed(model: Model) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        invite_create_dialog_open: False,
        invite_link_error: opt.None,
      )
    }),
    effect.none(),
  )
}

// =============================================================================
// Invite Link Create Handlers
// =============================================================================

/// Handle invite link email input change.
pub fn handle_invite_link_email_changed(
  model: Model,
  value: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, invite_link_email: value)
    }),
    effect.none(),
  )
}

// Justification: nested case improves clarity for branching logic.
/// Handle invite link create form submission.
pub fn handle_invite_link_create_submitted(
  model: Model,
) -> #(Model, Effect(Msg)) {
  case model.admin.invite_link_in_flight {
    True -> #(model, effect.none())
    False -> {
      let email = string.trim(model.admin.invite_link_email)

      case email == "" {
        True -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              invite_link_error: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.EmailRequired,
              )),
            )
          }),
          effect.none(),
        )
        False -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                invite_link_in_flight: True,
                invite_link_error: opt.None,
                invite_link_copy_status: opt.None,
              )
            })
          #(
            model,
            api_org.create_invite_link(email, fn(result) {
              admin_msg(InviteLinkCreated(result))
            }),
          )
        }
      }
    }
  }
}

/// Handle invite link created success.
pub fn handle_invite_link_created_ok(
  model: Model,
  link: InviteLink,
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        invite_link_in_flight: False,
        invite_create_dialog_open: False,
        invite_link_last: opt.Some(link),
        invite_link_email: "",
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.InviteLinkCreated,
    ))
  let list_fx =
    api_org.list_invite_links(fn(result) {
      admin_msg(InviteLinksFetched(result))
    })
  #(model, effect.batch([list_fx, toast_fx]))
}

/// Handle invite link created error.
pub fn handle_invite_link_created_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          invite_link_in_flight: False,
          invite_link_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          )),
        )
      }),
      update_helpers.toast_warning(update_helpers.i18n_t(
        model,
        i18n_text.NotPermitted,
      )),
    )
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          invite_link_in_flight: False,
          invite_link_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Invite Link Regenerate Handlers
// =============================================================================

// Justification: nested case improves clarity for branching logic.
/// Handle invite link regenerate click.
pub fn handle_invite_link_regenerate_clicked(
  model: Model,
  email: String,
) -> #(Model, Effect(Msg)) {
  case model.admin.invite_link_in_flight {
    True -> #(model, effect.none())
    False -> {
      let email = string.trim(email)

      case email == "" {
        True -> #(
          update_admin(model, fn(admin) {
            AdminModel(
              ..admin,
              invite_link_error: opt.Some(update_helpers.i18n_t(
                model,
                i18n_text.EmailRequired,
              )),
            )
          }),
          effect.none(),
        )
        False -> {
          let model =
            update_admin(model, fn(admin) {
              AdminModel(
                ..admin,
                invite_link_in_flight: True,
                invite_link_error: opt.None,
                invite_link_copy_status: opt.None,
                invite_link_email: email,
              )
            })
          #(
            model,
            api_org.regenerate_invite_link(email, fn(result) {
              admin_msg(InviteLinkRegenerated(result))
            }),
          )
        }
      }
    }
  }
}

/// Handle invite link regenerated success.
pub fn handle_invite_link_regenerated_ok(
  model: Model,
  link: InviteLink,
) -> #(Model, Effect(Msg)) {
  let model =
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        invite_link_in_flight: False,
        invite_link_last: opt.Some(link),
        invite_link_email: "",
      )
    })
  let toast_fx =
    update_helpers.toast_success(update_helpers.i18n_t(
      model,
      i18n_text.InviteLinkRegenerated,
    ))
  let list_fx =
    api_org.list_invite_links(fn(result) {
      admin_msg(InviteLinksFetched(result))
    })
  #(model, effect.batch([list_fx, toast_fx]))
}

/// Handle invite link regenerated error.
pub fn handle_invite_link_regenerated_error(
  model: Model,
  err: ApiError,
) -> #(Model, Effect(Msg)) {
  case err.status {
    401 -> update_helpers.reset_to_login(model)
    403 -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          invite_link_in_flight: False,
          invite_link_error: opt.Some(update_helpers.i18n_t(
            model,
            i18n_text.NotPermitted,
          )),
        )
      }),
      update_helpers.toast_warning(update_helpers.i18n_t(
        model,
        i18n_text.NotPermitted,
      )),
    )
    _ -> #(
      update_admin(model, fn(admin) {
        AdminModel(
          ..admin,
          invite_link_in_flight: False,
          invite_link_error: opt.Some(err.message),
        )
      }),
      effect.none(),
    )
  }
}

// =============================================================================
// Copy Handlers
// =============================================================================

/// Handle invite link copy click.
pub fn handle_invite_link_copy_clicked(
  model: Model,
  text: String,
) -> #(Model, Effect(Msg)) {
  #(
    update_admin(model, fn(admin) {
      AdminModel(
        ..admin,
        invite_link_copy_status: opt.Some(update_helpers.i18n_t(
          model,
          i18n_text.Copying,
        )),
      )
    }),
    copy_to_clipboard(text, fn(ok) { admin_msg(InviteLinkCopyFinished(ok)) }),
  )
}

/// Handle invite link copy finished.
pub fn handle_invite_link_copy_finished(
  model: Model,
  ok: Bool,
) -> #(Model, Effect(Msg)) {
  let message = case ok {
    True -> update_helpers.i18n_t(model, i18n_text.Copied)
    False -> update_helpers.i18n_t(model, i18n_text.CopyFailed)
  }

  #(
    update_admin(model, fn(admin) {
      AdminModel(..admin, invite_link_copy_status: opt.Some(message))
    }),
    effect.none(),
  )
}

// =============================================================================
// Helpers
// =============================================================================

fn copy_to_clipboard(text: String, callback: fn(Bool) -> Msg) -> Effect(Msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
