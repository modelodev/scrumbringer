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
//// - Root model assembly (see `features/admin/update.gleam`)
//// - User permissions and authentication handling (see `features/admin/update.gleam`)
////
//// ## Relations
////
//// - **features/admin/update.gleam**: Applies local transitions to the root model
//// - **api/org.gleam**: Provides API effects for invite operations

import gleam/option as opt
import gleam/string

import lustre/effect.{type Effect}

import domain/api_error.{type ApiError, type ApiResult}
import domain/org.{type InviteLink}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/api/org as api_org
import scrumbringer_client/client_ffi
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/types.{
  type DialogState, type InviteLinkForm, DialogClosed, DialogOpen,
  Error as OperationError, Idle, InFlight, InviteLinkForm,
}
import scrumbringer_client/features/admin/msg as admin_messages

pub type Context(parent_msg) {
  Context(
    on_links_fetched: fn(ApiResult(List(InviteLink))) -> parent_msg,
    on_link_created: fn(ApiResult(InviteLink)) -> parent_msg,
    on_link_regenerated: fn(ApiResult(InviteLink)) -> parent_msg,
    on_link_invalidated: fn(ApiResult(InviteLink)) -> parent_msg,
    on_copy_finished: fn(Bool) -> parent_msg,
    email_required: String,
    copying: String,
    copied: String,
    copy_failed: String,
  )
}

pub type Success {
  InviteLinkCreated
  InviteLinkRegenerated
  InviteLinkInvalidated
}

pub type FeedbackContext(parent_msg) {
  FeedbackContext(
    invite_link_created: String,
    invite_link_regenerated: String,
    invite_link_invalidated: String,
    on_success_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type ErrorFeedbackContext(parent_msg) {
  ErrorFeedbackContext(
    not_permitted: String,
    on_warning_toast: fn(String) -> Effect(parent_msg),
  )
}

pub type AuthPolicy {
  NoAuthCheck
  CheckAuth(ApiError)
}

pub type Update(parent_msg) {
  Update(admin_invites.Model, Effect(parent_msg), AuthPolicy)
}

pub fn try_update(
  model: admin_invites.Model,
  inner: admin_messages.Msg,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
  error_feedback: ErrorFeedbackContext(parent_msg),
) -> opt.Option(Update(parent_msg)) {
  case inner {
    admin_messages.InviteCreateDialogOpened ->
      handle_invite_create_dialog_opened(model)
      |> without_auth_check

    admin_messages.InviteCreateDialogClosed ->
      handle_invite_create_dialog_closed(model)
      |> without_auth_check

    admin_messages.InviteLinkEmailChanged(value) ->
      handle_invite_link_email_changed(model, value)
      |> without_auth_check

    admin_messages.InviteLinksFetched(Ok(links)) ->
      handle_invite_links_fetched_ok(model, links)
      |> without_auth_check

    admin_messages.InviteLinksFetched(Error(err)) ->
      handle_invite_links_fetched_error(model, err)
      |> with_auth_check(err)

    admin_messages.InviteLinkCreateSubmitted ->
      handle_invite_link_create_submitted(model, context)
      |> without_auth_check

    admin_messages.InviteLinkRegenerateClicked(email) ->
      handle_invite_link_regenerate_clicked(model, email, context)
      |> without_auth_check

    admin_messages.InviteLinkCreated(Ok(link)) ->
      handle_invite_link_created_ok(model, link, context, feedback)
      |> without_auth_check

    admin_messages.InviteLinkCreated(Error(err)) ->
      handle_invite_link_created_error(model, err, error_feedback)
      |> with_auth_check(err)

    admin_messages.InviteLinkRegenerated(Ok(link)) ->
      handle_invite_link_regenerated_ok(model, link, context, feedback)
      |> without_auth_check

    admin_messages.InviteLinkRegenerated(Error(err)) ->
      handle_invite_link_regenerated_error(model, err, error_feedback)
      |> with_auth_check(err)

    admin_messages.InviteLinkInvalidateClicked(email) ->
      handle_invite_link_invalidate_clicked(model, email)
      |> without_auth_check

    admin_messages.InviteLinkInvalidateCancelled ->
      handle_invite_link_invalidate_cancelled(model)
      |> without_auth_check

    admin_messages.InviteLinkInvalidateConfirmed ->
      handle_invite_link_invalidate_confirmed(model, context)
      |> without_auth_check

    admin_messages.InviteLinkInvalidated(Ok(link)) ->
      handle_invite_link_invalidated_ok(model, link, context, feedback)
      |> without_auth_check

    admin_messages.InviteLinkInvalidated(Error(err)) ->
      handle_invite_link_invalidated_error(model, err, error_feedback)
      |> with_auth_check(err)

    admin_messages.InviteLinkCopyClicked(text) ->
      handle_invite_link_copy_clicked(model, text, context)
      |> without_auth_check

    admin_messages.InviteLinkCopyFinished(ok) ->
      handle_invite_link_copy_finished(model, ok, context)
      |> without_auth_check

    _ -> opt.None
  }
}

fn without_auth_check(
  result: #(admin_invites.Model, Effect(parent_msg)),
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, NoAuthCheck)
}

fn with_auth_check(
  result: #(admin_invites.Model, Effect(parent_msg)),
  err: ApiError,
) -> opt.Option(Update(parent_msg)) {
  with_policy(result, CheckAuth(err))
}

fn with_policy(
  result: #(admin_invites.Model, Effect(parent_msg)),
  auth_policy: AuthPolicy,
) -> opt.Option(Update(parent_msg)) {
  let #(model, fx) = result
  opt.Some(Update(model, fx, auth_policy))
}

// =============================================================================
// Invite Links Fetch Handlers
// =============================================================================

/// Handle invite links fetch success.
pub fn handle_invite_links_fetched_ok(
  model: admin_invites.Model,
  links: List(InviteLink),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(admin_invites.Model(..model, invite_links: Loaded(links)), effect.none())
}

/// Handle invite links fetch error.
pub fn handle_invite_links_fetched_error(
  model: admin_invites.Model,
  err: ApiError,
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(admin_invites.Model(..model, invite_links: Failed(err)), effect.none())
}

// =============================================================================
// Invite Link Dialog Handlers
// =============================================================================

/// Handle invite create dialog opened.
pub fn handle_invite_create_dialog_opened(
  model: admin_invites.Model,
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_dialog: DialogOpen(
        form: InviteLinkForm(email: ""),
        operation: Idle,
      ),
    ),
    effect.none(),
  )
}

/// Handle invite create dialog closed.
pub fn handle_invite_create_dialog_closed(
  model: admin_invites.Model,
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_dialog: DialogClosed(operation: Idle),
    ),
    effect.none(),
  )
}

// =============================================================================
// Invite Link Create Handlers
// =============================================================================

/// Handle invite link email input change.
pub fn handle_invite_link_email_changed(
  model: admin_invites.Model,
  value: String,
) -> #(admin_invites.Model, Effect(parent_msg)) {
  let dialog = case model.invite_link_dialog {
    DialogClosed(operation: operation) -> DialogClosed(operation: operation)
    DialogOpen(form: InviteLinkForm(email: _), operation: operation) ->
      DialogOpen(form: InviteLinkForm(email: value), operation: operation)
  }

  #(admin_invites.Model(..model, invite_link_dialog: dialog), effect.none())
}

/// Handle invite link create form submission.
pub fn handle_invite_link_create_submitted(
  model: admin_invites.Model,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  case model.invite_link_dialog {
    DialogClosed(..) -> #(model, effect.none())
    DialogOpen(form: InviteLinkForm(email: email), operation: operation) ->
      case operation {
        InFlight -> #(model, effect.none())
        _ -> submit_invite_link_create(model, string.trim(email), context)
      }
  }
}

fn submit_invite_link_create(
  model: admin_invites.Model,
  email: String,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  case email == "" {
    True -> #(
      admin_invites.Model(
        ..model,
        invite_link_dialog: DialogOpen(
          form: InviteLinkForm(email: email),
          operation: OperationError(context.email_required),
        ),
      ),
      effect.none(),
    )
    False -> #(
      admin_invites.Model(
        ..model,
        invite_link_dialog: DialogOpen(
          form: InviteLinkForm(email: email),
          operation: InFlight,
        ),
        invite_link_copy_status: opt.None,
      ),
      api_org.create_invite_link(email, context.on_link_created),
    )
  }
}

/// Handle invite link created success.
pub fn handle_invite_link_created_ok(
  model: admin_invites.Model,
  link: InviteLink,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_dialog: DialogClosed(operation: Idle),
      invite_link_last: opt.Some(link),
      invite_link_copy_status: opt.None,
    ),
    effect.batch([
      api_org.list_invite_links(context.on_links_fetched),
      success_effect(InviteLinkCreated, feedback),
    ]),
  )
}

/// Handle invite link created error.
pub fn handle_invite_link_created_error(
  model: admin_invites.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  #(
    admin_invites.Model(
      ..model,
      invite_link_dialog: update_invite_error_state(
        model.invite_link_dialog,
        message,
      ),
    ),
    error_effect(err, message, feedback),
  )
}

// =============================================================================
// Invite Link Regenerate Handlers
// =============================================================================

/// Handle invite link regenerate click.
pub fn handle_invite_link_regenerate_clicked(
  model: admin_invites.Model,
  email: String,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  case model.invite_link_dialog {
    DialogOpen(operation: InFlight, ..) | DialogClosed(operation: InFlight) -> #(
      model,
      effect.none(),
    )
    dialog ->
      submit_invite_link_regenerate(model, dialog, string.trim(email), context)
  }
}

fn submit_invite_link_regenerate(
  model: admin_invites.Model,
  dialog: DialogState(InviteLinkForm),
  email: String,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  case email == "" {
    True -> #(
      admin_invites.Model(
        ..model,
        invite_link_dialog: update_invite_error_state(
          dialog,
          context.email_required,
        ),
      ),
      effect.none(),
    )
    False -> #(
      admin_invites.Model(
        ..model,
        invite_link_dialog: update_invite_in_flight(dialog, email),
        invite_link_copy_status: opt.None,
      ),
      api_org.regenerate_invite_link(email, context.on_link_regenerated),
    )
  }
}

/// Handle invite link regenerated success.
pub fn handle_invite_link_regenerated_ok(
  model: admin_invites.Model,
  link: InviteLink,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_dialog: DialogClosed(operation: Idle),
      invite_link_last: opt.Some(link),
      invite_link_copy_status: opt.None,
    ),
    effect.batch([
      api_org.list_invite_links(context.on_links_fetched),
      success_effect(InviteLinkRegenerated, feedback),
    ]),
  )
}

/// Handle invite link regenerated error.
pub fn handle_invite_link_regenerated_error(
  model: admin_invites.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)

  #(
    admin_invites.Model(
      ..model,
      invite_link_dialog: update_invite_error_state(
        model.invite_link_dialog,
        message,
      ),
    ),
    error_effect(err, message, feedback),
  )
}

pub fn handle_invite_link_invalidate_clicked(
  model: admin_invites.Model,
  email: String,
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_invalidate_confirm: opt.Some(email),
    ),
    effect.none(),
  )
}

pub fn handle_invite_link_invalidate_cancelled(
  model: admin_invites.Model,
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(..model, invite_link_invalidate_confirm: opt.None),
    effect.none(),
  )
}

pub fn handle_invite_link_invalidate_confirmed(
  model: admin_invites.Model,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  case model.invite_link_invalidate_confirm {
    opt.None -> #(model, effect.none())
    opt.Some(email) -> #(
      admin_invites.Model(
        ..model,
        invite_link_invalidate_in_flight: opt.Some(email),
        invite_link_copy_status: opt.None,
      ),
      api_org.invalidate_invite_link(email, context.on_link_invalidated),
    )
  }
}

pub fn handle_invite_link_invalidated_ok(
  model: admin_invites.Model,
  _link: InviteLink,
  context: Context(parent_msg),
  feedback: FeedbackContext(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_invalidate_confirm: opt.None,
      invite_link_invalidate_in_flight: opt.None,
      invite_link_copy_status: opt.None,
    ),
    effect.batch([
      api_org.list_invite_links(context.on_links_fetched),
      success_effect(InviteLinkInvalidated, feedback),
    ]),
  )
}

pub fn handle_invite_link_invalidated_error(
  model: admin_invites.Model,
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  let message = error_message(err, feedback)
  #(
    admin_invites.Model(..model, invite_link_invalidate_in_flight: opt.None),
    error_effect(err, message, feedback),
  )
}

fn update_invite_error_state(
  dialog: DialogState(InviteLinkForm),
  message: String,
) -> DialogState(InviteLinkForm) {
  case dialog {
    DialogOpen(form: form, ..) ->
      DialogOpen(form: form, operation: OperationError(message))
    DialogClosed(..) -> DialogClosed(operation: OperationError(message))
  }
}

fn update_invite_in_flight(
  dialog: DialogState(InviteLinkForm),
  email: String,
) -> DialogState(InviteLinkForm) {
  case dialog {
    DialogOpen(form: InviteLinkForm(email: _), ..) ->
      DialogOpen(form: InviteLinkForm(email: email), operation: InFlight)
    DialogClosed(..) -> DialogClosed(operation: InFlight)
  }
}

pub fn error_message(
  err: ApiError,
  feedback: ErrorFeedbackContext(parent_msg),
) -> String {
  case err.status {
    403 -> feedback.not_permitted
    _ -> err.message
  }
}

pub fn error_effect(
  err: ApiError,
  message: String,
  feedback: ErrorFeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  case err.status {
    403 -> feedback.on_warning_toast(message)
    _ -> effect.none()
  }
}

// =============================================================================
// Copy Handlers
// =============================================================================

/// Handle invite link copy click.
pub fn handle_invite_link_copy_clicked(
  model: admin_invites.Model,
  text: String,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  #(
    admin_invites.Model(
      ..model,
      invite_link_copy_status: opt.Some(context.copying),
    ),
    copy_to_clipboard(text, context.on_copy_finished),
  )
}

/// Handle invite link copy finished.
pub fn handle_invite_link_copy_finished(
  model: admin_invites.Model,
  ok: Bool,
  context: Context(parent_msg),
) -> #(admin_invites.Model, Effect(parent_msg)) {
  let message = case ok {
    True -> context.copied
    False -> context.copy_failed
  }

  #(
    admin_invites.Model(..model, invite_link_copy_status: opt.Some(message)),
    effect.none(),
  )
}

pub fn success_effect(
  success: Success,
  context: FeedbackContext(parent_msg),
) -> Effect(parent_msg) {
  context.on_success_toast(success_message(success, context))
}

fn success_message(success: Success, context: FeedbackContext(parent_msg)) {
  case success {
    InviteLinkCreated -> context.invite_link_created
    InviteLinkRegenerated -> context.invite_link_regenerated
    InviteLinkInvalidated -> context.invite_link_invalidated
  }
}

// =============================================================================
// Helpers
// =============================================================================

fn copy_to_clipboard(
  text: String,
  callback: fn(Bool) -> parent_msg,
) -> Effect(parent_msg) {
  effect.from(fn(dispatch) {
    client_ffi.copy_to_clipboard(text, fn(ok) { dispatch(callback(ok)) })
    Nil
  })
}
