-module(http_binary_handler).

-export([ init/2
        , info/3
        , terminate/3
        ]).

-spec init(cowboy_req:req(), any()) ->
  {loop | shutdown, any(), integer()}.
init(Req, _Opts) ->
  case cowboy_req:method(Req) of
    {<<"GET">>, Req1} ->
      Headers = [{<<"content-type">>, <<"text/event-stream">>},
                 {<<"cache-control">>, <<"no-cache">>}],
      {ok, Req2} = cowboy_req:chunked_reply(200, Headers, Req1),
      shotgun_test_utils:auto_send(count),
      {loop, Req2, 1};
    {_, _} ->
      Headers = [{<<"content-type">>, <<"text/html">>}],
      StatusCode = 405, % Method not Allowed
      {ok, Req1} = cowboy_req:reply(StatusCode, Headers, Req),
      {shutdown, Req1, 0}
  end.

-spec info(term(), cowboy_req:req(), integer()) ->
    {loop, cowboy_req:req(), integer()}.
info(count, Req, Count) ->
  case Count > 2 of
    true  ->
          {ok, Req, 0};
    false ->
          ok = cowboy_req:chunk(integer_to_binary(Count), Req),
          shotgun_test_utils:auto_send(count),
          {loop, Req, Count + 1}
  end.


-spec terminate(term(), cowboy_req:req(), integer()) -> ok.
terminate(_Reason, _Req, _State) ->
    ok.
