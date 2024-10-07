-module(http_server).

-export([start/0, stop/0]).
-export([start/2, stop/1, start_phase/3]).

%%------------------------------------------------------------------------------
%% Application
%%------------------------------------------------------------------------------

%% @doc Starts the application
start() ->
    application:ensure_all_started(?MODULE).

%% @doc Stops the application
stop() ->
    application:stop(?MODULE).

%%------------------------------------------------------------------------------
%% Behaviour
%%------------------------------------------------------------------------------

%% @private
start(_StartType, _StartArgs) ->
    http_server_sup:start_link().

%% @private
stop(_State) ->
    ok = cowboy:stop_listener(http_server).

-spec start_phase(atom(), application:start_type(), []) -> ok | {error, term()}.
start_phase(start_cowboy_http, _StartType, []) ->
    Port = application:get_env(http_server, http_port, 8888),
    ListenerCount = application:get_env(http_server, http_listener_count, 10),
    Routes =
        [{'_',
          [{"/", http_simple_handler, []},
           {"/basic-auth", http_basic_auth_handler, []},
           {"/chunked-sse[/:count]", lasse_handler, [http_sse_handler]},
           {"/chunked-binary", http_binary_handler, []}]}],
    Dispatch = cowboy_router:compile(Routes),
    TransportOptions = [{port, Port}],
    ProtocolOptions = #{env => #{dispatch => Dispatch}},
    {ok, _} = cowboy:start_clear(http_server, TransportOptions, ProtocolOptions),
    ok.
