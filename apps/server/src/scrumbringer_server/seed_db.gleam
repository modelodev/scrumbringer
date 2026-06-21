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
import domain/task_status
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog
import scrumbringer_server/use_case/audit_events_db

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
    status: task_status.TaskPhase,
    created_by: Int,
    claimed_by: Option(Int),
    card_id: Option(Int),
    created_from_rule_id: Option(Int),
    pool_lifetime_s: Int,
    created_at: Option(String),
    claimed_at: Option(String),
    completed_at: Option(String),
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

/// Options for inserting a root hierarchy card.
pub type RootCardInsertOptions {
  RootCardInsertOptions(
    project_id: Int,
    name: String,
    description: Option(String),
    state: card.CardPhase,
    created_by: Int,
    created_at: Option(String),
    activated_at: Option(String),
    completed_at: Option(String),
  )
}

/// Options for inserting a workflow.
pub type WorkflowInsertOptions {
  WorkflowInsertOptions(
    org_id: Int,
    project_id: Int,
    name: String,
    description: Option(String),
    active: Bool,
    created_by: Int,
    created_at: Option(String),
  )
}

/// Options for inserting a rule.
pub type RuleInsertOptions {
  RuleInsertOptions(
    workflow_id: Int,
    name: String,
    goal: Option(String),
    resource_type: String,
    task_type_id: Option(Int),
    to_state: String,
    active: Bool,
    created_at: Option(String),
  )
}

/// Options for inserting a task template.
pub type TemplateInsertOptions {
  TemplateInsertOptions(
    org_id: Int,
    project_id: Int,
    type_id: Int,
    name: String,
    description: String,
    priority: Int,
    created_by: Int,
    created_at: Option(String),
  )
}

/// Options for inserting a task event.
pub type TaskEventInsertOptions {
  TaskEventInsertOptions(
    org_id: Int,
    project_id: Int,
    task_id: Int,
    actor_user_id: Int,
    event_type: audit_events_db.TaskEventType,
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

/// Insert a project member.
pub fn insert_member(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
  role: project_role.ProjectRole,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO project_members (project_id, user_id, role) VALUES ($1, $2, $3)",
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
  let execution_state = task_execution_state(opts.status)
  let claimed_mode = task_claimed_mode(opts.status)
  let claimed_by = task_claimed_by(opts.status, opts.claimed_by)
  let claimed_at = task_claimed_at(opts.status, opts.claimed_at)
  let closed_at = task_closed_at(opts.status, opts.completed_at)
  let closed_by = task_closed_by(opts.status, opts.claimed_by, opts.created_by)
  let closed_reason = task_closed_reason(opts.status)

  let base_cols =
    "project_id, type_id, title, description, priority, execution_state, claimed_mode, created_by, claimed_by, card_id, created_from_rule_id, pool_lifetime_s, closed_by, closed_reason"
  let base_vals = "$1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14"
  let base_idx = 15

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "created_at",
      opts.created_at,
      [],
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
      status: task_status.Available,
      created_by: created_by,
      claimed_by: None,
      card_id: card_id,
      created_from_rule_id: None,
      pool_lifetime_s: 0,
      created_at: None,
      claimed_at: None,
      completed_at: None,
      last_entered_pool_at: None,
    ),
  )
}

/// Update a task's status.
pub fn update_task_status(
  db: pog.Connection,
  task_id: Int,
  status: task_status.TaskPhase,
  claimed_by: Option(Int),
) -> Result(Nil, String) {
  let execution_state = task_execution_state(status)
  case status {
    task_status.Claimed(mode) -> {
      case claimed_by {
        Some(claimed_user_id) ->
          pog.query(
            "UPDATE tasks SET execution_state = $1, claimed_mode = $2, claimed_by = $3, claimed_at = NOW(), closed_at = NULL, closed_by = NULL, closed_reason = NULL WHERE id = $4",
          )
          |> pog.parameter(pog.text(execution_state))
          |> pog.parameter(pog.text(claim_mode_to_string(mode)))
          |> pog.parameter(pog.int(claimed_user_id))
          |> pog.parameter(pog.int(task_id))
          |> pog.execute(db)
          |> result.map(fn(_) { Nil })
          |> result.map_error(fn(e) {
            "update_task_status: " <> string.inspect(e)
          })
        None -> Error("update_task_status: claimed_by is required")
      }
    }
    task_status.Done -> {
      pog.query(
        "UPDATE tasks SET execution_state = $1, claimed_mode = NULL, claimed_by = NULL, closed_at = NOW(), closed_by = $2, closed_reason = 'done' WHERE id = $3",
      )
      |> pog.parameter(pog.text(execution_state))
      |> pog.parameter(pog.nullable(pog.int, claimed_by))
      |> pog.parameter(pog.int(task_id))
      |> pog.execute(db)
      |> result.map(fn(_) { Nil })
      |> result.map_error(fn(e) { "update_task_status: " <> string.inspect(e) })
    }
    task_status.Available -> {
      pog.query(
        "UPDATE tasks SET execution_state = $1, claimed_mode = NULL, claimed_by = NULL, claimed_at = NULL, closed_at = NULL, closed_by = NULL, closed_reason = NULL WHERE id = $2",
      )
      |> pog.parameter(pog.text(execution_state))
      |> pog.parameter(pog.int(task_id))
      |> pog.execute(db)
      |> result.map(fn(_) { Nil })
      |> result.map_error(fn(e) { "update_task_status: " <> string.inspect(e) })
    }
  }
}

fn task_execution_state(status: task_status.TaskPhase) -> String {
  case status {
    task_status.Available -> "available"
    task_status.Claimed(_) -> "claimed"
    task_status.Done -> "closed"
  }
}

fn task_claimed_mode(status: task_status.TaskPhase) -> Option(String) {
  case status {
    task_status.Claimed(mode) -> Some(claim_mode_to_string(mode))
    _ -> None
  }
}

fn task_claimed_by(
  status: task_status.TaskPhase,
  claimed_by: Option(Int),
) -> Option(Int) {
  case status {
    task_status.Claimed(_) -> claimed_by
    _ -> None
  }
}

fn task_claimed_at(
  status: task_status.TaskPhase,
  claimed_at: Option(String),
) -> Option(String) {
  case status {
    task_status.Claimed(_) -> default_timestamp(claimed_at)
    _ -> None
  }
}

fn task_closed_at(
  status: task_status.TaskPhase,
  completed_at: Option(String),
) -> Option(String) {
  case status {
    task_status.Done -> default_timestamp(completed_at)
    _ -> None
  }
}

fn task_closed_by(
  status: task_status.TaskPhase,
  claimed_by: Option(Int),
  created_by: Int,
) -> Option(Int) {
  case status {
    task_status.Done -> Some(option_to_int(claimed_by, created_by))
    _ -> None
  }
}

fn task_closed_reason(status: task_status.TaskPhase) -> Option(String) {
  case status {
    task_status.Done -> Some("done")
    _ -> None
  }
}

fn claim_mode_to_string(mode: task_status.ClaimedState) -> String {
  case mode {
    task_status.Taken -> "taken"
    task_status.Ongoing -> "ongoing"
  }
}

fn default_timestamp(value: Option(String)) -> Option(String) {
  case value {
    Some(_) -> value
    None -> Some("NOW()")
  }
}

fn option_to_int(value: Option(Int), default: Int) -> Int {
  case value {
    Some(inner) -> inner
    None -> default
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

// =============================================================================
// Root hierarchy card operations
// =============================================================================

/// Insert a root hierarchy card with full control over execution fields.
pub fn insert_root_card(
  db: pog.Connection,
  opts: RootCardInsertOptions,
) -> Result(Int, String) {
  let base_cols =
    "project_id, parent_card_id, title, description, color, created_by, execution_state"
  let base_vals = "$1, NULL, $2, $3, NULL, $4, $5"
  let base_idx = 6

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      base_cols,
      base_vals,
      base_idx,
      "created_at",
      opts.created_at,
      [],
    )

  let #(cols, vals, idx, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "activated_at",
      opts.activated_at,
      params,
    )

  let #(cols, vals, _, params) =
    append_optional_timestamp(
      cols,
      vals,
      idx,
      "closed_at",
      opts.completed_at,
      params,
    )

  let state = card.state_to_string(opts.state)
  let closed_fields = case opts.state {
    card.Closed -> ", closed_by_kind, closed_reason"
    _ -> ""
  }
  let closed_values = case opts.state {
    card.Closed -> ", 'system', 'rollup'"
    _ -> ""
  }

  let sql =
    "INSERT INTO cards ("
    <> cols
    <> closed_fields
    <> ") VALUES ("
    <> vals
    <> closed_values
    <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.project_id))
    |> pog.parameter(pog.text(opts.name))
    |> pog.parameter(pog.text(option.unwrap(opts.description, "")))
    |> pog.parameter(pog.int(opts.created_by))
    |> pog.parameter(pog.text(state))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_root_card: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Assign the first available root cards of a project to a parent card.
pub fn assign_cards_to_parent_card(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
  limit: Int,
) -> Result(Nil, String) {
  pog.query(
    "UPDATE cards
     SET parent_card_id = $2
     WHERE id IN (
       SELECT id
       FROM cards
       WHERE project_id = $1
         AND parent_card_id IS NULL
       ORDER BY id
       LIMIT $3
     )",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(parent_card_id))
  |> pog.parameter(pog.int(limit))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "assign_cards_to_parent_card: " <> string.inspect(e)
  })
}

/// Assign a specific card to a parent card.
pub fn assign_card_to_parent_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Int,
) -> Result(Nil, String) {
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

/// Assign available root-pool tasks (card_id is null) to a parent card.
pub fn assign_available_pool_tasks_to_parent_card(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
  limit: Int,
) -> Result(Nil, String) {
  assign_pool_tasks_to_parent_card_by_status(
    db,
    project_id,
    parent_card_id,
    task_status.Available,
    limit,
  )
}

/// Assign claimed root-pool tasks (card_id is null) to a parent card.
pub fn assign_claimed_pool_tasks_to_parent_card(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
  limit: Int,
) -> Result(Nil, String) {
  assign_pool_tasks_to_parent_card_by_status(
    db,
    project_id,
    parent_card_id,
    task_status.Claimed(task_status.Taken),
    limit,
  )
}

/// Assign completed root-pool tasks (card_id is null) to a parent card.
pub fn assign_completed_pool_tasks_to_parent_card(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
  limit: Int,
) -> Result(Nil, String) {
  assign_pool_tasks_to_parent_card_by_status(
    db,
    project_id,
    parent_card_id,
    task_status.Done,
    limit,
  )
}

fn assign_pool_tasks_to_parent_card_by_status(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
  status: task_status.TaskPhase,
  limit: Int,
) -> Result(Nil, String) {
  let status = task_status.task_status_to_string(status)
  pog.query(
    "UPDATE tasks
     SET parent_card_id = $2
     WHERE id IN (
       SELECT id
       FROM tasks
       WHERE project_id = $1
         AND card_id IS NULL
         AND parent_card_id IS NULL
         AND status = $3
       ORDER BY id
       LIMIT $4
     )",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(parent_card_id))
  |> pog.parameter(pog.text(status))
  |> pog.parameter(pog.int(limit))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "assign_pool_tasks_to_parent_card_by_status: " <> string.inspect(e)
  })
}

/// Insert a task dependency.
pub fn insert_task_dependency(
  db: pog.Connection,
  task_id: Int,
  depends_on_task_id: Int,
  created_by: Int,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO task_dependencies (task_id, depends_on_task_id, created_by)
     VALUES ($1, $2, $3)
     ON CONFLICT DO NOTHING",
  )
  |> pog.parameter(pog.int(task_id))
  |> pog.parameter(pog.int(depends_on_task_id))
  |> pog.parameter(pog.int(created_by))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_task_dependency: " <> string.inspect(e) })
}

// =============================================================================
// Workflow Operations
// =============================================================================

/// Insert a workflow with full control over fields.
pub fn insert_workflow(
  db: pog.Connection,
  opts: WorkflowInsertOptions,
) -> Result(Int, String) {
  let base_cols = "org_id, project_id, name, description, active, created_by"
  let base_vals = "$1, $2, $3, $4, $5, $6"
  let base_idx = 7

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
    "INSERT INTO workflows ("
    <> cols
    <> ") VALUES ("
    <> vals
    <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.org_id))
    |> pog.parameter(pog.int(opts.project_id))
    |> pog.parameter(pog.text(opts.name))
    |> pog.parameter(pog.nullable(pog.text, opts.description))
    |> pog.parameter(pog.bool(opts.active))
    |> pog.parameter(pog.int(opts.created_by))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_workflow: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Simple workflow insert with defaults.
pub fn insert_workflow_simple(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  name: String,
  created_by: Int,
) -> Result(Int, String) {
  insert_workflow(
    db,
    WorkflowInsertOptions(
      org_id: org_id,
      project_id: project_id,
      name: name,
      description: None,
      active: True,
      created_by: created_by,
      created_at: None,
    ),
  )
}

// =============================================================================
// Rule Operations
// =============================================================================

/// Insert a rule with full control over fields.
pub fn insert_rule(
  db: pog.Connection,
  opts: RuleInsertOptions,
) -> Result(Int, String) {
  let base_cols =
    "workflow_id, name, goal, resource_type, task_type_id, to_state, active"
  let base_vals = "$1, $2, $3, $4, $5, $6, $7"
  let base_idx = 8

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
    "INSERT INTO rules (" <> cols <> ") VALUES (" <> vals <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.workflow_id))
    |> pog.parameter(pog.text(opts.name))
    |> pog.parameter(pog.nullable(pog.text, opts.goal))
    |> pog.parameter(pog.text(opts.resource_type))
    |> pog.parameter(pog.nullable(pog.int, opts.task_type_id))
    |> pog.parameter(pog.text(opts.to_state))
    |> pog.parameter(pog.bool(opts.active))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_rule: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Simple rule insert with defaults.
pub fn insert_rule_simple(
  db: pog.Connection,
  workflow_id: Int,
  name: String,
  resource_type: String,
  task_type_id: Option(Int),
  to_state: String,
) -> Result(Int, String) {
  insert_rule(
    db,
    RuleInsertOptions(
      workflow_id: workflow_id,
      name: name,
      goal: None,
      resource_type: resource_type,
      task_type_id: task_type_id,
      to_state: to_state,
      active: True,
      created_at: None,
    ),
  )
}

/// Attach a template to a rule.
pub fn attach_template(
  db: pog.Connection,
  rule_id: Int,
  template_id: Int,
  execution_order: Int,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO rule_templates (rule_id, template_id, execution_order) VALUES ($1, $2, $3)",
  )
  |> pog.parameter(pog.int(rule_id))
  |> pog.parameter(pog.int(template_id))
  |> pog.parameter(pog.int(execution_order))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "attach_template: " <> string.inspect(e) })
}

// =============================================================================
// Template Operations
// =============================================================================

/// Insert a task template with full control over fields.
pub fn insert_template(
  db: pog.Connection,
  opts: TemplateInsertOptions,
) -> Result(Int, String) {
  let base_cols =
    "org_id, project_id, type_id, name, description, priority, created_by"
  let base_vals = "$1, $2, $3, $4, $5, $6, $7"
  let base_idx = 8

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
    "INSERT INTO task_templates ("
    <> cols
    <> ") VALUES ("
    <> vals
    <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(opts.org_id))
    |> pog.parameter(pog.int(opts.project_id))
    |> pog.parameter(pog.int(opts.type_id))
    |> pog.parameter(pog.text(opts.name))
    |> pog.parameter(pog.text(opts.description))
    |> pog.parameter(pog.int(opts.priority))
    |> pog.parameter(pog.int(opts.created_by))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_template: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
}

/// Simple template insert with defaults.
pub fn insert_template_simple(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  type_id: Int,
  name: String,
  created_by: Int,
) -> Result(Int, String) {
  insert_template(
    db,
    TemplateInsertOptions(
      org_id: org_id,
      project_id: project_id,
      type_id: type_id,
      name: name,
      description: "Seeded",
      priority: 3,
      created_by: created_by,
      created_at: None,
    ),
  )
}

// =============================================================================
// Task Event Operations
// =============================================================================

/// Insert a task event with optional timestamp.
pub fn insert_task_event(
  db: pog.Connection,
  opts: TaskEventInsertOptions,
) -> Result(Nil, String) {
  insert_task_event_raw(
    db,
    opts.org_id,
    opts.project_id,
    opts.task_id,
    opts.actor_user_id,
    audit_events_db.event_type_to_string(opts.event_type),
    opts.created_at,
  )
}

fn insert_task_event_raw(
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
  |> result.map_error(fn(e) { "insert_task_event: " <> string.inspect(e) })
}

/// Simple task event insert.
pub fn insert_task_event_simple(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  task_id: Int,
  user_id: Int,
  event_type: String,
) -> Result(Nil, String) {
  insert_task_event_raw(
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
// Task Note Operations
// =============================================================================

/// Insert a task note.
pub fn insert_task_note(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  content: String,
  created_at: Option(String),
) -> Result(Int, String) {
  let base_cols = "task_id, user_id, content"
  let base_vals = "$1, $2, $3"
  let base_idx = 4

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
    "INSERT INTO task_notes ("
    <> cols
    <> ") VALUES ("
    <> vals
    <> ") RETURNING id"

  let base_query =
    pog.query(sql)
    |> pog.parameter(pog.int(task_id))
    |> pog.parameter(pog.int(user_id))
    |> pog.parameter(pog.text(content))

  apply_timestamp_params(base_query, params)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "insert_task_note: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [id] -> Ok(id)
      _ -> Error("No ID")
    }
  })
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
// Task Position Operations
// =============================================================================

/// Upsert a task position for a user.
pub fn insert_task_position(
  db: pog.Connection,
  task_id: Int,
  user_id: Int,
  x: Int,
  y: Int,
) -> Result(Nil, String) {
  pog.query(
    "INSERT INTO task_positions (task_id, user_id, x, y, updated_at)
     VALUES ($1, $2, $3, $4, NOW())
     ON CONFLICT (task_id, user_id)
     DO UPDATE SET x = $3, y = $4, updated_at = NOW()",
  )
  |> pog.parameter(pog.int(task_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.parameter(pog.int(x))
  |> pog.parameter(pog.int(y))
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) { "insert_task_position: " <> string.inspect(e) })
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
// Query Helpers
// =============================================================================

/// Query a single integer value.
pub fn query_int(db: pog.Connection, sql: String) -> Result(Int, String) {
  pog.query(sql)
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(fn(e) { "Query failed: " <> string.inspect(e) })
  |> result.try(fn(r) {
    case r.rows {
      [v] -> Ok(v)
      _ -> Error("No rows")
    }
  })
}

/// Reset workflow-related tables for re-seeding.
pub fn reset_workflow_tables(db: pog.Connection) -> Result(Nil, String) {
  use _ <- result.try(
    pog.query(
      "TRUNCATE rule_templates, rule_executions, rules, workflows, task_templates, audit_events, tasks, task_types, cards, task_positions, task_notes, user_task_work_session, user_task_work_total, project_member_capabilities, capabilities, project_members, projects CASCADE",
    )
    |> pog.execute(db)
    |> result.map(fn(_) { Nil })
    |> result.map_error(fn(e) { "Truncate failed: " <> string.inspect(e) }),
  )

  pog.query(
    "INSERT INTO projects (id, org_id, name) VALUES (1, 1, 'Default') ON CONFLICT (id) DO NOTHING",
  )
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(e) {
    "Reset default project failed: " <> string.inspect(e)
  })
}

// =============================================================================
// Internal Helpers
// =============================================================================

fn int_decoder() {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}
