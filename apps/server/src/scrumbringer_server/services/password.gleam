import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/result

pub type PasswordError {
  HashingFailed(reason: Dynamic)
  VerificationFailed(reason: Dynamic)
  HashNotUtf8
}

pub fn hash(password: String) -> Result(String, PasswordError) {
  let password = <<password:utf8>>

  argon2_hash(password)
  |> result.map_error(HashingFailed)
  |> result.try(fn(hash) {
    bit_array.to_string(hash)
    |> result.replace_error(HashNotUtf8)
  })
}

pub fn verify(password: String, hash: String) -> Result(Bool, PasswordError) {
  let password = <<password:utf8>>
  let hash = <<hash:utf8>>

  argon2_verify(password, hash)
  |> result.map_error(VerificationFailed)
}

@external(erlang, "argon2", "hash")
fn argon2_hash(password: BitArray) -> Result(BitArray, Dynamic)

@external(erlang, "argon2", "verify")
fn argon2_verify(password: BitArray, hash: BitArray) -> Result(Bool, Dynamic)
