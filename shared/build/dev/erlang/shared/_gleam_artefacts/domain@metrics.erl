-module(domain@metrics).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/domain/metrics.gleam").
-export_type([my_metrics/0, org_metrics_bucket/0, org_metrics_project_overview/0, org_metrics_overview/0, metrics_project_task/0, org_metrics_project_tasks_payload/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Metrics domain types for ScrumBringer.\n"
    "\n"
    " Defines structures for personal, organization, and project metrics.\n"
    "\n"
    " ## Usage\n"
    "\n"
    " ```gleam\n"
    " import shared/domain/metrics.{type MyMetrics, type OrgMetricsOverview}\n"
    "\n"
    " let metrics = MyMetrics(window_days: 30, claimed_count: 10, released_count: 2, completed_count: 8)\n"
    " ```\n"
).

-type my_metrics() :: {my_metrics, integer(), integer(), integer(), integer()}.

-type org_metrics_bucket() :: {org_metrics_bucket, binary(), integer()}.

-type org_metrics_project_overview() :: {org_metrics_project_overview,
        integer(),
        binary(),
        integer(),
        integer(),
        integer(),
        gleam@option:option(integer()),
        gleam@option:option(integer())}.

-type org_metrics_overview() :: {org_metrics_overview,
        integer(),
        integer(),
        integer(),
        integer(),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        gleam@option:option(integer()),
        integer(),
        list(org_metrics_bucket()),
        list(org_metrics_bucket()),
        list(org_metrics_project_overview())}.

-type metrics_project_task() :: {metrics_project_task,
        domain@task:task(),
        integer(),
        integer(),
        integer(),
        gleam@option:option(binary())}.

-type org_metrics_project_tasks_payload() :: {org_metrics_project_tasks_payload,
        integer(),
        integer(),
        list(metrics_project_task())}.


