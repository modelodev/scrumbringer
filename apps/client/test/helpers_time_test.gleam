import gleeunit/should
import scrumbringer_client/helpers/time as helpers_time

pub fn format_seconds_mm_ss_test() {
  helpers_time.format_seconds(65)
  |> should.equal("01:05")
}

pub fn format_seconds_hh_mm_ss_test() {
  helpers_time.format_seconds(3665)
  |> should.equal("1:01:05")
}

pub fn now_working_elapsed_from_ms_adds_delta_test() {
  helpers_time.now_working_elapsed_from_ms(60, 1000, 6000)
  |> should.equal("01:05")
}
