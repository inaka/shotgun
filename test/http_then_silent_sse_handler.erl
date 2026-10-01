-module(http_then_silent_sse_handler).

-behavior(lasse_handler).

-dialyzer(no_undefined_callbacks).

-export([init/3, handle_notify/2, handle_info/2, handle_error/3, terminate/3]).

%% Sends count events 100 ms apart and then keeps the connection open
%% without sending anything else, so that the stream looks half-open
%% after it has delivered data.
init(_InitArgs, _LastEventId, Req) ->
    shotgun_test_utils:auto_send(ping),
    CountBin = cowboy_req:binding(count, Req, <<"2">>),
    {ok, Req, {1, binary_to_integer(CountBin) + 1}}.

handle_notify(ping, State) ->
    {nosend, State}.

handle_info(ping, {X, Count} = State) when X >= Count ->
    {nosend, State};
handle_info(ping, {X, Count}) ->
    shotgun_test_utils:auto_send(ping),
    Event =
        #{id => integer_to_binary(X),
          event => <<"ping-pong">>,
          data => <<"pong">>},
    {send, Event, {X + 1, Count}}.

handle_error(_Msg, _Reason, State) ->
    State.

terminate(_Reason, _Req, _State) ->
    ok.
