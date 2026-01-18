-module(domain@task).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/task.gleam").
-export_type([task/0, task_note/0, task_position/0, active_task/0, active_task_payload/0, task_filters/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Task domain types for ScrumBringer.\n"
    "\n"
    " Defines the core Task type and related structures for task management.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/task.{type Task, type TaskFilters}\n"
    " import shared/domain/task_status.{type TaskStatus}\n"
    "\n"
    " let filters = TaskFilters(status: Some(\"available\"), type_id: None, capability_id: None, q: None)\n"
    " ```\n"
).

-type task() :: {task,
        integer(),
        integer(),
        integer(),
        domain@task_type:task_type_inline(),
        gleam@option:option(domain@task_status:ongoing_by()),
        binary(),
        gleam@option:option(binary()),
        integer(),
        domain@task_status:task_status(),
        domain@task_status:work_state(),
        integer(),
        gleam@option:option(integer()),
        gleam@option:option(binary()),
        gleam@option:option(binary()),
        binary(),
        integer()}.

-type task_note() :: {task_note,
        integer(),
        integer(),
        integer(),
        binary(),
        binary()}.

-type task_position() :: {task_position,
        integer(),
        integer(),
        integer(),
        integer(),
        binary()}.

-type active_task() :: {active_task, integer(), integer(), binary(), integer()}.

-type active_task_payload() :: {active_task_payload,
        gleam@option:option(active_task()),
        binary()}.

-type task_filters() :: {task_filters,
        gleam@option:option(binary()),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        gleam@option:option(binary())}.


