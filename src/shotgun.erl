-module(shotgun).
-author(pyotrgalois).

-behavior(gen_fsm).

-export([
         start/0,
         stop/0,
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
         open_state/2,
         open_state/3,
         wait_response/2,
         receive_data/2,
         receive_chunk/2
        ]).

start() ->
    {ok, _Started} = application:ensure_all_started(shotgun).

stop() ->
    application:stop(shotgun).

-spec open(Host :: string(), Port :: integer()) -> {ok, pid()}.
open(Host, Port) ->
    gen_fsm:start(shotgun, [Host, Port], []).

-spec close(pid()) -> ok.
close(Pid) ->
    gen_fsm:send_all_state_event(Pid, 'shutdown'),
    ok.

get(Pid, Url) ->
    get(Pid, Url, [], #{}).

get(Pid, Url, Headers) ->
    get(Pid, Url, Headers, #{}).

get(Pid, Url, Headers, Options) ->
    case maps:is_key(stream, Options) of
        true ->
            gen_fsm:send_event(Pid, {asyncget, Url, Headers});
        false ->
            gen_fsm:sync_send_event(Pid, {get, Url, Headers})
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
    {ok, open_state, #{pid => Pid}}.

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
open_state({asyncget, Url, Headers}, #{pid := Pid} = _State) ->
    StreamRef = gun:get(Pid, Url, Headers),
    NewState = clean_state(),
    {next_state, wait_response, NewState#{pid := Pid, stream := StreamRef}}.

open_state({get, Url, Headers}, From, #{pid := Pid} = _State) ->
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
    {next_state, open_state, State};
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
    {next_state, open_state, State};
receive_data({gun_error, _Pid, StreamRef, _Reason},
             #{stream := StreamRef} = State) ->
    {next_state, open_state, State}.

%% chunked data response
receive_chunk({'DOWN', _, _, _, _Reason}, _State) ->
    error(incomplete);
receive_chunk({gun_data, _Pid, _StreamRef, nofin, Data},
              #{responses := Responses} = State) ->
    NewResponses = queue:in(Data, Responses),
    {next_state, receive_chunk, State#{responses => NewResponses}};
receive_chunk({gun_data, _Pid, _StreamRef, fin, Data},
              #{responses := Responses} = State) ->
    NewResponses = queue:in(Data, Responses),
    {next_state, open_state, State#{responses => NewResponses}};
receive_chunk({gun_error, _Pid, _StreamRef, _Reason}, State) ->
    {next_state, open_state, State}.

%% internal
clean_state() ->
    #{pid => undefined,
      stream => undefined,
      from => undefined,
      responses => queue:new(),
      data => <<"">>,
      status_code => undefined,
      headers => undefined
     }.
