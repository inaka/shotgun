-module(http_base_handler).

-export([init/2, content_types_accepted/2, content_types_provided/2, forbidden/2,
         resource_exists/2]).

%% cowboy
-spec init(cowboy_req:req(), State) -> {cowboy_rest, cowboy_req:req(), State}
    when State :: term().
init(Req, Opts) ->
    {cowboy_rest, Req, Opts}.

-spec content_types_accepted(cowboy_req:req(), State) ->
                                {[{binary(), atom()}], cowboy_req:req(), State}
    when State :: term().
content_types_accepted(Req, State) ->
    {[{<<"text/plain">>, handle_post}], Req, State}.

-spec content_types_provided(cowboy_req:req(), State) ->
                                {[{{binary(), binary(), []}, atom()}], cowboy_req:req(), State}
    when State :: term().
content_types_provided(Req, State) ->
    Method = cowboy_req:method(Req),
    Handler =
        case Method of
            <<"HEAD">> ->
                handle_head;
            _ ->
                handle_get
        end,
    {[{{<<"text">>, <<"plain">>, []}, Handler}, {{<<"text">>, <<"html">>, []}, Handler}],
     Req,
     State}.

-spec forbidden(cowboy_req:req(), State) -> {false, cowboy_req:req(), State}
    when State :: term().
forbidden(Req, State) ->
    {false, Req, State}.

-spec resource_exists(cowboy_req:req(), State) -> {true, cowboy_req:req(), State}
    when State :: term().
resource_exists(Req, State) ->
    {true, Req, State}.
