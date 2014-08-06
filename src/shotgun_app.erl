-module(shotgun_app).
-behavior(application).

-export([
         start/2,
         stop/1
        ]).

-spec start(term(), term()) -> ok.
start(_StartType, _StartArgs) ->
    shotgun_sup:start_link().

-spec stop(term()) -> ok.
stop(_State) ->
    ok.
