-module(shotgun_stream_SUITE).

-export([all/0, groups/0, init_per_suite/1, end_per_suite/1, init_per_group/2,
         end_per_group/2, init_per_testcase/2, end_per_testcase/2]).
-export([binary_callback/1, binary_queue/1, sse_callback/1, sse_queue/1, synchronous/1,
         no_content/1, content_length/1, trailers/1, synchronous_trailers/1, read_timeout/1,
         timeout_reset/1, timeout_cancelled/1, default_timeout/1, queued_work/1,
         queued_work_trailers/1, sse_trailers/1, trailers_timeout_cancelled/1,
         heartbeat_resets_timeout/1, timeout_before_headers/1, timeout_after_data/1,
         error_status/1, stream_reset/1, content_length_sse/1, content_length_queue/1,
         content_length_sse_queue/1, upload_post/1, upload_put/1, upload_patch/1,
         close_before_headers/1, close_during_body/1, calls_before_headers/1, calls_during_body/1,
         sse_buffer_remainder/1, reopen_failure/1, disconnect_sse_callback/1,
         disconnect_sse_queue/1, disconnect_binary_callback/1, disconnect_binary_queue/1,
         disconnect_before_headers/1, disconnect_after_completion/1, disconnect_default_reopen/1,
         disconnect_explicit_reopen/1]).

-include_lib("common_test/include/ct.hrl").

-spec all() -> [{group, atom()}].
all() ->
    [{group, http}, {group, http2}, {group, https_http2}].

-spec groups() -> [{atom(), list(), [atom()]}].
groups() ->
    Tests =
        [binary_callback, binary_queue, sse_callback, sse_queue, synchronous, no_content,
         content_length, content_length_sse, content_length_queue, content_length_sse_queue,
         trailers, synchronous_trailers, read_timeout, timeout_reset, timeout_cancelled,
         default_timeout, queued_work, queued_work_trailers, sse_trailers,
         trailers_timeout_cancelled, heartbeat_resets_timeout, timeout_before_headers,
         timeout_after_data, error_status, upload_post, upload_patch, upload_put,
         close_before_headers, close_during_body, calls_before_headers, calls_during_body,
         sse_buffer_remainder, reopen_failure, disconnect_sse_callback, disconnect_sse_queue,
         disconnect_binary_callback, disconnect_binary_queue, disconnect_before_headers,
         disconnect_after_completion, disconnect_default_reopen, disconnect_explicit_reopen],
    [{http, [], Tests},
     {http2, [], Tests ++ [stream_reset]},
     {https_http2,
      [],
      [binary_callback,
       sse_callback,
       synchronous,
       content_length,
       trailers,
       disconnect_sse_callback]}].

-spec init_per_suite(shotgun_test_utils:config()) -> term().
init_per_suite(Config) ->
    {ok, _} = shotgun:start(),
    {ok, _} = application:ensure_all_started(cowboy),
    Config.

-spec end_per_suite(shotgun_test_utils:config()) -> term().
end_per_suite(Config) ->
    ok = shotgun:stop(),
    Config.

-spec init_per_group(atom(), shotgun_test_utils:config()) -> shotgun_test_utils:config().
init_per_group(https_http2, Config) ->
    {ok, _} = application:ensure_all_started(ssl),
    %% Generate ephemeral test credentials; no private key files are needed.
    Cert =
        public_key:pkix_test_data(#{root => [{digest, sha256}, {key, {namedCurve, secp256r1}}],
                                    peer => [{digest, sha256}, {key, {namedCurve, secp256r1}}]}),
    [{protocol, http2}, {tls, Cert} | Config];
init_per_group(Protocol, Config) ->
    [{protocol, Protocol} | Config].

-spec end_per_group(atom(), shotgun_test_utils:config()) -> shotgun_test_utils:config().
end_per_group(_, Config) ->
    Config.

-spec init_per_testcase(atom(), shotgun_test_utils:config()) ->
                           shotgun_test_utils:config().
init_per_testcase(_, Config) ->
    Dispatch = cowboy_router:compile([{'_', [{"/", http_stream_handler, self()}]}]),
    Protocol = ?config(protocol, Config),
    ProtocolOpts = #{env => #{dispatch => Dispatch}},
    {Type, Opts} =
        case proplists:get_value(tls, Config) of
            undefined ->
                {ok, _} = cowboy:start_clear(shotgun_stream_test, [{port, 0}], ProtocolOpts),
                {http, #{gun_opts => #{protocols => [Protocol]}}};
            Cert ->
                {ok, _} = cowboy:start_tls(shotgun_stream_test, [{port, 0} | Cert], ProtocolOpts),
                %% Let ALPN negotiate HTTP/2, rather than forcing an HTTP/2-only client.
                {https, #{tls_opts => [{verify, verify_none}]}}
        end,
    Port = ranch:get_port(shotgun_stream_test),
    {ok, Conn} = shotgun:open("localhost", Port, Type, Opts),
    unlink(Conn),
    [{conn, Conn} | Config].

-spec end_per_testcase(atom(), shotgun_test_utils:config()) ->
                          shotgun_test_utils:config().
end_per_testcase(_, Config) ->
    try
        shotgun:close(?config(conn, Config))
    catch
        _:_ ->
            ok
    end,
    ok = cowboy:stop_listener(shotgun_stream_test),
    Config.

-spec binary_callback(shotgun_test_utils:config()) -> term().
binary_callback(Config) ->
    {Handler, Ref} = start_stream(Config, callback(binary), #{}),
    Handler ! {data, nofin, <<"first">>},
    receive
        {event, nofin, Ref, <<"first">>} ->
            ok
    after 2000 ->
        ct:fail(no_first_data)
    end,
    Handler ! {data, fin, <<"last">>},
    {<<"last">>, _} = collect(Ref, <<>>),
    reusable(Config).

-spec binary_queue(shotgun_test_utils:config()) -> term().
binary_queue(Config) ->
    {Handler, Ref} = start_stream(Config, #{async => true}, #{}),
    Handler ! {data, nofin, <<"first">>},
    Handler ! {data, fin, <<"last">>},
    Events = queued(?config(conn, Config), Ref, []),
    <<"firstlast">> = iolist_to_binary([Data || {_, Ref0, Data} <- Events, Ref0 =:= Ref]),
    [] = shotgun:events(?config(conn, Config)),
    reusable(Config).

-spec sse_callback(shotgun_test_utils:config()) -> term().
sse_callback(Config) ->
    {Handler, Ref} = start_stream(Config, callback(sse), #{}),
    Handler ! {data, nofin, <<"data: fir">>},
    Handler ! {data, nofin, <<"st\n\ndata: second\n\n">>},
    receive
        {event, nofin, Ref, <<"data: first">>} ->
            ok
    after 2000 ->
        ct:fail(no_first_event)
    end,
    receive
        {event, nofin, Ref, <<"data: second">>} ->
            ok
    after 2000 ->
        ct:fail(no_second_event)
    end,
    Handler ! {data, fin, <<>>},
    receive
        {event, fin, Ref, <<>>} ->
            ok
    after 2000 ->
        ct:fail(no_fin)
    end,
    reusable(Config).

-spec sse_queue(shotgun_test_utils:config()) -> term().
sse_queue(Config) ->
    {Handler, Ref} = start_stream(Config, #{async => true, async_mode => sse}, #{}),
    Handler ! {data, nofin, <<"data: fir">>},
    Handler ! {data, fin, <<"st\n\ndata: second\n\n">>},
    Events = queued(?config(conn, Config), Ref, []),
    [<<"data: first">>, <<"data: second">>] = [D || {_, _, D} <- Events, D =/= <<>>],
    reusable(Config).

-spec synchronous(shotgun_test_utils:config()) -> term().
synchronous(Config) ->
    Conn = ?config(conn, Config),
    request(Conn, #{}),
    Handler = ready(Config),
    Handler ! {headers, 200, #{}},
    Handler ! {data, nofin, <<"first">>},
    receive
        {result, _} ->
            ct:fail(premature_reply)
    after 50 ->
        ok
    end,
    Handler ! {data, fin, <<"last">>},
    {ok, #{body := <<"firstlast">>}} = result(),
    reusable(Config).

-spec no_content(shotgun_test_utils:config()) -> term().
no_content(Config) ->
    request(?config(conn, Config), #{async => true}),
    Handler = ready(Config),
    Handler ! {reply, 204},
    {ok, #{status_code := 204}} = result(),
    [] = shotgun:events(?config(conn, Config)),
    reusable(Config).

-spec content_length(shotgun_test_utils:config()) -> term().
content_length(Config) ->
    content_length(Config, callback(binary), <<"firstlast">>).

-spec content_length_sse(shotgun_test_utils:config()) -> term().
content_length_sse(Config) ->
    content_length(Config, callback(sse), <<"data: event\n\n">>).

-spec content_length_queue(shotgun_test_utils:config()) -> term().
content_length_queue(Config) ->
    content_length(Config, #{async => true}, <<"firstlast">>).

-spec content_length_sse_queue(shotgun_test_utils:config()) -> term().
content_length_sse_queue(Config) ->
    content_length(Config, #{async => true, async_mode => sse}, <<"data: event\n\n">>).

content_length(Config, Opts, Body) ->
    %% Repeat on the same connection to check protocol survives request cleanup.
    lists:foreach(fun(_) -> content_length_response(Config, Opts, Body) end, [1, 2]),
    reusable(Config).

content_length_response(Config, Opts, Body) ->
    Headers = #{<<"content-length">> => integer_to_binary(byte_size(Body))},
    request(?config(conn, Config), Opts#{read_timeout => 150}),
    Handler = ready(Config),
    Handler ! {headers, 200, Headers},
    case ?config(protocol, Config) of
        http ->
            Handler ! {data, nofin, binary:part(Body, 0, 1)},
            %% Buffered HTTP/1 responses must ignore the streaming read timeout.
            receive
                {result, _} ->
                    ct:fail(premature_http1_response);
                {event, _, _, _} ->
                    ct:fail(unexpected_http1_callback)
            after 250 ->
                ok
            end,
            Handler ! {data, fin, binary:part(Body, 1, byte_size(Body) - 1)},
            {ok, #{status_code := 200, body := Body}} = result(),
            [] = shotgun:events(?config(conn, Config));
        http2 ->
            {ok, Ref} = result(),
            true = is_reference(Ref),
            Handler ! {data, fin, Body},
            Data =
                case maps:is_key(handle_event, Opts) of
                    true ->
                        element(1, collect(Ref, <<>>));
                    false ->
                        iolist_to_binary([D || {_, _, D} <- queued(?config(conn, Config), Ref, [])])
                end,
            Expected =
                case maps:get(async_mode, Opts, binary) of
                    binary ->
                        Body;
                    sse ->
                        <<"data: event">>
                end,
            Expected = Data
    end.

-spec trailers(shotgun_test_utils:config()) -> term().
trailers(Config) ->
    {Handler, Ref} =
        start_stream(Config, callback(binary), #{<<"trailer">> => <<"x-complete">>}),
    Handler ! {data, nofin, <<"body">>},
    Handler ! trailers,
    {<<"body">>, _} = collect(Ref, <<>>),
    reusable(Config).

-spec synchronous_trailers(shotgun_test_utils:config()) -> term().
synchronous_trailers(Config) ->
    request(?config(conn, Config), #{}),
    Handler = ready(Config),
    Handler ! {headers, 200, #{<<"trailer">> => <<"x-complete">>}},
    Handler ! {data, nofin, <<"body">>},
    Handler ! trailers,
    {ok, #{body := <<"body">>}} = result(),
    reusable(Config).

-spec read_timeout(shotgun_test_utils:config()) -> term().
read_timeout(Config) ->
    Conn = ?config(conn, Config),
    Monitor = monitor(process, Conn),
    start_stream(Config, #{async => true, read_timeout => 150}, #{}),
    receive
        {'DOWN', Monitor, process, Conn, {shutdown, read_timeout}} ->
            ok
    after 2000 ->
        ct:fail(no_read_timeout)
    end.

-spec timeout_reset(shotgun_test_utils:config()) -> term().
timeout_reset(Config) ->
    Opts = (callback(binary))#{read_timeout => 500},
    {Handler, Ref} = start_stream(Config, Opts, #{}),
    lists:foreach(fun(_) ->
                     timer:sleep(150),
                     Handler ! {data, nofin, <<"alive">>},
                     receive
                         {event, nofin, Ref, <<"alive">>} ->
                             ok
                     after 2000 ->
                         ct:fail(timeout_not_reset)
                     end
                  end,
                  lists:seq(1, 5)),
    Handler ! {data, fin, <<>>},
    collect(Ref, <<>>),
    reusable(Config).

-spec timeout_cancelled(shotgun_test_utils:config()) -> term().
timeout_cancelled(Config) ->
    {Handler, Ref} = start_stream(Config, (callback(binary))#{read_timeout => 150}, #{}),
    Handler ! {data, fin, <<>>},
    collect(Ref, <<>>),
    timer:sleep(250),
    reusable(Config).

-spec default_timeout(shotgun_test_utils:config()) -> term().
default_timeout(Config) ->
    {Handler, Ref} = start_stream(Config, callback(binary), #{}),
    timer:sleep(250),
    true = is_process_alive(?config(conn, Config)),
    Handler ! {data, fin, <<>>},
    collect(Ref, <<>>),
    reusable(Config).

%% A queued request must not prevent finishing the current stream.
-spec queued_work(shotgun_test_utils:config()) -> term().
queued_work(Config) ->
    queued_work(Config, {data, fin, <<"body">>}, #{}).

-spec queued_work_trailers(shotgun_test_utils:config()) -> term().
queued_work_trailers(Config) ->
    queued_work(Config, trailers, #{<<"trailer">> => <<"x-complete">>}).

queued_work(Config, Finish, Headers) ->
    {Handler, Ref} = start_stream(Config, callback(binary), Headers),
    request(?config(conn, Config), #{}),
    receive
        {stream_ready, _, _} ->
            ct:fail(request_overtook_stream)
    after 50 ->
        ok
    end,
    Handler ! Finish,
    collect(Ref, <<>>),
    Next = ready(Config),
    Next ! {reply, 204},
    {ok, #{status_code := 204}} = result(),
    ok.

-spec sse_trailers(shotgun_test_utils:config()) -> term().
sse_trailers(Config) ->
    {Handler, Ref} =
        start_stream(Config, callback(sse), #{<<"trailer">> => <<"x-complete">>}),
    Handler ! {data, nofin, <<"data: event\n\n">>},
    receive
        {event, nofin, Ref, <<"data: event">>} ->
            ok
    after 2000 ->
        ct:fail(no_sse_event)
    end,
    Handler ! trailers,
    receive
        {event, fin, Ref, <<>>} ->
            ok
    after 2000 ->
        ct:fail(no_sse_completion)
    end,
    reusable(Config).

-spec trailers_timeout_cancelled(shotgun_test_utils:config()) -> term().
trailers_timeout_cancelled(Config) ->
    {Handler, Ref} =
        start_stream(Config,
                     (callback(binary))#{read_timeout => 150},
                     #{<<"trailer">> => <<"x-complete">>}),
    Handler ! trailers,
    collect(Ref, <<>>),
    timer:sleep(250),
    reusable(Config).

-spec heartbeat_resets_timeout(shotgun_test_utils:config()) -> term().
heartbeat_resets_timeout(Config) ->
    {Handler, Ref} = start_stream(Config, (callback(sse))#{read_timeout => 500}, #{}),
    %% No complete SSE event is produced, but every body fragment is activity.
    lists:foreach(fun(_) ->
                     timer:sleep(150),
                     Handler ! {data, nofin, <<": heartbeat\n">>}
                  end,
                  lists:seq(1, 5)),
    Handler ! {data, fin, <<"\n">>},
    collect(Ref, <<>>),
    reusable(Config).

-spec timeout_before_headers(shotgun_test_utils:config()) -> term().
timeout_before_headers(Config) ->
    request(?config(conn, Config), (callback(binary))#{read_timeout => 150}),
    Handler = ready(Config),
    timer:sleep(250),
    Handler ! {headers, 200, #{}},
    {ok, Ref} = result(),
    Handler ! {data, fin, <<>>},
    collect(Ref, <<>>),
    reusable(Config).

-spec timeout_after_data(shotgun_test_utils:config()) -> term().
timeout_after_data(Config) ->
    Conn = ?config(conn, Config),
    Monitor = monitor(process, Conn),
    {Handler, Ref} = start_stream(Config, (callback(binary))#{read_timeout => 150}, #{}),
    Handler ! {data, nofin, <<"body">>},
    receive
        {event, nofin, Ref, <<"body">>} ->
            ok
    after 2000 ->
        ct:fail(no_body)
    end,
    receive
        {'DOWN', Monitor, process, Conn, {shutdown, read_timeout}} ->
            ok
    after 2000 ->
        ct:fail(no_read_timeout_after_data)
    end.

-spec error_status(shotgun_test_utils:config()) -> term().
error_status(Config) ->
    request(?config(conn, Config), callback(binary)),
    Handler = ready(Config),
    Handler ! {headers, 503, #{}},
    {ok, Ref} = result(),
    true = is_reference(Ref),
    Handler ! {data, fin, <<"unavailable">>},
    {<<"unavailable">>, fin} = collect(Ref, <<>>),
    reusable(Config).

-spec stream_reset(shotgun_test_utils:config()) -> term().
stream_reset(Config) ->
    {Handler, _Ref} = start_stream(Config, (callback(binary))#{read_timeout => 150}, #{}),
    Handler ! reset,
    %% RST_STREAM ends only this HTTP/2 stream. A queued request must proceed.
    reusable(Config),
    timer:sleep(250),
    reusable(Config).

-spec upload_post(shotgun_test_utils:config()) -> term().
upload_post(Config) ->
    upload(Config, post, <<"POST">>).

-spec upload_patch(shotgun_test_utils:config()) -> term().
upload_patch(Config) ->
    upload(Config, patch, <<"PATCH">>).

-spec upload_put(shotgun_test_utils:config()) -> term().
upload_put(Config) ->
    upload(Config, put, <<"PUT">>).

upload(Config, Verb, Method) ->
    Conn = ?config(conn, Config),
    {ok, Ref} =
        case Verb of
            post ->
                shotgun:post(Conn, "/", #{}, #{});
            patch ->
                shotgun:patch(Conn, "/", #{}, #{});
            put ->
                shotgun:put(Conn, "/", #{}, #{})
        end,
    true = is_reference(Ref),
    Handler = ready(Config),
    Handler ! read_body,
    ok = shotgun:data(Conn, <<"first">>),
    ok = shotgun:data(Conn, <<"last">>, fin),
    receive
        {request_body, Method, <<"firstlast">>} ->
            ok
    after 2000 ->
        ct:fail(upload_corrupted)
    end,
    await_state(Conn, at_rest),
    reusable(Config).

-spec close_before_headers(shotgun_test_utils:config()) -> term().
close_before_headers(Config) ->
    Conn = ?config(conn, Config),
    request(Conn, #{}),
    Handler = ready(Config),
    close_and_check(Conn),
    {error, _} = result(),
    Handler ! {reply, 204}.

-spec close_during_body(shotgun_test_utils:config()) -> term().
close_during_body(Config) ->
    Conn = ?config(conn, Config),
    request(Conn, #{}),
    Handler = ready(Config),
    Handler ! {headers, 200, #{}},
    Handler ! {data, nofin, <<"partial">>},
    await_state(Conn, receive_data),
    close_and_check(Conn),
    {error, _} = result(),
    Handler ! {data, fin, <<>>}.

close_and_check(Conn) ->
    Monitor = monitor(process, Conn),
    ok = shotgun:close(Conn),
    receive
        {'DOWN', Monitor, process, Conn, normal} ->
            ok
    after 2000 ->
        ct:fail(close_did_not_stop_connection)
    end.

-spec calls_before_headers(shotgun_test_utils:config()) -> term().
calls_before_headers(Config) ->
    Conn = ?config(conn, Config),
    request(Conn, #{}),
    Handler = ready(Config),
    {error, {unexpected, invalid_request}} = gen_statem:call(Conn, invalid_request),
    [] = shotgun:events(Conn),
    Handler ! {reply, 204},
    {ok, #{status_code := 204}} = result(),
    reusable(Config).

-spec calls_during_body(shotgun_test_utils:config()) -> term().
calls_during_body(Config) ->
    Conn = ?config(conn, Config),
    request(Conn, #{}),
    Handler = ready(Config),
    Handler ! {headers, 200, #{}},
    Handler ! {data, nofin, <<"first">>},
    await_state(Conn, receive_data),
    {error, {unexpected, invalid_request}} = gen_statem:call(Conn, invalid_request),
    [] = shotgun:events(Conn),
    Handler ! {data, fin, <<"last">>},
    {ok, #{body := <<"firstlast">>}} = result(),
    reusable(Config).

-spec sse_buffer_remainder(shotgun_test_utils:config()) -> term().
sse_buffer_remainder(Config) ->
    {Handler, Ref} = start_stream(Config, callback(sse), #{}),
    Handler ! {data, nofin, <<"data: first\n\ndata: sec">>},
    receive
        {event, nofin, Ref, <<"data: first">>} ->
            ok
    after 2000 ->
        ct:fail(no_complete_event)
    end,
    Handler ! {data, fin, <<"ond\n\n">>},
    {<<"data: second">>, fin} = collect(Ref, <<>>),
    reusable(Config).

-spec reopen_failure(shotgun_test_utils:config()) -> term().
reopen_failure(Config) ->
    Conn = ?config(conn, Config),
    %% Close the peer, then verify failed reopening leaves the client available
    %% for another reopen and updates its negotiated protocol on success.
    ok = cowboy:stop_listener(shotgun_stream_test),
    await_state(Conn, down),
    {error, gun_open_failed} =
        shotgun:reopen(Conn, "127.0.0.1", 0, http, #{gun_opts => #{retry => 0}}),
    {down, _} = sys:get_state(Conn),
    Dispatch = cowboy_router:compile([{'_', [{"/", http_stream_handler, self()}]}]),
    {ok, _} =
        cowboy:start_clear(shotgun_stream_test, [{port, 0}], #{env => #{dispatch => Dispatch}}),
    Port = ranch:get_port(shotgun_stream_test),
    {ok, Conn} = shotgun:reopen(Conn, "localhost", Port, http),
    %% HTTP on a cleartext connection defaults to HTTP/1.
    reusable([{protocol, http} | proplists:delete(protocol, Config)]).

await_state(Conn, Expected) ->
    await_state(Conn, Expected, erlang:monotonic_time(millisecond) + 2000).

await_state(Conn, Expected, Deadline) ->
    case sys:get_state(Conn) of
        {Expected, _} ->
            ok;
        Other ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true ->
                    timer:sleep(10),
                    await_state(Conn, Expected, Deadline);
                false ->
                    ct:fail({state_timeout, Expected, Other})
            end
    end.

-spec disconnect_sse_callback(shotgun_test_utils:config()) -> term().
disconnect_sse_callback(Config) ->
    disconnect_stream(Config, callback(sse)).

-spec disconnect_sse_queue(shotgun_test_utils:config()) -> term().
disconnect_sse_queue(Config) ->
    disconnect_stream(Config, #{async => true, async_mode => sse}).

-spec disconnect_binary_callback(shotgun_test_utils:config()) -> term().
disconnect_binary_callback(Config) ->
    disconnect_stream(Config, callback(binary)).

-spec disconnect_binary_queue(shotgun_test_utils:config()) -> term().
disconnect_binary_queue(Config) ->
    disconnect_stream(Config, #{async => true, async_mode => binary}).

disconnect_stream(Config, Opts) ->
    Conn = ?config(conn, Config),
    Monitor = monitor(process, Conn),
    %% A long read timeout must not postpone notification of a known failure.
    {Handler, Ref} =
        start_stream(Config, Opts#{allow_reconnect => false, read_timeout => 10000}, #{}),
    Handler ! {data, nofin, <<"data: alive\n\n">>},
    case maps:is_key(handle_event, Opts) of
        true ->
            receive
                {event, nofin, Ref, _} ->
                    ok
            after 2000 ->
                ct:fail(no_stream_activity)
            end;
        false ->
            await_buffered_event(Conn)
    end,
    drop_transport(),
    await_disconnect(Monitor, Conn),
    receive
        {event, fin, Ref, _} ->
            ct:fail(disconnect_reported_as_success)
    after 0 ->
        ok
    end.

await_buffered_event(Conn) ->
    await_buffered_event(Conn, erlang:monotonic_time(millisecond) + 2000).

await_buffered_event(Conn, Deadline) ->
    case shotgun:events(Conn) of
        [_ | _] ->
            ok;
        [] ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true ->
                    timer:sleep(10),
                    await_buffered_event(Conn, Deadline);
                false ->
                    ct:fail(no_buffered_stream_activity)
            end
    end.

-spec disconnect_before_headers(shotgun_test_utils:config()) -> term().
disconnect_before_headers(Config) ->
    Conn = ?config(conn, Config),
    Monitor = monitor(process, Conn),
    request(Conn,
            #{async => true,
              async_mode => sse,
              allow_reconnect => false}),
    _Handler = ready(Config),
    drop_transport(),
    await_disconnect(Monitor, Conn),
    {error, _} = result().

-spec disconnect_after_completion(shotgun_test_utils:config()) -> term().
disconnect_after_completion(Config) ->
    Conn = ?config(conn, Config),
    Monitor = monitor(process, Conn),
    {Handler, Ref} = start_stream(Config, (callback(sse))#{allow_reconnect => false}, #{}),
    Handler ! {data, fin, <<>>},
    collect(Ref, <<>>),
    await_state(Conn, at_rest),
    drop_transport(),
    await_disconnect(Monitor, Conn).

-spec disconnect_default_reopen(shotgun_test_utils:config()) -> term().
disconnect_default_reopen(Config) ->
    disconnect_reopen(Config, callback(sse)).

-spec disconnect_explicit_reopen(shotgun_test_utils:config()) -> term().
disconnect_explicit_reopen(Config) ->
    disconnect_reopen(Config, (callback(sse))#{allow_reconnect => true, read_timeout => 150}).

disconnect_reopen(Config, Opts) ->
    Conn = ?config(conn, Config),
    Monitor = monitor(process, Conn),
    start_stream(Config, Opts, #{}),
    drop_transport(),
    await_state(Conn, down),
    %% Outlive the optional read timeout: a disconnected reusable PID must stay alive.
    receive
        {'DOWN', Monitor, process, Conn, Reason} ->
            ct:fail({unexpected_exit, Reason})
    after 250 ->
        ok
    end,
    {error, gun_down} = shotgun:get(Conn, "/"),
    Port = ranch:get_port(shotgun_stream_test),
    Protocol = ?config(protocol, Config),
    {ok, Conn} =
        shotgun:reopen(Conn, "localhost", Port, http, #{gun_opts => #{protocols => [Protocol]}}),
    {Handler, Ref} = start_stream(Config, callback(sse), #{}),
    Handler ! {data, fin, <<"data: reopened\n\n">>},
    {<<"data: reopened">>, fin} = collect(Ref, <<>>),
    true = demonitor(Monitor, [flush]),
    reusable(Config).

%% Keep the listener running so Gun can reconnect successfully. Killing the
%% listener would let the old implementation exit only after exhausting retries.
drop_transport() ->
    [Transport] = ranch:procs(shotgun_stream_test, connections),
    exit(Transport, kill).

await_disconnect(Monitor, Conn) ->
    receive
        {'DOWN', Monitor, process, Conn, {shutdown, {gun_down, _Reason}}} ->
            ok;
        {'DOWN', Monitor, process, Conn, Reason} ->
            ct:fail({wrong_disconnect_reason, Reason})
    after 2000 ->
        ct:fail(no_disconnect_notification)
    end.

callback(Mode) ->
    Self = self(),
    #{async => true,
      async_mode => Mode,
      handle_event => fun(Fin, Ref, Data) -> Self ! {event, Fin, Ref, Data} end}.

request(Conn, Opts) ->
    Self = self(),
    spawn_link(fun() ->
                  Self ! {result, shotgun:get(Conn, "/", #{<<"te">> => <<"trailers">>}, Opts)}
               end).

-spec ready(shotgun_test_utils:config()) -> term().
ready(Config) ->
    Expected =
        case ?config(protocol, Config) of
            http ->
                'HTTP/1.1';
            http2 ->
                'HTTP/2'
        end,
    receive
        {stream_ready, Handler, Expected} ->
            Handler
    after 2000 ->
        ct:fail(wrong_protocol_or_no_request)
    end.

result() ->
    receive
        {result, Result} ->
            Result
    after 2000 ->
        ct:fail(no_response)
    end.

start_stream(Config, Opts, Headers) ->
    request(?config(conn, Config), Opts),
    Handler = ready(Config),
    Handler ! {headers, 200, Headers},
    {ok, Ref} = result(),
    true = is_reference(Ref),
    {Handler, Ref}.

collect(Ref, Acc) ->
    receive
        {event, nofin, Ref, Data} ->
            collect(Ref, <<Acc/binary, Data/binary>>);
        {event, fin, Ref, Data} ->
            {<<Acc/binary, Data/binary>>, fin}
    after 2000 ->
        ct:fail(missing_stream_completion)
    end.

queued(Conn, Ref, Acc) ->
    Deadline = erlang:monotonic_time(millisecond) + 2000,
    queued(Conn, Ref, Acc, Deadline).

queued(Conn, Ref, Acc, Deadline) ->
    Events = shotgun:events(Conn),
    New = Acc ++ Events,
    case lists:any(fun({Fin, R, _}) -> Fin =:= fin andalso R =:= Ref end, New) of
        true ->
            New;
        false ->
            case erlang:monotonic_time(millisecond) < Deadline of
                true ->
                    timer:sleep(10),
                    queued(Conn, Ref, New, Deadline);
                false ->
                    ct:fail(missing_queued_completion)
            end
    end.

-spec reusable(shotgun_test_utils:config()) -> term().
reusable(Config) ->
    request(?config(conn, Config), #{}),
    Handler = ready(Config),
    Handler ! {reply, 204},
    {ok, #{status_code := 204}} = result(),
    ok.
