-module(shotgun).
-author(pyotrgalois).

-export([start/0
        , start/2
        , stop/0
        , stop/1
        ]).

start() ->
    {ok, _Started} = application:ensure_all_started(shotgun).

stop() ->
    application:stop(shotgun).

start(_StartType, _StartArgs) ->
    shotgun_sup:start_link().

stop(_State) ->
    ok.
