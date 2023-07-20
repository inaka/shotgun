%%% @author Federico Carrone <federico@inaka.net>
%%% @author Juan Facorro <juan@inaka.net>
%%% @doc Shotgun's main interface.
%%%      Use the functions provided in this module to open a connection and make
%%%      requests.
-module(shotgun).
-author("federico@inaka.net").
-author("juan@inaka.net").

-behaviour(gen_statem).

-export([ start/0
        , stop/0
        , start_link/4
        ]).

-export([ open/2
        , open/3
        , open/4
        , close/1
        ]).

-export([ %% get
          get/2
        , get/3
        , get/4
          %% post
        , post/4
        , post/5
          %% delete
        , delete/4
          %% head
        , head/4
          %% options
        , options/4
          %% patch
        , patch/4
        , patch/5
          %% put
        , put/4
        , put/5
          %% generic request
        , request/6
          %% data
        , data/2
        , data/3
          %% events
        , events/1
        , parse_event/1
        ]).

% gen_statem callbacks
-export([ init/1
        , callback_mode/0
        , terminate/3
        , code_change/4
        ]).

% gen_statem states
-export([ at_rest/3
        , wait_response/3
        , receive_data/3
        , receive_chunk/3
        ]).

-type connection_type() :: http | https.

-type open_opts()       ::
        #{
           tcp_opts => []
         , tls_opts => []
           %% timeout is passed to gun:await_up. Default if not specified
           %% is 5000 ms.
         , timeout => timeout()
           %% gun_opts are passed to gun:open
         , gun_opts => gun:opts()
         }.

-type connection() :: pid().
-type http_verb()  :: get | post | head | delete | patch | put | options.
-type uri()        :: iodata().
-type headers()    :: #{_ => _} | proplists:proplist().
-type body()       :: iodata() | body_chunked.
-type options()    ::
        #{ async => boolean()
         , async_mode => binary | sse
         , handle_event => fun((fin | nofin, reference(), binary()) -> any())
         , timeout => timeout() %% Default 5000 ms
         }.

-type response() :: #{ status_code => integer()
                     , headers => proplists:proplist()
                     , body => binary()
                     }.

-type result()   :: {ok, reference() | response()} | {error, term()}.

-type event()    :: #{ id    => binary()
                     , event => binary()
                     , data  => binary()
                     }.

-type work()  :: {atom(), list(), pid()} |
                 {atom(), {module(), boolean()}, list(), pid()}.

-export_type([response/0, event/0]).

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
    gen_statem:start_link(shotgun, [{Host, Port, Type, Opts}], []).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @equiv get(Host, Port, http, #{})
-spec open(Host :: string(), Port :: integer()) ->
    {ok, pid()} | {error, gun_open_failed | gun_open_timeout}.
open(Host, Port) ->
    open(Host, Port, http).

-spec open(Host :: string(), Port :: integer(), Type :: connection_type()) ->
    {ok, pid()} | {error, gun_open_failed | gun_open_timeout};
    (Host :: string(), Port :: integer(), Opts :: open_opts()) ->
    {ok, pid()} | {error, gun_open_failed | gun_open_timeout}.
%% @equiv get(Host, Port, Type, #{}) or get(Host, Port, http, Opts)
open(Host, Port, Type) when is_atom(Type) ->
  open(Host, Port, Type, #{});

open(Host, Port, Opts) when is_map(Opts) ->
  open(Host, Port, http, Opts).

%% @doc Opens a connection of the type provided with the host and port
%% specified and the specified connection timeout and/or Ranch
%% transport options.
-spec open(Host :: string(), Port :: integer(), Type :: connection_type(),
           Opts :: open_opts()) ->
    {ok, pid()} | {ok, pid(), term()} |
    {error, already_present | {already_started, pid()} |
            gun_open_failed | gun_open_timeout}.
open(Host, Port, Type, Opts) ->
    supervisor:start_child(shotgun_sup, [Host, Port, Type, Opts]).

%% @doc Closes the connection with the host.
-spec close(pid()) -> ok.
close(Pid) ->
    gen_statem:cast(Pid, shutdown),
    ok.

%% @equiv get(Pid, Uri, #{}, #{})
-spec get(pid(), iodata()) -> result().
get(Pid, Uri) ->
    get(Pid, Uri, #{}, #{}).

%% @equiv get(Pid, Uri, Headers, #{})
-spec get(pid(), iodata(), headers()) -> result().
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
%%     <code>async_mode</code>:
%%     when async is true the mode specifies how the data received will be
%%     processed. <code>binary</code> mode treats eat chunk received as raw
%%     binary. <code>see</code> mode buffers each chunk, splitting the data
%%     received into SSE. Default value is <code>binary</code>.
%%   </li>
%%   <li>
%%     <code>handle_event</code>:
%%     this function will be called each time either a chunk is received
%%     (<code>async_mode = binary</code>) or an event is parsed
%%     (<code>async_mode = sse</code>). If no handle_event function is provided
%%     the data received is added to a queue, whose values can be obtained
%%     calling the <code>shotgun:events/1</code>. Default value is undefined.
%%   </li>
%% </ul>
%% @end
-spec get(connection(), uri(), headers(), options()) -> result().
get(Pid, Uri, Headers, Options) ->
    request(Pid, get, Uri, Headers, [], Options).

%% @doc Performs a chunked <strong>POST</strong> request to <code>Uri</code>
%% using %% <code>Headers</code> as the content data.
-spec post(connection(), uri(), headers(), options()) -> result().
post(Pid, Uri, Headers, Options) ->
    request(Pid, post, Uri, Headers, body_chunked, Options).

%% @doc Performs a <strong>POST</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec post(connection(), uri(), headers(), body(), options()) -> result().
post(Pid, Uri, Headers, Body, Options) ->
    request(Pid, post, Uri, Headers, Body, Options).

%% @doc Performs a <strong>DELETE</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec delete(connection(), uri(), headers(), options()) -> result().
delete(Pid, Uri, Headers, Options) ->
    request(Pid, delete, Uri, Headers, [], Options).

%% @doc Performs a <strong>HEAD</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec head(connection(), uri(), headers(), options()) -> result().
head(Pid, Uri, Headers, Options) ->
    request(Pid, head, Uri, Headers, [], Options).

%% @doc Performs a <strong>OPTIONS</strong> request to <code>Uri</code> using
%% <code>Headers</code>.
-spec options(connection(), uri(), headers(), options()) -> result().
options(Pid, Uri, Headers, Options) ->
    request(Pid, options, Uri, Headers, [], Options).

%% @doc Performs a chunked <strong>PATCH</strong> request to <code>Uri</code>
%% using %% <code>Headers</code> as the content data.
-spec patch(connection(), uri(), headers(), options()) -> result().
patch(Pid, Uri, Headers, Options) ->
    request(Pid, post, Uri, Headers, body_chunked, Options).

%% @doc Performs a <strong>PATCH</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec patch(connection(), uri(), headers(), body(), options()) -> result().
patch(Pid, Uri, Headers, Body, Options) ->
    request(Pid, patch, Uri, Headers, Body, Options).

%% @doc Performs a chunked <strong>PUT</strong> request to <code>Uri</code>
%% using %% <code>Headers</code> as the content data.
-spec put(connection(), uri(), headers(), options()) -> result().
put(Pid, Uri, Headers, Options) ->
    request(Pid, put, Uri, Headers, body_chunked, Options).

%% @doc Performs a <strong>PUT</strong> request to <code>Uri</code> using
%% <code>Headers</code> and <code>Body</code> as the content data.
-spec put(connection(), uri(), headers(), body(), options()) -> result().
put(Pid, Uri, Headers, Body, Options) ->
    request(Pid, put, Uri, Headers, Body, Options).

%% @doc Performs a request to <code>Uri</code> using the HTTP method
%% specified by <code>Method</code>,  <code>Body</code> as the content data and
%% <code>Headers</code> as the request's headers.
-spec request(connection(), http_verb(), uri(), headers(), body(), options()) ->
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
        gen_statem:call(Pid, Event, Timeout)
    catch
        _:Reason -> {error, Reason}
    end;
request(Pid, Method, Uri, Headers0, Body, Options) ->
    try
        check_uri(Uri),
        #{headers := Headers, timeout := Timeout} =
          process_options(Options, Headers0, Method),
        Event = {Method, {Uri, Headers, Body}},
        gen_statem:call(Pid, Event, Timeout)
    catch
        _:Reason -> {error, Reason}
    end.

%% @doc Send data when the
-spec data(connection(), body()) -> ok | {error, any()}.
data(Conn, Data) ->
    data(Conn, Data, nofin).

-spec data(connection(), body(), fin | nofin) -> ok | {error, any()}.
data(Conn, Data, FinNoFin) ->
    gen_statem:call(Conn, {data, Data, FinNoFin}).

%% @doc Returns a list of all received events up to now.
-spec events(Pid :: pid()) -> [{nofin | fin, reference(), binary()}].
events(Pid) ->
    gen_statem:call(Pid, get_events).

%% @doc Parse an SSE event in binary format. For example the following binary
%% <code>&lt;&lt;"data: some content\n"&gt;&gt;</code> will be turned into the
%% following map <code>#{&lt;&lt;"data"&gt;&gt; =>
%% &lt;&lt;"some content"&gt;&gt;}</code>.
-spec parse_event(binary()) -> event().
parse_event(EventBin) ->
    Lines = binary:split(EventBin, <<"\n">>, [global]),
    FoldFun =
        fun(Line, #{data := Data} = Event) ->
                case Line of
                    <<"data:", NewData/binary>> ->
                        TrimmedNewData = binary_ltrim(NewData),
                        Event#{
                            data => <<Data/binary, TrimmedNewData/binary, "\n">>
                        };
                    <<"id:", Id/binary>> ->
                        Event#{id => binary_ltrim(Id)};
                    <<"event:", EventName/binary>> ->
                        Event#{event => binary_ltrim(EventName)};
                    <<_Comment/binary>> ->
                        Event
                end
        end,
    lists:foldl(FoldFun, #{data => <<>>}, Lines).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_statem callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-type statedata() :: #{ async            => boolean()
                      , async_mode       => false | binary | sse
                      , buffer           => binary()
                      , data             => binary()
                      , from             => term()
                      , handle_event     => term()
                      , headers          => term()
                      , pending_requests => queue:queue() | undefined
                      , pid              => pid() | undefined
                      , responses        => queue:queue() | undefined
                      , status_code      => integer() | undefined
                      , stream           => reference() | undefined}.

%% @private
-spec callback_mode() -> state_functions.
callback_mode() -> state_functions.

%% @private
-spec init([{string(), integer(), connection_type(), open_opts()}]) ->
    {ok, at_rest, statedata()} | {stop, gun_open_timeout} | {stop, gun_open_failed}.
init([{Host, Port, Type, Opts}]) ->
    GunType = case Type of
                  http -> tcp;
                  https -> ssl
              end,
    TcpOpts = maps:get(tcp_opts, Opts, []),
    TlsOpts = maps:get(tls_opts, Opts, []),
    PassedGunOpts = maps:get(gun_opts, Opts, #{}),
    DefaultGunOpts = #{
                transport     => GunType,
                retry         => 1,
                retry_timeout => 1,
                tcp_opts      => TcpOpts,
                tls_opts      => TlsOpts
               },
    GunOpts = maps:merge(DefaultGunOpts, PassedGunOpts),
    Timeout = maps:get(timeout, Opts, 5000),
    {ok, Pid} = gun:open(Host, Port, GunOpts),
    _ = monitor(process, Pid),
    case gun:await_up(Pid, Timeout) of
      {ok, _} ->
        StateData = clean_state_data(),
        {ok, at_rest, StateData#{pid => Pid}};
      %The only apparent timeout for gun:open is the connection timeout of the
      %underlying transport. So, a timeout message here comes from gun:await_up.
      {error, timeout} ->
        {stop, gun_open_timeout};
      %gun currently terminates with reason normal if gun:open fails to open
      %the requested connection. This bubbles up through gun:await_up.
      {error, normal} ->
        {stop, gun_open_failed};
      %gun can terminate with reason {shutdown, nxdomain}; however, that's not
      %explicitly specced and makes dialyzer unhappy, so we loosely pattern
      %match it here.
      {error, _} ->
        {stop, gun_open_failed}
    end.

%% @private
-spec handle_info(term(), atom(), term()) ->
    {next_state, atom(), statedata()}.
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
    Module:StateName(cast, Event, StateData).

%% @private
-spec code_change(term(), atom(), term(), term()) -> {ok, atom(), term()}.
code_change(_OldVsn, StateName, StateData, _Extra) ->
    {ok, StateName, StateData}.

%% @private
-spec terminate(term(), atom(), term()) -> ok.
terminate(_Reason, _StateName, #{pid := Pid} = _StateData) ->
    gun:shutdown(Pid),
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% gen_statem states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%See if we have work. If we do, dispatch.
%If we don't, stay in at_rest.
%% @private
-spec at_rest({call, gen_statem:from()} | cast | info, term(), statedata()) ->
    {keep_state_and_data, [{reply, gen_statem:from(), {error, {unexpected, atom()}}}]} |
    {keep_state, statedata(), [{reply, gen_statem:from(), list()}]} |
    {keep_state, statedata(), [{timeout, timeout(), get_work}]} |
    stop |
    {next_state, atom(), statedata()}.
at_rest({call, From}, Event, StateData) ->
    enqueue_work_or_stop(at_rest, Event, From, StateData);
at_rest(cast, {'DOWN', _, _, _, Reason}, _StateData) ->
    exit(Reason);
at_rest(timeout, _Event, StateData) ->
    case get_work(StateData) of
        no_work ->
            {next_state, at_rest, StateData};
        {ok, Work, NewStateData} ->
            ok = gen_statem:cast(self(), Work),
            {next_state, at_rest, NewStateData}
    end;
at_rest(cast, shutdown, _StateData) ->
    stop;
at_rest(cast, {get_async, {HandleEvent, AsyncMode}, Args, From},
        StateData = #{pid := Pid}) ->
    StreamRef = do_http_verb(get, Pid, Args),
    CleanStateData = clean_state_data(StateData),
    NewStateData = CleanStateData#{
                     from => From,
                     pid => Pid,
                     stream => StreamRef,
                     handle_event => HandleEvent,
                     async => true,
                     async_mode => AsyncMode
                    },
    {next_state, wait_response, NewStateData};
at_rest(cast, {HttpVerb, {_, _, Body} = Args, From}, StateData = #{pid := Pid}) ->
    StreamRef = do_http_verb(HttpVerb, Pid, Args),
    CleanStateData = clean_state_data(StateData),
    NewStateData = CleanStateData#{ pid    => Pid
                                  , stream => StreamRef
                                  , from   => From
                                  },
    case Body of
        body_chunked ->
            gen_statem:cast(self(), body_chunked);
        _ -> ok
    end,
    {next_state, wait_response, NewStateData};
at_rest(info, Event, StateData) ->
    handle_info(Event, at_rest, StateData).

%% @private
-spec wait_response({call, gen_statem:from()} | cast | info, term(), statedata()) ->
    {keep_state_and_data, [{reply, gen_statem:from(), {error, {unexpected, atom()}}}]} |
    {keep_state, statedata(), [{reply, gen_statem:from(), list()}]} |
    {keep_state, statedata(), [{timeout, timeout(), get_work}]} |
    stop |
    {stop, {unexpected, any()}, statedata()} |
    {next_state, atom(), statedata()}.
wait_response({call, From}
              , {data, Data, FinNoFin}
              , #{stream := StreamRef, pid := Pid} = StateData) ->
    ok = gun:data(Pid, StreamRef, FinNoFin, Data),
    {next_state, wait_response, StateData, [{reply, From, ok}]};
wait_response({call, From}, Event, StateData) ->
    enqueue_work_or_stop(wait_response, Event, From, StateData);
wait_response(cast, shutdown, _StateData) ->
    stop;
wait_response(cast, {'DOWN', _, _, _, Reason}, _StateData) ->
    exit(Reason);
wait_response(cast, {gun_response, _Pid, _StreamRef, fin, StatusCode, Headers},
              #{from := From} = StateData) ->
    Response = #{status_code => StatusCode, headers => Headers},
    {next_state, at_rest, StateData, [{reply, From, {ok, Response}}]};
wait_response(cast, {gun_response, _Pid, _StreamRef, nofin, StatusCode, Headers},
              #{from := From, stream := StreamRef, async := Async} = StateData) ->
    {StateName, Actions} =
      case lists:keyfind(<<"transfer-encoding">>, 1, Headers) of
          {<<"transfer-encoding">>, <<"chunked">>} when Async ->
              Result = {ok, StreamRef},
              {receive_chunk, [{reply, From, Result}]};
          _ ->
              {receive_data, []}
      end,
    { next_state
    , StateName
    , StateData#{status_code := StatusCode, headers := Headers}
    , Actions
    };
wait_response(cast, {gun_error, _Pid, _StreamRef, Error},
              #{from := From} = StateData) ->
    {next_state, at_rest, StateData, [{reply, From, {error, Error}}]};
wait_response(cast, body_chunked,
              #{stream := StreamRef, from := From} = StateData) ->
    {next_state, wait_response, StateData, [{reply, From, {ok, StreamRef}}]};
wait_response(cast, Event, StateData) ->
    {stop, {unexpected, Event}, StateData};
wait_response(info, Event, StateData) ->
    handle_info(Event, wait_response, StateData).

%% @private
%% @doc Regular response
-spec receive_data({call, gen_statem:from()} | cast | info, term(), statedata()) ->
    {keep_state_and_data, [{reply, gen_statem:from(), {error, {unexpected, atom()}}}]} |
    {keep_state, statedata(), [{reply, gen_statem:from(), list()}]} |
    {keep_state, statedata(), [{timeout, timeout(), get_work}]} |
    stop |
    {next_state, atom(), statedata()}.
receive_data({call, From}, Event, StateData) ->
    enqueue_work_or_stop(receive_data, Event, From, StateData);
receive_data(cast, shutdown, _StateData) ->
    stop;
receive_data(cast, {'DOWN', _, _, _, _Reason}, _StateData) ->
    error(incomplete);
receive_data(cast, {gun_data, _Pid, StreamRef, nofin, Data},
             #{stream := StreamRef, data := DataAcc} = StateData) ->
    NewData = <<DataAcc/binary, Data/binary>>,
    {next_state, receive_data, StateData#{data => NewData}};
receive_data(cast, {gun_data, _Pid, _StreamRef, fin, Data},
             #{data := DataAcc, from := From, status_code
               := StatusCode, headers := Headers} = StateData) ->
    NewData = <<DataAcc/binary, Data/binary>>,
    Result = {ok, #{status_code => StatusCode,
                    headers => Headers,
                    body => NewData
                   }},
    {next_state, at_rest, StateData, [{reply, From, Result}]};
receive_data(cast, {gun_error, _Pid, StreamRef, _Reason},
             #{stream := StreamRef} = StateData) ->
    {next_state, at_rest, StateData};
receive_data(info, Event, StateData) ->
    handle_info(Event, receive_data, StateData).

%% @private
%% @doc Chunked data response
-spec receive_chunk({call, gen_statem:from()} | cast | info, term(), statedata()) ->
    {keep_state_and_data, [{reply, gen_statem:from(), {error, {unexpected, atom()}}}]} |
    {keep_state, statedata(), [{reply, gen_statem:from(), list()}]} |
    {keep_state, statedata(), [{timeout, timeout(), get_work}]} |
    stop |
    {next_state, atom(), statedata(), [{timeout, 0, 0}]} |
    {next_state, atom(), statedata()}.
receive_chunk({call, From}, Event, StateData) ->
    enqueue_work_or_stop(receive_chunk, Event, From, StateData);
receive_chunk(cast, {'DOWN', _, _, _, _Reason}, _StateData) ->
    error(incomplete);
receive_chunk(cast, shutdown, _StateData) ->
    stop;
receive_chunk(cast, {gun_data, _Pid, StreamRef, IsFin, Data}, StateData) ->
    NewStateData = manage_chunk(IsFin, StreamRef, Data, StateData),
    case IsFin of
        fin ->
            {next_state, at_rest, NewStateData, [{timeout, 0, 0}]};
        nofin ->
            {next_state, receive_chunk, NewStateData}
    end;
receive_chunk(cast, {gun_error, _Pid, _StreamRef, _Reason}, StateData) ->
    {next_state, at_rest, StateData, [{timeout, 0, 0}]};
receive_chunk(info, Event, StateData) ->
    handle_info(Event, receive_chunk, StateData).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Private
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @private
-spec clean_state_data() -> statedata().
clean_state_data() ->
    clean_state_data(#{}).

%% @private
-spec clean_state_data(map()) -> statedata().
clean_state_data(StateData) ->
    Responses = maps:get(responses, StateData, queue:new()),
    Requests  = maps:get(pending_requests, StateData, queue:new()),
    #{
       pid              => undefined,
       stream           => undefined,
       handle_event     => undefined,
       from             => undefined,
       responses        => Responses,
       data             => <<"">>,
       status_code      => undefined,
       headers          => undefined,
       async            => false,
       async_mode       => binary,
       buffer           => <<"">>,
       pending_requests => Requests
     }.

%% @private
-spec do_http_verb(http_verb(), pid(), tuple()) -> reference().
do_http_verb(Method, Pid, {Uri, Headers, body_chunked}) ->
    gun:request(Pid, http_verb_bin(Method), Uri, Headers);
do_http_verb(Method, Pid, {Uri, Headers, Body}) ->
    gun:request(Pid, http_verb_bin(Method), Uri, Headers, Body).

-spec http_verb_bin(atom()) -> binary().
http_verb_bin(Method) ->
    MethodStr = string:to_upper(atom_to_list(Method)),
    list_to_binary(MethodStr).

%% @private
-spec manage_chunk(fin | nofin, reference(), binary(), statedata()) ->
  statedata().
manage_chunk(IsFin, StreamRef, Data,
             StateData = #{handle_event := undefined,
                           responses := Responses,
                           async_mode := binary}) ->
    NewResponses = queue:in({IsFin, StreamRef, Data}, Responses),
    StateData#{responses => NewResponses};
manage_chunk(IsFin, StreamRef, Data,
             StateData = #{handle_event := undefined,
                           responses := Responses,
                           async_mode := sse}) ->
    {Events, NewStateData} = sse_events(IsFin, Data, StateData),
    FunAdd = fun(Event, Acc) ->
                     queue:in({IsFin, StreamRef, Event}, Acc)
             end,
    NewResponses = lists:foldl(FunAdd, Responses, Events),
    NewStateData#{responses => NewResponses};
manage_chunk(IsFin, StreamRef, Data,
             StateData = #{handle_event := HandleEvent,
                           async_mode := binary}) ->
    HandleEvent(IsFin, StreamRef, Data),
    StateData;
manage_chunk(IsFin, StreamRef, Data,
             StateData = #{handle_event := HandleEvent,
                           async_mode := sse}) ->
    {Events, NewStateData} = sse_events(IsFin, Data, StateData),
    Fun = fun (Event) -> HandleEvent(IsFin, StreamRef, Event) end,
    lists:foreach(Fun, Events),
    NewStateData.

%% @private
-spec process_options(map(), headers(), http_verb()) -> map().
process_options(Options, Headers0, HttpVerb) ->
    Headers = basic_auth_header(Headers0),
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
-spec basic_auth_header(headers()) -> proplists:proplist().
basic_auth_header(Headers) when is_map(Headers) ->
    basic_auth_header(maps:to_list(Headers));
basic_auth_header(Headers) ->
    case lists:keyfind(basic_auth, 1, Headers) of
        false ->
            Headers;
        {_, {User, Password}} = Res ->
            HeadersList = lists:delete(Res, Headers),
            Base64 = encode_basic_auth(User, Password),
            BasicAuth = {<<"Authorization">>, <<"Basic ", Base64/binary>>},
            [BasicAuth | HeadersList]
    end.

%% @private
-type ascii_string() :: [1..255].

-spec encode_basic_auth(ascii_string(), ascii_string()) -> binary().
encode_basic_auth(Username, Password) ->
    base64:encode(Username ++ [$: | Password]).

%% @private
-spec sse_events(fin | nofin, binary(), statedata()) ->
    {list(binary()), statedata()}.
sse_events(IsFin, Data, StateData = #{buffer := Buffer}) ->
    NewBuffer = <<Buffer/binary, Data/binary>>,
    DataList = binary:split(NewBuffer, <<"\n\n">>, [global]),
    case {IsFin, lists:reverse(DataList)} of
        {fin, [_]} ->
            {[<<>>], StateData#{buffer := NewBuffer}};
        {nofin, [_]} ->
            {[], StateData#{buffer := NewBuffer}};
        {_, [<<>> | Events]} ->
            {lists:reverse(Events), StateData#{buffer := <<"">>}};
        {_, [Rest | Events]} ->
            {lists:reverse(Events), StateData#{buffer := Rest}}
    end.

%% @private
-spec check_uri(iolist()) -> ok .
check_uri([$/ | _]) -> ok;
check_uri(U) ->
  case iolist_to_binary(U) of
    <<"/", _/binary>> -> ok;
    _ -> throw (missing_slash_uri)
  end.

%% @private
-spec enqueue_work_or_stop(atom(), term(), gen_statem:from(), statedata()) ->
    {keep_state, statedata(), [{reply, gen_statem:from(), list()}]} |
    {keep_state, statedata(), [{timeout, timeout(), get_work}]} |
    {keep_state_and_data, [{reply, gen_statem:from(), {error, {unexpected, atom()}}}]}.
enqueue_work_or_stop(_StateName, get_events, From, #{responses := Responses} = StateData) ->
    Reply = queue:to_list(Responses),
    {keep_state, StateData#{responses := queue:new()}, [{reply, From, Reply}]};
enqueue_work_or_stop(StateName = at_rest, Event, From, StateData) ->
    enqueue_work_or_stop(StateName, Event, From, StateData, 0);
enqueue_work_or_stop(StateName, Event, From, StateData) ->
    enqueue_work_or_stop(StateName, Event, From, StateData, infinity).

%% @private
-spec enqueue_work_or_stop(atom(), term(), gen_statem:from(), statedata(), timeout()) ->
    {keep_state_and_data, [{reply, gen_statem:from(), {error, {unexpected, atom()}}}]} |
    {keep_state, statedata(), [{timeout, timeout(), get_work}]}.
enqueue_work_or_stop(_StateName, Event, From, StateData, Timeout) ->
    case create_work(Event, From) of
        {ok, Work} ->
            NewStateData = append_work(Work, StateData),
            {keep_state, NewStateData, [{timeout, Timeout, get_work}]};
        not_work ->
            Error = {error, {unexpected, Event}},
            {keep_state_and_data, [{reply, From, Error}]}
    end.

%% @private
-spec create_work({atom(), list()}, gen_statem:from()) ->
    not_work | {ok, work()}.
create_work({M = get_async, {HandleEvent, AsyncMode}, Args}, From) ->
    {ok, {M, {HandleEvent, AsyncMode}, Args, From}};
create_work({M, Args}, From)
  when M == get orelse M == post
       orelse M == delete orelse M == head
       orelse M == options orelse M == patch
       orelse M == put ->
    {ok, {M, Args, From}};
create_work(_, _) ->
    not_work.

%% @private
-spec get_work(statedata()) -> no_work | {ok, work(), statedata()}.
get_work(StateData) ->
    PendingReqs = maps:get(pending_requests, StateData),
    case queue:is_empty(PendingReqs) of
        true ->
            no_work;
        false ->
            {{value, Work}, Rest} = queue:out(PendingReqs),
            NewStateData = StateData#{pending_requests => Rest},
            {ok, Work, NewStateData}
    end.

%% @private
-spec append_work(work(), statedata()) -> statedata().
append_work(Work, StateData) ->
    #{pending_requests := PendingReqs} = StateData,
    StateData#{pending_requests := queue:in(Work, PendingReqs)}.

%% @private
-spec binary_ltrim(binary()) -> binary().
binary_ltrim(<<32, Bin/binary>>) ->
    binary_ltrim(Bin);
binary_ltrim(Bin) ->
    Bin.
