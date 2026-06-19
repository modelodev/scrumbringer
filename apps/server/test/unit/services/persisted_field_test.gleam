import gleam/dynamic
import gleam/dynamic/decode
import pog
import scrumbringer_server/use_case/persisted_field
import scrumbringer_server/use_case/service_error

pub fn required_returns_parsed_value_test() {
  let parse = fn(value) {
    case value {
      "ready" -> Ok("parsed")
      _ -> Error(Nil)
    }
  }

  let assert Ok("parsed") =
    persisted_field.required("ready", parse, "Invalid persisted state")
}

pub fn required_includes_invalid_value_in_unexpected_error_test() {
  let parse = fn(value) {
    case value {
      "ready" -> Ok("parsed")
      _ -> Error(Nil)
    }
  }

  let assert Error(service_error.Unexpected("Invalid persisted state: archived")) =
    persisted_field.required("archived", parse, "Invalid persisted state")
}

pub fn returned_row_returns_first_row_test() {
  let assert Ok(1) =
    persisted_field.returned_row([1, 2], "task_notes.create_note")
}

pub fn returned_row_includes_operation_in_unexpected_error_test() {
  let assert Error(service_error.Unexpected(
    "task_notes.create_note returned no row",
  )) = persisted_field.returned_row([], "task_notes.create_note")
}

pub fn query_row_returns_first_row_test() {
  let assert Ok(1) = persisted_field.query_row([1, 2])
}

pub fn query_row_maps_empty_rows_to_query_error_test() {
  let assert Error(pog.UnexpectedResultType([])) = persisted_field.query_row([])
}

pub fn int_decoder_reads_first_field_test() {
  let row = dynamic.array([dynamic.int(42)])

  let assert Ok(42) = decode.run(row, persisted_field.int_decoder())
}

pub fn bool_decoder_reads_first_field_test() {
  let row = dynamic.array([dynamic.bool(True)])

  let assert Ok(True) = decode.run(row, persisted_field.bool_decoder())
}

pub fn string_decoder_reads_first_field_test() {
  let row = dynamic.array([dynamic.string("ready")])

  let assert Ok("ready") = decode.run(row, persisted_field.string_decoder())
}
