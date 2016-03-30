-module(http_base_handler).

-export([ init/2
        , content_types_accepted/2
        , content_types_provided/2
        , forbidden/2
        , resource_exists/2
        ]).

%% cowboy
init(Req, Opts) ->
  {cowboy_rest, Req, Opts}.

content_types_accepted(Req, State) ->
  {[{<<"text/plain">>, handle_post}], Req, State}.

content_types_provided(Req, State) ->
  Method = cowboy_req:method(Req),
  Handler = case Method of
              <<"HEAD">> -> handle_head;
              _ -> handle_get
            end,
  {[{<<"text/plain">>, Handler}], Req, State}.

forbidden(Req, State) ->
  {false, Req, State}.

resource_exists(Req, State) ->
  {true, Req, State}.
