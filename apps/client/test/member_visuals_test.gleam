import scrumbringer_client/member_visuals
import support/assertions.{assert_equal}

pub fn priority_to_px_mapping_test() {
  member_visuals.priority_to_px(1) |> assert_equal(64)
  member_visuals.priority_to_px(2) |> assert_equal(80)
  member_visuals.priority_to_px(3) |> assert_equal(96)
  member_visuals.priority_to_px(4) |> assert_equal(112)
  member_visuals.priority_to_px(5) |> assert_equal(128)
  member_visuals.priority_to_px(0) |> assert_equal(96)
}

pub fn decay_factor_clamps_and_scales_test() {
  member_visuals.decay_factor_from_age_days(-1) |> assert_equal(0.0)
  member_visuals.decay_factor_from_age_days(0) |> assert_equal(0.0)
  member_visuals.decay_factor_from_age_days(15) |> assert_equal(0.5)
  member_visuals.decay_factor_from_age_days(30) |> assert_equal(1.0)
  member_visuals.decay_factor_from_age_days(31) |> assert_equal(1.0)
}
