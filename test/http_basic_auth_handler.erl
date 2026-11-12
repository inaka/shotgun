-module(http_basic_auth_handler).

-include_lib("mixer/include/mixer.hrl").

-mixin([{http_base_handler,
         [init/2, content_types_accepted/2, content_types_provided/2, resource_exists/2]}]).

-export([allowed_methods/2, is_authorized/2, handle_get/2]).

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
    {[<<"GET">>], Req, State}.

-spec is_authorized(cowboy_req:req(), State) ->
                       {true | {false, binary()}, cowboy_req:req(), State}
    when State :: term().
is_authorized(Req, State) ->
    case cowboy_req:parse_header(<<"authorization">>, Req) of
        {basic, <<"user">>, <<"pass">>} ->
            {true, Req, State};
        _WhenOthers ->
            {{false, <<>>}, Req, State}
    end.

%% internal
-spec handle_get(cowboy_req:req(), State) -> {iodata(), cowboy_req:req(), State}
    when State :: term().
handle_get(Req, State) ->
    Body = [<<"Secret information">>],
    {Body, Req, State}.
