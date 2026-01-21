-- project_members_update_role.sql
-- Update a project member's role with last-manager protection.
-- Parameters: $1 = project_id, $2 = user_id, $3 = new_role
-- Returns: user_id, email, role (new), previous_role, status
-- Status values:
--   'allowed' - Role was changed
--   'no_change' - Role unchanged (idempotent)
--   'last_manager' - Cannot demote last manager (caller should return 422)
-- Empty result = user not a member (caller should return 404)

WITH current_state AS (
  SELECT
    pm.role as old_role,
    u.email,
    (SELECT COUNT(*) FROM project_members WHERE project_id = $1 AND role = 'manager') as manager_count
  FROM project_members pm
  JOIN users u ON u.id = pm.user_id
  WHERE pm.project_id = $1 AND pm.user_id = $2
),
validation AS (
  SELECT
    old_role,
    email,
    manager_count,
    CASE
      -- Idempotent: no change needed
      WHEN old_role = $3 THEN 'no_change'
      -- Promotion (member → manager): always allowed
      WHEN old_role = 'member' AND $3 = 'manager' THEN 'allowed'
      -- Demotion with multiple managers: allowed
      WHEN old_role = 'manager' AND $3 = 'member' AND manager_count > 1 THEN 'allowed'
      -- Demotion with single manager: blocked
      WHEN old_role = 'manager' AND $3 = 'member' AND manager_count = 1 THEN 'last_manager'
      -- Fallback (shouldn't happen with valid roles)
      ELSE 'allowed'
    END as status
  FROM current_state
)
UPDATE project_members pm
SET role = CASE WHEN v.status = 'allowed' THEN $3 ELSE pm.role END
FROM validation v
WHERE pm.project_id = $1
  AND pm.user_id = $2
RETURNING
  pm.user_id,
  v.email,
  pm.role as role,
  v.old_role as previous_role,
  v.status;
