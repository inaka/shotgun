-module(http_silent_sse_handler).

-behavior(lasse_handler).

-dialyzer(no_undefined_callbacks).

-export([init/3, handle_notify/2, handle_info/2, handle_error/3, terminate/3]).

-type state() :: no_state.

%% Sends the response headers and then nothing, so that the stream looks
%% half-open to the client.
-spec init(term(), undefined | binary(), cowboy_req:req()) ->
              {ok | no_content, cowboy_req:req(), state()}.
init(_InitArgs, _LastEventId, Req) ->
    {ok, Req, no_state}.

-spec handle_notify(term(), state()) -> {nosend, state()}.
handle_notify(_Msg, State) ->
    {nosend, State}.

-spec handle_info(term(), state()) -> {nosend, state()}.
handle_info(_Msg, State) ->
    {nosend, State}.

-spec handle_error(term(), term(), state()) -> state().
handle_error(_Msg, _Reason, State) ->
    State.

-spec terminate(term(), cowboy_req:req(), state()) -> ok.
terminate(_Reason, _Req, _State) ->
    ok.
