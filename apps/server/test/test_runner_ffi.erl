%% Custom test runner that runs tests sequentially to avoid database race conditions.
-module(test_runner_ffi).
-export([run_tests_sequential/0]).

-define(MODULE_TIMEOUT_SECONDS, 240).

run_tests_sequential() ->
    %% Find all test modules
    {ok, Files} = file:list_dir("build/dev/erlang/scrumbringer_server/_gleam_artefacts"),
    TestModules = lists:filtermap(
        fun(File) ->
            case lists:suffix("_test.erl", File) of
                true ->
                    ModName = list_to_atom(lists:sublist(File, length(File) - 4)),
                    %% Skip the main test entry point
                    case ModName of
                        scrumbringer_server_test -> false;
                        test_runner -> false;
                        _ -> {true, ModName}
                    end;
                false ->
                    false
            end
        end,
        Files
    ),

    %% Run tests sequentially:
    %% - {inorder, [...]} makes modules run one after another
    %% - {inorder, {module, Mod}} makes tests within each module run sequentially
    Options = [verbose, no_tty, {timeout, ?MODULE_TIMEOUT_SECONDS},
               {report, {gleeunit_progress, [{colored, true}]}}],

    %% Wrap each module in {inorder, ...} to run its tests sequentially.
    %% HTTP integration modules bootstrap PostgreSQL-backed apps and can exceed
    %% EUnit's default 5s timeout on slower local runs.
    SequentialModules = [
        {timeout, ?MODULE_TIMEOUT_SECONDS, {inorder, {module, Mod}}}
     || Mod <- TestModules
    ],

    %% Then wrap the list to run modules sequentially
    Result = eunit:test({inorder, SequentialModules}, Options),

    case Result of
        ok -> 0;
        error -> 1
    end.
