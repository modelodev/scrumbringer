import gleeunit/should
import scrumbringer_client/member_visuals

pub fn priority_to_px_mapping_test() {
  member_visuals.priority_to_px(1) |> should.equal(64)
  member_visuals.priority_to_px(2) |> should.equal(80)
  member_visuals.priority_to_px(3) |> should.equal(96)
  member_visuals.priority_to_px(4) |> should.equal(112)
  member_visuals.priority_to_px(5) |> should.equal(128)
  member_visuals.priority_to_px(0) |> should.equal(96)
}

pub fn decay_factor_clamps_and_scales_test() {
  member_visuals.decay_factor_from_age_days(-1) |> should.equal(0.0)
  member_visuals.decay_factor_from_age_days(0) |> should.equal(0.0)
  member_visuals.decay_factor_from_age_days(15) |> should.equal(0.5)
  member_visuals.decay_factor_from_age_days(30) |> should.equal(1.0)
  member_visuals.decay_factor_from_age_days(31) |> should.equal(1.0)
}
