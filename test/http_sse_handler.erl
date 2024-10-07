-module(http_sse_handler).

-behavior(lasse_handler).

-dialyzer(no_undefined_callbacks).

-export([init/3, handle_notify/2, handle_info/2, handle_error/3, terminate/3]).

init(_InitArgs, _LastEventId, Req) ->
    shotgun_test_utils:auto_send(ping),
    CountBin = cowboy_req:binding(count, Req, <<"2">>),
    case binary_to_integer(CountBin) of
        0 ->
            {no_content, Req, {0, 0}};
        Count ->
            {ok, Req, {1, Count + 1}}
    end.

handle_notify(ping, State) ->
    {nosend, State}.

handle_info(ping, {X, Count} = State) when X >= Count ->
    {stop, State};
handle_info(ping, {X, Count}) ->
    shotgun_test_utils:auto_send(ping),

    Event =
        #{id => integer_to_binary(X),
          event => <<"ping-pong">>,
          data => <<"pong">>,
          comment => <<"This is a comment">>},
    {send, Event, {X + 1, Count}}.

handle_error(_Msg, _Reason, Count) ->
    Count.

terminate(_Reason, _Req, _Count) ->
    ok.
