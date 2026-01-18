-module(shared).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/shared.gleam").
-export([main/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Shared domain types package for ScrumBringer.\n"
    "\n"
    " This package contains canonical domain ADTs used by both client and server.\n"
    " Types are defined here to ensure consistency across the codebase.\n"
).

-file("src/shared.gleam", 6).
-spec main() -> nil.
main() ->
    nil.
