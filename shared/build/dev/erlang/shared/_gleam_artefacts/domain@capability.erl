-module(domain@capability).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/capability.gleam").
-export_type([capability/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Capability domain types for ScrumBringer.\n"
    "\n"
    " Defines capability structures used for skill-based task filtering.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/capability.{type Capability}\n"
    "\n"
    " let cap = Capability(id: 1, name: \"Backend Development\")\n"
    " ```\n"
).

-type capability() :: {capability, integer(), binary()}.


