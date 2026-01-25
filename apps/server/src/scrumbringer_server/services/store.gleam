//// In-memory store actor for auth state (test-only helper).
////
//// Provides an OTP actor-based store for user registration, login,
//// and invite handling without requiring a real database.
//// State is volatile and not supervised; do not use in production.

import gleam/erlang/process
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/result
import scrumbringer_server/services/auth_logic
import scrumbringer_server/services/store_state as ss

/// Opaque store handle wrapping an actor subject.
pub opaque type Store {
  Store(subject: process.Subject(Message))
}

type Message {
  Register(
    email: String,
    password: String,
    org_name: Option(String),
    invite_code: Option(String),
    now_iso: String,
    now_unix: Int,
    reply_with: process.Subject(Result(ss.StoredUser, auth_logic.AuthError)),
  )

  Login(
    email: String,
    password: String,
    reply_with: process.Subject(Result(ss.StoredUser, auth_logic.AuthError)),
  )

  GetUser(user_id: Int, reply_with: process.Subject(Result(ss.StoredUser, Nil)))

  InsertInvite(invite: ss.OrgInvite, reply_with: process.Subject(Nil))

  DebugSnapshot(reply_with: process.Subject(ss.State))
}

/// Starts a new store actor with empty initial state.
///
/// ## Example
///
/// ```gleam
/// let store = start()
/// ```
pub fn start() -> Store {
  let assert Ok(started) =
    actor.new(ss.initial())
    |> actor.on_message(handle_message)
    |> actor.start

  Store(started.data)
}

/// Registers a new user in the store.
///
/// ## Example
///
/// ```gleam
/// register(store, "user@example.com", "password123", None, None, "2024-01-01T00:00:00Z", 1704067200)
/// ```
pub fn register(
  store: Store,
  email: String,
  password: String,
  org_name: Option(String),
  invite_code: Option(String),
  now_iso: String,
  now_unix: Int,
) -> Result(ss.StoredUser, auth_logic.AuthError) {
  actor.call(store.subject, waiting: 5000, sending: fn(reply_with) {
    Register(
      email: email,
      password: password,
      org_name: org_name,
      invite_code: invite_code,
      now_iso: now_iso,
      now_unix: now_unix,
      reply_with: reply_with,
    )
  })
}

/// Authenticates a user by email and password.
///
/// ## Example
///
/// ```gleam
/// login(store, "user@example.com", "password123")
/// ```
pub fn login(
  store: Store,
  email: String,
  password: String,
) -> Result(ss.StoredUser, auth_logic.AuthError) {
  actor.call(store.subject, waiting: 5000, sending: fn(reply_with) {
    Login(email: email, password: password, reply_with: reply_with)
  })
}

/// Retrieves a user by ID from the store.
pub fn get_user(store: Store, user_id: Int) -> Result(ss.StoredUser, Nil) {
  actor.call(store.subject, waiting: 5000, sending: fn(reply_with) {
    GetUser(user_id: user_id, reply_with: reply_with)
  })
}

/// Inserts an organization invite into the store.
pub fn insert_invite(store: Store, invite: ss.OrgInvite) -> Nil {
  actor.call(store.subject, waiting: 5000, sending: fn(reply_with) {
    InsertInvite(invite: invite, reply_with: reply_with)
  })
}

/// Returns a snapshot of the current store state (for debugging).
pub fn debug_snapshot(store: Store) -> ss.State {
  actor.call(store.subject, waiting: 5000, sending: fn(reply_with) {
    DebugSnapshot(reply_with: reply_with)
  })
}

fn handle_message(
  state: ss.State,
  message: Message,
) -> actor.Next(ss.State, Message) {
  case message {
    Register(
      email,
      password,
      org_name,
      invite_code,
      now_iso,
      now_unix,
      reply_with,
    ) -> {
      let register_result =
        auth_logic.register(
          state,
          email,
          password,
          org_name,
          invite_code,
          now_iso,
          now_unix,
        )

      let reply_value = register_result |> result.map(fn(x) { x.1 })

      let next_state = case register_result {
        Ok(#(new_state, _)) -> new_state
        Error(_) -> state
      }

      process.send(reply_with, reply_value)
      actor.continue(next_state)
    }

    Login(email, password, reply_with) -> {
      process.send(reply_with, auth_logic.login(state, email, password))
      actor.continue(state)
    }

    GetUser(user_id, reply_with) -> {
      process.send(reply_with, auth_logic.get_user(state, user_id))
      actor.continue(state)
    }

    InsertInvite(invite, reply_with) -> {
      process.send(reply_with, Nil)
      actor.continue(auth_logic.insert_invite(state, invite))
    }

    DebugSnapshot(reply_with) -> {
      process.send(reply_with, state)
      actor.continue(state)
    }
  }
}
