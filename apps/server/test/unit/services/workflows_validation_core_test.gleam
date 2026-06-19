import fixtures
import gleam/option.{Some}
import scrumbringer_server
import scrumbringer_server/use_case/capabilities_db
import scrumbringer_server/use_case/workflows/validation_core
import support/assertions as expect

pub fn validate_task_title_value_rejects_empty_test() {
  case validation_core.validate_task_title_value("   ") {
    Ok(_) -> expect.fail()
    Error(validation_core.ValidationError(_)) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn validate_task_title_value_rejects_too_long_test() {
  let long = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

  case validation_core.validate_task_title_value(long) {
    Ok(_) -> expect.fail()
    Error(validation_core.ValidationError(_)) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn validate_priority_value_rejects_out_of_range_test() {
  case validation_core.validate_priority_value(0) {
    Ok(_) -> expect.fail()
    Error(validation_core.ValidationError(_)) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn validate_task_type_in_project_rejects_mismatched_project_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(other_project_id) =
    fixtures.create_project(handler, session, "Other")
  let assert Ok(type_id) =
    fixtures.create_task_type(handler, session, project_id, "Bug", "bug-ant")

  case
    validation_core.validate_task_type_in_project(db, type_id, other_project_id)
  {
    Ok(_) -> expect.fail()
    Error(validation_core.ValidationError(_)) -> Nil
    Error(_) -> expect.fail()
  }
}

pub fn validate_capability_in_project_rejects_mismatched_project_test() {
  let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
  let scrumbringer_server.App(db: db, ..) = app

  let assert Ok(project_id) = fixtures.create_project(handler, session, "Core")
  let assert Ok(other_project_id) =
    fixtures.create_project(handler, session, "Other")
  let assert Ok(capability) =
    capabilities_db.create_capability(db, project_id, "QA")

  case
    validation_core.validate_capability_in_project(
      db,
      Some(capability.id),
      other_project_id,
    )
  {
    Ok(_) -> expect.fail()
    Error(validation_core.ValidationError(_)) -> Nil
    Error(_) -> expect.fail()
  }
}
