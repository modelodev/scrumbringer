import fixtures
import gleam/option.{None}
import gleeunit/should
import scrumbringer_server
import scrumbringer_server/services/cards_db
import scrumbringer_server/services/org_invites_db
import scrumbringer_server/services/service_error
import scrumbringer_server/services/task_templates_db

pub fn cards_db_returns_not_found_for_missing_card_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case cards_db.get_card(db, 999_999, 1) {
    Ok(_) -> should.fail()
    Error(cards_db.CardNotFound) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn cards_db_update_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case cards_db.update_card(db, 999_999, None, "Title", None, None, 1) {
    Ok(_) -> should.fail()
    Error(cards_db.CardNotFound) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn cards_db_delete_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case cards_db.delete_card(db, 999_999) {
    Ok(_) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn task_templates_update_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case
    task_templates_db.update_template(db, 999_999, 1, 1, None, None, None, None)
  {
    Ok(_) -> should.fail()
    Error(service_error.NotFound) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn task_templates_delete_returns_not_found_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case task_templates_db.delete_template(db, 999_999, 1) {
    Ok(_) -> should.fail()
    Error(service_error.NotFound) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}

pub fn org_invites_rejects_invalid_expiry_test() {
  let assert Ok(#(app, _handler, _session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  case org_invites_db.create_invite(db, 1, 1, 0) {
    Ok(_) -> should.fail()
    Error(org_invites_db.ExpiryHoursInvalid) -> should.be_true(True)
    Error(_) -> should.fail()
  }
}
