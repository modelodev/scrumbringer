-- migrate:up
-- Story 3.2: Workflows engine v1

--------------------------------------------------------------------------------
-- 1. Workflows
--------------------------------------------------------------------------------

CREATE TABLE workflows (
    id BIGSERIAL PRIMARY KEY,
    org_id BIGINT NOT NULL REFERENCES organizations(id),
    project_id BIGINT REFERENCES projects(id),
    name TEXT NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT false,
    created_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(org_id, project_id, name)
);

CREATE INDEX idx_workflows_org ON workflows(org_id);
CREATE INDEX idx_workflows_project ON workflows(project_id);

--------------------------------------------------------------------------------
-- 2. Rules
--------------------------------------------------------------------------------

CREATE TABLE rules (
    id BIGSERIAL PRIMARY KEY,
    workflow_id BIGINT NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    goal TEXT,
    resource_type TEXT NOT NULL CHECK (resource_type IN ('task', 'card')),
    task_type_id BIGINT REFERENCES task_types(id),
    to_state TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rules_workflow ON rules(workflow_id);
CREATE INDEX idx_rules_active ON rules(active) WHERE active = true;

--------------------------------------------------------------------------------
-- 3. Task templates
--------------------------------------------------------------------------------

CREATE TABLE task_templates (
    id BIGSERIAL PRIMARY KEY,
    org_id BIGINT NOT NULL REFERENCES organizations(id),
    project_id BIGINT REFERENCES projects(id),
    name TEXT NOT NULL,
    description TEXT,
    type_id BIGINT NOT NULL REFERENCES task_types(id),
    priority INT NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    created_by BIGINT NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_templates_org ON task_templates(org_id);
CREATE INDEX idx_task_templates_project ON task_templates(project_id);

--------------------------------------------------------------------------------
-- 4. Rule templates (N:M)
--------------------------------------------------------------------------------

CREATE TABLE rule_templates (
    rule_id BIGINT NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
    template_id BIGINT NOT NULL REFERENCES task_templates(id) ON DELETE CASCADE,
    execution_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (rule_id, template_id)
);

--------------------------------------------------------------------------------
-- 5. Rule executions
--------------------------------------------------------------------------------

CREATE TABLE rule_executions (
    id BIGSERIAL PRIMARY KEY,
    rule_id BIGINT NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
    origin_type TEXT NOT NULL CHECK (origin_type IN ('task', 'card')),
    origin_id BIGINT NOT NULL,
    outcome TEXT NOT NULL CHECK (outcome IN ('applied', 'suppressed')),
    suppression_reason TEXT,
    user_id BIGINT REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(rule_id, origin_type, origin_id)
);

CREATE INDEX idx_rule_executions_rule ON rule_executions(rule_id);
CREATE INDEX idx_rule_executions_origin ON rule_executions(origin_type, origin_id);

-- migrate:down

DROP INDEX idx_rule_executions_origin;
DROP INDEX idx_rule_executions_rule;
DROP TABLE rule_executions;

DROP TABLE rule_templates;

DROP INDEX idx_task_templates_project;
DROP INDEX idx_task_templates_org;
DROP TABLE task_templates;

DROP INDEX idx_rules_active;
DROP INDEX idx_rules_workflow;
DROP TABLE rules;

DROP INDEX idx_workflows_project;
DROP INDEX idx_workflows_org;
DROP TABLE workflows;
