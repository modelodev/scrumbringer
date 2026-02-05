import gleam/list
import gleeunit/should
import scrumbringer_client/client_state
import scrumbringer_client/helpers/i18n as helpers_i18n
import scrumbringer_client/helpers/validation as helpers_validation
import scrumbringer_client/i18n/text as i18n_text

pub fn validate_required_string_trims_value_test() {
  let model = client_state.default_model()
  let result =
    helpers_validation.validate_required_string(
      model,
      "  hello  ",
      i18n_text.NameRequired,
    )
  case result {
    Ok(value) ->
      helpers_validation.non_empty_string_value(value)
      |> should.equal("hello")
    Error(_) -> should.fail()
  }
}

pub fn validate_required_string_reports_error_test() {
  let model = client_state.default_model()
  let expected = helpers_i18n.i18n_t(model, i18n_text.NameRequired)
  helpers_validation.validate_required_string(
    model,
    "   ",
    i18n_text.NameRequired,
  )
  |> should.equal(Error(expected))
}

pub fn validate_required_fields_returns_values_test() {
  let model = client_state.default_model()
  let result =
    helpers_validation.validate_required_fields(model, [
      #("a", i18n_text.NameRequired),
      #("b", i18n_text.EmailRequired),
    ])
  case result {
    Ok(values) ->
      values
      |> list.map(helpers_validation.non_empty_string_value)
      |> should.equal(["a", "b"])
    Error(_) -> should.fail()
  }
}
