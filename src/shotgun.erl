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
         pop/1
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
         receive_chunk/2,
         parse_event/1
        ]).

start() ->
    {ok, _Started} = application:ensure_all_started(shotgun).

stop() ->
    application:stop(shotgun).

start_link(Host, Port) ->
    gen_fsm:start(shotgun, [Host, Port], []).

-spec open(Host :: string(), Port :: integer()) -> {ok, pid()}.
open(Host, Port) ->
    supervisor:start_child(shotgun_sup, [Host, Port]).

-spec close(pid()) -> ok.
close(Pid) ->
    gen_fsm:send_all_state_event(Pid, 'shutdown'),
    ok.

get(Pid, Url) ->
    get(Pid, Url, #{}, #{}).

get(Pid, Url, Headers) ->
    get(Pid, Url, Headers, #{}).

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

-spec pop(Pid :: pid()) -> {binary()}.
pop(Pid) ->
    gen_fsm:sync_send_all_state_event(Pid, get_response).

%% gen_fsm callbacks
init([Host, Port]) ->
    Opts = [
            {type, tcp},
            {retry, 1},
            {retry_timeout, 1}
           ],
    {ok, Pid} = gun:open(Host, Port, Opts),
    {ok, at_rest, #{pid => Pid}}.

handle_event(shutdown, _StateName, StateData) ->
    {stop, normal, StateData}.

handle_sync_event(get_response, _From, StateName, #{responses := Responses} = State) ->
    {Reply, NewResponses} = case queue:out(Responses) of
                                {{value, Response}, NewQueue} ->
                                    {Response, NewQueue};
                                {empty, Responses} ->
                                    {no_data, Responses}
                            end,
    {reply, Reply, StateName, State#{responses := NewResponses}}.

handle_info(Event, StateName, StateData) ->
    ?MODULE:StateName(Event, StateData).

code_change(_OldVsn, StateName, StateData, _Extra) ->
    {ok, StateName, StateData}.

terminate(_Reason, _StateName, #{pid := Pid} = _State) ->
    gun:shutdown(Pid),
    ok.

%% state functions
at_rest({asyncget, Url, Headers}, From, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),
    gen_fsm:reply(From, StreamRef),
    NewState = clean_state(),
    {next_state, wait_response, NewState#{pid := Pid, stream := StreamRef}};
at_rest({asyncget, Url, Headers, HandleEvent}, From, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),
    gen_fsm:reply(From, StreamRef),
    NewState = clean_state(),
    {next_state, wait_response, NewState#{pid := Pid, stream := StreamRef, handle_event := HandleEvent}};
at_rest({get, Url, Headers}, From, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),

    NewState = clean_state(),
    {next_state, wait_response, NewState#{pid := Pid,
                                          stream := StreamRef,
                                          from := From}}.

wait_response({'DOWN', _, _, _, Reason}, _State) ->
    exit(Reason);
wait_response({gun_response, _Pid, _StreamRef, fin, StatusCode, Headers},
              #{from := From} = State) ->
    gen_fsm:reply(From, #{status_code => StatusCode, headers => Headers}),
    {next_state, at_rest, State};
wait_response({gun_response, _Pid, _StreamRef, nofin, StatusCode, Headers}, State) ->
    StateName = case lists:keyfind(<<"transfer-encoding">>, 1, Headers) of
                    {<<"transfer-encoding">>, <<"chunked">>} ->
                        receive_chunk;
                    _ ->
                        receive_data
                end,
    {next_state, StateName, State#{status_code := StatusCode, headers := Headers}};
wait_response(Event, State) ->
    {stop, {unexpected, Event}, State}.

%% regular response
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
receive_chunk({'DOWN', _, _, _, _Reason}, _State) ->
    error(incomplete);
receive_chunk({gun_data, _Pid, StreamRef, IsFin, Data},
              #{
                handle_event := HandleEvent,
                buffer := Buffer
               } = State) ->
    NewBuffer = <<Buffer/binary, Data/binary>>,
    DataList = binary:split(NewBuffer, <<"\n\n">>, [global]),

    case lists:reverse(DataList) of
        [_] ->
            {next_state, receive_chunk, State#{buffer := NewBuffer}};
        [Last | Start] ->
            lists:foreach(
              fun(Event) ->
                      HandleEvent(IsFin, StreamRef, Event)
              end, Start),
            case Last of
                <<>> ->
                    {next_state, receive_chunk, State#{buffer := <<"">>}};
                _ ->
                    {next_state, receive_chunk, State#{buffer := Last}}
            end
    end;
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
      headers => undefined,
      buffer => <<"">>
     }.

maps_get(Key, Map, Default) ->
    case maps:is_key(Key, Map) of
        true ->
            maps:get(Key, Map);
        false ->
            Default
    end.

parse_event(Event) ->
    Lines = binary:split(Event, <<"\n">>, [global]),
    FoldFun = fun(Line, {DataList, Id, EventName}) ->
                  case Line of
                      <<"data: ", Data/binary>> ->
                          {[Data | DataList], Id, EventName};
                      <<"id: ", NewId/binary>> ->
                          {DataList, NewId, EventName};
                      <<"event: ", NewEventName/binary>> ->
                          {DataList, Id, NewEventName}
                  end
          end,
    lists:foldr(FoldFun, {[], undefined, undefined}, Lines).

%%     NewResponses = queue:in({IsFin, StreamRef, Data}, Responses)
