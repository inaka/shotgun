-module(shotgun_state_SUITE).

-export([all/0, protocol_update/1, legacy_down/1, transport_monitor_failure/1,
         unexpected_response_event/1, request_failure/1, partial_body_failure/1,
         invalid_chunked_uri/1]).

-include_lib("common_test/include/ct.hrl").

-spec all() -> [atom()].
all() ->
    [protocol_update,
     legacy_down,
     transport_monitor_failure,
     unexpected_response_event,
     request_failure,
     partial_body_failure,
     invalid_chunked_uri].

%% These exported state callbacks also need to tolerate transport events that
%% are difficult to deliver deterministically through a real network connection.
-spec protocol_update(shotgun_test_utils:config()) -> term().
protocol_update(_) ->
    State = #{pid => self(), protocol => http},
    {next_state, at_rest, Updated} = shotgun:at_rest(info, {gun_up, self(), http2}, State),
    http2 = maps:get(protocol, Updated).

-spec legacy_down(shotgun_test_utils:config()) -> term().
legacy_down(_) ->
    Owner = self(),
    Transport =
        spawn_link(fun() ->
                      receive
                          {'$gen_cast', shutdown} ->
                              Owner ! transport_shutdown
                      end
                   end),
    State =
        #{pid => Transport,
          protocol => http2,
          stream => make_ref(),
          responses => queue:from_list([event]),
          pending_requests => queue:from_list([work])},
    {next_state, down, Clean} = shotgun:at_rest(cast, {gun_down, legacy, legacy}, State),
    undefined = maps:get(pid, Clean),
    undefined = maps:get(stream, Clean),
    [event] =
        queue:to_list(
            maps:get(responses, Clean)),
    [work] =
        queue:to_list(
            maps:get(pending_requests, Clean)),
    receive
        transport_shutdown ->
            ok
    after 1000 ->
        ct:fail(transport_not_shutdown)
    end.

-spec transport_monitor_failure(shotgun_test_utils:config()) -> term().
transport_monitor_failure(_) ->
    Down = {'DOWN', make_ref(), process, self(), transport_failed},
    {'EXIT', transport_failed} = (catch shotgun:wait_response(cast, Down, #{})),
    {'EXIT', {incomplete, _}} = (catch shotgun:receive_data(cast, Down, #{})),
    {'EXIT', {incomplete, _}} = (catch shotgun:receive_chunk(cast, Down, #{})),
    ok.

-spec unexpected_response_event(shotgun_test_utils:config()) -> term().
unexpected_response_event(_) ->
    State = #{stream => make_ref()},
    {stop, {unexpected, invalid_event}, State} =
        shotgun:wait_response(cast, invalid_event, State).

-spec request_failure(shotgun_test_utils:config()) -> term().
request_failure(_) ->
    From = {self(), make_ref()},
    State = #{from => From},
    {next_state, at_rest, State, [{reply, From, {error, stream_failed}}]} =
        shotgun:wait_response(cast, {gun_error, self(), make_ref(), stream_failed}, State).

-spec partial_body_failure(shotgun_test_utils:config()) -> term().
partial_body_failure(_) ->
    Ref = make_ref(),
    State = #{stream => Ref},
    {next_state, at_rest, State} =
        shotgun:receive_data(cast, {gun_error, self(), Ref, stream_failed}, State).

-spec invalid_chunked_uri(shotgun_test_utils:config()) -> term().
invalid_chunked_uri(_) ->
    {error, missing_slash_uri} = shotgun:post(self(), "invalid", #{}, #{}),
    {error, missing_slash_uri} = shotgun:put(self(), "invalid", #{}, #{}),
    {error, missing_slash_uri} = shotgun:patch(self(), "invalid", #{}, #{}).
