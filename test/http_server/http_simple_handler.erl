-module(http_simple_handler).

-include_lib("mixer/include/mixer.hrl").
-mixin([
        {http_base_handler,
         [
          init/2,
          content_types_accepted/2,
          content_types_provided/2,
          resource_exists/2
         ]}
       ]).

-export([ allowed_methods/2
        , handle_head/2
        , handle_get/2
        , handle_post/2
        , delete_resource/2
        ]).

%% cowboy
allowed_methods(Req, State) ->
  Methods =[ <<"GET">>
           , <<"POST">>
           , <<"HEAD">>
           , <<"OPTIONS">>
           , <<"DELETE">>
           , <<"PATCH">>
           , <<"PUT">>
           ],
  {Methods, Req, State}.

%% internal

handle_head(Req, State) ->
  {<<>>, Req, State}.

handle_get(Req, State) ->
  %% Force cowboy to send more than one TCP packet by making
  %% the body big enough
  Body = lists:duplicate(1000, <<"I'm simple!">>),
  {Body, Req, State}.

handle_post(Req, State) ->
  {ok, Data, Req1} = cowboy_req:body(Req),
  Method = cowboy_req:method(Req1),
  Body = [Method, <<": ">>, Data],
  Req2 = cowboy_req:set_resp_body(Body, Req1),
  {true, Req2, State}.

delete_resource(Req, State) ->
  {true, Req, State}.
