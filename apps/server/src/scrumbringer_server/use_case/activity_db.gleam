//// Database operations for activity feeds.
////
//// Activity is read from the canonical audit log and mapped into the shared
//// `domain/activity` contract before it crosses the HTTP boundary.

import domain/activity/entity.{type ActivityEvent, ActivityEvent}
import domain/activity/id as activity_id
import domain/activity/kind as activity_kind
import domain/activity/subject.{type ActivitySubject, ActivityCard, ActivityTask}
import domain/audit_event/kind_codec as audit_kind
import domain/card/id as card_id
import domain/project/id as project_id
import domain/task/id as task_id
import domain/user/id as user_id
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pog

pub type ActivityError {
  UnknownAuditKind(String)
  InvalidSubject(String)
  DbError(pog.QueryError)
}

type ActivityRow {
  ActivityRow(
    id: Int,
    project_id: Int,
    subject_type: String,
    subject_id: Int,
    event_type: String,
    actor_user_id: Int,
    actor_label: String,
    related_subject_type: String,
    related_subject_id: Int,
    created_at: String,
  )
}

const task_activity_sql = "
select
  e.id::int as id,
  e.project_id::int as project_id,
  'task' as subject_type,
  e.task_id::int as subject_id,
  e.event_type,
  e.actor_user_id::int as actor_user_id,
  coalesce(nullif(u.email, ''), 'Unknown user') as actor_label,
  case when t.card_id is null then '' else 'card' end as related_subject_type,
  coalesce(t.card_id, 0)::int as related_subject_id,
  to_char(e.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from audit_events e
join tasks t on t.id = e.task_id
left join users u on u.id = e.actor_user_id
where e.task_id = $1
order by e.created_at desc, e.id desc
limit $2
"

const card_activity_sql = "
with recursive subtree as (
  select c.id
  from cards c
  where c.id = $1

  union all

  select child.id
  from cards child
  join subtree parent on parent.id = child.parent_card_id
),
events as (
  select
    e.id,
    e.project_id,
    'card' as subject_type,
    e.card_id as subject_id,
    e.event_type,
    e.actor_user_id,
    '' as related_subject_type,
    0 as related_subject_id,
    e.created_at
  from audit_events e
  where e.card_id in (select id from subtree)

  union all

  select
    e.id,
    e.project_id,
    'task' as subject_type,
    e.task_id as subject_id,
    e.event_type,
    e.actor_user_id,
    'card' as related_subject_type,
    t.card_id as related_subject_id,
    e.created_at
  from audit_events e
  join tasks t on t.id = e.task_id
  where t.card_id in (select id from subtree)
)
select
  events.id::int as id,
  events.project_id::int as project_id,
  events.subject_type,
  events.subject_id::int as subject_id,
  events.event_type,
  events.actor_user_id::int as actor_user_id,
  coalesce(nullif(u.email, ''), 'Unknown user') as actor_label,
  coalesce(events.related_subject_type, '') as related_subject_type,
  coalesce(events.related_subject_id, 0)::int as related_subject_id,
  to_char(events.created_at at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') as created_at
from events
left join users u on u.id = events.actor_user_id
order by events.created_at desc, events.id desc
limit $2
"

pub fn list_for_task(
  db: pog.Connection,
  task_id: Int,
  limit: Int,
) -> Result(List(ActivityEvent), ActivityError) {
  query_activity(db, task_activity_sql, task_id, limit)
}

pub fn list_for_card(
  db: pog.Connection,
  card_id: Int,
  limit: Int,
) -> Result(List(ActivityEvent), ActivityError) {
  query_activity(db, card_activity_sql, card_id, limit)
}

fn query_activity(
  db: pog.Connection,
  sql: String,
  subject_id: Int,
  limit: Int,
) -> Result(List(ActivityEvent), ActivityError) {
  use returned <- result.try(
    pog.query(sql)
    |> pog.parameter(pog.int(subject_id))
    |> pog.parameter(pog.int(limit))
    |> pog.returning(activity_row_decoder())
    |> pog.execute(db)
    |> result.map_error(DbError),
  )

  list.try_map(returned.rows, row_to_activity)
}

fn activity_row_decoder() -> decode.Decoder(ActivityRow) {
  use id <- decode.field(0, decode.int)
  use project_id <- decode.field(1, decode.int)
  use subject_type <- decode.field(2, decode.string)
  use subject_id <- decode.field(3, decode.int)
  use event_type <- decode.field(4, decode.string)
  use actor_user_id <- decode.field(5, decode.int)
  use actor_label <- decode.field(6, decode.string)
  use related_subject_type <- decode.field(7, decode.string)
  use related_subject_id <- decode.field(8, decode.int)
  use created_at <- decode.field(9, decode.string)

  decode.success(ActivityRow(
    id: id,
    project_id: project_id,
    subject_type: subject_type,
    subject_id: subject_id,
    event_type: event_type,
    actor_user_id: actor_user_id,
    actor_label: actor_label,
    related_subject_type: related_subject_type,
    related_subject_id: related_subject_id,
    created_at: created_at,
  ))
}

fn row_to_activity(row: ActivityRow) -> Result(ActivityEvent, ActivityError) {
  use subject <- result.try(parse_subject(row.subject_type, row.subject_id))
  use kind <- result.try(parse_activity_kind(row.event_type))
  use related_subject <- result.try(parse_related_subject(
    row.related_subject_type,
    row.related_subject_id,
  ))

  Ok(ActivityEvent(
    id: activity_id.new(row.id),
    project_id: project_id.new(row.project_id),
    subject: subject,
    kind: kind,
    actor_user_id: user_id.new(row.actor_user_id),
    actor_label: row.actor_label,
    summary: summary(kind),
    related_subject: related_subject,
    created_at: row.created_at,
  ))
}

fn parse_activity_kind(
  raw: String,
) -> Result(activity_kind.ActivityKind, ActivityError) {
  case audit_kind.parse(raw) {
    Ok(kind) -> Ok(activity_kind.from_audit_kind(kind))
    Error(other) -> Error(UnknownAuditKind(other))
  }
}

fn parse_subject(
  subject_type: String,
  subject_id: Int,
) -> Result(ActivitySubject, ActivityError) {
  case subject_type {
    "card" -> Ok(ActivityCard(card_id.new(subject_id)))
    "task" -> Ok(ActivityTask(task_id.new(subject_id)))
    other -> Error(InvalidSubject(other))
  }
}

fn parse_related_subject(
  subject_type: String,
  subject_id: Int,
) -> Result(Option(ActivitySubject), ActivityError) {
  case string.trim(subject_type), subject_id {
    "", _ -> Ok(None)
    "card", id if id > 0 -> Ok(Some(ActivityCard(card_id.new(id))))
    "task", id if id > 0 -> Ok(Some(ActivityTask(task_id.new(id))))
    other, _ -> Error(InvalidSubject(other))
  }
}

fn summary(kind: activity_kind.ActivityKind) -> String {
  case kind {
    activity_kind.CardActivated -> "Card activated"
    activity_kind.CardClosed -> "Card closed"
    activity_kind.CardMoved -> "Card moved"
    activity_kind.TaskCreated -> "Task created"
    activity_kind.TaskClaimed -> "Task claimed"
    activity_kind.TaskReleased -> "Task released"
    activity_kind.TaskClosed -> "Task closed"
    activity_kind.TaskDependencyAdded -> "Task dependency added"
    activity_kind.TaskDependencyRemoved -> "Task dependency removed"
    activity_kind.NoteCreated -> "Note created"
    activity_kind.NotePinned -> "Note pinned"
    activity_kind.NoteUnpinned -> "Note unpinned"
    activity_kind.DueDateChanged -> "Due date changed"
  }
}
