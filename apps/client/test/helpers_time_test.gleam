import scrumbringer_client/helpers/time as helpers_time

pub fn format_seconds_mm_ss_test() {
  let assert "01:05" = helpers_time.format_seconds(65)
}

pub fn format_seconds_hh_mm_ss_test() {
  let assert "1:01:05" = helpers_time.format_seconds(3665)
}

pub fn now_working_elapsed_from_ms_adds_delta_test() {
  let assert "01:05" = helpers_time.now_working_elapsed_from_ms(60, 1000, 6000)
}
