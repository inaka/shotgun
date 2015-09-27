%%% @author Federico Carrone <federico@inaka.net>
%%% @author Juan Facorro <juan@inaka.net>
%%% @doc Shotgun's main interface.
%%%      Use the functions provided in this module to open a connection and make
%%%      requests.
-module(shotgun).
-author("federico@inaka.net").
-author("juan@inaka.net").

-behaviour(gen_fsm).

-export([
         start/0,
         stop/0,
         start_link/4,
         open/2,
         open/3,
         open/4,
         close/1,
         %% get
         get/2,
         get/3,
         get/4,
         %% post
         post/5,
         %% delete
         delete/4,
         %% head
         head/4,
         %% options
         options/4,
         %% patch
         patch/5,
         %% put
         put/5,
         %% generic request
         request/6,
         %% events
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
         receive_chunk/2,
         parse_event/1
        ]).

-type response() ::
        #{
           status_code => integer(),
           header => map(),
           body => binary()
         }.
-type result() :: {ok, reference() | response()} | {error, term()}.
-type headers() :: #{}.
-type options() ::
        #{
           async => boolean(),
           async_data => binary | sse,
           handle_event => fun((fin | nofin, reference(), binary()) -> any()),
           basic_auth => {string(), string()},
           timeout => pos_integer() | infinity %% Default 5000 ms
         }.
-type http_verb() :: get | post | head | delete | patch | put | options.

-type connection_type() :: http | https.

-type open_opts() ::
        #{
            transport_opts => [],
            timeout => pos_integer() | infinity }.
%% transport_opts are passed to Ranch's TCP transport, which is -itself- a thin layer over gen_tcp. <br/>
%% timeout is passed to gun:await_up. Default if not specified is 5000 ms.

%% @doc Starts the application and all the ones it depends on.
-spec start() -> {ok, [atom()]}.
start() ->
    {ok, _} = application:ensure_all_started(shotgun).

%% @doc Stops the application
-spec stop() -> ok | {error, term()}.
stop() ->
    application:stop(shotgun).

%% @private
-spec start_link(string(), integer(), connection_type(), open_opts()) ->
    {ok, pid()} | ignore | {error, term()}.
start_link(Host, Port, Type, Opts) ->
    gen_fsm:start_link(shotgun, [Host, Port, Type, Opts], []).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @equiv get(Host, Port, http, #{})
-spec open(Host :: string(), Port :: integer()) ->
    {ok, pid()} | {error, gun_open_failed} | {error, gun_timeout}.
open(Host, Port) ->
    open(Host, Port, http).

-spec open(Host :: string(), Port :: integer(), Type :: connection_type()) ->
    {ok, pid()} | {error, gun_open_failed} | {error, gun_timeout};
    (Host :: string(), Port :: integer(), Opts :: open_opts()) ->
    {ok, pid()} | {error, gun_open_failed} | {error, gun_timeout}.
%% @equiv get(Host, Port, Type, #{}) or get(Host, Port, http, Opts)
open(Host, Port, Type) when is_atom(Type) ->
  open(Host, Port, Type, #{});

open(Host, Port, Opts) when is_map(Opts) ->
  open(Host, Port, http, Opts).

%% @doc Opens a connection of the type provided with the host and port specified and the specified connection timeout and/or Ranch transport options.
-spec open(Host :: string(), Port :: integer(), Type :: connection_type(), Opts :: open_opts()) ->
    {ok, pid()} | {error, gun_open_failed} | {error, gun_timeout}.
open(Host, Port, Type, Opts) ->
    supervisor:start_child(shotgun_sup, [Host, Port, Type, Opts]).

%% @doc Closes the connection with the host.
-spec close(pid()) -> ok.
close(Pid) ->
    gen_fsm:send_all_state_event(Pid, 'shutdown'),
    ok.

%% @equiv get(Pid, Uri, #{}, #{})
-spec get(pid(), string()) -> result().
get(Pid, Uri) ->
    get(Pid, Uri, #{}, #{}).

%% @equiv get(Pid, Uri, Headers, #{})
-spec get(pid(), string(), headers()) -> result().
get(Pid, Uri, Headers) ->
    get(Pid, Uri, Headers, #{}).

%% @doc Performs a <strong>GET</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
%% Available options are: <br/>
%% <ul>
%%   <li>
%%     <code>async</code>:
%%     specifies if the request performed will return a chunked response.
%%     It currently only works for GET requests. Default value is false.
%%   </li>
%%   <li>
%%     <code>async_data</code>:
%%     when async is true the mode specifies how the data received will be
%%     processed. binary mode treats eat chunk received as raw binary. sse mode
%%     buffers each chunk, splitting the data received into SSE. Default value
%%     is binary.
%%   </li>
%%   <li>
%%     <code>handle_event</code>:
%%     this function will be called each time either a chunk is received
%%     (<code>async_data = binary</code>) or an event is parsed
%%     (<code>async_data = sse</code>). If no handle_event function is provided
%%     the data received is added to a queue, whose values can be obtained
%%     calling the <code>shotgun:events/1</code>. Default value is undefined.
%%   </li>
%% </ul>
%% @end
-spec get(pid(), string(), headers(), options()) -> result().
get(Pid, Uri, Headers, Options) ->
    request(Pid, get, Uri, Headers, [], Options).

%% @doc Performs a <strong>POST</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec post(pid(), string(), headers(), iodata(), options()) -> result().
post(Pid, Uri, Headers, Body, Options) ->
    request(Pid, post, Uri, Headers, Body, Options).

%% @doc Performs a <strong>DELETE</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec delete(pid(), string(), headers(), options()) -> result().
delete(Pid, Uri, Headers, Options) ->
    request(Pid, delete, Uri, Headers, [], Options).

%% @doc Performs a <strong>HEAD</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec head(pid(), string(), headers(), options()) -> result().
head(Pid, Uri, Headers, Options) ->
    request(Pid, head, Uri, Headers, [], Options).

%% @doc Performs a <strong>OPTIONS</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec options(pid(), string(), headers(), options()) -> result().
options(Pid, Uri, Headers, Options) ->
    request(Pid, options, Uri, Headers, [], Options).

%% @doc Performs a <strong>PATCH</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec patch(pid(), string(), headers(), iodata(), options()) -> result().
patch(Pid, Uri, Headers, Body, Options) ->
    request(Pid, patch, Uri, Headers, Body, Options).

%% @doc Performs a <strong>PUT</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec put(pid(), string(), headers(), iodata(), options()) -> result().
put(Pid, Uri, Headers0, Body, Options) ->
    request(Pid, put, Uri, Headers0, Body, Options).

%% @doc Performs a request to <code>Uri</code> using the HTTP method
%% specified by <code>Method</code>,  <code>Body</code> as the content data and
%% <code>Headers</code> as the request's headers.
-spec request(pid(), http_verb(), string(), headers(), iodata(), options()) ->
    result().
request(Pid, get, Uri, Headers0, Body, Options) ->
    try
        check_uri(Uri),
        #{handle_event := HandleEvent,
          async := IsAsync,
          async_mode := AsyncMode,
          headers := Headers,
          timeout := Timeout} = process_options(Options, Headers0, get),

        Event = case IsAsync of
                    true ->
                        {get_async,
                         {HandleEvent, AsyncMode},
                         {Uri, Headers, Body}};
                    false ->
                        {get, {Uri, Headers, Body}}
                end,
        gen_fsm:sync_send_event(Pid, Event, Timeout)
    catch
        _:Reason -> {error, Reason}
    end;
request(Pid, Method, Uri, Headers0, Body, Options) ->
    try
        check_uri(Uri),
        #{headers := Headers, timeout := Timeout} =
          process_options(Options, Headers0, Method),
        Event = {Method, {Uri, Headers, Body}},
        gen_fsm:sync_send_event(Pid, Event, Timeout)
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Returns a list of all received events up to now.
-spec events(Pid :: pid()) -> [{nofin | fin, reference(), binary()}].
events(Pid) ->
    gen_fsm:sync_send_all_state_event(Pid, get_events).

%% @doc Parse an SSE event in binary format. For example the following binary
%% <code>&lt;&lt;"data: some content\n"&gt;&gt;</code> will be turned into the
%% following map <code>#{&lt;&lt;"data"&gt;&gt; =>
%% &lt;&lt;"some content"&gt;&gt;}</code>.
-spec parse_event(binary()) ->
    {Data :: binary(), Id :: binary(), EventName :: binary()}.
parse_event(EventBin) ->
    Lines = binary:split(EventBin, <<"\n">>, [global]),
    FoldFun = fun(Line, #{data := DataList} = Event) ->
                  case Line of
                      <<"data: ", Data/binary>> ->
                          Event#{ data => [Data | DataList]};
                      <<"id: ", Id/binary>> ->
                          Event#{id => Id};
                      <<"event: ", EventName/binary>> ->
                          Event#{event => EventName};
                      <<_Comment/binary>> ->
                          Event
                  end
          end,
    lists:foldr(FoldFun, #{data => []}, Lines).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_fsm callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @private
-spec init([term()]) -> {ok, at_rest, map()} | {stop, gun_open_timeout} | {stop, gun_open_failed}.
init([Host, Port, Type, Opts]) ->
    GunType = case Type of
                  http -> tcp;
                  https -> ssl
              end,
    TransportOpts = maps:get(transport_opts, Opts, []),
    GunOpts = #{transport      => GunType,
                retry          => 1,
                retry_timeout  => 1,
                transport_opts => TransportOpts
               },
    Timeout = maps:get(timeout, Opts, 5000),
    {ok, Pid} = gun:open(Host, Port, GunOpts),
    case gun:await_up(Pid, Timeout) of
      {ok, _} ->
        State = clean_state(),
        {ok, at_rest, State#{pid => Pid}};
      %The only apparent timeout for gun:open is the connection timeout of the
      %underlying transport. So, a timeout message here comes from gun:await_up.
      {error, timeout} ->
        {stop, gun_open_timeout};
      %gun currently terminates with reason normal if gun:open fails to open
      %the requested connection. This bubbles up through gun:await_up.
      {error, normal} ->
        {stop, gun_open_failed}
    end.

%% @private
-spec handle_event(term(), atom(), term()) -> term().
handle_event(shutdown, _StateName, StateData) ->
    {stop, normal, StateData}.

%% @private
-spec handle_sync_event(term(), {pid(), term()}, atom(), term()) ->
    term().
handle_sync_event(get_events,
                  _From,
                  StateName,
                  #{responses := Responses} = State) ->
    Reply = queue:to_list(Responses),
    {reply, Reply, StateName, State#{responses := queue:new()}}.

%% @private
-spec handle_info(term(), atom(), term()) -> term().
handle_info({gun_up, Pid, _Protocol}, StateName, StateData = #{pid := Pid}) ->
    {next_state, StateName, StateData};
handle_info(
    {gun_down, Pid, Protocol, {error, Reason},
     KilledStreams, UnprocessedStreams}, StateName,
    StateData = #{pid := Pid}) ->
    error_logger:warning_msg(
        "~p connection down on ~p: ~p (Killed: ~p, Unprocessed: ~p)",
        [Protocol, Pid, Reason, KilledStreams, UnprocessedStreams]),
    {next_state, StateName, StateData};
handle_info(
    {gun_down, Pid, _, _, _, _}, StateName, StateData = #{pid := Pid}) ->
    {next_state, StateName, StateData};
handle_info(Event, StateName, StateData) ->
    Module = ?MODULE,
    Module:StateName(Event, StateData).

%% @private
-spec code_change(term(), atom(), term(), term()) -> {ok, atom(), term()}.
code_change(_OldVsn, StateName, StateData, _Extra) ->
    {ok, StateName, StateData}.

%% @private
-spec terminate(term(), atom(), term()) -> ok.
terminate(_Reason, _StateName, #{pid := Pid} = _State) ->
    gun:shutdown(Pid),
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_fsm states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @private
-spec at_rest(term(), pid(), term()) -> term().
at_rest({get_async, {HandleEvent, AsyncMode}, Args}, From, #{pid := Pid}) ->
    StreamRef = do_http_verb(get, Pid, Args),
    CleanState = clean_state(),
    NewState = CleanState#{
                 from => From,
                 pid => Pid,
                 stream => StreamRef,
                 handle_event => HandleEvent,
                 async => true,
                 async_mode => AsyncMode
                },
    {next_state, wait_response, NewState};
at_rest({HttpVerb, Args}, From, #{pid := Pid}) ->
    StreamRef = do_http_verb(HttpVerb, Pid, Args),
    CleanState = clean_state(),
    NewState = CleanState#{
                 pid => Pid,
                 stream => StreamRef,
                 from => From
                },
    {next_state, wait_response, NewState}.

%% @private
-spec wait_response(term(), term()) -> term().
wait_response({'DOWN', _, _, _, Reason}, _State) ->
    exit(Reason);
wait_response({gun_response, _Pid, _StreamRef, fin, StatusCode, Headers},
              #{from := From,
                async := Async,
                responses := Responses} = State) ->
    Response = #{status_code => StatusCode, headers => Headers},
    NewResponses =
        case Async of
            false ->
                gen_fsm:reply(From, {ok, Response}),
                Responses;
            true ->
                gen_fsm:reply(From, {ok, Response})
        end,
    {next_state, at_rest, State#{responses => NewResponses}};
wait_response({gun_response, _Pid, _StreamRef, nofin, StatusCode, Headers},
              #{from := From, stream := StreamRef, async := Async} = State) ->
    StateName =
      case lists:keyfind(<<"transfer-encoding">>, 1, Headers) of
        {<<"transfer-encoding">>, <<"chunked">>} when Async == true->
          Result = {ok, StreamRef},
          gen_fsm:reply(From, Result),
          receive_chunk;
        _ ->
          receive_data
      end,
    {
      next_state,
      StateName,
      State#{status_code := StatusCode, headers := Headers}
    };
wait_response({gun_error, _Pid, _StreamRef, Error},
              #{from := From} = State) ->
    gen_fsm:reply(From, {error, Error}),
    {next_state, at_rest, State};
wait_response(Event, State) ->
    {stop, {unexpected, Event}, State}.

%% @private
%% @doc Regular response
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
    Result= {ok, #{status_code => StatusCode,
                   headers => Headers,
                   body => NewData
                  }},
    gen_fsm:reply(From, Result),
    {next_state, at_rest, State};
receive_data({gun_error, _Pid, StreamRef, _Reason},
             #{stream := StreamRef} = State) ->
    {next_state, at_rest, State}.

%% @private
%% @doc Chunked data response
-spec receive_chunk(term(), term()) -> term().
receive_chunk({'DOWN', _, _, _, _Reason}, _State) ->
    error(incomplete);
receive_chunk({gun_data, _Pid, StreamRef, IsFin, Data}, State) ->
    NewState = manage_chunk(IsFin, StreamRef, Data, State),
    case IsFin of
        fin ->
            {next_state, at_rest, NewState};
        nofin ->
            {next_state, receive_chunk, NewState}
    end;
receive_chunk({gun_error, _Pid, _StreamRef, _Reason}, State) ->
    {next_state, at_rest, State}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Private
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @private
clean_state() ->
    #{
       pid => undefined,
       stream => undefined,
       handle_event => undefined,
       from => undefined,
       responses => queue:new(),
       data => <<"">>,
       status_code => undefined,
       headers => undefined,
       async => false,
       async_mode => binary,
       buffer => <<"">>
     }.

%% @private
-spec do_http_verb(http_verb(), pid(), tuple()) -> reference().
do_http_verb(Method, Pid, {Uri, Headers, Body}) ->
    MethodStr = string:to_upper(atom_to_list(Method)),
    MethodBin = list_to_binary(MethodStr),
    gun:request(Pid, MethodBin, Uri, Headers, Body).

%% @private
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := undefined,
                       responses := Responses,
                       async_mode := binary}) ->
    NewResponses = queue:in({IsFin, StreamRef, Data}, Responses),
    State#{responses => NewResponses};
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := undefined,
                       responses := Responses,
                       async_mode := sse}) ->
    {Events, NewState} = sse_events(IsFin, Data, State),
    FunAdd = fun(Event, Acc) ->
                     queue:in({IsFin, StreamRef, Event}, Acc)
             end,
    NewResponses = lists:foldl(FunAdd, Responses, Events),
    NewState#{responses => NewResponses};
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := HandleEvent,
                       async_mode := binary}) ->
    HandleEvent(IsFin, StreamRef, Data),
    State;
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := HandleEvent,
                       async_mode := sse}) ->
    {Events, NewState} = sse_events(IsFin, Data, State),
    Fun = fun (Event) -> HandleEvent(IsFin, StreamRef, Event) end,
    lists:foreach(Fun, Events),

    NewState.

%% @private
process_options(Options, HeadersMap, HttpVerb) ->
    Headers = basic_auth_header(HeadersMap),
    HandleEvent = maps:get(handle_event, Options, undefined),
    Async = maps:get(async, Options, false),
    AsyncMode = maps:get(async_mode, Options, binary),
    Timeout = maps:get(timeout, Options, 5000),
    case {Async, HttpVerb} of
        {true, get} -> ok;
        {true, Other} -> throw({async_unsupported, Other});
        _ -> ok
    end,
    #{handle_event => HandleEvent,
      async => Async,
      async_mode => AsyncMode,
      headers => Headers,
      timeout => Timeout
     }.

%% @private
basic_auth_header(Headers) ->
    case maps:get(basic_auth, Headers, undefined) of
        undefined ->
            maps:to_list(Headers);
        {User, Password} ->
            HeadersClean = maps:remove(basic_auth, Headers),
            HeadersList = maps:to_list(HeadersClean),
            Base64 = encode_basic_auth(User, Password),
            BasicAuth = {<<"Authorization">>, <<"Basic ", Base64/binary>>},
            [BasicAuth | HeadersList]
    end.

%% @private
encode_basic_auth([], []) ->
    [];
encode_basic_auth(Username, Password) ->
    base64:encode(Username ++ [$: | Password]).

%% @private
sse_events(IsFin, Data, State = #{buffer := Buffer}) ->
    NewBuffer = <<Buffer/binary, Data/binary>>,
    DataList = binary:split(NewBuffer, <<"\n\n">>, [global]),
    case {IsFin, lists:reverse(DataList)} of
        {fin, [_]} ->
            {[<<>>], State#{buffer := NewBuffer}};
        {nofin, [_]} ->
            {[], State#{buffer := NewBuffer}};
        {_, [<<>> | Events]} ->
            {lists:reverse(Events), State#{buffer := <<"">>}};
        {_, [Rest | Events]} ->
            {lists:reverse(Events), State#{buffer := Rest}}
    end.

%% @private
check_uri([$/ | _]) -> ok;
check_uri(_) -> throw(missing_slash_uri).
