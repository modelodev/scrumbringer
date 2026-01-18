-module(domain@project).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/project.gleam").
-export_type([project/0, project_member/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Project domain types for ScrumBringer.\n"
    "\n"
    " Defines project and project member structures.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/project.{type Project, type ProjectMember}\n"
    "\n"
    " let project = Project(id: 1, name: \"My Project\", my_role: \"admin\")\n"
    " ```\n"
).

-type project() :: {project, integer(), binary(), binary()}.

-type project_member() :: {project_member, integer(), binary(), binary()}.


