-module(http_basic_auth_handler).

-include_lib("mixer/include/mixer.hrl").

-mixin([{http_base_handler,
         [init/2, content_types_accepted/2, content_types_provided/2, resource_exists/2]}]).

-export([allowed_methods/2, is_authorized/2, handle_get/2]).

%% cowboy
allowed_methods(Req, State) ->
    {[<<"GET">>], Req, State}.

is_authorized(Req, State) ->
    case cowboy_req:parse_header(<<"authorization">>, Req) of
        {basic, <<"user">>, <<"pass">>} ->
            {true, Req, State};
        _WhenOthers ->
            {{false, <<>>}, Req, State}
    end.

%% internal
handle_get(Req, State) ->
    Body = [<<"Secret information">>],
    {Body, Req, State}.
