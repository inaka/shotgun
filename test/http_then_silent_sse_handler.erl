-module(http_then_silent_sse_handler).

-behavior(lasse_handler).

-dialyzer(no_undefined_callbacks).

-export([init/3, handle_notify/2, handle_info/2, handle_error/3, terminate/3]).

-type state() :: {integer(), integer()}.

%% Sends count events 100 ms apart and then keeps the connection open
%% without sending anything else, so that the stream looks half-open
%% after it has delivered data.
-spec init(term(), undefined | binary(), cowboy_req:req()) ->
              {ok | no_content, cowboy_req:req(), state()}.
init(_InitArgs, _LastEventId, Req) ->
    shotgun_test_utils:auto_send(ping),
    CountBin = cowboy_req:binding(count, Req, <<"2">>),
    {ok, Req, {1, binary_to_integer(CountBin) + 1}}.

-spec handle_notify(term(), state()) -> {nosend, state()}.
handle_notify(ping, State) ->
    {nosend, State}.

-spec handle_info(ping, state()) ->
                     {nosend, state()} | {send, lasse_handler:event(), state()} | {stop, state()}.
handle_info(ping, {X, Count} = State) when X >= Count ->
    {nosend, State};
handle_info(ping, {X, Count}) ->
    shotgun_test_utils:auto_send(ping),
    Event =
        #{id => integer_to_binary(X),
          event => <<"ping-pong">>,
          data => <<"pong">>},
    {send, Event, {X + 1, Count}}.

-spec handle_error(term(), term(), state()) -> state().
handle_error(_Msg, _Reason, State) ->
    State.

-spec terminate(term(), cowboy_req:req(), state()) -> ok.
terminate(_Reason, _Req, _State) ->
    ok.
