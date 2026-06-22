//// Database operations for cards (fichas).
////
//// ## Mission
////
//// Manages CRUD operations for cards and lifecycle state.
////
//// ## Responsibilities
////
//// - List cards with persisted lifecycle state
//// - Create, update, delete cards
//// - Validate delete constraints (no tasks)
//// - Validate tree and lifecycle transitions

import domain/card.{
  type Card, type CardColor, type CardPhase, Active, Card, Closed, Draft,
  UnknownCardColor, optional_color_to_string as shared_optional_color_to_string,
  parse_optional_color as shared_parse_optional_color,
}
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import helpers/option as option_helpers
import pog
import scrumbringer_server/sql
import scrumbringer_server/use_case/audit_events_db
import scrumbringer_server/use_case/persisted_field

// =============================================================================
// Types
// =============================================================================

const no_parent_create_value = 0

const no_parent_update_value = -1

pub type CardActionImpact {
  CardActionImpact(
    changed_tasks: Int,
    pool_open_after: Int,
    healthy_pool_limit: Int,
  )
}

/// Errors for card operations.
pub type CardError {
  CardNotFound
  CardHasTasks(task_count: Int)
  CardHasChildCards(child_count: Int)
  CardHasOperationalHistory
  InvalidParentCard
  InvalidParentExecutionPhase(String)
  ParentCardClosed
  ParentDoesNotAcceptCards
  InvalidColor(String)
  InvalidMovePoolToParentCard
  CardHasClaimedDescendant(Int)
  CannotActivateClosedCard
  CardAlreadyClosed
  CannotMoveClosedCard
  CannotMoveIntoClosedCard
  DestinationDoesNotAcceptCards
  DestinationNotFound
  MoveWouldCreateCycle
  DbError(pog.QueryError)
}

// =============================================================================
// Public API
// =============================================================================

/// List all cards for a project.
pub fn list_cards(
  db: pog.Connection,
  project_id: Int,
  user_id: Int,
) -> Result(List(Card), CardError) {
  use returned <- result.try(
    sql.cards_list(db, project_id, user_id)
    |> result.map_error(DbError),
  )

  list.try_map(returned.rows, fn(row) {
    card_from_counts(
      row.id,
      row.project_id,
      row.parent_card_id,
      row.title,
      row.description,
      row.color,
      row.execution_state,
      row.created_by,
      row.created_at,
      row.due_date,
      row.task_count,
      row.completed_count,
      row.available_count,
      row.has_new_notes,
    )
  })
}

/// Get a single card by ID.
pub fn get_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Card, CardError) {
  case sql.cards_get(db, card_id, user_id) {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) ->
      card_from_counts(
        row.id,
        row.project_id,
        row.parent_card_id,
        row.title,
        row.description,
        row.color,
        row.execution_state,
        row.created_by,
        row.created_at,
        row.due_date,
        row.task_count,
        row.completed_count,
        row.available_count,
        row.has_new_notes,
      )
  }
}

fn card_from_counts(
  id: Int,
  project_id: Int,
  parent_card_id: Int,
  title: String,
  description: String,
  color: String,
  execution_state: String,
  created_by: Int,
  created_at: String,
  due_date: String,
  task_count: Int,
  completed_count: Int,
  _available_count: Int,
  has_new_notes: Bool,
) -> Result(Card, CardError) {
  use state <- result.try(card_phase_from_execution_state(execution_state))
  card_from_fields(
    id,
    project_id,
    parent_card_id,
    title,
    description,
    color,
    state,
    task_count,
    completed_count,
    created_by,
    created_at,
    due_date,
    has_new_notes,
  )
}

fn card_phase_from_execution_state(
  execution_state: String,
) -> Result(CardPhase, CardError) {
  case execution_state {
    "draft" -> Ok(Draft)
    "active" -> Ok(Active)
    "closed" -> Ok(Closed)
    other -> Error(InvalidParentExecutionPhase(other))
  }
}

fn card_from_fields(
  id: Int,
  project_id: Int,
  parent_card_id: Int,
  title: String,
  description: String,
  color: String,
  state: CardPhase,
  task_count: Int,
  completed_count: Int,
  created_by: Int,
  created_at: String,
  due_date: String,
  has_new_notes: Bool,
) -> Result(Card, CardError) {
  use parsed_color <- result.try(parse_optional_color(color))
  Ok(Card(
    id: id,
    project_id: project_id,
    parent_card_id: option_helpers.int_to_option(parent_card_id),
    title: title,
    description: description,
    color: parsed_color,
    state: state,
    task_count: task_count,
    completed_count: completed_count,
    created_by: created_by,
    created_at: created_at,
    due_date: option_helpers.string_to_option(due_date),
    has_new_notes: has_new_notes,
  ))
}

/// Create a new card.
pub fn create_card(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(CardColor),
  due_date: Option(String),
  created_by: Int,
) -> Result(Card, CardError) {
  case validate_parent_for_create(db, project_id, parent_card_id) {
    Error(e) -> Error(e)
    Ok(Nil) ->
      create_card_row(
        db,
        project_id,
        parent_card_id,
        title,
        description,
        color,
        due_date,
        created_by,
      )
  }
}

fn create_card_row(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(CardColor),
  due_date: Option(String),
  created_by: Int,
) -> Result(Card, CardError) {
  let desc = description_text(description)
  let col = shared_optional_color_to_string(color)
  let due = due_date_text(due_date)

  case
    sql.cards_create(
      db,
      project_id,
      title,
      desc,
      col,
      created_by,
      parent_card_id_create_value(parent_card_id),
      due,
    )
  {
    Error(e) -> Error(DbError(e))
    Ok(returned) -> {
      use row <- result.try(
        persisted_field.query_row(returned.rows)
        |> result.map_error(DbError),
      )
      card_from_fields(
        row.id,
        row.project_id,
        row.parent_card_id,
        row.title,
        row.description,
        row.color,
        Draft,
        0,
        0,
        row.created_by,
        row.created_at,
        row.due_date,
        False,
      )
    }
  }
}

/// Update a card's title, description, and color.
pub fn update_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Option(Int),
  title: String,
  description: Option(String),
  color: Option(CardColor),
  due_date: Option(String),
  org_id: Int,
  user_id: Int,
) -> Result(Card, CardError) {
  use current <- result.try(get_card(db, card_id, user_id))
  use _ <- result.try(validate_parent_for_update(
    db,
    current.project_id,
    current.parent_card_id,
    parent_card_id,
  ))

  let desc = description_text(description)
  let col = shared_optional_color_to_string(color)
  let due = due_date_text(due_date)

  case
    sql.cards_update(
      db,
      card_id,
      title,
      desc,
      col,
      parent_card_id_update_value(parent_card_id),
      due,
    )
  {
    Error(e) -> Error(DbError(e))
    Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      // After update, we need to get current task counts
      case sql.cards_get(db, card_id, user_id) {
        Error(e) -> Error(DbError(e))
        Ok(pog.Returned(rows: [], ..)) -> Error(CardNotFound)
        Ok(pog.Returned(rows: [full_row, ..], ..)) -> {
          use state <- result.try(card_phase_from_execution_state(
            full_row.execution_state,
          ))
          use updated <- result.try(card_from_fields(
            row.id,
            row.project_id,
            row.parent_card_id,
            row.title,
            row.description,
            row.color,
            state,
            full_row.task_count,
            full_row.completed_count,
            row.created_by,
            row.created_at,
            row.due_date,
            full_row.has_new_notes,
          ))
          use _ <- result.try(record_card_due_date_change(
            db,
            org_id,
            updated.project_id,
            updated.id,
            user_id,
            current.due_date,
            updated.due_date,
          ))
          Ok(updated)
        }
      }
    }
  }
}

fn record_card_due_date_change(
  db: pog.Connection,
  org_id: Int,
  project_id: Int,
  card_id: Int,
  user_id: Int,
  previous_due_date: Option(String),
  next_due_date: Option(String),
) -> Result(Nil, CardError) {
  case previous_due_date == next_due_date {
    True -> Ok(Nil)
    False ->
      audit_events_db.insert_for_card(
        db,
        org_id,
        project_id,
        card_id,
        user_id,
        audit_events_db.DueDateChanged,
      )
      |> result.map_error(DbError)
  }
}

/// Delete a card only when it has no child content or operational history.
pub fn delete_card(db: pog.Connection, card_id: Int) -> Result(Nil, CardError) {
  use _ <- result.try(validate_card_delete(db, card_id))

  case sql.cards_delete(db, card_id) {
    Error(e) -> Error(DbError(e))
    Ok(_) -> Ok(Nil)
  }
}

pub fn activate_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(CardActionImpact, CardError) {
  use execution_state <- result.try(card_execution_state(db, card_id))
  case execution_state {
    "closed" -> Error(CannotActivateClosedCard)
    _ -> activate_open_card(db, card_id, user_id)
  }
}

fn activate_open_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(CardActionImpact, CardError) {
  pog.query(
    "WITH RECURSIVE target AS (
       SELECT c.id, c.project_id, p.org_id
       FROM cards c
       JOIN projects p ON p.id = c.project_id
       WHERE c.id = $1
     ),
     settings AS (
       SELECT COALESCE(ps.healthy_pool_limit, 20)::int AS healthy_pool_limit
       FROM target
       LEFT JOIN project_settings ps ON ps.project_id = target.project_id
     ),
     current_pool AS (
       SELECT COUNT(*)::int AS open_count
       FROM tasks task
       LEFT JOIN cards card ON card.id = task.card_id
       WHERE task.project_id = (SELECT project_id FROM target)
         AND task.execution_state = 'available'
         AND (
           task.card_id IS NULL
           OR card.execution_state = 'active'
         )
     ),
     subtree AS (
       SELECT id
       FROM cards
       WHERE id IN (SELECT id FROM target)
       UNION ALL
       SELECT child.id
       FROM cards child
       JOIN subtree parent ON child.parent_card_id = parent.id
     ),
     impact AS (
       SELECT COUNT(*)::int AS opened_count
       FROM tasks task
       JOIN cards card ON card.id = task.card_id
       JOIN subtree node ON node.id = card.id
       WHERE task.execution_state = 'available'
         AND card.execution_state = 'draft'
     ),
     updated AS (
       UPDATE cards
       SET execution_state = 'active',
           activated_at = COALESCE(activated_at, NOW()),
           activated_by = CASE
             WHEN id = $1 THEN $2
             ELSE COALESCE(activated_by, $2)
           END,
           activation_source = CASE
             WHEN id = $1 THEN 'direct_activation'
             ELSE COALESCE(activation_source, 'activated_by_ancestor')
           END,
           activation_source_card_id = CASE
             WHEN id = $1 THEN NULL
             ELSE COALESCE(activation_source_card_id, $1)
           END
       WHERE id IN (SELECT id FROM subtree)
         AND execution_state = 'draft'
       RETURNING id
     ),
     entered_pool AS (
       UPDATE tasks
       SET last_entered_pool_at = COALESCE(last_entered_pool_at, NOW())
       WHERE card_id IN (SELECT id FROM updated)
         AND execution_state = 'available'
       RETURNING id
     ),
     audit AS (
       INSERT INTO audit_events (
         org_id,
         project_id,
         card_id,
         actor_user_id,
         event_type,
         payload_json,
         created_at
       )
       SELECT
         target.org_id,
         target.project_id,
         target.id,
         $2,
         'card_activated',
         '{}'::jsonb,
         NOW()
       FROM target
       WHERE EXISTS (SELECT 1 FROM updated WHERE updated.id = target.id)
       RETURNING id
     )
     SELECT
       impact.opened_count,
       current_pool.open_count + impact.opened_count,
       settings.healthy_pool_limit
     FROM impact, current_pool, settings",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.returning(card_action_impact_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [impact] -> Ok(impact)
      _ -> Ok(CardActionImpact(0, 0, 20))
    }
  })
}

pub fn close_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(CardActionImpact, CardError) {
  use execution_state <- result.try(card_execution_state(db, card_id))
  case execution_state {
    "closed" -> Error(CardAlreadyClosed)
    _ -> close_open_card(db, card_id, user_id)
  }
}

fn close_open_card(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(CardActionImpact, CardError) {
  use claimed_count <- result.try(count_claimed_tasks(db, card_id))
  case claimed_count > 0 {
    True -> Error(CardHasClaimedDescendant(claimed_count))
    False ->
      pog.query(
        "WITH RECURSIVE target AS (
           SELECT c.id, c.project_id, p.org_id
           FROM cards c
           JOIN projects p ON p.id = c.project_id
           WHERE c.id = $1
         ),
         settings AS (
           SELECT COALESCE(ps.healthy_pool_limit, 20)::int AS healthy_pool_limit
           FROM target
           LEFT JOIN project_settings ps ON ps.project_id = target.project_id
         ),
         current_pool AS (
           SELECT COUNT(*)::int AS open_count
           FROM tasks task
           LEFT JOIN cards card ON card.id = task.card_id
           WHERE task.project_id = (SELECT project_id FROM target)
             AND task.execution_state = 'available'
             AND (
               task.card_id IS NULL
               OR card.execution_state = 'active'
             )
         ),
         subtree AS (
           SELECT id
           FROM cards
           WHERE id IN (SELECT id FROM target)
           UNION ALL
           SELECT child.id
           FROM cards child
           JOIN subtree parent ON child.parent_card_id = parent.id
         ),
         pool_removed AS (
           SELECT COUNT(*)::int AS removed_count
           FROM tasks task
           JOIN cards card ON card.id = task.card_id
           JOIN subtree node ON node.id = task.card_id
           WHERE task.execution_state = 'available'
             AND card.execution_state = 'active'
         ),
         closed_tasks AS (
           UPDATE tasks
           SET execution_state = 'closed',
               closed_at = NOW(),
               closed_by = $2,
               closed_reason = 'closed_by_ancestor',
               pool_lifetime_s = pool_lifetime_s + CASE
                 WHEN last_entered_pool_at IS NULL THEN 0
                 ELSE GREATEST(0, EXTRACT(EPOCH FROM (NOW() - last_entered_pool_at))::bigint)
               END,
               last_entered_pool_at = NULL,
               version = version + 1
           WHERE card_id IN (SELECT id FROM subtree)
             AND execution_state = 'available'
           RETURNING id
         ),
         closed_cards AS (
           UPDATE cards
           SET execution_state = 'closed',
               closed_at = COALESCE(closed_at, NOW()),
               closed_by = $2,
               closed_by_kind = 'user',
               closed_reason = 'manually_closed'
           WHERE id IN (SELECT id FROM subtree)
             AND execution_state <> 'closed'
           RETURNING id
         ),
         audit AS (
           INSERT INTO audit_events (
             org_id,
             project_id,
             card_id,
             actor_user_id,
             event_type,
             payload_json,
             created_at
           )
           SELECT
             target.org_id,
             target.project_id,
             target.id,
             $2,
             'card_closed',
             '{}'::jsonb,
             NOW()
           FROM target
           WHERE EXISTS (SELECT 1 FROM closed_cards WHERE closed_cards.id = target.id)
           RETURNING id
         )
         SELECT
           (SELECT COUNT(*)::int FROM closed_tasks),
           GREATEST(0, current_pool.open_count - pool_removed.removed_count)::int,
           settings.healthy_pool_limit
         FROM current_pool, pool_removed, settings",
      )
      |> pog.parameter(pog.int(card_id))
      |> pog.parameter(pog.int(user_id))
      |> pog.returning(card_action_impact_decoder())
      |> pog.execute(db)
      |> result.map_error(DbError)
      |> result.try(fn(returned) {
        case returned.rows {
          [impact] -> Ok(impact)
          _ -> Ok(CardActionImpact(0, 0, 20))
        }
      })
  }
}

pub fn rollup_closed_cards(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Int, CardError) {
  rollup_closed_cards_loop(db, card_id, user_id, 0, 0)
}

fn rollup_closed_cards_loop(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
  depth: Int,
  closed_count: Int,
) -> Result(Int, CardError) {
  case depth > 64 {
    True -> Ok(closed_count)
    False ->
      case rollup_card_if_complete(db, card_id, user_id) {
        Error(e) -> Error(e)
        Ok(None) -> Ok(closed_count)
        Ok(Some(parent_card_id)) ->
          rollup_closed_cards_loop(
            db,
            parent_card_id,
            user_id,
            depth + 1,
            closed_count + 1,
          )
      }
  }
}

fn rollup_card_if_complete(
  db: pog.Connection,
  card_id: Int,
  user_id: Int,
) -> Result(Option(Int), CardError) {
  pog.query(
    "WITH eligible AS (
       SELECT c.id, c.parent_card_id, c.project_id, p.org_id
       FROM cards c
       JOIN projects p ON p.id = c.project_id
       WHERE c.id = $1
         AND c.execution_state <> 'closed'
         AND (
           EXISTS (SELECT 1 FROM tasks t WHERE t.card_id = c.id)
           OR EXISTS (SELECT 1 FROM cards child WHERE child.parent_card_id = c.id)
         )
         AND NOT EXISTS (
           SELECT 1
           FROM tasks t
           WHERE t.card_id = c.id
             AND t.execution_state <> 'closed'
         )
         AND NOT EXISTS (
           SELECT 1
           FROM cards child
           WHERE child.parent_card_id = c.id
             AND child.execution_state <> 'closed'
         )
     ),
     updated AS (
       UPDATE cards card
       SET execution_state = 'closed',
           closed_at = COALESCE(card.closed_at, NOW()),
           closed_by = $2,
           closed_by_kind = 'system',
           closed_reason = 'rollup'
       FROM eligible
       WHERE card.id = eligible.id
       RETURNING card.parent_card_id
     ),
     audit AS (
       INSERT INTO audit_events (
         org_id,
         project_id,
         card_id,
         actor_user_id,
         event_type,
         payload_json,
         created_at
       )
       SELECT
         eligible.org_id,
         eligible.project_id,
         eligible.id,
         $2,
         'card_closed',
         '{\"reason\":\"rollup\"}'::jsonb,
         NOW()
       FROM eligible
       WHERE EXISTS (SELECT 1 FROM updated)
       RETURNING id
     )
     SELECT COALESCE(updated.parent_card_id, 0), COALESCE((SELECT COUNT(*)::int FROM audit), 0)
     FROM updated",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.int(user_id))
  |> pog.returning(rollup_parent_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [parent_card_id] -> Ok(option_helpers.int_to_option(parent_card_id))
      _ -> Ok(None)
    }
  })
}

pub fn move_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Option(Int),
) -> Result(CardActionImpact, CardError) {
  use _ <- result.try(validate_move_card(db, card_id, parent_card_id))
  pog.query(
    "WITH target AS (
       SELECT project_id
       FROM cards
       WHERE id = $1
     ),
     settings AS (
       SELECT COALESCE(ps.healthy_pool_limit, 20)::int AS healthy_pool_limit
       FROM target
       LEFT JOIN project_settings ps ON ps.project_id = target.project_id
     ),
     current_pool AS (
       SELECT COUNT(*)::int AS open_count
       FROM tasks task
       LEFT JOIN cards card ON card.id = task.card_id
       WHERE task.project_id = (SELECT project_id FROM target)
         AND task.execution_state = 'available'
         AND (
           task.card_id IS NULL
           OR card.execution_state = 'active'
         )
     ),
     moved AS (
       UPDATE cards
       SET parent_card_id = $2
       WHERE id = $1
       RETURNING id
     )
     SELECT
       0,
       current_pool.open_count,
       settings.healthy_pool_limit
     FROM current_pool, settings",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.nullable(pog.int, parent_card_id))
  |> pog.returning(card_action_impact_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [impact] -> Ok(impact)
      _ -> Ok(CardActionImpact(0, 0, 20))
    }
  })
}

fn card_execution_state(
  db: pog.Connection,
  card_id: Int,
) -> Result(String, CardError) {
  pog.query("SELECT execution_state FROM cards WHERE id = $1")
  |> pog.parameter(pog.int(card_id))
  |> pog.returning(string_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [state] -> Ok(state)
      _ -> Error(CardNotFound)
    }
  })
}

fn validate_card_delete(
  db: pog.Connection,
  card_id: Int,
) -> Result(Nil, CardError) {
  use outcome <- result.try(card_delete_validation_outcome(db, card_id))
  case outcome {
    DeleteAllowed -> Ok(Nil)
    DeleteNotFound -> Error(CardNotFound)
    DeleteHasTasks(count) -> Error(CardHasTasks(count))
    DeleteHasChildCards(count) -> Error(CardHasChildCards(count))
    DeleteHasOperationalHistory -> Error(CardHasOperationalHistory)
  }
}

type CardDeleteValidation {
  DeleteAllowed
  DeleteNotFound
  DeleteHasTasks(Int)
  DeleteHasChildCards(Int)
  DeleteHasOperationalHistory
}

fn card_delete_validation_outcome(
  db: pog.Connection,
  card_id: Int,
) -> Result(CardDeleteValidation, CardError) {
  pog.query(
    "WITH target AS (
       SELECT id, execution_state
       FROM cards
       WHERE id = $1
     ),
     counts AS (
       SELECT
         (SELECT COUNT(*)::int FROM tasks WHERE card_id = $1) AS task_count,
         (SELECT COUNT(*)::int FROM cards WHERE parent_card_id = $1) AS child_count,
         EXISTS (
           SELECT 1
           FROM audit_events
           WHERE card_id = $1
         ) AS has_audit_events,
         EXISTS (
           SELECT 1
           FROM card_notes
           WHERE card_id = $1
         ) AS has_notes
     )
     SELECT
       CASE
         WHEN NOT EXISTS (SELECT 1 FROM target) THEN 'not_found'
         WHEN counts.task_count > 0 THEN 'tasks'
         WHEN counts.child_count > 0 THEN 'children'
         WHEN EXISTS (
           SELECT 1
           FROM target
           WHERE execution_state <> 'draft'
         ) THEN 'history'
         WHEN counts.has_audit_events THEN 'history'
         WHEN counts.has_notes THEN 'history'
         ELSE 'ok'
       END,
       counts.task_count,
       counts.child_count
     FROM counts",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.returning(card_delete_validation_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [outcome] -> Ok(outcome)
      _ -> Error(CardNotFound)
    }
  })
}

fn card_delete_validation_decoder() {
  use reason <- decode.field(0, decode.string)
  use task_count <- decode.field(1, decode.int)
  use child_count <- decode.field(2, decode.int)
  case reason {
    "ok" -> decode.success(DeleteAllowed)
    "not_found" -> decode.success(DeleteNotFound)
    "tasks" -> decode.success(DeleteHasTasks(task_count))
    "children" -> decode.success(DeleteHasChildCards(child_count))
    "history" -> decode.success(DeleteHasOperationalHistory)
    _ -> decode.success(DeleteHasOperationalHistory)
  }
}

fn validate_move_card(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Option(Int),
) -> Result(Nil, CardError) {
  use outcome <- result.try(move_validation_outcome(db, card_id, parent_card_id))
  case outcome {
    "ok" -> Ok(Nil)
    "not_found" -> Error(CardNotFound)
    "card_closed" -> Error(CannotMoveClosedCard)
    "dest_not_found" -> Error(DestinationNotFound)
    "dest_closed" -> Error(CannotMoveIntoClosedCard)
    "dest_tasks" -> Error(DestinationDoesNotAcceptCards)
    "cycle" -> Error(MoveWouldCreateCycle)
    _ -> Error(InvalidParentCard)
  }
}

fn move_validation_outcome(
  db: pog.Connection,
  card_id: Int,
  parent_card_id: Option(Int),
) -> Result(String, CardError) {
  pog.query(
    "WITH RECURSIVE current_card AS (
       SELECT id, project_id, parent_card_id, execution_state
       FROM cards
       WHERE id = $1
     ),
     destination AS (
       SELECT cards.id, cards.project_id, cards.parent_card_id, cards.execution_state
       FROM cards, current_card
       WHERE cards.id = $2
         AND cards.project_id = current_card.project_id
     ),
     subtree AS (
       SELECT id
       FROM cards
       WHERE id = $1
       UNION ALL
       SELECT child.id
       FROM cards child
       JOIN subtree parent ON child.parent_card_id = parent.id
     )
     SELECT CASE
       WHEN NOT EXISTS (SELECT 1 FROM current_card) THEN 'not_found'
       WHEN EXISTS (
         SELECT 1 FROM current_card WHERE execution_state = 'closed'
       ) THEN 'card_closed'
       WHEN $2 IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM destination)
         THEN 'dest_not_found'
       WHEN $2 IS NOT NULL
         AND EXISTS (SELECT 1 FROM destination WHERE execution_state = 'closed')
         THEN 'dest_closed'
       WHEN $2 IS NOT NULL
         AND EXISTS (SELECT 1 FROM tasks WHERE card_id = $2)
         THEN 'dest_tasks'
       WHEN $2 IS NOT NULL
         AND EXISTS (SELECT 1 FROM subtree WHERE id = $2)
         THEN 'cycle'
       ELSE 'ok'
     END",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.parameter(pog.nullable(pog.int, parent_card_id))
  |> pog.returning(string_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [outcome] -> Ok(outcome)
      _ -> Error(CardNotFound)
    }
  })
}

fn count_claimed_tasks(
  db: pog.Connection,
  card_id: Int,
) -> Result(Int, CardError) {
  pog.query(
    "WITH RECURSIVE subtree AS (
       SELECT id
       FROM cards
       WHERE id = $1
       UNION ALL
       SELECT child.id
       FROM cards child
       JOIN subtree parent ON child.parent_card_id = parent.id
     )
     SELECT COUNT(*)::int
     FROM tasks task
     JOIN subtree node ON node.id = task.card_id
     WHERE task.execution_state = 'claimed'",
  )
  |> pog.parameter(pog.int(card_id))
  |> pog.returning(int_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [count] -> Ok(count)
      _ -> Ok(0)
    }
  })
}

fn int_decoder() {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}

fn string_decoder() {
  use value <- decode.field(0, decode.string)
  decode.success(value)
}

fn rollup_parent_decoder() {
  use parent_card_id <- decode.field(0, decode.int)
  use _audit_count <- decode.field(1, decode.int)
  decode.success(parent_card_id)
}

fn card_action_impact_decoder() {
  use changed_tasks <- decode.field(0, decode.int)
  use pool_open_after <- decode.field(1, decode.int)
  use healthy_pool_limit <- decode.field(2, decode.int)
  decode.success(CardActionImpact(
    changed_tasks: changed_tasks,
    pool_open_after: pool_open_after,
    healthy_pool_limit: healthy_pool_limit,
  ))
}

// =============================================================================
// State Derivation (delegated to shared module)
// =============================================================================

fn parse_optional_color(color: String) -> Result(Option(CardColor), CardError) {
  case shared_parse_optional_color(color) {
    Ok(parsed) -> Ok(parsed)
    Error(UnknownCardColor(value)) -> Error(InvalidColor(value))
  }
}

fn description_text(description: Option(String)) -> String {
  option_helpers.option_to_value(description, "")
}

fn due_date_text(due_date: Option(String)) -> String {
  option_helpers.option_to_value(due_date, "")
}

fn parent_card_id_create_value(parent_card_id: Option(Int)) -> Int {
  option_helpers.option_to_value(parent_card_id, no_parent_create_value)
}

fn parent_card_id_update_value(parent_card_id: Option(Int)) -> Int {
  option_helpers.option_to_value(parent_card_id, no_parent_update_value)
}

fn validate_parent_for_create(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Option(Int),
) -> Result(Nil, CardError) {
  case parent_card_id {
    None -> Ok(Nil)
    Some(id) if id <= 0 -> Ok(Nil)
    Some(id) -> validate_card_parent_accepts_cards(db, project_id, id)
  }
}

fn validate_parent_for_update(
  db: pog.Connection,
  project_id: Int,
  current_parent_card_id: Option(Int),
  target_parent_card_id: Option(Int),
) -> Result(Nil, CardError) {
  let _ = db
  let _ = project_id
  let _ = current_parent_card_id
  let _ = target_parent_card_id
  Ok(Nil)
}

fn validate_card_parent_accepts_cards(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
) -> Result(Nil, CardError) {
  use outcome <- result.try(card_parent_validation_outcome(
    db,
    project_id,
    parent_card_id,
  ))
  case outcome {
    "ok" -> Ok(Nil)
    "not_found" -> Error(InvalidParentCard)
    "closed" -> Error(ParentCardClosed)
    "has_tasks" -> Error(ParentDoesNotAcceptCards)
    _ -> Error(InvalidParentCard)
  }
}

fn card_parent_validation_outcome(
  db: pog.Connection,
  project_id: Int,
  parent_card_id: Int,
) -> Result(String, CardError) {
  pog.query(
    "WITH parent AS (
       SELECT id, execution_state
       FROM cards
       WHERE id = $2
         AND project_id = $1
     )
     SELECT CASE
       WHEN NOT EXISTS (SELECT 1 FROM parent) THEN 'not_found'
       WHEN EXISTS (
         SELECT 1 FROM parent WHERE execution_state = 'closed'
       ) THEN 'closed'
       WHEN EXISTS (
         SELECT 1 FROM tasks WHERE card_id = $2
       ) THEN 'has_tasks'
       ELSE 'ok'
     END",
  )
  |> pog.parameter(pog.int(project_id))
  |> pog.parameter(pog.int(parent_card_id))
  |> pog.returning(string_decoder())
  |> pog.execute(db)
  |> result.map_error(DbError)
  |> result.try(fn(returned) {
    case returned.rows {
      [outcome] -> Ok(outcome)
      _ -> Error(InvalidParentCard)
    }
  })
}
