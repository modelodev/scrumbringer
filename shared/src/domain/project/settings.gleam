//// Project settings used by card tree execution decisions.

pub opaque type HealthyPoolLimit {
  HealthyPoolLimit(Int)
}

pub type HealthyPoolLimitError {
  InvalidHealthyPoolLimit(Int)
}

pub fn healthy_pool_limit_from_int(
  value: Int,
) -> Result(HealthyPoolLimit, HealthyPoolLimitError) {
  case value > 0 {
    True -> Ok(HealthyPoolLimit(value))
    False -> Error(InvalidHealthyPoolLimit(value))
  }
}

pub fn healthy_pool_limit_unchecked(value: Int) -> HealthyPoolLimit {
  HealthyPoolLimit(value)
}

pub fn healthy_pool_limit_to_int(limit: HealthyPoolLimit) -> Int {
  let HealthyPoolLimit(value) = limit
  value
}
