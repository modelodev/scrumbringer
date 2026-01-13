import gleam/int

pub fn priority_to_px(priority: Int) -> Int {
  case priority {
    1 -> 64
    2 -> 80
    3 -> 96
    4 -> 112
    5 -> 128
    _ -> 96
  }
}

pub fn decay_factor_from_age_days(age_days: Int) -> Float {
  let clamped = int.min(int.max(age_days, 0), 30)
  clamped |> int.to_float |> fn(v) { v /. 30.0 }
}
