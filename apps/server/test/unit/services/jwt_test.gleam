import domain/org_role
import gleam/bit_array
import gleam/crypto
import gleam/json
import gleeunit/should
import scrumbringer_server/services/jwt
import scrumbringer_server/services/time

const secret_a = <<"secret-a":utf8>>

const secret_b = <<"secret-b":utf8>>

fn base64_json(value: json.Json) -> String {
  value
  |> json.to_string
  |> fn(s) { <<s:utf8>> }
  |> bit_array.base64_url_encode(False)
}

fn sign_with_payload(payload: json.Json, secret: BitArray) -> String {
  let header =
    json.object([
      #("alg", json.string("HS256")),
      #("typ", json.string("JWT")),
    ])

  let header_b64 = base64_json(header)
  let payload_b64 = base64_json(payload)
  let signing_input = header_b64 <> "." <> payload_b64
  let signature = crypto.hmac(<<signing_input:utf8>>, crypto.Sha256, secret)
  let signature_b64 = bit_array.base64_url_encode(signature, False)
  signing_input <> "." <> signature_b64
}

fn sign_with_payload_string(payload: String, secret: BitArray) -> String {
  let header =
    json.object([
      #("alg", json.string("HS256")),
      #("typ", json.string("JWT")),
    ])

  let header_b64 = base64_json(header)
  let payload_b64 =
    payload
    |> fn(s) { <<s:utf8>> }
    |> bit_array.base64_url_encode(False)
  let signing_input = header_b64 <> "." <> payload_b64
  let signature = crypto.hmac(<<signing_input:utf8>>, crypto.Sha256, secret)
  let signature_b64 = bit_array.base64_url_encode(signature, False)
  signing_input <> "." <> signature_b64
}

pub fn verify_invalid_format_for_two_segments_test() {
  case jwt.verify("abc.def", secret_a) {
    Error(jwt.InvalidFormat) -> Nil
    _ -> should.fail()
  }
}

pub fn verify_invalid_signature_test() {
  let now = time.now_unix_seconds()
  let claims =
    jwt.Claims(
      user_id: 1,
      org_id: 1,
      org_role: org_role.Admin,
      iat: now - 10,
      exp: now + 100,
    )

  let token = jwt.sign(claims, secret_a)

  case jwt.verify(token, secret_b) {
    Error(jwt.InvalidSignature) -> Nil
    _ -> should.fail()
  }
}

pub fn verify_invalid_json_payload_test() {
  let token = sign_with_payload_string("not json", secret_a)

  case jwt.verify(token, secret_a) {
    Error(jwt.InvalidJson) -> Nil
    _ -> should.fail()
  }
}

pub fn verify_missing_claim_test() {
  let payload =
    json.object([
      #("sub", json.int(1)),
      #("org_id", json.int(1)),
      #("org_role", json.string("admin")),
      #("iat", json.int(10)),
      // missing exp
    ])

  let token = sign_with_payload(payload, secret_a)

  case jwt.verify(token, secret_a) {
    Error(jwt.MissingClaim) -> Nil
    _ -> should.fail()
  }
}

pub fn verify_unsupported_role_test() {
  let payload =
    json.object([
      #("sub", json.int(1)),
      #("org_id", json.int(1)),
      #("org_role", json.string("superadmin")),
      #("iat", json.int(10)),
      #("exp", json.int(9_999_999)),
    ])

  let token = sign_with_payload(payload, secret_a)

  case jwt.verify(token, secret_a) {
    Error(jwt.UnsupportedRole) -> Nil
    _ -> should.fail()
  }
}

pub fn verify_expired_token_test() {
  let now = time.now_unix_seconds()
  let claims =
    jwt.Claims(
      user_id: 1,
      org_id: 1,
      org_role: org_role.Admin,
      iat: now - 100,
      exp: now - 10,
    )

  let token = jwt.sign(claims, secret_a)

  case jwt.verify(token, secret_a) {
    Error(jwt.Expired) -> Nil
    _ -> should.fail()
  }
}
