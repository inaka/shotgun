-module(http_simple_handler).

-include_lib("mixer/include/mixer.hrl").

-mixin([{http_base_handler,
         [init/2, content_types_accepted/2, content_types_provided/2, resource_exists/2]}]).

-export([allowed_methods/2, handle_head/2, handle_get/2, handle_post/2,
         delete_resource/2]).

%% Specifications for callbacks forwarded by mixer.
-spec init(cowboy_req:req(), State) -> {cowboy_rest, cowboy_req:req(), State}
    when State :: term().
-spec content_types_accepted(cowboy_req:req(), State) ->
                                {[{binary(), atom()}], cowboy_req:req(), State}
    when State :: term().
-spec content_types_provided(cowboy_req:req(), State) ->
                                {[{{binary(), binary(), []}, atom()}], cowboy_req:req(), State}
    when State :: term().
-spec resource_exists(cowboy_req:req(), State) -> {true, cowboy_req:req(), State}
    when State :: term().
%% cowboy
-spec allowed_methods(cowboy_req:req(), State) -> {[binary()], cowboy_req:req(), State}
    when State :: term().
allowed_methods(Req, State) ->
    Methods =
        [<<"GET">>, <<"POST">>, <<"HEAD">>, <<"OPTIONS">>, <<"DELETE">>, <<"PATCH">>, <<"PUT">>],
    {Methods, Req, State}.

%% internal

-spec handle_head(cowboy_req:req(), State) -> {binary(), cowboy_req:req(), State}
    when State :: term().
handle_head(Req, State) ->
    {<<>>, Req, State}.

-spec handle_get(cowboy_req:req(), State) -> {iodata(), cowboy_req:req(), State}
    when State :: term().
handle_get(Req, State) ->
    %% Force cowboy to send more than one TCP packet by making
    %% the body big enough
    Body = lists:duplicate(1000, <<"I'm simple!">>),
    {Body, Req, State}.

-spec handle_post(cowboy_req:req(), State) -> {true, cowboy_req:req(), State}
    when State :: term().
handle_post(Req, State) ->
    {ok, Data, Req1} = cowboy_req:read_body(Req),
    Method = cowboy_req:method(Req1),
    Body = [Method, <<": ">>, Data],
    Req2 = cowboy_req:set_resp_body(Body, Req1),
    {true, Req2, State}.

-spec delete_resource(cowboy_req:req(), State) -> {true, cowboy_req:req(), State}
    when State :: term().
delete_resource(Req, State) ->
    {true, Req, State}.
