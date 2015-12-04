-module(http_base_handler).

-export([ init/3
        , rest_init/2
        , content_types_accepted/2
        , content_types_provided/2
        , forbidden/2
        , resource_exists/2
        ]).

%% cowboy
init(_Transport, _Req, _Opts) ->
  {upgrade, protocol, cowboy_rest}.

rest_init(Req, _Opts) ->
  {ok, Req, #{}}.

content_types_accepted(Req, State) ->
  {[{<<"text/plain">>, handle_post}], Req, State}.

content_types_provided(Req, State) ->
  {Method, Req1} = cowboy_req:method(Req),
  Handler = case Method of
              <<"HEAD">> -> handle_head;
              _ -> handle_get
            end,
  {[{<<"text/plain">>, Handler}], Req1, State}.

forbidden(Req, State) ->
  {false, Req, State}.

resource_exists(Req, State) ->
  {true, Req, State}.
