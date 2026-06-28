import gleam/option
import lustre/effect
import support/domain_fixtures

import domain/api_error.{ApiError}
import domain/card.{type Card, Active, Card}
import domain/remote.{Failed, Loaded}
import scrumbringer_client/client_state/admin/cards as admin_cards
import scrumbringer_client/features/admin/cards
import scrumbringer_client/features/pool/msg as pool_messages

fn sample_card(id: Int) -> Card {
  domain_fixtures.card(id, 1, "Card")
}

fn crud_feedback_context() -> cards.CrudFeedbackContext(Nil) {
  cards.CrudFeedbackContext(
    card_created: "Card created",
    card_updated: "Card updated",
    card_deleted: "Card deleted",
    on_success_toast: fn(_) { effect.from(fn(_dispatch) { Nil }) },
  )
}

fn update(
  model: admin_cards.Model,
  msg: pool_messages.Msg,
) -> #(
  admin_cards.Model,
  effect.Effect(Nil),
  cards.AuthPolicy,
  cards.FocusPolicy,
) {
  let assert option.Some(cards.Update(next, fx, auth_policy, focus_policy)) =
    cards.try_update(model, msg, crud_feedback_context())

  #(next, fx, auth_policy, focus_policy)
}

pub fn cards_fetched_ok_sets_loaded_cards_test() {
  let #(next, fx, auth_policy, focus_policy) =
    update(
      admin_cards.default_model(),
      pool_messages.CardsFetched(Ok([sample_card(1)])),
    )

  let assert Loaded([card]) = next.cards
  let assert 1 = card.id
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn cards_fetched_error_sets_failed_cards_test() {
  let err = ApiError(status: 500, code: "ERR", message: "failed")

  let #(next, fx, auth_policy, focus_policy) =
    update(admin_cards.default_model(), pool_messages.CardsFetched(Error(err)))

  let assert Failed(_) = next.cards
  let assert True = fx == effect.none()
  let assert cards.CheckAuth(auth_err) = auth_policy
  let assert True = auth_err == err
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn open_create_dialog_sets_dialog_mode_test() {
  let #(next, fx, auth_policy, focus_policy) =
    update(
      admin_cards.default_model(),
      pool_messages.OpenCardDialog(admin_cards.CardDialogCreate(option.None)),
    )

  let assert option.Some(admin_cards.CardDialogCreate(option.None)) =
    next.cards_dialog_mode
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn open_edit_dialog_sets_dialog_mode_test() {
  let #(next, fx, auth_policy, focus_policy) =
    update(
      admin_cards.default_model(),
      pool_messages.OpenCardDialog(admin_cards.CardDialogEdit(1)),
    )

  let assert option.Some(admin_cards.CardDialogEdit(1)) = next.cards_dialog_mode
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn close_dialog_clears_dialog_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards_dialog_mode: option.Some(admin_cards.CardDialogCreate(option.None)),
    )

  let #(next, fx, auth_policy, focus_policy) =
    update(model, pool_messages.CloseCardDialog)

  let assert option.None = next.cards_dialog_mode
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.FocusAfterClose = focus_policy
}

pub fn crud_created_prepends_card_and_closes_dialog_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([sample_card(1)]),
      cards_dialog_mode: option.Some(admin_cards.CardDialogCreate(option.None)),
    )

  let #(next, fx, auth_policy, focus_policy) =
    update(model, pool_messages.CardCrudCreated(sample_card(2)))

  let assert Loaded([created, existing]) = next.cards
  let assert 2 = created.id
  let assert 1 = existing.id
  let assert option.None = next.cards_dialog_mode
  let assert True = fx != effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn crud_updated_replaces_matching_card_test() {
  let updated = Card(..sample_card(1), title: "Updated")
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([sample_card(1), sample_card(2)]),
    )

  let #(next, fx, auth_policy, focus_policy) =
    update(model, pool_messages.CardCrudUpdated(updated))

  let assert Loaded([first, second]) = next.cards
  let assert "Updated" = first.title
  let assert 2 = second.id
  let assert True = fx != effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn crud_deleted_removes_matching_card_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([sample_card(1), sample_card(2)]),
    )

  let #(next, fx, auth_policy, focus_policy) =
    update(model, pool_messages.CardCrudDeleted(1))

  let assert Loaded([remaining]) = next.cards
  let assert 2 = remaining.id
  let assert True = fx != effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn card_viewed_clears_new_notes_for_matching_card_test() {
  let unread = Card(..sample_card(1), has_new_notes: True)
  let other = Card(..sample_card(2), has_new_notes: True)
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([unread, other]),
    )

  let next = cards.handle_card_viewed(model, 1)

  let assert Loaded([first, second]) = next.cards
  let assert False = first.has_new_notes
  let assert True = second.has_new_notes
}

pub fn card_viewed_preserves_unloaded_cards_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Failed(ApiError(status: 500, code: "ERR", message: "failed")),
    )

  let next = cards.handle_card_viewed(model, 1)

  let assert Failed(_) = next.cards
}

pub fn show_empty_toggled_flips_visibility_test() {
  let model =
    admin_cards.Model(..admin_cards.default_model(), cards_show_empty: True)

  let #(next, fx, auth_policy, focus_policy) =
    update(model, pool_messages.CardsShowEmptyToggled)

  let assert False = next.cards_show_empty
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn show_closed_toggled_flips_visibility_test() {
  let model =
    admin_cards.Model(..admin_cards.default_model(), cards_show_closed: True)

  let #(next, fx, auth_policy, focus_policy) =
    update(model, pool_messages.CardsShowClosedToggled)

  let assert False = next.cards_show_closed
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn state_filter_changed_parses_valid_state_and_clears_invalid_test() {
  let #(filtered, fx, auth_policy, focus_policy) =
    update(
      admin_cards.default_model(),
      pool_messages.CardsStateFilterChanged("en_curso"),
    )
  let assert option.Some(Active) = filtered.cards_state_filter
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy

  let #(cleared, _fx, _, _) =
    update(filtered, pool_messages.CardsStateFilterChanged("unknown"))
  let assert option.None = cleared.cards_state_filter
}

pub fn search_changed_updates_query_test() {
  let #(next, fx, auth_policy, focus_policy) =
    update(
      admin_cards.default_model(),
      pool_messages.CardsSearchChanged("release"),
    )

  let assert "release" = next.cards_search
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn try_update_fetch_error_requests_auth_check_test() {
  let err = ApiError(status: 500, code: "ERR", message: "failed")

  let assert option.Some(cards.Update(next, fx, auth_policy, focus_policy)) =
    cards.try_update(
      admin_cards.default_model(),
      pool_messages.CardsFetched(Error(err)),
      crud_feedback_context(),
    )
  let assert cards.CheckAuth(auth_err) = auth_policy

  let assert True = auth_err == err
  let assert Failed(_) = next.cards
  let assert True = fx == effect.none()
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn try_update_close_dialog_requests_focus_policy_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards_dialog_mode: option.Some(admin_cards.CardDialogCreate(option.None)),
    )

  let assert option.Some(cards.Update(next, fx, auth_policy, focus_policy)) =
    cards.try_update(
      model,
      pool_messages.CloseCardDialog,
      crud_feedback_context(),
    )

  let assert option.None = next.cards_dialog_mode
  let assert True = fx == effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.FocusAfterClose = focus_policy
}

pub fn try_update_crud_created_returns_local_update_test() {
  let model =
    admin_cards.Model(
      ..admin_cards.default_model(),
      cards: Loaded([sample_card(1)]),
      cards_dialog_mode: option.Some(admin_cards.CardDialogCreate(option.None)),
    )

  let assert option.Some(cards.Update(next, fx, auth_policy, focus_policy)) =
    cards.try_update(
      model,
      pool_messages.CardCrudCreated(sample_card(2)),
      crud_feedback_context(),
    )

  let assert Loaded([created, existing]) = next.cards
  let assert 2 = created.id
  let assert 1 = existing.id
  let assert True = fx != effect.none()
  let assert cards.NoAuthCheck = auth_policy
  let assert cards.NoFocusAfterUpdate = focus_policy
}

pub fn try_update_ignores_non_card_messages_test() {
  let assert option.None =
    cards.try_update(
      admin_cards.default_model(),
      pool_messages.MemberPoolVisibilityChanged("all-open"),
      crud_feedback_context(),
    )
}
