# Story ref4-0.5: Tests para JSON Helpers y Mappers

## Status: Ready

## Story

**As a** developer,
**I want** tests for the JSON helper functions and Option mappers,
**so that** I can document expected behavior before moving these functions to shared modules in Fase 1.

## Acceptance Criteria

1. **option_int_json None test**: Test verifies `option_int_json(None)` returns `json.null()`.
2. **option_int_json Some test**: Test verifies `option_int_json(Some(42))` returns `json.int(42)`.
3. **option_string_json None test**: Test verifies `option_string_json(None)` returns `json.null()`.
4. **option_string_json Some test**: Test verifies `option_string_json(Some("hello"))` returns `json.string("hello")`.
5. **All tests pass in CI**: Tests run successfully via `make test`.

**Note on Mapper Functions**: The `int_to_option` and `string_to_option` functions are currently **private** (`fn` not `pub fn`) in multiple files. Testing them directly is not possible. They will be tested when extracted to `shared/src/helpers/option.gleam` in **Fase 1** (ref4-1.2). This story focuses on the **public** presenter functions only.

## Tasks / Subtasks

- [ ] Task 1: Create unit tests for JSON presenters (AC: 1, 2, 3, 4)
  - [ ] Create `apps/server/test/unit/presenters_test.gleam`
  - [ ] Test: `option_int_json_returns_null_for_none_test`
  - [ ] Test: `option_int_json_returns_int_for_some_test`
  - [ ] Test: `option_string_json_returns_null_for_none_test`
  - [ ] Test: `option_string_json_returns_string_for_some_test`

- [ ] Task 2: Verify CI passes (AC: 5)
  - [ ] Run `make test` and verify all tests pass
  - [ ] Fix any test failures

**Deferred to Fase 1**: Tests for `int_to_option` and `string_to_option` will be created when these functions are extracted to `shared/src/helpers/option.gleam` and made public (story ref4-1.2).

## Dev Notes

### Source Tree (relevant to this story)

```
apps/server/
├── src/scrumbringer_server/
│   └── http/tasks/
│       └── presenters.gleam      # READ: option_int_json, option_string_json (PUBLIC)
├── test/
│   └── unit/
│       └── presenters_test.gleam  # CREATE
```

**Note**: The `int_to_option` and `string_to_option` functions exist as **private** (`fn`) in 5 files:
- `services/rules_engine.gleam`
- `services/rule_metrics_db.gleam`
- `services/task_templates_db.gleam`
- `services/workflows_db.gleam`
- `services/rules_db.gleam`

These will be consolidated and made public in Fase 1 (ref4-1.2).

### Functions to Test

From `apps/server/src/scrumbringer_server/http/tasks/presenters.gleam`:

```gleam
pub fn option_int_json(value: Option(Int)) -> json.Json {
  case value {
    None -> json.null()
    Some(n) -> json.int(n)
  }
}

pub fn option_string_json(value: Option(String)) -> json.Json {
  case value {
    None -> json.null()
    Some(s) -> json.string(s)
  }
}
```

From `apps/server/src/scrumbringer_server/persistence/tasks/mappers.gleam` (and duplicates in other files):

```gleam
fn int_to_option(value: Int) -> Option(Int) {
  case value {
    0 -> None
    n -> Some(n)
  }
}

fn string_to_option(value: String) -> Option(String) {
  case value {
    "" -> None
    s -> Some(s)
  }
}
```

### Test Pattern: JSON Presenters

```gleam
// test/unit/presenters_test.gleam
import gleeunit
import gleeunit/should
import gleam/json
import gleam/option.{None, Some}
import scrumbringer_server/http/tasks/presenters

pub fn main() {
  gleeunit.main()
}

pub fn option_int_json_returns_null_for_none_test() {
  presenters.option_int_json(None)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_int_json_returns_int_for_some_test() {
  presenters.option_int_json(Some(42))
  |> json.to_string()
  |> should.equal("42")
}

pub fn option_string_json_returns_null_for_none_test() {
  presenters.option_string_json(None)
  |> json.to_string()
  |> should.equal("null")
}

pub fn option_string_json_returns_string_for_some_test() {
  presenters.option_string_json(Some("hello"))
  |> json.to_string()
  |> should.equal("\"hello\"")
}
```

### Deferred: Mapper Functions

The `int_to_option` and `string_to_option` functions are **private** and duplicated across 5 files. Testing them will be addressed in **Fase 1** when they are:
1. Extracted to `shared/src/helpers/option.gleam`
2. Made `pub fn` (public)
3. All duplicates removed

**Known edge cases to document in Fase 1 tests:**
- `int_to_option(0)` returns `None` - may be incorrect for valid zero values
- `string_to_option("")` returns `None` - may be incorrect for legitimate empty strings

### Dependencies

This story depends on:
- **ref4-0.1**: Test infrastructure must be in place

### Preparation for Fase 1

The presenter tests in this story serve as:
1. **Documentation** of current behavior
2. **Regression protection** when extracting to `shared/src/helpers/json.gleam`
3. **Contract specification** for the new shared modules

After Fase 1 extracts `option_int_json` and `option_string_json` to shared modules, update imports in tests to point to the new location.

### Testing

**Test file location:**
- `apps/server/test/unit/presenters_test.gleam`
- `apps/server/test/unit/mappers_test.gleam`

**Framework:** gleeunit

**Run command:** `cd apps/server && gleam test`

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-20 | 0.1 | Story created from refactoring roadmap Fase 0.5 | po |

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

## QA Results
