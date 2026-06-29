//// Dev/test atomic database operations for seeding.
////
//// ## Mission
////
//// Provide reusable, low-level SQL insert operations for seed scripts and test
//// fixtures with support for:
//// - Custom timestamps (for simulating historical data)
//// - Optional fields (active, first_login_at, etc.)
//// - All seed-relevant entities
////
//// ## Responsibilities
////
//// - Insert single records with full control over fields
//// - Return inserted IDs for chaining
//// - Handle nullable/optional fields correctly
////
//// ## Non-responsibilities
////
//// - Business logic or scenarios (see seed_builder.gleam)
//// - CLI or output (see seed.gleam)

import domain/card
import domain/org_role
import domain/project_role
import domain/task/state as task_state
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog

// =============================================================================
// Types
// =============================================================================

/// Options for inserting a user.
pub type UserInsertOptions {
  UserInsertOptions(
    org_id: Int,
    email: String,
    org_role: org_role.OrgRole,
    first_login_at: Option(String),
    created_at: Option(String),
  )
}

/// Options for inserting a task.
pub type TaskInsertOptions {
  TaskInsertOptions(
    project_id: Int,
    type_id: Int,
    title: String,
    description: String,
    priority: Int,
    execution_state: task_state.TaskExecutionState,
    created_by: Int,
    card_id: Option(Int),
    created_from_rule_id: Option(Int),
    pool_lifetime_s: Int,
    due_date: Option(String),
    created_at: Option(String),
    last_entered_pool_at: Option(String),
  )
}

/// Options for inserting a card.
pub type CardInsertOptions {
  CardInsertOptions(
    project_id: Int,
    title: String,
    description: String,
    color: Option(card.CardColor),
    created_by: Int,
    created_at: Option(String),
  )
}

/// Options for inserting a work session.
pub type WorkSessionInsertOptions {
  WorkSessionInsertOptions(
    user_id: Int,
    task_id: Int,
    started_at: Option(String),
    last_heartbeat_at: Option(String),
    ended_at: Option(String),
    ended_reason: Option(String),
    created_at: Option(String),
  )
}

/// Options for inserting a historical automation rule execution.
pub type RuleExecutionInsertOptions {
  RuleExecutionInsertOptions(
    rule_id: Int,
    event_key: String,
    task_id: Option(Int),
    card_id: Option(Int),
    outcome: String,
    suppression_reason: Option(String),
    user_id: Option(Int),
    template_id: Option(Int),
    template_version: Option(Int),
    created_task_id: Option(Int),
    created_at: Option(String),
  )
}

// =============================================================================
// Constants
// =============================================================================

/// Fixed password hash for "passwordpassword" (argon2).
const default_password_hash = "$argon2id$v=19$m=19456,t=2,p=1$WFdS11YsLLialYVbuHIxhg$N3DNEU4tlErd/6a8eP5VZEwvpN2UgLWgET+mS41iAYI"

// =============================================================================
// Timestamp Helpers
// =============================================================================

fn is_sql_timestamp(value: String) -> Bool {
  string.starts_with(value, "NOW()")
  || string.starts_with(value, "CURRENT_TIMESTAMP")
}

fn timestamp_value(
  value: String,
  param_idx: Int,
) -> #(String, Option(String), Int) {
  case is_sql_timestamp(value) {
    True -> #(value, None, param_idx)
    False -> #(
      "$" <> int.to_string(param_idx) <> "::timestamptz",
      Some(value),
      param_idx + 1,
    )
  }
}

fn append_optional_timestamp(
  cols: String,
  vals: String,
  param_idx: Int,
  column: String,
  value: Option(String),
  params: List(String),
) -> #(String, String, Int, List(String)) {
  case value {
    None -> #(cols, vals, param_idx, params)
    Some(ts) -> {
      let #(val_expr, param, next_idx) = timestamp_value(ts, param_idx)
      let next_cols = cols <> ", " <> column
      let next_vals = vals <> ", " <> val_expr
      let next_params = case param {
        Some(p) -> list.append(params, [p])
        None -> params
      }
      #(next_cols, next_vals, next_idx, next_params)
    }
  }
}

fn is_sql_date(value: String) -> Bool {
  string.starts_with(value, "CURRENT_DATE")
}

fn date_value(value: String, param_idx: Int) -> #(String, Option(String), Int) {
  case is_sql_date(value) {
    True -> #(value, None, param_idx)
    False -> #(
      "$" <> int.to_string(param_idx) <> "::date",
      Some(value),
      param_idx + 1,
    )
  }
}

fn append_optional_date(
  cols: String,
  vals: String,
  param_idx: Int,
  column: String,
  value: Option(String),
  params: List(String),
) -> #(String, String, Int, List(String)) {
  case value {
    None -> #(cols, vals, param_idx, params)
    Some(date) -> {
      let #(val_expr, param, next_idx) = date_value(date, param_idx)
      let next_cols = cols <> ", " <> column
      let next_vals = vals <> ", " <> val_expr
      let next_params = case param {
        Some(p) -> list.append(params, [p])
        None -> params
      }
      #(next_cols, next_vals, next_idx, next_params)
    }
  }
}

fn apply_timestamp_params(
  query: pog.Query(a),
  params: List(String),
) -> pog.Query(a) {
  list.fold(params, query, fn(query, value) {
    pog.parameter(query, pog.text(value))
  })
}

// =============================================================================
// User Operations
// =============================================================================

/// Insert or update a user with full control over fields.
pub fn insert_user(
  db: pog.Connection,
  opts: UserInsertOptions,
) -> Result(Int, String) {
  let base_cols = "email, password_hash, org_id, org_role"
  let base_vals = "$1, $2, $3, $4"
  let base_idx = 5

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "first_login_at",
      opts.first_login_at,
      [],
    )

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "created_at",
      opts.created_at,
      params,
    )

  let sql = "INSERT INTO users (" <> cols <> ") VALUES (" <> vals <> ")
     ON CONFLICT (email) DO UPDATE
     SET password_hash = EXCLUDED.password_hash,
         org_id = EXCLUDED.org_id,
         org_role = EXCLUDED.org_role
     RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.text(opts.email))
    |> pog.parameter(pog.text(default_password_hash))
    |> pog.parameter(pog.int(opts.org_id))
    |> pog.parameter(pog.text(org_role.to_string(opts.org_role)))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) {
    "insert_user " <> opts.email <> ": " <> string.inspect(e)
  })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID for " <> opts.email)
    }
  })
}

/// Simple user insert with defaults.
pub fn insert_user_simple(
  db: pog.Connection,
  org_id: Int,
  email: String,
  org_role: org_role.OrgRole,
) -> Result(Int, String) {
  insert_user(
    db,
    UserInsertOptions(
      org_id: org_id,
      email: email,
      org_role: org_role,
      first_login_at: None,
      created_at: None,
    ),
  )
}

// =============================================================================
// Project Operations
// =============================================================================

/// Insert an organization.
pub fn insert_organization(
  db: pog.Connection,
  name: String,
) -> Result(Int, String) {
  pog.query("INSERT INTO organizations (name) VALUES ($1) RETURNING id")
  |> pog.parameter(pog.text(name))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_organization: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Insert a project with optional timestamp.
pub fn insert_project(
  db: pog.Connection,
  org_id: Int,
  name: String,
  created_at: Option(String),
) -> Result(Int, String) {
  let base_cols = "org_id, name"
  let base_vals = "$1, $2"
  let base_idx = 3

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "created_at",
      created_at,
      [],
    )

  let sql =
    "INSERT INTO projects (" <> cols <> ") VALUES (" <> vals <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.text(name))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_project: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Find a project id by organization and name.
pub fn project_id_by_name(
  db: pog.Connection,
  org_id: Int,
  name: String,
) -> Result(Int, String) {
  pog.query("SELECT id FROM projects WHERE org_id = $1 AND name = $2")
  |> pog.parameter(pog.int(org_id))
  |> pog.parameter(pog.text(name))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "project_id_by_name: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No project named " <> name)
    }
  })
}

/// Insert or update seed-specific project settings.
pub fn upsert_project_settings(
  db: pog.Connection,
  project_id: Int,
  healthy_pool_limit: Int,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO project_settings (project_id, healthy_pool_limit) VALUES ($1, $2) ON CONFLICT (project_id) DO UPDATE SET healthy_pool_limit = EXCLUDED.healthy_pool_limit",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(healthy_pool_limit))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "upsert_project_settings: " <> string.inspect(e) })
}

/// Insert a project member.
pub fn insert_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: project_role.ProjectRole,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO project_members (project_id, user_id, role)
     VALUES ($1, $2, $3)
     ON CONFLICT (project_id, user_id)
     DO UPDATE SET role = EXCLUDED.role",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.text(project_role.to_string(role)))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_member: " <> string.inspect(e) })
}

// =============================================================================
// Capability Operations
// =============================================================================

/// Insert a capability.
pub fn insert_capability(
  db: pog.Connection,
  project_id: Int,
  name: String,
) -> Result(Int, String) {
  pog.query(
    "INSERT INTO capabilities (project_id, name) VALUES ($1, $2) RETURNING id",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.text(name))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_capability: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

// =============================================================================
// Task Type Operations
// =============================================================================

/// Insert a task type.
pub fn insert_task_type(
  db: pog.Connection,
  project_id: Int,
  name: String,
  icon: String,
) -> Result(Int, String) {
  pog.query(
    "INSERT INTO task_types (project_id, name, icon) VALUES ($1, $2, $3) RETURNING id",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.text(icon))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_task_type: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Insert a task type with an optional capability.
pub fn insert_task_type_with_capability(
  db: pog.Connection,
  project_id: Int,
  name: String,
  icon: String,
  capability_id: Option(Int),
) -> Result(Int, String) {
  let cap_val = case capability_id {
    Some(id) -> id
    None -> 0
  }

  pog.query(
    "INSERT INTO task_types (project_id, name, icon, capability_id) VALUES ($1, $2, $3, NULLIF($4, 0)) RETURNING id",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.text(name))
  |> pog.parameter(pog.text(icon))
  |> pog.parameter(pog.int(cap_val))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) {
    "insert_task_type_with_capability: " <> string.inspect(e)
  })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

// =============================================================================
// Task Operations
// =============================================================================

/// Insert a task with full control over fields.
pub fn insert_task(
  db: pog.Connection,
  opts: TaskInsertOptions,
) -> Result(Int, String) {
  let execution_state = task_execution_state(opts.execution_state)
  let claimed_mode = task_claimed_mode(opts.execution_state)
  let claimed_by = task_state.claimed_by(opts.execution_state)
  let claimed_at = task_state.claimed_at(opts.execution_state)
  let closed_at = task_closed_at(opts.execution_state)
  let closed_by = task_closed_by(opts.execution_state)
  let closed_reason = task_closed_reason(opts.execution_state)

  let base_cols =
    "project_id, type_id, title, description, priority, execution_state, claimed_mode, created_by, claimed_by, card_id, created_from_rule_id, pool_lifetime_s, closed_by, closed_reason"
  let base_vals = "$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14"
  let base_idx = 15

  let #(cols, vals, idx, params) =
    append_optional_date(
      base_cols,
      base_vals,
      base_idx,
      "due_date",
      opts.due_date,
      [],
    )

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "created_at",
      opts.created_at,
      params,
    )

  let #(cols, vals, idx, params) =
    append_optional_timestamp(cols, vals, idx, "claimed_at", claimed_at, params)

  let #(cols, vals, idx, params) =
    append_optional_timestamp(cols, vals, idx, "closed_at", closed_at, params)

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "last_entered_pool_at",
      opts.last_entered_pool_at,
      params,
    )

  let sql =
    "INSERT INTO tasks (" <> cols <> ") VALUES (" <> vals <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.project_id))
    |> pog.parameter(pog.int(opts.type_id))
    |> pog.parameter(pog.text(opts.title))
    |> pog.parameter(pog.text(opts.description))
    |> pog.parameter(pog.int(opts.priority))
    |> pog.parameter(pog.text(execution_state))
    |> pog.parameter(pog.nullable(pog.text, claimed_mode))
    |> pog.parameter(pog.int(opts.created_by))
    |> pog.parameter(pog.nullable(pog.int, claimed_by))
    |> pog.parameter(pog.nullable(pog.int, opts.card_id))
    |> pog.parameter(pog.nullable(pog.int, opts.created_from_rule_id))
    |> pog.parameter(pog.int(opts.pool_lifetime_s))
    |> pog.parameter(pog.nullable(pog.int, closed_by))
    |> pog.parameter(pog.nullable(pog.text, closed_reason))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_task: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Simple task insert with defaults.
pub fn insert_task_simple(
  db: pog.Connection,
  project_id: Int,
  type_id: Int,
  title: String,
  created_by: Int,
  card_id: Option(Int),
) -> Result(Int, String) {
  insert_task(
    db,
    TaskInsertOptions(
      project_id: project_id,
      type_id: type_id,
      title: title,
      description: "Seeded",
      priority: 3,
      execution_state: task_state.Available,
      created_by: created_by,
      card_id: card_id,
      created_from_rule_id: None,
      pool_lifetime_s: 0,
      due_date: None,
      created_at: None,
      last_entered_pool_at: None,
    ),
  )
}

fn task_execution_state(state: task_state.TaskExecutionState) -> String {
  case state {
    task_state.Available -> "available"
    task_state.Claimed(..) -> "claimed"
    task_state.Closed(..) -> "closed"
  }
}

fn task_claimed_mode(state: task_state.TaskExecutionState) -> Option(String) {
  case state {
    task_state.Claimed(mode: mode, ..) -> Some(claim_mode_to_string(mode))
    _ -> None
  }
}

fn task_closed_at(state: task_state.TaskExecutionState) -> Option(String) {
  case state {
    task_state.Closed(closed_at: closed_at, ..) -> Some(closed_at)
    _ -> None
  }
}

fn task_closed_by(state: task_state.TaskExecutionState) -> Option(Int) {
  case state {
    task_state.Closed(closed_by: closed_by, ..) -> Some(closed_by)
    _ -> None
  }
}

fn task_closed_reason(state: task_state.TaskExecutionState) -> Option(String) {
  case state {
    task_state.Closed(reason: reason, ..) ->
      Some(closed_reason_to_string(reason))
    _ -> None
  }
}

fn claim_mode_to_string(mode: task_state.TaskClaimMode) -> String {
  case mode {
    task_state.Taken -> "taken"
    task_state.Ongoing -> "ongoing"
  }
}

fn closed_reason_to_string(reason: task_state.TaskClosedReason) -> String {
  case reason {
    task_state.ClosedByClaimant -> "done"
    task_state.ManuallyClosed -> "manually_closed"
    task_state.ClosedByAncestor -> "closed_by_ancestor"
  }
}

// =============================================================================
// Card Operations
// =============================================================================

/// Insert a card with full control over fields.
pub fn insert_card(
  db: pog.Connection,
  opts: CardInsertOptions,
) -> Result(Int, String) {
  let base_cols = "project_id, title, description, color, created_by"
  let base_vals = "$1, $2, $3, $4, $5"
  let base_idx = 6

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "created_at",
      opts.created_at,
      [],
    )

  let sql =
    "INSERT INTO cards (" <> cols <> ") VALUES (" <> vals <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.project_id))
    |> pog.parameter(pog.text(opts.title))
    |> pog.parameter(pog.text(opts.description))
    |> pog.parameter(pog.nullable(
      pog.text,
      option.map(opts.color, card.color_to_string),
    ))
    |> pog.parameter(pog.int(opts.created_by))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_card: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Simple card insert with defaults.
pub fn insert_card_simple(
  db: pog.Connection,
  project_id: Int,
  title: String,
  color: Option(card.CardColor),
  created_by: Int,
) -> Result(Int, String) {
  insert_card(
    db,
    CardInsertOptions(
      project_id: project_id,
      title: title,
      description: "Seeded",
      color: color,
      created_by: created_by,
      created_at: None,
    ),
  )
}

/// Mark a seed card as active so operational views can show its tasks.
pub fn activate_card_for_seed(
  db: pog.Connection,
  card_id: Int,
) -> Result(Nil, String) {
  pog.query(
    "UPDATE cards
     SET execution_state = 'active',
         activated_at = coalesce(activated_at, created_at, now()),
         activated_by = coalesce(activated_by, created_by),
         activation_source = coalesce(activation_source, 'direct_activation')
     WHERE id = $1",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "activate_card_for_seed: " <> string.inspect(e) })
}

/// Assign a specific card to a parent card.
pub fn assign_card_to_parent_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Int,
) -> Result(Nil, String) {
  use _ <- result.try(require_parent_card_accepts_cards(db, parent_card_id))

  pog.query(
    "UPDATE cards
     SET parent_card_id = $2
     WHERE id = $1",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.int(parent_card_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "assign_card_to_parent_card: " <> string.inspect(e)
  })
}

// =============================================================================
// Audit Event Operations
// =============================================================================

fn insert_audit_event_raw(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  actor_user_id: Int,
  event_type: String,
  created_at: Option(String),
) -> Result(Nil, String) {
  let base_cols = "org_id, project_id, task_id, actor_user_id, event_type"
  let base_vals = "$1, $2, $3, $4, $5"
  let base_idx = 6

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "created_at",
      created_at,
      [],
    )

  let sql = "INSERT INTO audit_events (" <> cols <> ") VALUES (" <> vals <> ")"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(org_id))
    |> pog.parameter(pog.int(project_id))
    |> pog.parameter(pog.int(task_id))
    |> pog.parameter(pog.int(actor_user_id))
    |> pog.parameter(pog.text(event_type))

  apply_timestamp_params(base_query, params)
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_audit_event: " <> string.inspect(e) })
}

/// Simple audit event insert.
pub fn insert_audit_event_simple(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  user_id: Int,
  event_type: String,
) -> Result(Nil, String) {
  insert_audit_event_raw(
    db,
    org_id,
    project_id,
    task_id,
    user_id,
    event_type,
    None,
  )
}

// =============================================================================
// Project Member Capabilities
// =============================================================================

/// Insert a project member capability assignment.
pub fn insert_project_member_capability(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  capability_id: Int,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO project_member_capabilities (project_id, user_id, capability_id)
     VALUES ($1, $2, $3)
     ON CONFLICT DO NOTHING",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(capability_id))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "insert_project_member_capability: " <> string.inspect(e)
  })
}

// =============================================================================
// Work Session Operations
// =============================================================================

/// Insert a work session entry.
pub fn insert_work_session_entry(
  db: pog.Connection,
  opts: WorkSessionInsertOptions,
) -> Result(Nil, String) {
  let base_cols = "user_id, task_id, ended_reason"
  let base_vals = "$1, $2, $3"
  let base_idx = 4

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "started_at",
      opts.started_at,
      [],
    )

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "last_heartbeat_at",
      opts.last_heartbeat_at,
      params,
    )

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "ended_at",
      opts.ended_at,
      params,
    )

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "created_at",
      opts.created_at,
      params,
    )

  let sql =
    "INSERT INTO user_task_work_session ("
    <> cols
    <> ") VALUES ("
    <> vals
    <> ")"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.user_id))
    |> pog.parameter(pog.int(opts.task_id))
    |> pog.parameter(pog.nullable(pog.text, opts.ended_reason))

  apply_timestamp_params(base_query, params)
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "insert_work_session_entry: " <> string.inspect(e)
  })
}

/// Insert accumulated work time for a user on a task.
pub fn insert_work_session(
  db: pog.Connection,
  user_id: Int,
  task_id: Int,
  accumulated_s: Int,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO user_task_work_total (user_id, task_id, accumulated_s)
     VALUES ($1, $2, $3)
     ON CONFLICT (user_id, task_id) DO UPDATE SET accumulated_s = $3, updated_at = NOW()",
  )
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(task_id))
  |> pog.parameter(pog.int(accumulated_s))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_work_session: " <> string.inspect(e) })
}

// =============================================================================
// Rule Execution Operations
// =============================================================================

/// Insert one automation execution row for seed history and metrics screens.
pub fn insert_rule_execution(
  db: pog.Connection,
  opts: RuleExecutionInsertOptions,
) -> Result(Int, String) {
  let base_cols =
    "rule_id, event_key, task_id, card_id, outcome, suppression_reason, user_id, template_id, template_version, created_task_id"
  let base_vals = "$1, $2, $3, $4, $5, $6, $7, $8, $9, $10"
  let base_idx = 11

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "created_at",
      opts.created_at,
      [],
    )

  let sql =
    "INSERT INTO rule_executions ("
    <> cols
    <> ") VALUES ("
    <> vals
    <> ") ON CONFLICT DO NOTHING RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.rule_id))
    |> pog.parameter(pog.text(opts.event_key))
    |> pog.parameter(pog.nullable(pog.int, opts.task_id))
    |> pog.parameter(pog.nullable(pog.int, opts.card_id))
    |> pog.parameter(pog.text(opts.outcome))
    |> pog.parameter(pog.nullable(pog.text, opts.suppression_reason))
    |> pog.parameter(pog.nullable(pog.int, opts.user_id))
    |> pog.parameter(pog.nullable(pog.int, opts.template_id))
    |> pog.parameter(pog.nullable(pog.int, opts.template_version))
    |> pog.parameter(pog.nullable(pog.int, opts.created_task_id))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_rule_execution: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      [] -> Error("Duplicate rule execution event " <> opts.event_key)
      _ -> Error("No ID")
    }
  })
}

/// Reset all dev seed data and recreate the minimum workspace seed expects.
pub fn reset_seed_database(db: pog.Connection) -> Result(#(Int, Int), String) {
  use _ <- result.try(
    pog.query("TRUNCATE organizations RESTART IDENTITY CASCADE")
    |> pog.execute(db)
    |> result.map(fn(_) { Nil })
    |> result.map_error(fn(e) { "reset_seed_database: " <> string.inspect(e) }),
  )

  use org_id <- result.try(insert_organization(db, "Acme"))
  use admin_id <- result.try(insert_user_simple(
    db,
    org_id,
    "admin@example.com",
    org_role.Admin,
  ))
  use default_project_id <- result.try(insert_project(
    db,
    org_id,
    "Default",
    None,
  ))
  use _ <- result.try(insert_member(
    db,
    default_project_id,
    admin_id,
    project_role.Manager,
  ))

  Ok(#(org_id, admin_id))
}

// =============================================================================
// Internal Helpers
// =============================================================================

fn int_decoder() {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}

fn bool_decoder() {
  use value <- decode.field(0, decode.bool)
  decode.success(value)
}

fn require_parent_card_accepts_cards(
  db: pog.Connection,
  parent_card_id: Int,
) -> Result(Nil, String) {
  require_parent_child_kind(
    db,
    parent_card_id,
    "SELECT NOT EXISTS (
       SELECT 1 FROM tasks WHERE card_id = $1
     )",
    "require_parent_card_accepts_cards",
    "parent card already contains tasks",
  )
}

fn require_parent_child_kind(
  db: pog.Connection,
  parent_card_id: Int,
  query: String,
  operation: String,
  rejection_message: String,
) -> Result(Nil, String) {
  pog.query(query)
  |> pog.parameter(pog.int(parent_card_id))
  |> pog.returning(bool_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { operation <> ": " <> string.inspect(e) })
  |> result.try(fn(result) {
    case result.rows {
      [True] -> Ok(Nil)
      [False] -> Error(rejection_message)
      _ -> Error(operation <> " returned no row")
    }
  })
}
