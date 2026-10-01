-module(shotgun_async_SUITE).

-export([all/0, init_per_suite/1, end_per_suite/1, init_per_testcase/2,
         end_per_testcase/2]).
-export([
    get_sse/1,
    get_binary/1,
    work_queue/1,
    get_handle_event/1,
    async_unsupported/1,
    async_gun_down_no_reopen/1,
    async_gun_down_with_reopen/1,
    read_timeout_stops_silent_stream/1,
    read_timeout_stops_stream_after_data/1,
    read_timeout_reset_by_chunks/1,
    read_timeout_cancelled_when_connection_drops/1,
    read_timeout_default_keeps_silent_stream/1,
    read_timeout_rejects_invalid_values/1
]).

-include_lib("common_test/include/ct.hrl").

%%------------------------------------------------------------------------------
%% Common Test
%%------------------------------------------------------------------------------

-spec all() -> [atom()].
all() ->
    shotgun_test_utils:all(?MODULE).

-spec init_per_suite(shotgun_test_utils:config()) -> shotgun_test_utils:config().
init_per_suite(Config) ->
    {ok, _} = shotgun:start(),
    {ok, _} = http_server:start(),
    Config.

-spec end_per_suite(shotgun_test_utils:config()) -> shotgun_test_utils:config().
end_per_suite(Config) ->
    ok = shotgun:stop(),
    ok = http_server:stop(),
    Config.

-spec init_per_testcase(atom(), shotgun_test_utils:config()) ->
                           shotgun_test_utils:config().
init_per_testcase(_, Config) ->
    Port = application:get_env(http_server, http_port, 8888),
    {ok, Conn} = shotgun:open("localhost", Port),
    [{conn, Conn} | Config].

-spec end_per_testcase(atom(), shotgun_test_utils:config()) ->
                          shotgun_test_utils:config().
end_per_testcase(_, Config) ->
    Conn = ?config(conn, Config),
    ok = shotgun:close(Conn),
    Config.

%%------------------------------------------------------------------------------
%% Test Cases
%%------------------------------------------------------------------------------

-spec get_sse(shotgun_test_utils:config()) -> {comment, string()}.
get_sse(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("GET returns a ref"),
    Opts = #{async => true, async_mode => sse},
    {ok, Ref} = shotgun:get(Conn, <<"/chunked-sse">>, #{}, Opts),
    true = is_reference(Ref),

    timer:sleep(500),

    ct:comment("There are 3 elements"),
    [Event1, Event2, Fin] = shotgun:events(Conn),

    {nofin, Ref, EventBin1} = Event1,
    #{data := <<"pong\n">>} = shotgun:parse_event(EventBin1),
    {nofin, Ref, EventBin2} = Event2,
    #{data := <<"pong\n">>} = shotgun:parse_event(EventBin2),
    {fin, Ref, <<>>} = Fin,

    ct:comment("GET returns a response when no content is available"),
    {ok, Response} = shotgun:get(Conn, <<"/chunked-sse/0">>, #{}, Opts),
    #{status_code := 204} = Response,

    ct:comment("There are 0 elements"),
    [] = shotgun:events(Conn),

    {comment, ""}.

-spec get_binary(shotgun_test_utils:config()) -> {comment, string()}.
get_binary(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("GET should return a ref"),
    Opts = #{async => true, async_mode => binary},
    {ok, Ref} = shotgun:get(Conn, <<"/chunked-binary">>, #{}, Opts),
    true = is_reference(Ref),

    timer:sleep(500),

    [Chunk1, Chunk2, Fin] = shotgun:events(Conn),
    {nofin, Ref, <<"1">>} = Chunk1,
    {nofin, Ref, <<"2">>} = Chunk2,
    {fin, Ref, <<>>} = Fin,

    {comment, ""}.

-spec work_queue(shotgun_test_utils:config()) -> {comment, string()}.
work_queue(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("Async GET should return a ref"),
    Opts = #{async => true, async_mode => sse},
    {ok, RefAsyncGet} = shotgun:get(Conn, <<"/chunked-sse/20">>, #{}, Opts),
    true = is_reference(RefAsyncGet),

    ct:comment("Queued GET should return a ref as well"),
    {ok, Response} = shotgun:get(Conn, <<"/">>),
    #{status_code := 200} = Response,
    ct:comment("Events from the async GET should be there"),
    Events = shotgun:events(Conn),
    21 = length(Events), %% 20 nofin + 1 fin

    {comment, ""}.

-spec get_handle_event(shotgun_test_utils:config()) -> {comment, string()}.
get_handle_event(Config) ->
    Conn = ?config(conn, Config),
    Self = self(),

    ct:comment("SSE: GET should return a ref"),
    HandleEvent =
        fun(_, _, EventBin) ->
           case shotgun:parse_event(EventBin) of
               #{id := Data} ->
                   Self ! Data;
               _ ->
                   ok
           end
        end,
    Opts =
        #{async => true,
          async_mode => sse,
          handle_event => HandleEvent},
    {ok, _Ref} = shotgun:get(Conn, <<"/chunked-sse/3">>, #{}, Opts),

    timer:sleep(500),

    ok = shotgun_test_utils:wait_receive(<<"1">>, 500),
    ok = shotgun_test_utils:wait_receive(<<"2">>, 500),
    ok = shotgun_test_utils:wait_receive(<<"3">>, 500),
    timeout = shotgun_test_utils:wait_receive(<<"4">>, 500),

    ct:comment("SSE: GET should return a ref"),
    HandleEventBin = fun(_, _, Data) -> Self ! Data end,
    OptsBin =
        #{async => true,
          async_mode => binary,
          handle_event => HandleEventBin},
    {ok, _RefBin} = shotgun:get(Conn, <<"/chunked-binary">>, #{}, OptsBin),
    timer:sleep(500),

    ok = shotgun_test_utils:wait_receive(<<"1">>, 500),
    ok = shotgun_test_utils:wait_receive(<<"2">>, 500),
    timeout = shotgun_test_utils:wait_receive(<<"3">>, 500),

    {comment, ""}.

-spec async_unsupported(shotgun_test_utils:config()) -> {comment, string()}.
async_unsupported(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("Async POST should return an error"),
    {error, {async_unsupported, post}} = shotgun:post(Conn, "/", #{}, <<>>, #{async => true}),

    ct:comment("Async PUT should return an error"),
    {error, {async_unsupported, put}} = shotgun:put(Conn, "/", #{}, <<>>, #{async => true}),

    {comment, ""}.

-spec async_gun_down_no_reopen(shotgun_test_utils:config()) -> {comment, string()}.
async_gun_down_no_reopen(Config) ->
    Conn = ?config(conn, Config),
    Self = self(),

    ct:comment("SSE: GET should return a ref"),
    HandleEvent =
        fun(_, _, EventBin) ->
           case shotgun:parse_event(EventBin) of
               #{id := Data} ->
                   Self ! Data;
               _ ->
                   ok
           end
        end,
    Opts =
        #{async => true,
          async_mode => sse,
          allow_reconnect => false,
          handle_event => HandleEvent},
    {ok, _Ref} = shotgun:get(Conn, <<"/chunked-sse/3">>, #{}, Opts),

    timer:sleep(500),

    ok = shotgun_test_utils:wait_receive(<<"1">>, 500),
    {at_rest, _} = sys:get_state(Conn),
    %% Server is stopped immediately after receiving event.
    %% We should be at rest waiting for the next event.
    http_server:stop_listener(),
    timer:sleep(500),
    %% Listener needs to be running at test end.
    http_server:start_listener(),

    ct:comment("Connection should be closed after server shutdown"),
    false = erlang:is_process_alive(Conn),

    {comment, ""}.

-spec async_gun_down_with_reopen(shotgun_test_utils:config()) -> {comment, string()}.
async_gun_down_with_reopen(Config) ->
    Conn = ?config(conn, Config),
    Self = self(),

    ct:comment("SSE: GET should return a ref"),
    HandleEvent =
        fun(_, _, EventBin) ->
           case shotgun:parse_event(EventBin) of
               #{id := Data} ->
                   Self ! Data;
               _ ->
                   ok
           end
        end,
    Opts =
        #{async => true,
          async_mode => sse,
          allow_reconnect => true,
          handle_event => HandleEvent},
    {ok, _Ref} = shotgun:get(Conn, <<"/chunked-sse/3">>, #{}, Opts),

    timer:sleep(500),

    ok = shotgun_test_utils:wait_receive(<<"1">>, 500),
    {at_rest, _} = sys:get_state(Conn),
    %% Server is stopped immediately after receiving event.
    %% We should be at rest waiting for the next event.
    http_server:stop_listener(),
    timer:sleep(500),

    %% Listener needs to be running at test end.
    http_server:start_listener(),

    ct:comment("Connection should still be alive"),
    true = erlang:is_process_alive(Conn),

    Port = application:get_env(http_server, http_port, 8888),
    shotgun:reopen(Conn, "localhost", Port),

    {ok, _Ref2} = shotgun:get(Conn, <<"/chunked-sse/3">>, #{}, Opts),
    ok = shotgun_test_utils:wait_receive(<<"1">>, 500),

    {comment, ""}.

-spec read_timeout_stops_silent_stream(shotgun_test_utils:config()) -> {comment, string()}.
read_timeout_stops_silent_stream(Config) ->
    Conn = ?config(conn, Config),
    MRef = monitor(process, Conn),

    ct:comment("A stream that sends nothing is closed after read_timeout"),
    Opts = #{async => true, async_mode => sse, read_timeout => 300},
    Started = erlang:monotonic_time(millisecond),
    {ok, Ref} = shotgun:get(Conn, <<"/chunked-sse-silent">>, #{}, Opts),
    true = is_reference(Ref),
    Reason =
        receive
            {'DOWN', MRef, process, Conn, R} -> R
        after 2000 ->
            error(read_timeout_did_not_fire)
        end,
    {shutdown, read_timeout} = Reason,
    Elapsed = erlang:monotonic_time(millisecond) - Started,
    true = Elapsed >= 300,

    {comment, ""}.

-spec read_timeout_reset_by_chunks(shotgun_test_utils:config()) -> {comment, string()}.
read_timeout_reset_by_chunks(Config) ->
    Conn = ?config(conn, Config),
    MRef = monitor(process, Conn),

    ct:comment("Chunks that arrive within read_timeout keep the stream open"),
    %% Events arrive every 100 ms. Ten events take about one second, far
    %% longer than the 300 ms read_timeout, but no gap exceeds it.
    Opts = #{async => true, async_mode => sse, read_timeout => 300},
    {ok, Ref} = shotgun:get(Conn, <<"/chunked-sse/10">>, #{}, Opts),
    Events = collect_events_until_fin(Conn, Ref, [], 3000),
    11 = length(Events),
    {fin, Ref, <<>>} = lists:last(Events),

    ct:comment("The timer is cancelled at the end of the stream"),
    %% More than read_timeout of silence after the stream has ended.
    timer:sleep(500),
    receive
        {'DOWN', MRef, process, Conn, R} -> error({unexpected_exit, R})
    after 0 ->
        ok
    end,
    {ok, #{status_code := 200}} = shotgun:get(Conn, <<"/">>),

    {comment, ""}.

-spec read_timeout_default_keeps_silent_stream(shotgun_test_utils:config()) -> {comment, string()}.
read_timeout_default_keeps_silent_stream(Config) ->
    Conn = ?config(conn, Config),
    MRef = monitor(process, Conn),

    ct:comment("Without read_timeout a silent stream stays open"),
    Opts = #{async => true, async_mode => sse},
    {ok, _Ref} = shotgun:get(Conn, <<"/chunked-sse-silent">>, #{}, Opts),
    receive
        {'DOWN', MRef, process, Conn, R} -> error({unexpected_exit, R})
    after 700 ->
        ok
    end,

    {comment, ""}.

-spec read_timeout_stops_stream_after_data(shotgun_test_utils:config()) -> {comment, string()}.
read_timeout_stops_stream_after_data(Config) ->
    Conn = ?config(conn, Config),
    MRef = monitor(process, Conn),
    Self = self(),

    ct:comment("A stream that delivered data and then goes silent is closed"),
    %% Binary mode with a callback, the way a streaming consumer uses it.
    HandleEvent =
        fun(_IsFin, _Ref, _Bin) ->
           Self ! {chunk, erlang:monotonic_time(millisecond)}
        end,
    Opts =
        #{async => true,
          async_mode => binary,
          handle_event => HandleEvent,
          read_timeout => 300},
    {ok, _Ref} = shotgun:get(Conn, <<"/chunked-sse-then-silent/3">>, #{}, Opts),
    {Reason, LastChunkAt, Chunks} = await_down_collecting_chunks(MRef, Conn, undefined, 0),
    {shutdown, read_timeout} = Reason,
    true = Chunks >= 1,
    Elapsed = erlang:monotonic_time(millisecond) - LastChunkAt,
    true = Elapsed >= 300,

    {comment, ""}.

-spec read_timeout_cancelled_when_connection_drops(shotgun_test_utils:config()) ->
                                                      {comment, string()}.
read_timeout_cancelled_when_connection_drops(Config) ->
    Conn = ?config(conn, Config),
    MRef = monitor(process, Conn),

    ct:comment("A dropped connection cancels the read timer"),
    Opts =
        #{async => true,
          async_mode => sse,
          allow_reconnect => true,
          read_timeout => 500},
    {ok, _Ref} = shotgun:get(Conn, <<"/chunked-sse-silent">>, #{}, Opts),
    %% Kill the server side of the connection. gun reports a stream error
    %% and then reports the connection as down.
    _ = [exit(P, kill) || P <- ranch:procs(http_server, connections)],
    %% Longer than read_timeout. A stale timer would crash the process.
    timer:sleep(1000),
    receive
        {'DOWN', MRef, process, Conn, R} -> error({unexpected_exit, R})
    after 0 ->
        ok
    end,
    {down, _} = sys:get_state(Conn),

    ct:comment("The connection can be reopened"),
    Port = application:get_env(http_server, http_port, 8888),
    _ = shotgun:reopen(Conn, "localhost", Port),
    {ok, #{status_code := 200}} = shotgun:get(Conn, <<"/">>),

    {comment, ""}.

-spec read_timeout_rejects_invalid_values(shotgun_test_utils:config()) -> {comment, string()}.
read_timeout_rejects_invalid_values(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("Invalid read_timeout values are rejected before the request is sent"),
    lists:foreach(
        fun(Value) ->
           Opts = #{async => true, async_mode => sse, read_timeout => Value},
           {error, {invalid_read_timeout, Value}} =
               shotgun:get(Conn, <<"/chunked-sse-silent">>, #{}, Opts)
        end,
        [0, -1, 1.5, foo, "300", <<"300">>]),
    true = erlang:is_process_alive(Conn),
    {ok, #{status_code := 200}} = shotgun:get(Conn, <<"/">>),

    {comment, ""}.

%%------------------------------------------------------------------------------
%% Helpers
%%------------------------------------------------------------------------------

%% Polls the event queue until the fin marker for Ref is present.
%% Budget is the remaining time in milliseconds.
-spec collect_events_until_fin(pid(), reference(), [tuple()], integer()) -> [tuple()].
collect_events_until_fin(Conn, Ref, Acc, Budget) ->
    Events = Acc ++ shotgun:events(Conn),
    case lists:member({fin, Ref, <<>>}, Events) of
        true ->
            Events;
        false when Budget =< 0 ->
            error({no_fin_received, Events});
        false ->
            timer:sleep(50),
            collect_events_until_fin(Conn, Ref, Events, Budget - 50)
    end.

%% Collects chunk notifications until the connection exits. Returns the
%% exit reason, the time of the last chunk, and the number of chunks.
-spec await_down_collecting_chunks(reference(), pid(), integer() | undefined, non_neg_integer()) ->
                                      {term(), integer() | undefined, non_neg_integer()}.
await_down_collecting_chunks(MRef, Conn, LastAt, Count) ->
    receive
        {chunk, At} ->
            await_down_collecting_chunks(MRef, Conn, At, Count + 1);
        {'DOWN', MRef, process, Conn, Reason} ->
            {Reason, LastAt, Count}
    after 3000 ->
        error(read_timeout_did_not_fire)
    end.
