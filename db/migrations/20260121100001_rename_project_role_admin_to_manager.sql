-- migrate:up
-- Story 4.1: Rename project role 'admin' -> 'manager'

ALTER TABLE project_members DROP CONSTRAINT project_members_role_check;
UPDATE project_members SET role = 'manager' WHERE role = 'admin';
ALTER TABLE project_members ADD CONSTRAINT project_members_role_check
  CHECK (role IN ('manager', 'member'));

-- migrate:down

ALTER TABLE project_members DROP CONSTRAINT project_members_role_check;
UPDATE project_members SET role = 'admin' WHERE role = 'manager';
ALTER TABLE project_members ADD CONSTRAINT project_members_role_check
  CHECK (role IN ('member', 'admin'));
