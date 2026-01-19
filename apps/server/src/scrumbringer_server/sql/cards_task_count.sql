-- name: count_tasks_for_card
SELECT COUNT(*)::int as task_count
FROM tasks
WHERE card_id = $1;
