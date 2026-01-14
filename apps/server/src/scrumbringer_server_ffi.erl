-module(scrumbringer_server_ffi).
-export([db_pool_name/0, rate_limit_allow/4]).

db_pool_name() -> scrumbringer_db.

%% Best-effort, in-memory fixed-window limiter.
%%
%% Stores {Key, WindowStartUnix, Count}.
rate_limit_allow(Key, Limit, WindowSeconds, NowUnix)
  when is_binary(Key), is_integer(Limit), is_integer(WindowSeconds), is_integer(NowUnix) ->
  try
    Tab = ensure_rate_limit_table(),
    case ets:lookup(Tab, Key) of
      [] ->
        ets:insert(Tab, {Key, NowUnix, 1}),
        true;

      [{Key, WindowStart, Count}] when NowUnix - WindowStart >= WindowSeconds ->
        ets:insert(Tab, {Key, NowUnix, 1}),
        true;

      [{Key, WindowStart, Count}] when Count < Limit ->
        ets:insert(Tab, {Key, WindowStart, Count + 1}),
        true;

      [{Key, _WindowStart, _Count}] ->
        false
    end
  catch
    _:_ ->
      %% Fail open so we don't block legit traffic if ETS is unavailable.
      true
  end.

ensure_rate_limit_table() ->
  TabName = scrumbringer_rate_limit,
  case ets:info(TabName) of
    undefined -> ets:new(TabName, [named_table, public, set, {read_concurrency, true}]);
    _ -> TabName
  end.
