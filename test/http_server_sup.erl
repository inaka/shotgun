-module(http_server_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

%% admin api
-spec start_link() -> {ok, pid()} | ignore | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, {}).

%% behaviour callbacks
-spec init({}) -> {ok, {{one_for_one, 5, 10}, []}}.
init({}) ->
    {ok, {{one_for_one, 5, 10}, []}}.
