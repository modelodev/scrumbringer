import gleam/dynamic/decode
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import pog

pub type MetricsError {
  DbError(pog.QueryError)
  NotFound
  MetricsUnavailable
}

pub type WorkflowCount {
  WorkflowCount(name: Option(String), count: Int)
}

pub type ExecutionHealth {
  ExecutionHealth(
    avg_rebotes: Int,
    avg_pool_lifetime_s: Int,
    avg_executors: Int,
  )
}

pub type MilestoneMetrics {
  MilestoneMetrics(
    cards_total: Int,
    cards_completed: Int,
    tasks_total: Int,
    tasks_completed: Int,
    tasks_available: Int,
    tasks_claimed: Int,
    tasks_ongoing: Int,
    health: ExecutionHealth,
    workflows: List(WorkflowCount),
    most_activated: Option(String),
  )
}

pub type CardMetrics {
  CardMetrics(
    tasks_total: Int,
    tasks_completed: Int,
    tasks_available: Int,
    tasks_claimed: Int,
    tasks_ongoing: Int,
    health: ExecutionHealth,
    workflows: List(WorkflowCount),
    most_activated: Option(String),
  )
}

pub type TaskMetrics {
  TaskMetrics(
    claim_count: Int,
    release_count: Int,
    unique_executors: Int,
    first_claim_at: Option(String),
    current_state_duration_s: Int,
    pool_lifetime_s: Int,
    session_count: Int,
    total_work_time_s: Int,
  )
}

pub fn get_milestone_metrics(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(MilestoneMetrics, MetricsError) {
  use _ <- result.try(require_metrics_columns(db))
  use summary <- result.try(fetch_milestone_summary(db, milestone_id))
  use workflows <- result.try(fetch_milestone_workflows(db, milestone_id))

  Ok(MilestoneMetrics(
    cards_total: summary.cards_total,
    cards_completed: summary.cards_completed,
    tasks_total: summary.tasks_total,
    tasks_completed: summary.tasks_completed,
    tasks_available: summary.tasks_available,
    tasks_claimed: summary.tasks_claimed,
    tasks_ongoing: summary.tasks_ongoing,
    health: ExecutionHealth(
      avg_rebotes: summary.avg_rebotes,
      avg_pool_lifetime_s: summary.avg_pool_lifetime_s,
      avg_executors: summary.avg_executors,
    ),
    workflows: workflows,
    most_activated: most_activated_workflow(workflows),
  ))
}

pub fn get_card_metrics(
  db: pog.Connection,
  card_id: Int,
) -> Result(CardMetrics, MetricsError) {
  use _ <- result.try(require_metrics_columns(db))
  use summary <- result.try(fetch_card_summary(db, card_id))
  use workflows <- result.try(fetch_card_workflows(db, card_id))

  Ok(CardMetrics(
    tasks_total: summary.tasks_total,
    tasks_completed: summary.tasks_completed,
    tasks_available: summary.tasks_available,
    tasks_claimed: summary.tasks_claimed,
    tasks_ongoing: summary.tasks_ongoing,
    health: ExecutionHealth(
      avg_rebotes: summary.avg_rebotes,
      avg_pool_lifetime_s: summary.avg_pool_lifetime_s,
      avg_executors: summary.avg_executors,
    ),
    workflows: workflows,
    most_activated: most_activated_workflow(workflows),
  ))
}

pub fn get_task_metrics(
  db: pog.Connection,
  task_id: Int,
) -> Result(TaskMetrics, MetricsError) {
  use _ <- result.try(require_metrics_columns(db))

  let query =
    "
    with task_scope as (
      select
        t.id,
        t.pool_lifetime_s,
        t.created_at,
        coalesce((
          select max(e.created_at)
          from task_events e
          where e.task_id = t.id
        ), t.created_at) as last_state_change_at
      from tasks t
      where t.id = $1
    ), event_counts as (
      select
        e.task_id,
        coalesce(sum(case when e.event_type = 'task_claimed' then 1 else 0 end), 0)::int as claim_count,
        coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0)::int as release_count,
        coalesce(count(distinct case when e.event_type = 'task_claimed' then e.actor_user_id else null end), 0)::int as unique_executors,
        coalesce(to_char(min(case when e.event_type = 'task_claimed' then e.created_at else null end) at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), '') as first_claim_at
      from task_events e
      where e.task_id = $1
      group by e.task_id
    ), sessions as (
      select
        coalesce((select count(*)::int from user_task_work_session s where s.task_id = $1), 0) as session_count,
        coalesce((select sum(wt.accumulated_s)::int from user_task_work_total wt where wt.task_id = $1), 0) as total_work_time_s
    )
    select
      coalesce(ec.claim_count, 0) as claim_count,
      coalesce(ec.release_count, 0) as release_count,
      coalesce(ec.unique_executors, 0) as unique_executors,
      coalesce(ec.first_claim_at, '') as first_claim_at,
      greatest(0, extract(epoch from (now() - ts.last_state_change_at))::int) as current_state_duration_s,
      ts.pool_lifetime_s,
      ss.session_count,
      ss.total_work_time_s
    from task_scope ts
    left join event_counts ec on ec.task_id = ts.id
    cross join sessions ss
  "

  let decoder = {
    use claim_count <- decode.field(0, decode.int)
    use release_count <- decode.field(1, decode.int)
    use unique_executors <- decode.field(2, decode.int)
    use first_claim_at <- decode.field(3, decode.string)
    use current_state_duration_s <- decode.field(4, decode.int)
    use pool_lifetime_s <- decode.field(5, decode.int)
    use session_count <- decode.field(6, decode.int)
    use total_work_time_s <- decode.field(7, decode.int)
    decode.success(TaskMetrics(
      claim_count:,
      release_count:,
      unique_executors:,
      first_claim_at: string_to_option(first_claim_at),
      current_state_duration_s:,
      pool_lifetime_s:,
      session_count:,
      total_work_time_s:,
    ))
  }

  case
    pog.query(query)
    |> pog.parameter(pog.int(task_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> Ok(row)
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

type MilestoneSummary {
  MilestoneSummary(
    cards_total: Int,
    cards_completed: Int,
    tasks_total: Int,
    tasks_completed: Int,
    tasks_available: Int,
    tasks_claimed: Int,
    tasks_ongoing: Int,
    avg_rebotes: Int,
    avg_pool_lifetime_s: Int,
    avg_executors: Int,
  )
}

type CardSummary {
  CardSummary(
    tasks_total: Int,
    tasks_completed: Int,
    tasks_available: Int,
    tasks_claimed: Int,
    tasks_ongoing: Int,
    avg_rebotes: Int,
    avg_pool_lifetime_s: Int,
    avg_executors: Int,
  )
}

fn fetch_milestone_summary(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(MilestoneSummary, MetricsError) {
  let query =
    "
    with cards_scope as (
      select c.id
      from cards c
      where c.milestone_id = $1
    ), card_completion as (
      select
        c.id,
        count(t.id)::int as task_count,
        count(*) filter (where t.status = 'completed')::int as completed_count
      from cards_scope c
      left join tasks t on t.card_id = c.id
      group by c.id
    ), tasks_scope as (
      select
        t.id,
        t.status,
        t.pool_lifetime_s,
        exists(
          select 1
          from user_task_work_session ws
          where ws.task_id = t.id and ws.ended_at is null
        ) as is_ongoing
      from tasks t
      where t.milestone_id = $1
        or t.card_id in (select id from cards_scope)
    ), event_stats as (
      select
        t.id as task_id,
        coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0)::int as release_count,
        coalesce(count(distinct case when e.event_type = 'task_claimed' then e.actor_user_id else null end), 0)::int as unique_executors
      from tasks_scope t
      left join task_events e on e.task_id = t.id
      group by t.id
    )
    select
      (select count(*)::int from cards_scope) as cards_total,
      (select count(*)::int from card_completion where task_count > 0 and task_count = completed_count) as cards_completed,
      (select count(*)::int from tasks_scope) as tasks_total,
      (select count(*)::int from tasks_scope where status = 'completed') as tasks_completed,
      (select count(*)::int from tasks_scope where status = 'available') as tasks_available,
      (select count(*)::int from tasks_scope where status = 'claimed' and not is_ongoing) as tasks_claimed,
      (select count(*)::int from tasks_scope where status = 'claimed' and is_ongoing) as tasks_ongoing,
      coalesce((select round(avg(release_count))::int from event_stats), 0) as avg_rebotes,
      coalesce((select round(avg(pool_lifetime_s))::int from tasks_scope), 0) as avg_pool_lifetime_s,
      coalesce((select round(avg(unique_executors))::int from event_stats), 0) as avg_executors
  "

  let decoder = {
    use cards_total <- decode.field(0, decode.int)
    use cards_completed <- decode.field(1, decode.int)
    use tasks_total <- decode.field(2, decode.int)
    use tasks_completed <- decode.field(3, decode.int)
    use tasks_available <- decode.field(4, decode.int)
    use tasks_claimed <- decode.field(5, decode.int)
    use tasks_ongoing <- decode.field(6, decode.int)
    use avg_rebotes <- decode.field(7, decode.int)
    use avg_pool_lifetime_s <- decode.field(8, decode.int)
    use avg_executors <- decode.field(9, decode.int)
    decode.success(MilestoneSummary(
      cards_total:,
      cards_completed:,
      tasks_total:,
      tasks_completed:,
      tasks_available:,
      tasks_claimed:,
      tasks_ongoing:,
      avg_rebotes:,
      avg_pool_lifetime_s:,
      avg_executors:,
    ))
  }

  case
    pog.query(query)
    |> pog.parameter(pog.int(milestone_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      case milestone_exists(db, milestone_id) {
        Ok(True) -> Ok(row)
        Ok(False) -> Error(NotFound)
        Error(e) -> Error(DbError(e))
      }
    }
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn fetch_card_summary(
  db: pog.Connection,
  card_id: Int,
) -> Result(CardSummary, MetricsError) {
  let query =
    "
    with tasks_scope as (
      select
        t.id,
        t.status,
        t.pool_lifetime_s,
        exists(
          select 1
          from user_task_work_session ws
          where ws.task_id = t.id and ws.ended_at is null
        ) as is_ongoing
      from tasks t
      where t.card_id = $1
    ), event_stats as (
      select
        t.id as task_id,
        coalesce(sum(case when e.event_type = 'task_released' then 1 else 0 end), 0)::int as release_count,
        coalesce(count(distinct case when e.event_type = 'task_claimed' then e.actor_user_id else null end), 0)::int as unique_executors
      from tasks_scope t
      left join task_events e on e.task_id = t.id
      group by t.id
    )
    select
      (select count(*)::int from tasks_scope) as tasks_total,
      (select count(*)::int from tasks_scope where status = 'completed') as tasks_completed,
      (select count(*)::int from tasks_scope where status = 'available') as tasks_available,
      (select count(*)::int from tasks_scope where status = 'claimed' and not is_ongoing) as tasks_claimed,
      (select count(*)::int from tasks_scope where status = 'claimed' and is_ongoing) as tasks_ongoing,
      coalesce((select round(avg(release_count))::int from event_stats), 0) as avg_rebotes,
      coalesce((select round(avg(pool_lifetime_s))::int from tasks_scope), 0) as avg_pool_lifetime_s,
      coalesce((select round(avg(unique_executors))::int from event_stats), 0) as avg_executors
  "

  let decoder = {
    use tasks_total <- decode.field(0, decode.int)
    use tasks_completed <- decode.field(1, decode.int)
    use tasks_available <- decode.field(2, decode.int)
    use tasks_claimed <- decode.field(3, decode.int)
    use tasks_ongoing <- decode.field(4, decode.int)
    use avg_rebotes <- decode.field(5, decode.int)
    use avg_pool_lifetime_s <- decode.field(6, decode.int)
    use avg_executors <- decode.field(7, decode.int)
    decode.success(CardSummary(
      tasks_total:,
      tasks_completed:,
      tasks_available:,
      tasks_claimed:,
      tasks_ongoing:,
      avg_rebotes:,
      avg_pool_lifetime_s:,
      avg_executors:,
    ))
  }

  case
    pog.query(query)
    |> pog.parameter(pog.int(card_id))
    |> pog.returning(decoder)
    |> pog.execute(db)
  {
    Ok(pog.Returned(rows: [row, ..], ..)) -> {
      case card_exists(db, card_id) {
        Ok(True) -> Ok(row)
        Ok(False) -> Error(NotFound)
        Error(e) -> Error(DbError(e))
      }
    }
    Ok(pog.Returned(rows: [], ..)) -> Error(NotFound)
    Error(e) -> Error(DbError(e))
  }
}

fn fetch_milestone_workflows(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(List(WorkflowCount), MetricsError) {
  let query =
    "
    select
      coalesce(w.name, '') as workflow_name,
      count(*)::int as task_count
    from tasks t
    left join rules r on r.id = t.created_from_rule_id
    left join workflows w on w.id = r.workflow_id
    where t.milestone_id = $1
      or t.card_id in (
        select c.id
        from cards c
        where c.milestone_id = $1
      )
    group by coalesce(w.name, '')
    order by task_count desc, workflow_name asc
  "

  query_workflows(db, query, milestone_id)
}

fn fetch_card_workflows(
  db: pog.Connection,
  card_id: Int,
) -> Result(List(WorkflowCount), MetricsError) {
  let query =
    "
    select
      coalesce(w.name, '') as workflow_name,
      count(*)::int as task_count
    from tasks t
    left join rules r on r.id = t.created_from_rule_id
    left join workflows w on w.id = r.workflow_id
    where t.card_id = $1
    group by coalesce(w.name, '')
    order by task_count desc, workflow_name asc
  "

  query_workflows(db, query, card_id)
}

fn query_workflows(
  db: pog.Connection,
  query: String,
  id: Int,
) -> Result(List(WorkflowCount), MetricsError) {
  let decoder = {
    use workflow_name <- decode.field(0, decode.string)
    use count <- decode.field(1, decode.int)
    decode.success(WorkflowCount(
      name: string_to_option(workflow_name),
      count: count,
    ))
  }

  pog.query(query)
  |> pog.parameter(pog.int(id))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(DbError)
}

fn require_metrics_columns(db: pog.Connection) -> Result(Nil, MetricsError) {
  let query =
    "
    select count(*)::int as present
    from information_schema.columns
    where table_name = 'tasks'
      and column_name in ('pool_lifetime_s', 'last_entered_pool_at', 'created_from_rule_id')
  "

  let decoder = {
    use present <- decode.field(0, decode.int)
    decode.success(present)
  }

  case pog.query(query) |> pog.returning(decoder) |> pog.execute(db) {
    Ok(pog.Returned(rows: [present, ..], ..)) ->
      case present == 3 {
        True -> Ok(Nil)
        False -> Error(MetricsUnavailable)
      }
    Ok(_) -> Error(MetricsUnavailable)
    Error(e) -> Error(DbError(e))
  }
}

fn milestone_exists(
  db: pog.Connection,
  milestone_id: Int,
) -> Result(Bool, pog.QueryError) {
  exists_query(
    db,
    "select exists(select 1 from milestones where id = $1)",
    milestone_id,
  )
}

fn card_exists(db: pog.Connection, card_id: Int) -> Result(Bool, pog.QueryError) {
  exists_query(db, "select exists(select 1 from cards where id = $1)", card_id)
}

fn exists_query(
  db: pog.Connection,
  query: String,
  id: Int,
) -> Result(Bool, pog.QueryError) {
  let decoder = {
    use value <- decode.field(0, decode.bool)
    decode.success(value)
  }

  pog.query(query)
  |> pog.parameter(pog.int(id))
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map(fn(returned) {
    case returned.rows {
      [value, ..] -> value
      [] -> False
    }
  })
}

fn most_activated_workflow(workflows: List(WorkflowCount)) -> Option(String) {
  case workflows {
    [WorkflowCount(name: name, ..), ..] -> name
    [] -> None
  }
}

fn string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    other -> Some(other)
  }
}

pub fn percent(completed: Int, total: Int) -> Int {
  case total {
    0 -> 0
    _ -> completed * 100 / total
  }
}

pub fn workflow_name_or_default(name: Option(String)) -> String {
  case name {
    Some(value) -> value
    None -> "sin_workflow"
  }
}

pub fn id_to_string(id: Int) -> String {
  int.to_string(id)
}
