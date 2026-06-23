%% Test-only final cleanup gates for HT-12.
-module(final_cleanup_ht12_ffi).
-export([violations/1]).

violations(Check) when is_binary(Check) ->
    Root = repo_root(),
    case binary_to_list(Check) of
        "legacy_terms_do_not_exist_in_active_shared_server_client_code" ->
            legacy_term_violations(Root);
        "active_code_respects_final_architecture_boundaries" ->
            architecture_boundary_violations(Root);
        "domain_types_are_not_duplicated_in_server_or_client" ->
            domain_type_duplication_violations(Root);
        "api_contracts_live_under_shared_api" ->
            api_contract_violations(Root);
        "use_cases_do_not_live_in_generic_services" ->
            generic_services_violations(Root);
        "codecs_use_aspect_or_contract_codec_suffix" ->
            codec_suffix_violations(Root);
        "mutating_use_cases_persist_state_and_audit_event_atomically" ->
            transactional_audit_violations(Root);
        "mutating_use_cases_do_not_emit_audit_event_on_conflict" ->
            conflict_audit_violations(Root);
        "lustre_mutations_update_model_from_api_response" ->
            lustre_api_response_violations(Root);
        "lustre_update_does_not_reimplement_server_transaction_rules" ->
            lustre_transaction_rule_violations(Root);
        "legacy_routes_are_absent" ->
            legacy_route_violations(Root);
        "schema_final_has_no_legacy_tables_or_columns" ->
            schema_legacy_storage_violations(Root);
        "schema_final_enforces_canonical_data_model_invariants" ->
            schema_canonical_data_model_violations(Root);
        "seed_data_uses_hierarchy_and_root_pool_tasks" ->
            seed_hierarchy_violations(Root);
        "seed_data_covers_card_profiles_due_dates_and_closed_outcomes" ->
            seed_profiles_violations(Root);
        "ui_validation_covers_main_flows_and_responsive_states" ->
            ui_validation_violations(Root);
        "seed_data_covers_roles_permissions_and_capabilities" ->
            seed_roles_violations(Root);
        "seed_data_covers_healthy_and_saturated_pool_limits" ->
            seed_limits_violations(Root);
        "full_flow_smoke_test_for_manager_and_member" ->
            smoke_flow_violations(Root);
        "docs_and_i18n_do_not_expose_legacy_concepts" ->
            docs_i18n_violations(Root);
        "audit_events_replace_task_events_as_live_model" ->
            audit_replaces_task_events_violations(Root);
        "audit_event_kind_codec_roundtrip" ->
            audit_kind_codec_violations(Root);
        "metrics_are_derived_from_audit_events_not_task_events" ->
            metrics_audit_source_violations(Root);
        "legacy_metrics_are_removed_or_replaced_by_card_rollup_metrics" ->
            legacy_metrics_violations(Root);
        "final_full_refactor_review_has_no_required_changes_left" ->
            refactor_review_violations(Root);
        "final_cleanup_removes_obsolete_unnecessary_and_incompatible_code" ->
            obsolete_code_violations(Root);
        Unknown ->
            [bin(["unknown HT-12 gate: ", Unknown])]
    end.

repo_root() ->
    {ok, Cwd} = file:get_cwd(),
    filename:absname("../..", Cwd).

legacy_term_violations(Root) ->
    Terms = [
        legacy_bin(), title_legacy_bin(), legacy_plural_bin(), legacy_id_bin(),
        bin(["Card", "State"]), bin(["Pen", "diente"]),
        bin(["En", "Curso"]), bin(["Cer", "rada"]),
        bin(["Task", "Status"])
    ],
    files_containing(Root, active_code_roots(), Terms, source_exts()).

architecture_boundary_violations(Root) ->
    require_dirs(Root, [
        "shared/src/domain/card",
        "shared/src/domain/task",
        "shared/src/api/cards",
        "shared/src/api/tasks",
        "apps/server/src/scrumbringer_server/http",
        "apps/server/src/scrumbringer_server/repository",
        "apps/server/src/scrumbringer_server/use_case"
    ]) ++ forbid_dirs(Root, [
        "apps/server/src/scrumbringer_server/services",
        "apps/server/src/scrumbringer_server/persistence",
        "apps/client/src/scrumbringer_client/features/" ++ legacy_plural()
    ]).

domain_type_duplication_violations(Root) ->
    files_containing(Root, [
        "apps/server/src",
        "apps/client/src"
    ], [
        <<"pub type Task(">>,
        <<"pub type Card(">>,
        <<"pub type Project(">>,
        <<"pub type User(">>,
        <<"pub type ApiToken(">>
    ], source_exts()).

api_contract_violations(Root) ->
    require_dirs(Root, ["shared/src/api"]) ++
    files_containing(Root, [
        "apps/server/src",
        "apps/client/src"
    ], [
        <<"pub type CreateCardRequest">>,
        <<"pub type MoveCardRequest">>,
        <<"pub type ActivateCardRequest">>,
        <<"pub type CloseCardRequest">>,
        <<"pub type CreateTaskRequest">>
    ], source_exts()).

generic_services_violations(Root) ->
    forbid_dirs(Root, ["apps/server/src/scrumbringer_server/services"]).

codec_suffix_violations(Root) ->
    [bin(["codec file must use *_codec.gleam suffix: ", Path])
     || Path <- all_files(Root, ["shared/src"], source_exts()),
        filename:basename(Path) =:= "codec.gleam"].

transactional_audit_violations(Root) ->
    require_files(Root, [
        "apps/server/src/scrumbringer_server/use_case/card_activate.gleam",
        "apps/server/src/scrumbringer_server/use_case/card_close.gleam",
        "apps/server/src/scrumbringer_server/use_case/task_claim.gleam",
        "apps/server/src/scrumbringer_server/use_case/task_release.gleam",
        "apps/server/src/scrumbringer_server/use_case/task_complete.gleam",
        "apps/server/src/scrumbringer_server/repository/audit_events.gleam"
    ]) ++ require_content(Root, [
        "apps/server/src/scrumbringer_server/use_case/card_activate.gleam",
        "apps/server/src/scrumbringer_server/use_case/card_close.gleam",
        "apps/server/src/scrumbringer_server/use_case/task_claim.gleam",
        "apps/server/src/scrumbringer_server/use_case/task_release.gleam",
        "apps/server/src/scrumbringer_server/use_case/task_complete.gleam"
    ], [<<"transaction">>, <<"audit">>]).

conflict_audit_violations(Root) ->
    require_tests(Root, [
        "do_not_emit_audit_event_on_conflict",
        "conflict_does_not_emit_audit"
    ]).

lustre_api_response_violations(Root) ->
    files_missing_any(Root, [
        "apps/client/src/scrumbringer_client"
    ], [<<"ApiReturned">>, <<"from_api_response">>, <<"replace_from_response">>], source_exts()).

lustre_transaction_rule_violations(Root) ->
    files_containing(Root, [
        "apps/client/src/scrumbringer_client"
    ], [
        <<"recompute_completion">>,
        <<"transaction">>,
        <<"emit_audit">>
    ], source_exts()).

legacy_route_violations(Root) ->
    files_containing(Root, [
        "apps/server/src",
        "apps/server/test"
    ], [
        bin(["/", legacy_plural()]),
        bin(["/", legacy_plural(), "/"]),
        bin([legacy_plural(), "_http_test"]),
        bin([legacy_plural(), "_payloads_test"])
    ], source_exts()).

schema_legacy_storage_violations(Root) ->
    files_containing(Root, [
        "db/schema.sql"
    ], [
        legacy_plural_bin(),
        legacy_id_bin()
    ], [".sql"]).

schema_canonical_data_model_violations(Root) ->
    Path = filename:join(Root, "db/schema.sql"),
    case read_file(Path) of
        {ok, Text} ->
            forbidden_schema_terms(Text) ++ required_schema_terms(Text);
        error ->
            [<<"missing db/schema.sql">>]
    end.

forbidden_schema_terms(Text) ->
    LegacyStateText = schema_text_without_rule_trigger_kinds(Text),
    Forbidden = [
        <<"status text DEFAULT 'available'::text NOT NULL">>,
        <<"tasks_status_check">>,
        <<"idx_tasks_status">>,
        <<"idx_tasks_card_status">>,
        <<" NOT VALID">>,
        <<"task_completed">>,
        <<"task_done">>,
        <<"origin_type">>,
        <<"origin_id">>
    ],
    [bin(["db/schema.sql contains forbidden final-schema term: ", Term])
     || Term <- Forbidden,
        binary:match(LegacyStateText, Term) =/= nomatch].

schema_text_without_rule_trigger_kinds(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    Kept = [Line || Line <- Lines,
                    binary:match(Line, <<"rules_trigger_kind_check">>) =:= nomatch],
    join_binary_lines(Kept).

join_binary_lines([]) ->
    <<>>;
join_binary_lines([Line | Lines]) ->
    lists:foldl(fun(Next, Acc) -> <<Acc/binary, "\n", Next/binary>> end, Line, Lines).

required_schema_terms(Text) ->
    Required = [
        <<"prevent_card_cycle">>,
        <<"trg_cards_prevent_cycle">>,
        <<"prevent_task_dependency_cycle">>,
        <<"trg_task_dependencies_prevent_cycle">>,
        <<"tasks_project_type_fk">>,
        <<"tasks_project_capability_fk">>,
        <<"task_types_project_capability_fk">>,
        <<"task_templates_project_type_fk">>,
        <<"rules_workflow_task_type_project_fk">>,
        <<"enforce_api_token_org_scope">>,
        <<"trg_api_tokens_org_scope">>,
        <<"audit_events_target_check">>,
        <<"audit_events_task_project_fk">>,
        <<"audit_events_card_project_fk">>,
        <<"task_closed">>,
        <<"rule_executions_rule_id_fkey">>,
        <<"rule_executions_task_id_fkey">>,
        <<"rule_executions_card_id_fkey">>,
        <<"tasks_created_from_rule_id_fkey">>,
        <<"rules_trigger_kind_check">>,
        <<"idx_rules_trigger_kind">>,
        <<"project_settings_increment_version">>,
        <<"trg_project_settings_increment_version">>
    ],
    [bin(["db/schema.sql missing canonical final-schema term: ", Term])
     || Term <- Required,
        binary:match(Text, Term) =:= nomatch].

seed_hierarchy_violations(Root) ->
    require_content(Root, ["apps/server/src/scrumbringer_server/seed_builder.gleam"], [
        <<"root pool">>, <<"parent_card_id">>, <<"card">>
    ]) ++ files_containing(Root, ["apps/server/src/scrumbringer_server/seed_builder.gleam"], [
        legacy_bin(), legacy_id_bin()
    ], source_exts()).

seed_profiles_violations(Root) ->
    require_content(Root, ["apps/server/src/scrumbringer_server/seed_builder.gleam"], [
        <<"due_date">>, <<"closed">>, <<"Closed">>, <<"profile">>
    ]).

ui_validation_violations(Root) ->
    require_files(Root, [
        "docs/validation/ht12-ui-validation.md"
    ]).

seed_roles_violations(Root) ->
    require_content(Root, ["apps/server/src/scrumbringer_server/seed_builder.gleam"], [
        <<"manager">>, <<"member">>, <<"capability">>
    ]).

seed_limits_violations(Root) ->
    require_content(Root, ["apps/server/src/scrumbringer_server/seed_builder.gleam"], [
        <<"healthy">>, <<"saturated">>, <<"pool">>
    ]).

smoke_flow_violations(Root) ->
    require_files(Root, [
        "apps/server/test/full_flow_smoke_ht12_test.gleam",
        "docs/validation/ht12-ui-validation.md"
    ]).

docs_i18n_violations(Root) ->
    files_containing(Root, ["docs", "apps/client/src/scrumbringer_client/i18n"], [
        legacy_bin(), title_legacy_bin(), legacy_plural_bin(), legacy_id_bin()
    ], [".md", ".yml", ".yaml", ".gleam"]).

audit_replaces_task_events_violations(Root) ->
    files_containing(Root, [
        "apps/server/src",
        "apps/server/test",
        "db/schema.sql"
    ], [
        <<"task_events">>, <<"task_events_db">>
    ], source_exts() ++ [".sql"]).

audit_kind_codec_violations(Root) ->
    require_files(Root, [
        "shared/src/domain/audit_event/kind_codec.gleam",
        "shared/test/audit_event_kind_codec_ht12_test.gleam"
    ]).

metrics_audit_source_violations(Root) ->
    files_containing(Root, [
        "apps/server/src/scrumbringer_server/services/metrics_db.gleam",
        "apps/server/src/scrumbringer_server/sql"
    ], [
        <<"task_events">>
    ], source_exts() ++ [".sql"]) ++ require_content(Root, [
        "apps/server/src/scrumbringer_server/use_case/metrics_db.gleam"
    ], [<<"audit_events">>]).

legacy_metrics_violations(Root) ->
    files_containing(Root, [
        "apps/server/src",
        "apps/server/test",
        "apps/client/src",
        "apps/client/test"
    ], [
        bin([legacy_bin(), " metrics"]),
        bin([title_legacy_bin(), "Progress"]),
        bin(["include_metrics_", legacy_bin()]),
        bin(["/api/v1/", legacy_plural()])
    ], source_exts()).

refactor_review_violations(Root) ->
    require_files(Root, ["docs/validation/ht12-final-refactor-review.md"]).

obsolete_code_violations(Root) ->
    forbid_dirs(Root, [
        "shared/src/domain/" ++ legacy_root(),
        "apps/client/src/scrumbringer_client/features/" ++ legacy_plural()
    ]) ++ require_empty_glob(Root, "apps/server/src/scrumbringer_server/sql/" ++ legacy_plural() ++ "_").

active_code_roots() ->
    [
        "shared/src",
        "apps/server/src",
        "apps/client/src"
    ].

source_exts() ->
    [".gleam", ".erl", ".mjs"].

legacy_root() ->
    "mile" ++ "stone".

legacy_plural() ->
    legacy_root() ++ "s".

legacy_id() ->
    legacy_root() ++ "_id".

legacy_bin() ->
    bin(["mile", "stone"]).

title_legacy_bin() ->
    bin(["Mile", "stone"]).

legacy_plural_bin() ->
    bin([legacy_plural()]).

legacy_id_bin() ->
    bin([legacy_id()]).

require_dirs(Root, Paths) ->
    [bin(["missing required directory: ", Path])
     || Path <- Paths,
        not filelib:is_dir(filename:join(Root, Path))].

forbid_dirs(Root, Paths) ->
    [bin(["obsolete directory remains: ", Path])
     || Path <- Paths,
        filelib:is_dir(filename:join(Root, Path))].

require_files(Root, Paths) ->
    [bin(["missing required file: ", Path])
     || Path <- Paths,
        not filelib:is_file(filename:join(Root, Path))].

require_empty_glob(Root, Prefix) ->
    [bin(["obsolete file remains: ", rel(Root, Path)])
     || Path <- all_files(Root, ["apps/server/src/scrumbringer_server/sql"], [".sql"]),
        lists:prefix(filename:join(Root, Prefix), Path)].

require_tests(Root, Names) ->
    Text = join_file_texts(Root, ["apps/server/test", "apps/client/test", "shared/test"], source_exts()),
    [bin(["missing test coverage marker: ", Name])
     || Name <- Names,
        nomatch =:= binary:match(Text, list_to_binary(Name))].

require_content(Root, Paths, Terms) ->
    lists:append([
        case read_file(filename:join(Root, Path)) of
            {ok, Text} ->
                [bin(["missing ", Term, " in ", Path])
                 || Term <- Terms,
                    nomatch =:= binary:match(Text, Term)];
            error ->
                [bin(["missing required file: ", Path])]
        end
     || Path <- Paths]).

files_missing_any(Root, Paths, Terms, Exts) ->
    Text = join_file_texts(Root, Paths, Exts),
    case lists:any(fun(Term) -> binary:match(Text, Term) =/= nomatch end, Terms) of
        true -> [];
        false -> [bin(["none of required terms found: ", string:join([binary_to_list(T) || T <- Terms], ", ")])]
    end.

files_containing(Root, Paths, Terms, Exts) ->
    lists:sublist(
        [bin([rel(Root, Path), ": contains ", Term])
         || Path <- all_files(Root, Paths, Exts),
            {ok, Text} <- [read_file(Path)],
            Term <- Terms,
            binary:match(Text, Term) =/= nomatch,
            not ignored_match(Path, Term)],
        80
    ).

ignored_match(Path, _Term) ->
    Base = filename:basename(Path),
    lists:member(Base, ["final_cleanup_ht12_test.gleam", "final_cleanup_ht12_ffi.erl"]).

join_file_texts(Root, Paths, Exts) ->
    list_to_binary([
        [Text, <<"\n">>]
        || Path <- all_files(Root, Paths, Exts),
           {ok, Text} <- [read_file(Path)]
    ]).

all_files(Root, Paths, Exts) ->
    lists:sort(lists:append([files_under(filename:join(Root, Path), Exts) || Path <- Paths])).

files_under(Path, Exts) ->
    case filelib:is_regular(Path) of
        true ->
            case has_ext(Path, Exts) of
                true -> [filename:absname(Path)];
                false -> []
            end;
        false ->
            case file:list_dir(Path) of
                {ok, Names} ->
                    lists:append([files_under(filename:join(Path, Name), Exts)
                                  || Name <- Names,
                                     not lists:member(Name, ignored_dirs())]);
                _ ->
                    []
            end
    end.

ignored_dirs() ->
    ["build", ".git", "node_modules", ".awo"].

has_ext(Path, Exts) ->
    lists:member(filename:extension(Path), Exts).

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Text} -> {ok, Text};
        _ -> error
    end.

rel(Root, Path) ->
    Root1 = filename:absname(Root),
    Path1 = filename:absname(Path),
    Prefix = Root1 ++ "/",
    case lists:prefix(Prefix, Path1) of
        true -> lists:nthtail(length(Prefix), Path1);
        false -> Path1
    end.

bin(Parts) ->
    list_to_binary([part_to_binary(Part) || Part <- Parts]).

part_to_binary(Part) when is_binary(Part) -> Part;
part_to_binary(Part) when is_list(Part) -> list_to_binary(Part).
