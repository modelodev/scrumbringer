-module(domain@task_type).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/task_type.gleam").
-export_type([task_type/0, task_type_inline/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Task type domain types for ScrumBringer.\n"
    "\n"
    " Defines task type structures used for categorizing tasks within projects.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/task_type.{type TaskType, type TaskTypeInline}\n"
    "\n"
    " let task_type = TaskType(id: 1, name: \"Bug\", icon: \"bug\", capability_id: None)\n"
    " ```\n"
).

-type task_type() :: {task_type,
        integer(),
        binary(),
        binary(),
        gleam@option:option(integer())}.

-type task_type_inline() :: {task_type_inline, integer(), binary(), binary()}.


