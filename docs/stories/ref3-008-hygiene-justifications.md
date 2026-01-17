# Story ref3-008: Justificaciones finales y cierre de higiene global

## Status: Draft

## Story
**As a** maintainer,
**I want** to document explicit justifications for any files kept >100 lines,
**so that** the hygiene rule is satisfied consistently and future reviewers understand exceptions.

## Acceptance Criteria
1. Any file remaining >100 lines after ref3-006 has a clear justification in `////` module docs.
2. Justifications are concise, in English, and explain why splitting is not practical.
3. No functional changes are introduced.
4. Tests pass.

## Tasks / Subtasks

- [ ] Identify remaining >100 line files after ref3-006
  - [ ] Build list from `docs/sprint-3-backlog.md` and updated repo state

- [ ] Add `////` justifications to each remaining >100 line file
  - [ ] Explain why split is not practical (generated code, tight cohesion, external constraints)
  - [ ] Keep justifications brief and factual

- [ ] Verification
  - [ ] Run `gleam test`
  - [ ] Run `make test`

## Dev Notes
- This story should run after ref3-006 to avoid redundant justification on files that will be split.
- Justification must appear in module docs at top of file.
- Only documentation changes allowed.

## Testing
- `gleam test`
- `make test`

## Change Log
| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-01-17 | 0.1 | Created ref3-008 story for hygiene justifications | assistant |

## Dev Agent Record

## QA Results
