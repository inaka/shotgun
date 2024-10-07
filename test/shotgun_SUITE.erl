-module(shotgun_SUITE).

-export([all/0, init_per_suite/1, end_per_suite/1, init_per_testcase/2,
         end_per_testcase/2]).
-export([open/1, basic_auth/1, get/1, post/1, delete/1, head/1, options/1, patch/1, put/1,
         missing_slash_uri/1, complete_coverage/1, gun_down/1]).

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

-spec open(shotgun_test_utils:config()) -> {comment, string()}.
open(_Config) ->
    Port = application:get_env(http_server, http_port, 8888),
    {error, gun_open_failed} = shotgun:open("whatever", 8888),

    {error, gun_open_timeout} = shotgun:open("google.com", 8888, #{timeout => 1}),

    {ok, Conn} = shotgun:open("localhost", Port),
    ok = shotgun:close(Conn),

    {comment, ""}.

-spec basic_auth(shotgun_test_utils:config()) -> {comment, string()}.
basic_auth(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("GET should return 401"),
    {ok, Response1} = shotgun:get(Conn, "/basic-auth"),
    #{status_code := 401} = Response1,

    ct:comment("GET should return 200"),
    Headers = #{basic_auth => {"user", "pass"}},
    {ok, Response2} = shotgun:get(Conn, "/basic-auth", Headers),
    #{status_code := 200} = Response2,

    %% try the same request using proplists
    {ok, Response3} = shotgun:get(Conn, "/basic-auth", [{basic_auth, {"user", "pass"}}]),
    #{status_code := 200} = Response3,

    {comment, ""}.

-spec get(shotgun_test_utils:config()) -> {comment, string()}.
get(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("GET should return 200"),
    {ok, Response} = shotgun:get(Conn, "/"),
    #{status_code := 200} = Response,

    {ok, Response} = shotgun:get(Conn, "/", #{}),
    #{status_code := 200} = Response,

    {comment, ""}.

-spec post(shotgun_test_utils:config()) -> {comment, string()}.
post(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("POST should return 200"),
    Headers = #{<<"content-type">> => <<"text/plain">>},
    {ok, Response} = shotgun:post(Conn, "/", Headers, <<"Hello">>, #{}),
    #{status_code := 200, body := <<"POST: Hello">>} = Response,

    {comment, ""}.

-spec delete(shotgun_test_utils:config()) -> {comment, string()}.
delete(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("DELETE should return 204"),
    Headers = #{<<"content-type">> => <<"text/plain">>},
    {ok, Response} = shotgun:delete(Conn, "/", Headers, #{}),
    #{status_code := 204} = Response,

    {comment, ""}.

-spec head(shotgun_test_utils:config()) -> {comment, string()}.
head(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("HEAD should return 200"),
    Headers = #{<<"content-type">> => <<"text/plain">>},
    {ok, Response} = shotgun:head(Conn, "/", Headers, #{}),
    #{status_code := 200} = Response,

    {comment, ""}.

-spec options(shotgun_test_utils:config()) -> {comment, string()}.
options(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("OPTIONS should return 200"),
    Headers = #{<<"content-type">> => <<"text/plain">>},
    {ok, Response} = shotgun:options(Conn, "/", Headers, #{}),
    #{status_code := 200} = Response,

    {comment, ""}.

-spec patch(shotgun_test_utils:config()) -> {comment, string()}.
patch(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("PATCH should return 200"),
    Headers = #{<<"content-type">> => <<"text/plain">>},

    {ok, Response} = shotgun:patch(Conn, "/", Headers, <<"Hello">>, #{}),
    #{status_code := 200, body := <<"PATCH: Hello">>} = Response,

    {comment, ""}.

-spec put(shotgun_test_utils:config()) -> {comment, string()}.
put(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("PUT should return 200"),
    Headers = #{<<"content-type">> => <<"text/plain">>},

    {ok, Response} = shotgun:put(Conn, "/", Headers, <<"Hello">>, #{}),
    #{status_code := 200, body := <<"PUT: Hello">>} = Response,

    {comment, ""}.

-spec missing_slash_uri(shotgun_test_utils:config()) -> {comment, string()}.
missing_slash_uri(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("GET should return error"),
    {error, missing_slash_uri} = shotgun:get(Conn, "hello"),

    ct:comment("POST should return error"),
    {error, missing_slash_uri} = shotgun:post(Conn, "hello", #{}, <<>>, #{}),

    {comment, ""}.

-spec complete_coverage(shotgun_test_utils:config()) -> {comment, string()}.
complete_coverage(Config) ->
    Conn = ?config(conn, Config),

    ct:comment("Sending unexpected events should return an error"),
    {error, {unexpected, whatever}} = gen_statem:call(Conn, whatever),
    {error, {unexpected, _}} = shotgun:data(Conn, <<"data">>),

    ct:comment("gen_server's code_change"),
    {ok, at_rest, #{}} = shotgun:code_change(old_vsn, at_rest, #{}, extra),

    {comment, ""}.

-spec gun_down(shotgun_test_utils:config()) -> {comment, string()}.
gun_down(Config) ->
    Conn = ?config(conn, Config),

    ok = http_server:stop_listener(),

    % wait until gun_down detected
    timer:sleep(1000),

    ct:comment("Should get an error."),
    {error, gun_down} = shotgun:get(Conn, "/"),

    ok = http_server:start_listener(),

    ct:comment("Reconnecting ..."),
    Port = application:get_env(http_server, http_port, 8888),
    {ok, _Pid} = shotgun:reopen(Conn, "localhost", Port),

    {ok, Response} = shotgun:get(Conn, "/"),
    #{status_code := 200} = Response,

    {comment, ""}.
