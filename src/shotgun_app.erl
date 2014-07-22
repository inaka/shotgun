-module(shotgun_app).
-behavior(application).

-export([
         start/2,
         stop/1
        ]).

start(_StartType, _StartArgs) ->
    shotgun_sup:start_link().

stop(_State) ->
    ok.
