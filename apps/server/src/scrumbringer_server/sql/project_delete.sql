-- name: project_delete
-- Delete a project and all related data (cascade)
-- Returns the deleted project id if successful
with
  deleted_rules as (
    delete from rules
    where workflow_id in (select id from workflows where project_id = $1)
  ),
  deleted_workflows as (
    delete from workflows where project_id = $1
  ),
  deleted_task_templates as (
    delete from task_templates where project_id = $1
  ),
  deleted_member_capabilities as (
    delete from member_capabilities
    where project_id = $1
  ),
  deleted_capabilities as (
    delete from capabilities where project_id = $1
  ),
  deleted_task_types as (
    delete from task_types where project_id = $1
  ),
  deleted_tasks as (
    delete from tasks
    where card_id in (select id from cards where project_id = $1)
  ),
  deleted_cards as (
    delete from cards where project_id = $1
  ),
  deleted_members as (
    delete from project_members where project_id = $1
  )
delete from projects
where id = $1
returning id;
