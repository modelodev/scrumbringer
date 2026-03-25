---
description: "Inspect available AWO workflows and runtime entrypoints. Usage: /awo-help [workflow_id]"
agent: "awo-runtime"
subtask: true
execution_mode: "isolated-runtime"
runtime_command: true
mutates_state: false
requires_context: false
---

# /awo-help

Use the isolated AWO runtime helper to inspect generated workflows without depending on the current session mode.

## Native runtime mode

You are in native OpenCode runtime mode.
Run exactly: /awo-run <workflow_id> [context]
Do not invoke /awo-run via bash or from a shell prompt. Use slash commands only.

## Command surface

- Signature: `/awo-help [workflow_id]`
- Raw arguments: `$ARGUMENTS`
- Optional `$1`: workflow id to inspect in detail
- Empty `$1` is valid and means list all enabled workflows

## Runtime executor contract

1. Run as an isolated runtime subtask using agent `awo-runtime`, not the current session mode.
2. Read `.awo/awo.yaml` and `.awo/generated/opencode/manifest.json`.
3. If `$1` is present, read `.awo/generated/opencode/workflows/$1/compiled_workflow.json` and summarize steps, dependencies, runtime skills, and the first recommended command.
4. If `$1` is absent, list enabled workflows with step counts and the next recommended runtime command for each workflow.
5. Do not execute steps, mutate runtime evidence, or invent missing workflows.

## Execution mode self-check

Before responding, determine how you are being executed:

- **Native slash command** (correct): you are running as an isolated OpenCode subtask via `awo-runtime` agent. Proceed normally.
- **Missing `awo-runtime` agent**: return `RUNTIME_COMMAND_UNAVAILABLE_IN_SESSION` and explain the agent is required.
- **Missing generated commands** (`.opencode/commands/awo-*.md` absent): include `error_code: RUNTIME_ASSETS_MISSING` and instruct the user to run `awo apply`.
- **Manual prompt-driven or external mediator**: include `execution_mode: manual_guided` or `execution_mode: external_mediated` in output and warn that native slash commands are preferred.

## Session errors

If the isolated runtime helper cannot be started, return a short explicit failure note with `RUNTIME_COMMAND_UNAVAILABLE_IN_SESSION` and explain that `/awo-help` requires the generated `awo-runtime` subagent.
