-module(domain@api_error).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/api_error.gleam").
-export_type([api_error/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " API error domain types for ScrumBringer.\n"
    "\n"
    " Defines the common API error and result types used across client and server.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/api_error.{type ApiError, type ApiResult}\n"
    "\n"
    " case result {\n"
    "   Ok(data) -> use_data(data)\n"
    "   Error(ApiError(status: 404, code: \"NOT_FOUND\", message: msg)) -> show_not_found(msg)\n"
    "   Error(err) -> show_error(err.message)\n"
    " }\n"
    " ```\n"
).

-type api_error() :: {api_error, integer(), binary(), binary()}.


