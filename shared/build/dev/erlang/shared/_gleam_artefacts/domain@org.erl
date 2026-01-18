-module(domain@org).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/org.gleam").
-export_type([org_user/0, org_invite/0, invite_link/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Organization domain types for ScrumBringer.\n"
    "\n"
    " Defines organization user, invite, and invite link structures.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/org.{type OrgUser, type OrgInvite, type InviteLink}\n"
    "\n"
    " let user = OrgUser(id: 1, email: \"user@example.com\", org_role: \"member\", created_at: \"2024-01-17T12:00:00Z\")\n"
    " ```\n"
).

-type org_user() :: {org_user, integer(), binary(), binary(), binary()}.

-type org_invite() :: {org_invite, binary(), binary(), binary()}.

-type invite_link() :: {invite_link,
        binary(),
        binary(),
        binary(),
        binary(),
        binary(),
        gleam@option:option(binary()),
        gleam@option:option(binary())}.


