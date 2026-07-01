import fixtures
import gleam/option.{None}
import scrumbringer_server
import scrumbringer_server/use_case/cards_db
import scrumbringer_server/use_case/org_invites_db
import scrumbringer_server/use_case/service_error
import scrumbringer_server/use_case/task_templates_db
import support/assertions as expect

pub fn cards_db_returns_not_found_for_missing_card_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case cards_db.get_card(db, 999_999, 1) {
    Ok(_) -> expect.fail()
    Error(cards_db.CardNotFound) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn cards_db_update_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case
    cards_db.update_card(db, 999_999, None, "Title", None, None, None, 1, 1)
  {
    Ok(_) -> expect.fail()
    Error(cards_db.CardNotFound) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn cards_db_delete_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case cards_db.delete_card(db, 999_999, 1) {
    Ok(_) -> expect.fail()
    Error(cards_db.CardNotFound) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn task_templates_update_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case
    task_templates_db.update_template(db, 999_999, 1, 1, None, None, None, None)
  {
    Ok(_) -> expect.fail()
    Error(service_error.NotFound) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn task_templates_delete_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case task_templates_db.delete_template(db, 999_999, 1) {
    Ok(_) -> expect.fail()
    Error(service_error.NotFound) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn org_invites_rejects_invalid_expiry_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case org_invites_db.create_invite(db, 1, 1, 0) {
    Ok(_) -> expect.fail()
    Error(org_invites_db.ExpiryHoursInvalid) -> Nil
    Error(_) -> expect.fail()
  }
}
