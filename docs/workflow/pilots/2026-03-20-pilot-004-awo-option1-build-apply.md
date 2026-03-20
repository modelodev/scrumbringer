# Pilot 004 — AWO Option 1 Build/Apply

## Workflow
- wf_id: `scrumbringer_change_loop`
- version: `0.3.0`
- structural delta: added `interaction_review`

## Build/apply evidence
- `awo workflow show`: PASS
- `awo workflow graph --source`: PASS
- `awo build --target opencode --wf scrumbringer_change_loop --json`: PASS
- first `awo apply --target opencode --wf scrumbringer_change_loop --json`: FAIL with `DRIFT_BLOCK_CHANGED` on `AGENTS.md`
- workaround: remove stale `AWO:BEGIN/END` block from `AGENTS.md`
- second `awo apply --target opencode --wf scrumbringer_change_loop --json`: PASS

## Why this matters
- AWO exposed a real runtime-management issue instead of blindly overwriting files.
- The new workflow shape is structurally observable in graph/build/runtime artifacts.
- We now have a clean applied runtime for rerunning the same product request through OpenCode + AWO.
