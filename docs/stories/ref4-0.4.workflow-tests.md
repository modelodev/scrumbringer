# Story ref4-0.4: Tests de Workflows y Rules Engine

## Status: Ready

## Story

**As a** developer,
**I want** comprehensive tests for the workflows and rules engine,
**so that** I can safely refactor the complex workflow logic without breaking automation behavior.

## Acceptance Criteria

1. **Create workflow test**: Test verifies `create_workflow` succeeds with valid data.
2. **Create workflow duplicate test**: Test verifies `create_workflow` fails for duplicate name.
3. **Update workflow test**: Test verifies `update_workflow` succeeds for existing workflow.
4. **Cascade deactivation test**: Test verifies `set_active_cascade` deactivates child rules when workflow is deactivated.
5. **Delete workflow cascade test**: Test verifies `delete_workflow` succeeds and cascades to delete rules (FK uses ON DELETE CASCADE).
6. **Rule evaluation apply test**: Test verifies `evaluate_rule` applies a matching rule.
7. **Rule evaluation inactive test**: Test verifies `evaluate_rule` skips inactive rules.
8. **Rule evaluation idempotent test**: Test verifies `evaluate_rule` handles idempotent suppression.
9. **All tests pass in CI**: Tests run successfully via `make test`.

## Tasks / Subtasks

- [ ] Task 1: Create unit tests for workflows_db CRUD (AC: 1, 2, 3)
  - [ ] Create `apps/server/test/unit/services/workflows_db_test.gleam`
  - [ ] Test: `create_workflow_succeeds_with_valid_data_test`
  - [ ] Test: `create_workflow_fails_for_duplicate_name_test`
  - [ ] Test: `update_workflow_succeeds_for_existing_workflow_test`

- [ ] Task 2: Create unit tests for cascade behavior (AC: 4)
  - [ ] Test: `set_active_cascade_deactivates_children_test`
  - [ ] Test: `set_active_cascade_activates_children_test`

- [ ] Task 3: Create unit tests for delete behavior (AC: 5)
  - [ ] Test: `delete_workflow_succeeds_if_no_rules_test`
  - [ ] Test: `delete_workflow_cascades_deletes_rules_test`

- [ ] Task 4: Create unit tests for rules_engine evaluation (AC: 6, 7, 8)
  - [ ] Create `apps/server/test/unit/services/rules_engine_test.gleam`
  - [ ] Test: `evaluate_rule_applies_matching_rule_test`
  - [ ] Test: `evaluate_rule_skips_inactive_rule_test`
  - [ ] Test: `evaluate_rule_handles_idempotent_suppression_test`

- [ ] Task 5: Verify CI passes (AC: 9)
  - [ ] Run `make test` and verify all tests pass
  - [ ] Fix any test failures

## Dev Notes

### Source Tree (relevant to this story)

```
apps/server/
├── src/scrumbringer_server/
│   └── services/
│       ├── workflows_db.gleam    # READ: CRUD operations
│       ├── rules_db.gleam        # READ: rule operations
│       └── rules_engine.gleam    # READ: evaluate_rule
├── test/
│   └── unit/services/
│       ├── workflows_db_test.gleam  # CREATE
│       └── rules_engine_test.gleam  # CREATE
```

### Key Functions to Test

From `apps/server/src/scrumbringer_server/services/workflows_db.gleam`:

```gleam
pub fn create_workflow(
  db: pog.Connection,
  org_id: Int,
  project_id: Option(Int),
  name: String,
  description: String,
  active: Bool,
  created_by: Int,
) -> Result(Workflow, CreateWorkflowError)

pub fn update_workflow(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Option(Int),
  name: String,
  description: String,
  active: Int,
) -> Result(Workflow, UpdateWorkflowError)

pub fn set_active_cascade(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Option(Int),
  active: Bool,
) -> Result(Nil, UpdateWorkflowError)

pub fn delete_workflow(
  db: pog.Connection,
  workflow_id: Int,
  org_id: Int,
  project_id: Option(Int),
) -> Result(Nil, DeleteWorkflowError)
```

From `apps/server/src/scrumbringer_server/services/rules_engine.gleam`:

```gleam
pub fn evaluate_rule(
  db: pog.Connection,
  rule: Rule,
  event: Event,
  user_id: Option(Int),
) -> Result(RuleOutcome, EvaluationError)
```

### Error Types

```gleam
pub type CreateWorkflowError {
  CreateWorkflowAlreadyExists
  CreateWorkflowDbError(pog.QueryError)
}

pub type UpdateWorkflowError {
  UpdateWorkflowNotFound
  UpdateWorkflowAlreadyExists
  UpdateWorkflowDbError(pog.QueryError)
}

pub type DeleteWorkflowError {
  DeleteWorkflowNotFound
  DeleteWorkflowDbError(pog.QueryError)
}

pub type RuleOutcome {
  Applied(actions_taken: List(Action))
  Suppressed(reason: SuppressionReason)
}

pub type SuppressionReason {
  Idempotent
  NotUserTriggered
  NotMatching
  Inactive
}
```

### Test Pattern: Workflows DB

Uses `test/support/test_db.gleam` from ref4-0.1:

```gleam
// test/unit/services/workflows_db_test.gleam
import gleeunit
import gleeunit/should
import scrumbringer_server/services/workflows_db
import gleam/option.{None, Some}
import support/test_db

pub fn main() {
  gleeunit.main()
}

pub fn create_workflow_succeeds_with_valid_data_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: No workflow named "Test Workflow" exists
    let result = workflows_db.create_workflow(
      tx, 1, None, "Test Workflow", "desc", True, 1
    )

    // Then: Returns Ok(Workflow) with correct fields
    result |> should.be_ok()
  })
}

pub fn create_workflow_fails_for_duplicate_name_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: Create first workflow
    let _ = workflows_db.create_workflow(
      tx, 1, None, "Existing Workflow", "desc", True, 1
    )

    // When: Try to create duplicate
    let result = workflows_db.create_workflow(
      tx, 1, None, "Existing Workflow", "desc", True, 1
    )

    // Then: Returns Error(CreateWorkflowAlreadyExists)
    result |> should.be_error()
  })
}

pub fn set_active_cascade_deactivates_children_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: Workflow with active rules (setup required)
    // When: set_active_cascade(db, workflow_id, org_id, pid, False)
    // Then: Workflow and all rules are deactivated

    // Test implementation depends on having rules created first
    True |> should.be_true()
  })
}

pub fn delete_workflow_succeeds_if_no_rules_test() {
  let assert Ok(db) = test_db.get_test_connection()

  test_db.with_test_transaction(db, fn(tx) {
    // Given: Workflow with no rules
    let assert Ok(wf) = workflows_db.create_workflow(
      tx, 1, None, "To Delete", "desc", True, 1
    )

    // When: delete_workflow
    let result = workflows_db.delete_workflow(tx, wf.id, 1, None)

    // Then: Succeeds
    result |> should.be_ok()
  })
}
```

Note: `delete_workflow` uses `ON DELETE CASCADE` on rules FK, so workflows with rules CAN be deleted (rules are deleted too). Adjust AC5 test accordingly.

### Test Pattern: Rules Engine

```gleam
// test/unit/services/rules_engine_test.gleam
import gleeunit
import gleeunit/should
import scrumbringer_server/services/rules_engine

pub fn main() {
  gleeunit.main()
}

pub fn evaluate_rule_applies_matching_rule_test() {
  // Given: An active rule that matches the event criteria
  // When: evaluate_rule is called
  // Then: Returns Applied with list of actions

  True |> should.be_true()
}

pub fn evaluate_rule_skips_inactive_rule_test() {
  // Given: An inactive rule (active=False)
  // When: evaluate_rule is called
  // Then: Returns Suppressed(Inactive)

  True |> should.be_true()
}

pub fn evaluate_rule_handles_idempotent_suppression_test() {
  // Given: A rule that was already applied to this origin (task/card)
  // When: evaluate_rule is called again for same origin
  // Then: Returns Suppressed(Idempotent)

  True |> should.be_true()
}
```

### Database Schema Context

```sql
-- workflows table
CREATE TABLE workflows (
    id BIGSERIAL PRIMARY KEY,
    org_id BIGINT NOT NULL,
    project_id BIGINT,  -- NULL = org-scoped
    name TEXT NOT NULL,
    description TEXT,
    active BOOLEAN DEFAULT true,
    created_by BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(org_id, COALESCE(project_id, 0), name)
);

-- rules table
CREATE TABLE rules (
    id BIGSERIAL PRIMARY KEY,
    workflow_id BIGINT NOT NULL REFERENCES workflows(id),
    name TEXT NOT NULL,
    active BOOLEAN DEFAULT true,
    -- ... trigger, filter, action columns
);

-- rule_executions table (for idempotency check)
CREATE TABLE rule_executions (
    id BIGSERIAL PRIMARY KEY,
    rule_id BIGINT NOT NULL REFERENCES rules(id),
    origin_type TEXT NOT NULL,
    origin_id BIGINT NOT NULL,
    outcome TEXT NOT NULL,
    suppression_reason TEXT,
    user_id BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(rule_id, origin_type, origin_id)
);
```

### Dependencies

This story depends on:
- **ref4-0.1**: Test infrastructure must be in place

### Testing

**Test file location:**
- `apps/server/test/unit/services/workflows_db_test.gleam`
- `apps/server/test/unit/services/rules_engine_test.gleam`

**Framework:** gleeunit

**Run command:** `cd apps/server && gleam test`

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Story created from refactoring roadmap Fase 0.4 | po |

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## QA Results
