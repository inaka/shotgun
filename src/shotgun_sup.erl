%% @hidden
-module(shotgun_sup).
-author(pyotrgalois).

-behaviour(supervisor).

-export([
         start_link/0,
         init/1
        ]).

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec init(term()) ->
    {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    Procs = [{shotgun, {shotgun, start_link, []},
              temporary, 5000, worker, [shotgun]}],
    {ok, {{simple_one_for_one, 10, 10}, Procs}}.
