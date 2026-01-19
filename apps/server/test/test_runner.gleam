//// Custom test runner that executes tests sequentially.
////
//// ## Rationale
////
//// Tests share a single PostgreSQL database and use TRUNCATE for isolation.
//// Parallel execution causes race conditions where one test's TRUNCATE
//// invalidates another test's data mid-execution.
////
//// ## Limitations
////
//// - Sequential execution is slower than parallel
//// - Tests remain order-dependent (earlier test failures affect later tests)
//// - Does not achieve true isolation (transaction-per-test would be better)
////
//// ## Future Improvements
////
//// Consider transaction-per-test isolation where each test:
//// 1. Begins a transaction
//// 2. Runs all operations within that transaction
//// 3. Rolls back at the end (regardless of pass/fail)
////
//// This would allow parallel execution while maintaining isolation.
//// However, pog's transaction API commits on success, requiring custom
//// FFI or a test-specific connection mode.

@external(erlang, "test_runner_ffi", "run_tests_sequential")
pub fn run_tests_sequential() -> Int
