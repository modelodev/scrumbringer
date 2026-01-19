import test_runner

@external(erlang, "erlang", "halt")
fn halt(code: Int) -> Nil

pub fn main() {
  let code = test_runner.run_tests_sequential()
  halt(code)
}
