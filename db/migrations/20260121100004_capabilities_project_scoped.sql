-- migrate:up
-- Story 4.1: Capabilities become project-scoped + project_member_capabilities

-- Step 1: Drop old user_capabilities (org-scoped skills are lost)
DROP TABLE IF EXISTS user_capabilities;

-- Step 2: Migrate capabilities table
-- First drop dependent FKs from task_types
ALTER TABLE task_types DROP CONSTRAINT IF EXISTS task_types_capability_id_fkey;

-- Truncate capabilities (clean break)
TRUNCATE capabilities CASCADE;

-- Remove old constraints and indexes
ALTER TABLE capabilities DROP CONSTRAINT capabilities_name_org_id_key;
DROP INDEX IF EXISTS idx_capabilities_org;

-- Change org_id -> project_id
ALTER TABLE capabilities DROP COLUMN org_id;
ALTER TABLE capabilities ADD COLUMN project_id BIGINT NOT NULL REFERENCES projects(id);

-- Add new constraints
ALTER TABLE capabilities ADD CONSTRAINT capabilities_name_project_id_key UNIQUE(name, project_id);
CREATE INDEX idx_capabilities_project ON capabilities(project_id);

-- Restore task_types FK
ALTER TABLE task_types ADD CONSTRAINT task_types_capability_id_fkey
  FOREIGN KEY (capability_id) REFERENCES capabilities(id);

-- Step 3: Create new project_member_capabilities table
CREATE TABLE project_member_capabilities (
  project_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  capability_id BIGINT NOT NULL REFERENCES capabilities(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (project_id, user_id, capability_id),

  -- Ensure the user is a member of the project
  FOREIGN KEY (project_id, user_id) REFERENCES project_members(project_id, user_id) ON DELETE CASCADE
);

CREATE INDEX idx_project_member_capabilities_user ON project_member_capabilities(user_id);
CREATE INDEX idx_project_member_capabilities_capability ON project_member_capabilities(capability_id);

-- Step 4: Add trigger to ensure capability belongs to same project
CREATE OR REPLACE FUNCTION check_capability_project() RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM capabilities
    WHERE id = NEW.capability_id AND project_id = NEW.project_id
  ) THEN
    RAISE EXCEPTION 'Capability % does not belong to project %', NEW.capability_id, NEW.project_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_capability_project
  BEFORE INSERT OR UPDATE ON project_member_capabilities
  FOR EACH ROW EXECUTE FUNCTION check_capability_project();

-- migrate:down
-- WARNING: This will not restore org-scoped data

DROP TRIGGER IF EXISTS trg_check_capability_project ON project_member_capabilities;
DROP FUNCTION IF EXISTS check_capability_project();

DROP INDEX IF EXISTS idx_project_member_capabilities_capability;
DROP INDEX IF EXISTS idx_project_member_capabilities_user;
DROP TABLE IF EXISTS project_member_capabilities;

ALTER TABLE task_types DROP CONSTRAINT IF EXISTS task_types_capability_id_fkey;

DROP INDEX IF EXISTS idx_capabilities_project;
ALTER TABLE capabilities DROP CONSTRAINT capabilities_name_project_id_key;
ALTER TABLE capabilities DROP COLUMN project_id;
ALTER TABLE capabilities ADD COLUMN org_id BIGINT NOT NULL REFERENCES organizations(id);
ALTER TABLE capabilities ADD CONSTRAINT capabilities_name_org_id_key UNIQUE(name, org_id);
CREATE INDEX idx_capabilities_org ON capabilities(org_id);

ALTER TABLE task_types ADD CONSTRAINT task_types_capability_id_fkey
  FOREIGN KEY (capability_id) REFERENCES capabilities(id);

CREATE TABLE user_capabilities (
  user_id BIGINT NOT NULL REFERENCES users(id),
  capability_id BIGINT NOT NULL REFERENCES capabilities(id),
  PRIMARY KEY (user_id, capability_id)
);
CREATE INDEX idx_user_capabilities_user ON user_capabilities(user_id);
