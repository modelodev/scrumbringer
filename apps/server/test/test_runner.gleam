//// Custom test runner that executes tests sequentially.
////
//// This avoids race conditions when multiple test modules share the same database.

@external(erlang, "test_runner_ffi", "run_tests_sequential")
pub fn run_tests_sequential() -> Int
