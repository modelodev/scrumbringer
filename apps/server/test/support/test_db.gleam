//// Test database connection and transaction isolation helpers.
////
//// ## Mission
////
//// Provides transaction-based test isolation for unit tests that need
//// database access without persisting test data.
////
//// ## Environment Requirements
////
//// Requires `DATABASE_URL` environment variable to be set. This is the same
//// variable used by the main application. Example:
////
//// ```bash
//// export DATABASE_URL=postgres://user:pass@localhost/scrumbringer_test
//// ```
////
//// ## Usage
////
//// ```gleam
//// import support/test_db
//// import fixtures
////
//// pub fn my_db_test() {
////   // For tests that need the full app context:
////   let assert Ok(#(app, handler, session)) = fixtures.bootstrap()
////   let scrumbringer_server.App(db: db, ..) = app
////
////   test_db.with_test_transaction(db, fn(tx) {
////     // All operations here will be rolled back after the test
////     let result = some_db_operation(tx)
////     result |> should.be_ok()
////   })
//// }
//// ```
////
//// ## How It Works
////
//// The `with_test_transaction` helper wraps test code in a transaction that
//// always rolls back, ensuring test isolation without persisting test data.
//// This is achieved by having the inner function return an Error, which
//// triggers pog's automatic rollback.

import pog

/// Run a test function within a transaction that always rolls back.
/// This ensures test isolation without persisting test data.
///
/// The test function receives a transaction connection and can perform
/// any database operations. All changes are rolled back when the function
/// returns, regardless of success or failure.
pub fn with_test_transaction(
  db: pog.Connection,
  test_fn: fn(pog.Connection) -> a,
) -> a {
  // pog.transaction commits on Ok, rolls back on Error
  // We always want rollback for test isolation, so we wrap the result in Error
  let result =
    pog.transaction(db, fn(tx) {
      let test_result = test_fn(tx)
      // Force rollback by returning Error containing the actual result
      Error(test_result)
    })

  case result {
    Error(pog.TransactionRolledBack(value)) -> value
    _ -> panic as "Unexpected transaction result - expected rollback"
  }
}
