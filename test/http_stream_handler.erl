-module(http_stream_handler).

-export([init/2]).

%% The test controls delivery explicitly, independently of network packet boundaries.
-spec init(cowboy_req:req(), pid()) -> {ok, cowboy_req:req(), undefined}.
init(Req, Controller) ->
    Controller ! {stream_ready, self(), cowboy_req:version(Req)},
    receive
        read_body ->
            {Body, Req1} = read_body(Req, <<>>),
            Controller ! {request_body, cowboy_req:method(Req1), Body},
            {ok, cowboy_req:reply(201, #{}, Body, Req1), undefined};
        {headers, Status, Headers} ->
            Req1 = cowboy_req:stream_reply(Status, Headers, Req),
            deliver(Req1);
        {reply, Status} ->
            {ok, cowboy_req:reply(Status, #{}, <<>>, Req), undefined}
    after 5000 ->
        error(controller_timeout)
    end.

-spec deliver(cowboy_req:req()) -> {ok, cowboy_req:req(), undefined}.
deliver(Req) ->
    receive
        {data, IsFin, Data} ->
            ok = cowboy_req:stream_body(Data, IsFin, Req),
            case IsFin of
                fin ->
                    {ok, Req, undefined};
                nofin ->
                    deliver(Req)
            end;
        reset ->
            error(test_stream_reset);
        trailers ->
            ok = cowboy_req:stream_trailers(#{<<"x-complete">> => <<"yes">>}, Req),
            {ok, Req, undefined}
    after 5000 ->
        error(controller_timeout)
    end.

-spec read_body(cowboy_req:req(), binary()) -> {binary(), cowboy_req:req()}.
read_body(Req, Acc) ->
    case cowboy_req:read_body(Req) of
        {more, Data, Req1} ->
            read_body(Req1, <<Acc/binary, Data/binary>>);
        {ok, Data, Req1} ->
            {<<Acc/binary, Data/binary>>, Req1}
    end.
