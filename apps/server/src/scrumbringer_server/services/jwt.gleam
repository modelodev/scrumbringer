//// JWT (JSON Web Token) signing and verification.
////
//// Implements HS256 JWT tokens for session authentication.
//// Tokens contain user ID, org ID, role, and expiration.

import domain/org_role
import gleam/bit_array
import gleam/crypto
import gleam/dynamic/decode
import gleam/json
import gleam/result
import gleam/string
import scrumbringer_server/services/time

/// JWT payload claims.
pub type Claims {
  Claims(
    user_id: Int,
    org_id: Int,
    org_role: org_role.OrgRole,
    iat: Int,
    exp: Int,
  )
}

/// Errors that can occur during JWT operations.
pub type JwtError {
  InvalidFormat
  InvalidSignature
  InvalidJson
  MissingClaim
  UnsupportedRole
  Expired
}

/// Signs claims into a JWT string using HS256.
pub fn sign(claims: Claims, secret: BitArray) -> String {
  let header =
    json.object([
      #("alg", json.string("HS256")),
      #("typ", json.string("JWT")),
    ])

  let payload =
    json.object([
      #("sub", json.int(claims.user_id)),
      #("org_id", json.int(claims.org_id)),
      #("org_role", json.string(org_role.to_string(claims.org_role))),
      #("iat", json.int(claims.iat)),
      #("exp", json.int(claims.exp)),
    ])

  let header_b64 =
    header
    |> json.to_string
    |> fn(s) { <<s:utf8>> }
    |> bit_array.base64_url_encode(False)

  let payload_b64 =
    payload
    |> json.to_string
    |> fn(s) { <<s:utf8>> }
    |> bit_array.base64_url_encode(False)

  let signing_input = header_b64 <> "." <> payload_b64
  let signature = crypto.hmac(<<signing_input:utf8>>, crypto.Sha256, secret)
  let signature_b64 = bit_array.base64_url_encode(signature, False)

  signing_input <> "." <> signature_b64
}

/// Verifies a JWT and returns its claims if valid.
pub fn verify(token: String, secret: BitArray) -> Result(Claims, JwtError) {
  case string.split(token, ".") {
    [header_b64, payload_b64, signature_b64] -> {
      let signing_input = header_b64 <> "." <> payload_b64
      let expected =
        crypto.hmac(<<signing_input:utf8>>, crypto.Sha256, secret)
        |> bit_array.base64_url_encode(False)

      case crypto.secure_compare(<<expected:utf8>>, <<signature_b64:utf8>>) {
        False -> Error(InvalidSignature)
        True -> decode_claims(payload_b64)
      }
    }

    _ -> Error(InvalidFormat)
  }
}

fn decode_claims(payload_b64: String) -> Result(Claims, JwtError) {
  use payload_bits <- result.try(
    bit_array.base64_url_decode(payload_b64)
    |> result.replace_error(InvalidFormat),
  )

  use payload_string <- result.try(
    bit_array.to_string(payload_bits)
    |> result.replace_error(InvalidJson),
  )

  use dynamic <- result.try(
    json.parse(payload_string, decode.dynamic)
    |> result.replace_error(InvalidJson),
  )

  let decoder = {
    use user_id <- decode.field("sub", decode.int)
    use org_id <- decode.field("org_id", decode.int)
    use role_string <- decode.field("org_role", decode.string)
    use iat <- decode.field("iat", decode.int)
    use exp <- decode.field("exp", decode.int)
    decode.success(#(user_id, org_id, role_string, iat, exp))
  }

  use fields <- result.try(
    decode.run(dynamic, decoder)
    |> result.replace_error(MissingClaim),
  )

  let #(user_id, org_id, role_string, iat, exp) = fields

  use role <- result.try(
    org_role.parse(role_string)
    |> result.replace_error(UnsupportedRole),
  )

  case exp <= time.now_unix_seconds() {
    True -> Error(Expired)
    False ->
      Ok(Claims(
        user_id: user_id,
        org_id: org_id,
        org_role: role,
        iat: iat,
        exp: exp,
      ))
  }
}

/// Creates new claims with 24-hour expiration.
pub fn new_claims(
  user_id: Int,
  org_id: Int,
  org_role: org_role.OrgRole,
) -> Claims {
  let iat = time.now_unix_seconds()
  Claims(
    user_id: user_id,
    org_id: org_id,
    org_role: org_role,
    iat: iat,
    exp: iat + 86_400,
  )
}
