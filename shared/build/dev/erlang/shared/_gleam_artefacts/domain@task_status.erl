-module(domain@task_status).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/task_status.gleam").
-export([parse_task_status/1, task_status_to_string/1, parse_work_state/1, from_db/2, to_db_status/1, to_db_ongoing/1, is_claimed/1, is_ongoing/1, parse_filter/1, to_filter_string/1]).
-export_type([task_status/0, claimed_state/0, work_state/0, ongoing_by/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Task status domain types for ScrumBringer.\n"
    "\n"
    " Provides type-safe task status representation using ADTs instead of strings.\n"
    " Ensures compile-time verification of status transitions and eliminates\n"
    " string comparison bugs.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/task_status.{\n"
    "   type TaskStatus, Available, Claimed, Completed, Ongoing, Taken,\n"
    " }\n"
    "\n"
    " case status {\n"
    "   Available -> \"Task is available\"\n"
    "   Claimed(Taken) -> \"Task is claimed but not being worked on\"\n"
    "   Claimed(Ongoing) -> \"Task is actively being worked on\"\n"
    "   Completed -> \"Task is done\"\n"
    " }\n"
    " ```\n"
).

-type task_status() :: available | {claimed, claimed_state()} | completed.

-type claimed_state() :: taken | ongoing.

-type work_state() :: work_available |
    work_claimed |
    work_ongoing |
    work_completed.

-type ongoing_by() :: {ongoing_by, integer()}.

-file("src/domain/task_status.gleam", 115).
?DOC(
    " Parse a task status string into TaskStatus.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " parse_task_status(\"available\")  // -> Ok(Available)\n"
    " parse_task_status(\"claimed\")    // -> Ok(Claimed(Taken))\n"
    " parse_task_status(\"ongoing\")    // -> Ok(Claimed(Ongoing))\n"
    " parse_task_status(\"completed\")  // -> Ok(Completed)\n"
    " parse_task_status(\"invalid\")    // -> Error(\"Unknown task status: invalid\")\n"
    " ```\n"
).
-spec parse_task_status(binary()) -> {ok, task_status()} | {error, binary()}.
parse_task_status(Value) ->
    case Value of
        <<"available"/utf8>> ->
            {ok, available};

        <<"claimed"/utf8>> ->
            {ok, {claimed, taken}};

        <<"ongoing"/utf8>> ->
            {ok, {claimed, ongoing}};

        <<"completed"/utf8>> ->
            {ok, completed};

        _ ->
            {error, <<"Unknown task status: "/utf8, Value/binary>>}
    end.

-file("src/domain/task_status.gleam", 135).
?DOC(
    " Convert TaskStatus to string for API.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " task_status_to_string(Available)        // -> \"available\"\n"
    " task_status_to_string(Claimed(Taken))   // -> \"claimed\"\n"
    " task_status_to_string(Claimed(Ongoing)) // -> \"ongoing\"\n"
    " task_status_to_string(Completed)        // -> \"completed\"\n"
    " ```\n"
).
-spec task_status_to_string(task_status()) -> binary().
task_status_to_string(Status) ->
    case Status of
        available ->
            <<"available"/utf8>>;

        {claimed, taken} ->
            <<"claimed"/utf8>>;

        {claimed, ongoing} ->
            <<"ongoing"/utf8>>;

        completed ->
            <<"completed"/utf8>>
    end.

-file("src/domain/task_status.gleam", 154).
?DOC(
    " Parse work state string into WorkState.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " parse_work_state(\"available\")  // -> WorkAvailable\n"
    " parse_work_state(\"claimed\")    // -> WorkClaimed\n"
    " parse_work_state(\"ongoing\")    // -> WorkOngoing\n"
    " parse_work_state(\"completed\")  // -> WorkCompleted\n"
    " ```\n"
).
-spec parse_work_state(binary()) -> work_state().
parse_work_state(Value) ->
    case Value of
        <<"available"/utf8>> ->
            work_available;

        <<"claimed"/utf8>> ->
            work_claimed;

        <<"ongoing"/utf8>> ->
            work_ongoing;

        <<"completed"/utf8>> ->
            work_completed;

        _ ->
            work_claimed
    end.

-file("src/domain/task_status.gleam", 181).
?DOC(
    " Parse task status from database columns.\n"
    "\n"
    " Maps the database representation (status string + is_ongoing bool) to\n"
    " the type-safe ADT.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " from_db(\"available\", False)  // -> Available\n"
    " from_db(\"claimed\", False)    // -> Claimed(Taken)\n"
    " from_db(\"claimed\", True)     // -> Claimed(Ongoing)\n"
    " from_db(\"completed\", False)  // -> Completed\n"
    " ```\n"
).
-spec from_db(binary(), boolean()) -> task_status().
from_db(Status, Is_ongoing) ->
    case {Status, Is_ongoing} of
        {<<"available"/utf8>>, _} ->
            available;

        {<<"claimed"/utf8>>, true} ->
            {claimed, ongoing};

        {<<"claimed"/utf8>>, false} ->
            {claimed, taken};

        {<<"completed"/utf8>>, _} ->
            completed;

        {_, _} ->
            available
    end.

-file("src/domain/task_status.gleam", 202).
?DOC(
    " Convert task status to database status string.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " to_db_status(Available)        // -> \"available\"\n"
    " to_db_status(Claimed(Taken))   // -> \"claimed\"\n"
    " to_db_status(Claimed(Ongoing)) // -> \"claimed\"\n"
    " to_db_status(Completed)        // -> \"completed\"\n"
    " ```\n"
).
-spec to_db_status(task_status()) -> binary().
to_db_status(Status) ->
    case Status of
        available ->
            <<"available"/utf8>>;

        {claimed, _} ->
            <<"claimed"/utf8>>;

        completed ->
            <<"completed"/utf8>>
    end.

-file("src/domain/task_status.gleam", 219).
?DOC(
    " Convert task status to database is_ongoing boolean.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " to_db_ongoing(Claimed(Ongoing)) // -> True\n"
    " to_db_ongoing(Claimed(Taken))   // -> False\n"
    " to_db_ongoing(Available)        // -> False\n"
    " ```\n"
).
-spec to_db_ongoing(task_status()) -> boolean().
to_db_ongoing(Status) ->
    case Status of
        {claimed, ongoing} ->
            true;

        _ ->
            false
    end.

-file("src/domain/task_status.gleam", 239).
?DOC(
    " Check if status represents a claimed task (either Taken or Ongoing).\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " is_claimed(Claimed(Taken))   // -> True\n"
    " is_claimed(Claimed(Ongoing)) // -> True\n"
    " is_claimed(Available)        // -> False\n"
    " ```\n"
).
-spec is_claimed(task_status()) -> boolean().
is_claimed(Status) ->
    case Status of
        {claimed, _} ->
            true;

        _ ->
            false
    end.

-file("src/domain/task_status.gleam", 254).
?DOC(
    " Check if status represents an actively worked task.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " is_ongoing(Claimed(Ongoing)) // -> True\n"
    " is_ongoing(Claimed(Taken))   // -> False\n"
    " ```\n"
).
-spec is_ongoing(task_status()) -> boolean().
is_ongoing(Status) ->
    case Status of
        {claimed, ongoing} ->
            true;

        _ ->
            false
    end.

-file("src/domain/task_status.gleam", 271).
?DOC(
    " Parse status filter from query parameter string.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " parse_filter(\"available\")  // -> Ok(Available)\n"
    " parse_filter(\"claimed\")    // -> Ok(Claimed(Taken))\n"
    " parse_filter(\"completed\")  // -> Ok(Completed)\n"
    " parse_filter(\"invalid\")    // -> Error(Nil)\n"
    " ```\n"
).
-spec parse_filter(binary()) -> {ok, task_status()} | {error, nil}.
parse_filter(Value) ->
    case Value of
        <<"available"/utf8>> ->
            {ok, available};

        <<"claimed"/utf8>> ->
            {ok, {claimed, taken}};

        <<"completed"/utf8>> ->
            {ok, completed};

        _ ->
            {error, nil}
    end.

-file("src/domain/task_status.gleam", 288).
?DOC(
    " Convert status to filter query string for database.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " to_filter_string(Available) // -> \"available\"\n"
    " to_filter_string(Claimed(_)) // -> \"claimed\"\n"
    " ```\n"
).
-spec to_filter_string(task_status()) -> binary().
to_filter_string(Status) ->
    to_db_status(Status).
