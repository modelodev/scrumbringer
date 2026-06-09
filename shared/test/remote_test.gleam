import domain/api_error.{ApiError}
import domain/remote.{Failed, Loaded, Loading, NotAsked, should_fetch}

pub fn should_fetch_only_for_not_asked_or_failed_test() {
  let err = ApiError(status: 500, code: "ERR", message: "boom")

  let assert True = should_fetch(NotAsked)
  let assert True = should_fetch(Failed(err))
  let assert False = should_fetch(Loading)
  let assert False = should_fetch(Loaded([1]))
}
