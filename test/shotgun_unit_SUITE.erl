-module(shotgun_unit_SUITE).

-export([all/0]).
-export([parse_event/1, parse_event_optional_spaces/1, parse_event_extra_fields/1,
         parse_event_mixed_order/1, parse_event_minimal/1, parse_event_empty/1,
         parse_event_multiline_data/1]).

-include_lib("common_test/include/ct.hrl").

%%------------------------------------------------------------------------------
%% Common Test
%%------------------------------------------------------------------------------

-spec all() -> [atom()].
all() ->
    shotgun_test_utils:all(?MODULE).

%%------------------------------------------------------------------------------
%% Test Cases
%%------------------------------------------------------------------------------

-spec parse_event(shotgun_test_utils:config()) -> {comment, string()}.
parse_event(_Config) ->
    EventBin = <<"data:foo\nid:bar\nevent:baz">>,
    Expected =
        #{id => <<"bar">>,
          event => <<"baz">>,
          data => <<"foo\n">>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.

-spec parse_event_optional_spaces(shotgun_test_utils:config()) -> {comment, string()}.
parse_event_optional_spaces(_Config) ->
    EventBin = <<"data: foo\nid: bar\nevent: baz">>,
    Expected =
        #{id => <<"bar">>,
          event => <<"baz">>,
          data => <<"foo\n">>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.

-spec parse_event_extra_fields(shotgun_test_utils:config()) -> {comment, string()}.
parse_event_extra_fields(_Config) ->
    EventBin = <<"data:foo\nid:bar\nevent:baz\nextra:should-be-dropped">>,
    Expected =
        #{id => <<"bar">>,
          event => <<"baz">>,
          data => <<"foo\n">>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.

-spec parse_event_mixed_order(shotgun_test_utils:config()) -> {comment, string()}.
parse_event_mixed_order(_Config) ->
    EventBin = <<"id:bar\nextra:should-be-dropped\ndata:foo\nevent:baz">>,
    Expected =
        #{id => <<"bar">>,
          event => <<"baz">>,
          data => <<"foo\n">>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.

-spec parse_event_minimal(shotgun_test_utils:config()) -> {comment, string()}.
parse_event_minimal(_Config) ->
    EventBin = <<"id:bar">>,
    Expected = #{id => <<"bar">>, data => <<>>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.

-spec parse_event_empty(shotgun_test_utils:config()) -> {comment, string()}.
parse_event_empty(_Config) ->
    EventBin = <<"">>,
    Expected = #{data => <<>>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.

-spec parse_event_multiline_data(shotgun_test_utils:config()) -> {comment, string()}.
parse_event_multiline_data(_Config) ->
    EventBin = <<"data:foo1\ndata:foo2\ndata:foo3\nid:bar\nevent:baz">>,
    Expected =
        #{id => <<"bar">>,
          event => <<"baz">>,
          data => <<"foo1\nfoo2\nfoo3\n">>},
    Expected = shotgun:parse_event(EventBin),
    {comment, ""}.
