-- name: list_cards_for_project
SELECT
    c.id,
    c.project_id,
    c.title,
    coalesce(c.description, '') as description,
    c.created_by,
    to_char(c.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    COUNT(t.id)::int AS task_count,
    COUNT(t.id) FILTER (WHERE t.status = 'completed')::int AS completed_count,
    COUNT(t.id) FILTER (WHERE t.status = 'available')::int AS available_count
FROM cards c
LEFT JOIN tasks t ON t.card_id = c.id
WHERE c.project_id = $1
GROUP BY c.id
ORDER BY c.created_at DESC;
