-- name: list_cards_for_project
SELECT
    c.id,
    c.project_id,
    c.title,
    coalesce(c.description, '') as description,
    coalesce(c.color, '') as color,
    coalesce(c.milestone_id, 0) as milestone_id,
    c.created_by,
    to_char(c.created_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as created_at,
    COUNT(t.id)::int AS task_count,
    COUNT(t.id) FILTER (WHERE t.status = 'completed')::int AS completed_count,
    COUNT(t.id) FILTER (WHERE t.status = 'available')::int AS available_count,
    case
      when max(n.created_at) is null then false
      when v.last_viewed_at is null then true
      when max(n.created_at) > v.last_viewed_at then true
      else false
    end as has_new_notes
FROM cards c
LEFT JOIN tasks t ON t.card_id = c.id
LEFT JOIN card_notes n ON n.card_id = c.id
LEFT JOIN user_card_views v ON v.card_id = c.id and v.user_id = $2
WHERE c.project_id = $1
GROUP BY c.id, v.last_viewed_at
ORDER BY c.created_at DESC;
