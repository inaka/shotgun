%%% @author Federico Carrone <federico@inaka.net>
%%% @author Juan Facorro <juan@inaka.net>
%%% @doc Shotgun's main interface.
%%%      Use the functions provided in this module to open a connection and make
%%%      requests.
-module(shotgun).
-author("federico@inaka.net").
-author("juan@inaka.net").

-behavior(gen_fsm).

-export([
         start/0,
         stop/0,
         start_link/3,
         open/2,
         open/3,
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
           basic_auth => {string(), string()}
         }.
-type http_verb() :: get | post | head | delete | patch | put | options.

-type connection_type() :: http | https.


%% @doc Starts the application and all the ones it depends on.
-spec start() -> {ok, [atom()]}.
start() ->
    {ok, _} = application:ensure_all_started(shotgun).

%% @doc Stops the application
-spec stop() -> ok | {error, term()}.
stop() ->
    application:stop(shotgun).

%% @private
-spec start_link(string(), integer(), connection_type()) ->
    {ok, pid()} | ignore | {error, term()}.
start_link(Host, Port, Type) ->
    gen_fsm:start(shotgun, [Host, Port, Type], []).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @equiv get(Host, Port, http)
-spec open(Host :: string(), Port :: integer()) -> {ok, pid()}.
open(Host, Port) ->
    open(Host, Port, http).

%% @doc Opens a connection of the type provided with the host in port specified.
-spec open(Host :: string(), Port :: integer(), Type :: connection_type()) ->
    {ok, pid()}.
open(Host, Port, Type) ->
    supervisor:start_child(shotgun_sup, [Host, Port, Type]).


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
get(Pid, Uri, Headers0, Options) ->
    #{handle_event := HandleEvent,
      async := IsAsync,
      async_mode := AsyncMode,
      headers := Headers} = process_options(Options, Headers0, get),

    Event = case IsAsync of
                true ->
                    {get_async, {HandleEvent, AsyncMode}, {Uri, Headers, []}};
                false ->
                    {get, {Uri, Headers, []}}
           end,
    StreamRef = gen_fsm:sync_send_event(Pid, Event),
    {ok, StreamRef}.

%% @doc Performs a <strong>POST</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec post(pid(), string(), headers(), iodata(), options()) -> result().
post(Pid, Uri, Headers0, Body, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, post),
        Event = {post, {Uri, Headers, Body}},
        StreamRef = gen_fsm:sync_send_event(Pid, Event),
        {ok, StreamRef}
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Performs a <strong>DELETE</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec delete(pid(), string(), headers(), options()) -> result().
delete(Pid, Uri, Headers0, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, delete),
        Event = {delete, {Uri, Headers, []}},
        StreamRef = gen_fsm:sync_send_event(Pid, Event),
        {ok, StreamRef}
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Performs a <strong>HEAD</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec head(pid(), string(), headers(), options()) -> result().
head(Pid, Uri, Headers0, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, head),
        Event = {head, {Uri, Headers, []}},
        StreamRef = gen_fsm:sync_send_event(Pid, Event),
        {ok, StreamRef}
    catch
        _:Reason -> {error, Reason}

    end.
%% @doc Performs a <strong>OPTIONS</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec options(pid(), string(), headers(), options()) -> result().
options(Pid, Uri, Headers0, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, options),
        Event = {options, {Uri, Headers, []}},
        StreamRef = gen_fsm:sync_send_event(Pid, Event),
        {ok, StreamRef}
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Performs a <strong>PATCH</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec patch(pid(), string(), headers(), iodata(), options()) -> result().
patch(Pid, Uri, Headers0, Body, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, patch),
        Event = {patch, {Uri, Headers, Body}},
        StreamRef = gen_fsm:sync_send_event(Pid, Event),
        {ok, StreamRef}
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Performs a <strong>PUT</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec put(pid(), string(), headers(), iodata(), options()) -> result().
put(Pid, Uri, Headers0, Body, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, put),
        Event = {put, {Uri, Headers, Body}},
        StreamRef = gen_fsm:sync_send_event(Pid, Event),
        {ok, StreamRef}
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Performs a request to <code>Uri</code> using the HTTP method
%% specified by <code>Method</code>,  <code>Body</code> as the content data and
%% <code>Headers</code> as the request's headers.
-spec request(pid(), http_verb(), string(), headers(), iodata(), options()) ->
    result().
request(Pid, Method, Uri, Headers0, Body, Options) ->
    try
        #{handle_event := HandleEvent,
          headers := Headers} = process_options(Options, Headers0, Method),
        Event = {Method, {Uri, Headers, Body}},
        Response = gen_fsm:sync_send_event(Pid, Event),
        {ok, Response}
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
                          Event#{event => EventName}
                  end
          end,
    lists:foldr(FoldFun, #{data => []}, Lines).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_fsm callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @private
-spec init([term()]) -> term().
init([Host, Port, Type]) ->
    GunType = case Type of
                  http -> tcp;
                  https -> ssl
              end,
    Opts = [{type, GunType},
            {retry, 1},
            {retry_timeout, 1}
           ],
    {ok, Pid} = gun:open(Host, Port, Opts),
    State = clean_state(),
    {ok, at_rest, State#{pid => Pid}}.

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
                 pid => Pid,
                 stream => StreamRef,
                 handle_event => HandleEvent,
                 async => true,
                 async_mode => AsyncMode
                },
    gen_fsm:reply(From, StreamRef),
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
                gen_fsm:reply(From, Response),
                Responses;
            true ->
                queue:in(Response, Responses)
        end,
    {next_state, at_rest, State#{responses => NewResponses}};
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
    gen_fsm:reply(From, #{status_code => StatusCode,
                          headers => Headers,
                          body => NewData
                         }),
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
    manage_chunk(IsFin, StreamRef, Data, State);
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
       chunk_mode => binary,
       buffer => <<"">>
     }.

%% @private
maps_get(Key, Map, Default) ->
    case maps:is_key(Key, Map) of
        true ->
            maps:get(Key, Map);
        false ->
            Default
    end.

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
    {next_state, receive_chunk, State#{responses => NewResponses}};
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := undefined,
                       responses := Responses,
                       async_mode := sse}) ->
    {Events, NewState} = sse_events(Data, State),
    FunAdd = fun(Event, Acc) ->
                 queue:in({IsFin, StreamRef, Event}, Acc)
             end,
    NewResponses = lists:foldl(FunAdd, Responses, Events),
    {next_state, receive_chunk, NewState#{responses => NewResponses}};
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := HandleEvent,
                       async_mode := binary}) ->
    HandleEvent(IsFin, StreamRef, Data),
    {next_state, receive_chunk, State};
manage_chunk(IsFin, StreamRef, Data,
             State = #{handle_event := HandleEvent,
                       async_mode := sse}) ->
    {Events, NewState} = sse_events(Data, State),
    Fun = fun (Event) -> HandleEvent(IsFin, StreamRef, Event) end,
    lists:foreach(Fun, Events),

    {next_state, receive_chunk, NewState}.

%% @private
process_options(Options, HeadersMap, HttpVerb) ->
    Headers = basic_auth_header(HeadersMap),
    HandleEvent = maps_get(handle_event, Options, undefined),
    Async = maps_get(async, Options, false),
    AsyncMode = maps_get(async_mode, Options, binary),
    case {Async, HttpVerb} of
        {true, get} -> ok;
        {true, Other} -> throw({async_unsupported, Other});
        _ -> ok
    end,
    #{handle_event => HandleEvent,
      async => Async,
      async_mode => AsyncMode,
      headers => Headers}.

%% @private
basic_auth_header(Headers) ->
    case maps_get(basic_auth, Headers, undefined) of
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
sse_events(Data, State = #{buffer := Buffer}) ->
    NewBuffer = <<Buffer/binary, Data/binary>>,
    DataList = binary:split(NewBuffer, <<"\n\n">>, [global]),
    case lists:reverse(DataList) of
        [_] ->
            {[], State#{buffer := NewBuffer}};
        [<<>> | Events] ->
            {lists:reverse(Events), State#{buffer := <<"">>}};
        [Rest | Events] ->
            {lists:reverse(Events), State#{buffer := Rest}}
    end.
