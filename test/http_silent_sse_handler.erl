-module(http_silent_sse_handler).

-behavior(lasse_handler).

-dialyzer(no_undefined_callbacks).

-export([init/3, handle_notify/2, handle_info/2, handle_error/3, terminate/3]).

%% Sends the response headers and then nothing, so that the stream looks
%% half-open to the client.
init(_InitArgs, _LastEventId, Req) ->
    {ok, Req, no_state}.

handle_notify(_Msg, State) ->
    {nosend, State}.

handle_info(_Msg, State) ->
    {nosend, State}.

handle_error(_Msg, _Reason, State) ->
    State.

terminate(_Reason, _Req, _State) ->
    ok.
