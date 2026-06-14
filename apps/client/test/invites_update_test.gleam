import gleam/option
import lustre/effect

import domain/api_error.{ApiError}
import domain/org.{type InviteLink, Active, InviteLink}
import domain/remote
import scrumbringer_client/client_state/admin/invites as admin_invites
import scrumbringer_client/client_state/types.{
  DialogClosed, DialogOpen, Error as OperationError, Idle, InFlight,
  InviteLinkForm,
}
import scrumbringer_client/features/admin/msg as admin_messages
import scrumbringer_client/features/invites/update as invites_update

fn context() -> invites_update.Context(Nil) {
  invites_update.Context(
    on_links_fetched: fn(_result) { Nil },
    on_link_created: fn(_result) { Nil },
    on_link_regenerated: fn(_result) { Nil },
    on_link_invalidated: fn(_result) { Nil },
    on_copy_finished: fn(_ok) { Nil },
    email_required: "Email required",
    copying: "Copying",
    copied: "Copied",
    copy_failed: "Copy failed",
  )
}

fn feedback_context() -> invites_update.FeedbackContext(Nil) {
  invites_update.FeedbackContext(
    invite_link_created: "Invite link created",
    invite_link_regenerated: "Invite link regenerated",
    invite_link_invalidated: "Invite link invalidated",
    on_success_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn error_feedback_context() -> invites_update.ErrorFeedbackContext(Nil) {
  invites_update.ErrorFeedbackContext(
    not_permitted: "Not permitted",
    on_warning_toast: fn(_message) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn invite_link(email: String) -> InviteLink {
  InviteLink(
    email: email,
    token: "token",
    url_path: "/accept-invite?token=token",
    state: Active,
    created_at: "2026-01-01T10:00:00Z",
    used_at: option.None,
    invalidated_at: option.None,
  )
}

pub fn links_fetch_success_loads_local_state_test() {
  let links = [invite_link("new@example.test")]

  let #(next, fx) =
    invites_update.handle_invite_links_fetched_ok(
      admin_invites.default_model(),
      links,
    )

  let assert True = next.invite_links == remote.Loaded(links)
  let assert True = fx == effect.none()
}

pub fn links_fetch_error_sets_failed_local_state_test() {
  let err = ApiError(status: 500, code: "INVITES", message: "Boom")

  let #(next, fx) =
    invites_update.handle_invite_links_fetched_error(
      admin_invites.default_model(),
      err,
    )

  let assert True = next.invite_links == remote.Failed(err)
  let assert True = fx == effect.none()
}

pub fn create_submit_requires_email_test() {
  let model =
    admin_invites.Model(
      ..admin_invites.default_model(),
      invite_link_dialog: DialogOpen(
        form: InviteLinkForm(email: "  "),
        operation: Idle,
      ),
    )

  let #(next, fx) =
    invites_update.handle_invite_link_create_submitted(model, context())

  let assert DialogOpen(
    form: InviteLinkForm(email: ""),
    operation: OperationError("Email required"),
  ) = next.invite_link_dialog
  let assert True = fx == effect.none()
}

pub fn create_submit_sets_in_flight_and_clears_copy_status_test() {
  let model =
    admin_invites.Model(
      ..admin_invites.default_model(),
      invite_link_dialog: DialogOpen(
        form: InviteLinkForm(email: " new@example.test "),
        operation: Idle,
      ),
      invite_link_copy_status: option.Some("old"),
    )

  let #(next, _fx) =
    invites_update.handle_invite_link_create_submitted(model, context())

  let assert DialogOpen(
    form: InviteLinkForm(email: "new@example.test"),
    operation: InFlight,
  ) = next.invite_link_dialog
  let assert True = next.invite_link_copy_status == option.None
}

pub fn created_success_closes_dialog_and_remembers_link_test() {
  let link = invite_link("new@example.test")

  let #(next, fx) =
    invites_update.handle_invite_link_created_ok(
      admin_invites.default_model(),
      link,
      context(),
      feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.invite_link_dialog
  let assert True = next.invite_link_last == option.Some(link)
  let assert True = next.invite_link_copy_status == option.None
  let assert False = fx == effect.none()
}

pub fn regenerated_success_closes_dialog_and_remembers_link_test() {
  let link = invite_link("new@example.test")

  let #(next, fx) =
    invites_update.handle_invite_link_regenerated_ok(
      admin_invites.default_model(),
      link,
      context(),
      feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.invite_link_dialog
  let assert True = next.invite_link_last == option.Some(link)
  let assert True = next.invite_link_copy_status == option.None
  let assert False = fx == effect.none()
}

pub fn regenerated_error_sets_dialog_error_test() {
  let #(next, fx) =
    invites_update.handle_invite_link_regenerated_error(
      admin_invites.default_model(),
      ApiError(status: 500, code: "ERR", message: "No permission"),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: OperationError("No permission")) =
    next.invite_link_dialog
  let assert True = fx == effect.none()
}

pub fn created_forbidden_error_uses_local_message_and_feedback_test() {
  let #(next, fx) =
    invites_update.handle_invite_link_created_error(
      admin_invites.default_model(),
      ApiError(status: 403, code: "FORBIDDEN", message: "backend"),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: OperationError("Not permitted")) =
    next.invite_link_dialog
  let assert True = fx != effect.none()
}

pub fn regenerated_forbidden_error_uses_local_message_and_feedback_test() {
  let #(next, fx) =
    invites_update.handle_invite_link_regenerated_error(
      admin_invites.default_model(),
      ApiError(status: 403, code: "FORBIDDEN", message: "backend"),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: OperationError("Not permitted")) =
    next.invite_link_dialog
  let assert True = fx != effect.none()
}

pub fn copy_clicked_sets_copying_status_test() {
  let #(next, _fx) =
    invites_update.handle_invite_link_copy_clicked(
      admin_invites.default_model(),
      "copy me",
      context(),
    )

  let assert True = next.invite_link_copy_status == option.Some("Copying")
}

pub fn copy_finished_sets_success_or_failure_message_test() {
  let #(copied, copied_fx) =
    invites_update.handle_invite_link_copy_finished(
      admin_invites.default_model(),
      True,
      context(),
    )
  let #(failed, failed_fx) =
    invites_update.handle_invite_link_copy_finished(
      admin_invites.default_model(),
      False,
      context(),
    )

  let assert True = copied.invite_link_copy_status == option.Some("Copied")
  let assert True = failed.invite_link_copy_status == option.Some("Copy failed")
  let assert True = copied_fx == effect.none()
  let assert True = failed_fx == effect.none()
}

pub fn try_update_fetch_error_returns_auth_policy_test() {
  let err = ApiError(status: 401, code: "AUTH", message: "Expired")

  let assert option.Some(invites_update.Update(
    next,
    fx,
    invites_update.CheckAuth(auth_err),
  )) =
    invites_update.try_update(
      admin_invites.default_model(),
      admin_messages.InviteLinksFetched(Error(err)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert True = next.invite_links == remote.Failed(err)
  let assert True = auth_err == err
  let assert True = fx == effect.none()
}

pub fn try_update_created_ok_returns_local_update_test() {
  let link = invite_link("new@example.test")

  let assert option.Some(invites_update.Update(
    next,
    fx,
    invites_update.NoAuthCheck,
  )) =
    invites_update.try_update(
      admin_invites.default_model(),
      admin_messages.InviteLinkCreated(Ok(link)),
      context(),
      feedback_context(),
      error_feedback_context(),
    )

  let assert DialogClosed(operation: Idle) = next.invite_link_dialog
  let assert True = next.invite_link_last == option.Some(link)
  let assert False = fx == effect.none()
}

pub fn try_update_ignores_non_invite_messages_test() {
  let assert option.None =
    invites_update.try_update(
      admin_invites.default_model(),
      admin_messages.MemberAddDialogOpened,
      context(),
      feedback_context(),
      error_feedback_context(),
    )
}
