//// Password hashing and verification using Argon2.
////
//// Provides secure password hashing for user authentication.
//// Uses the Argon2 algorithm via Erlang NIF bindings.

import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/result

/// Errors that can occur during password operations.
pub type PasswordError {
  HashingFailed(reason: Dynamic)
  VerificationFailed(reason: Dynamic)
  HashNotUtf8
}

/// Hashes a password using Argon2.
///
/// ## Example
/// ```gleam
/// case password.hash("user_password") {
///   Ok(hash) -> store_hash(hash)
///   Error(HashingFailed(_)) -> Error(InternalError)
/// }
/// ```
pub fn hash(password: String) -> Result(String, PasswordError) {
  let password = <<password:utf8>>

  argon2_hash(password)
  |> result.map_error(HashingFailed)
  |> result.try(fn(hash) {
    bit_array.to_string(hash)
    |> result.replace_error(HashNotUtf8)
  })
}

/// Verifies a password against a stored hash.
///
/// ## Example
/// ```gleam
/// case password.verify(input_password, stored_hash) {
///   Ok(True) -> Ok(Authenticated)
///   Ok(False) -> Error(InvalidCredentials)
///   Error(_) -> Error(InternalError)
/// }
/// ```
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
