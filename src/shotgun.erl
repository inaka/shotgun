-module(shotgun).
-author(pyotrgalois).

-behavior(gen_fsm).

-export([
         start/0,
         stop/0,
         start_link/2,
         open/2,
         close/1,
         get/2,
         get/3,
         get/4,
         events/1
        ]).

-export([
         init/1,
         handle_event/3,
         handle_sync_event/4,
         handle_info/3,
         terminate/3,
         code_change/4
        ]).

-export([
         at_rest/3,
         wait_response/2,
         receive_data/2,
         receive_chunk/2
        ]).

-type response() :: #{}.
-type headers() :: #{}.
-type options() :: [].

-spec start() -> {ok, [atom()]}.
start() ->
    {ok, _} = application:ensure_all_started(shotgun).

-spec stop() -> ok | {error, term()}.
stop() ->
    application:stop(shotgun).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec start_link(string(), integer()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Host, Port) ->
    gen_fsm:start(shotgun, [Host, Port], []).

-spec open(Host :: string(), Port :: integer()) -> {ok, pid()}.
open(Host, Port) ->
    supervisor:start_child(shotgun_sup, [Host, Port]).

-spec close(pid()) -> ok.
close(Pid) ->
    gen_fsm:send_all_state_event(Pid, 'shutdown'),
    ok.

-spec get(pid(), string()) -> response().
get(Pid, Url) ->
    get(Pid, Url, #{}, #{}).

-spec get(pid(), string(), headers()) -> response().
get(Pid, Url, Headers) ->
    get(Pid, Url, Headers, #{}).

-spec get(pid(), string(), headers(), options()) -> response().
get(Pid, Url, HeadersMap, Options) ->
    Headers = maps:to_list(HeadersMap),

    HandleEvent = maps_get(handle_event, Options, undefined),
    Async = maps_get(async, Options, undefined),
    case {HandleEvent, Async} of
        {undefined, undefined} ->
            gen_fsm:sync_send_event(Pid, {get, Url, Headers});
        {undefined, Async} ->
            gen_fsm:sync_send_event(Pid, {asyncget, Url, Headers});
        _ ->
            gen_fsm:sync_send_event(Pid, {asyncget, Url, Headers, HandleEvent})
    end.

-spec events(Pid :: pid()) -> {binary()}.
events(Pid) ->
    gen_fsm:sync_send_all_state_event(Pid, get_response).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_fsm callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec init([term()]) -> term().
init([Host, Port]) ->
    Opts = [
            {type, tcp},
            {retry, 1},
            {retry_timeout, 1}
           ],
    {ok, Pid} = gun:open(Host, Port, Opts),
    State = clean_state(),
    {ok, at_rest, State#{pid => Pid}}.

-spec handle_event(term(), atom(), term()) -> term().
handle_event(shutdown, _StateName, StateData) ->
    {stop, normal, StateData}.

-spec handle_sync_event(term(), {pid(), term()}, atom(), term()) ->
    term().
handle_sync_event(get_response,
                  _From,
                  StateName,
                  #{responses := Responses} = State) ->
    Reply = queue:to_list(Responses),
    {reply, Reply, StateName, State#{responses := queue:new()}}.

-spec handle_info(term(), atom(), term()) -> term().
handle_info(Event, StateName, StateData) ->
    Module = ?MODULE,
    Module:StateName(Event, StateData).

-spec code_change(term(), atom(), term(), term()) -> {ok, atom(), term()}.
code_change(_OldVsn, StateName, StateData, _Extra) ->
    {ok, StateName, StateData}.

-spec terminate(term(), atom(), term()) -> ok.
terminate(_Reason, _StateName, #{pid := Pid} = _State) ->
    gun:shutdown(Pid),
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_fsm states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec at_rest(term(), pid(), term()) -> term().
at_rest({asyncget, Url, Headers}, From, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),
    gen_fsm:reply(From, StreamRef),
    NewState = clean_state(),
    {next_state, wait_response, NewState#{pid := Pid, stream := StreamRef}};
at_rest({asyncget, Url, Headers, HandleEvent}, From, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),
    gen_fsm:reply(From, StreamRef),
    NewState = clean_state(),
    {
      next_state,
      wait_response,
      NewState#{pid := Pid, stream := StreamRef, handle_event := HandleEvent}
    };
at_rest({get, Url, Headers}, From, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),

    NewState = clean_state(),
    {next_state, wait_response, NewState#{pid := Pid,
                                          stream := StreamRef,
                                          from := From}}.

-spec wait_response(term(), term()) -> term().
wait_response({'DOWN', _, _, _, Reason}, _State) ->
    exit(Reason);
wait_response({gun_response, _Pid, _StreamRef, fin, StatusCode, Headers},
              #{from := From} = State) ->
    gen_fsm:reply(From, #{status_code => StatusCode, headers => Headers}),
    {next_state, at_rest, State};
wait_response({gun_response, _Pid, _StreamRef, nofin, StatusCode, Headers},
              State) ->
    StateName = case lists:keyfind(<<"transfer-encoding">>, 1, Headers) of
                    {<<"transfer-encoding">>, <<"chunked">>} ->
                        receive_chunk;
                    _ ->
                        receive_data
                end,
    {
      next_state,
      StateName,
      State#{status_code := StatusCode, headers := Headers}
    };
wait_response(Event, State) ->
    {stop, {unexpected, Event}, State}.

%% regular response
-spec receive_data(term(), term()) -> term().
receive_data({'DOWN', _, _, _, _Reason}, _State) ->
    error(incomplete);
receive_data({gun_data, _Pid, StreamRef, nofin, Data},
             #{stream := StreamRef, data := DataAcc} = State) ->
    NewData = <<DataAcc/binary, Data/binary>>,
    {next_state, receive_data, State#{data => NewData}};
receive_data({gun_data, _Pid, _StreamRef, fin, Data},
             #{data := DataAcc, from := From, status_code
               := StatusCode, headers := Headers} = State) ->
    NewData = <<DataAcc/binary, Data/binary>>,
    gen_fsm:reply(From, #{status_code => StatusCode,
                          headers => Headers,
                          body => NewData
                         }),
    {next_state, at_rest, State};
receive_data({gun_error, _Pid, StreamRef, _Reason},
             #{stream := StreamRef} = State) ->
    {next_state, at_rest, State}.

%% chunked data response
-spec receive_chunk(term(), term()) -> term().
receive_chunk({'DOWN', _, _, _, _Reason}, _State) ->
    error(incomplete);
receive_chunk({gun_data, _Pid, StreamRef, nofin, Data},
              #{responses := Responses, handle_event := HandleEvent} = State) ->
    manage_chunk(nofin, HandleEvent, StreamRef, Data, Responses, State);
receive_chunk({gun_data, _Pid, StreamRef, fin, Data},
              #{responses := Responses, handle_event := HandleEvent} = State) ->
    manage_chunk(fin, HandleEvent, StreamRef, Data, Responses, State);
receive_chunk({gun_error, _Pid, _StreamRef, _Reason}, State) ->
    {next_state, at_rest, State}.

%% internal
clean_state() ->
    #{pid => undefined,
      stream => undefined,
      handle_event => undefined,
      from => undefined,
      responses => queue:new(),
      data => <<"">>,
      status_code => undefined,
      headers => undefined
     }.

maps_get(Key, Map, Default) ->
    case maps:is_key(Key, Map) of
        true ->
            maps:get(Key, Map);
        false ->
            Default
    end.

manage_chunk(IsFin, undefined, StreamRef, Data, Responses, State) ->
    NewResponses = queue:in({IsFin, StreamRef, Data}, Responses),
    {next_state, receive_chunk, State#{responses => NewResponses}};
manage_chunk(IsFin, HandleEvent, StreamRef, Data, _Responses, State) ->
    HandleEvent(IsFin, StreamRef, Data),
    {next_state, receive_chunk, State}.
