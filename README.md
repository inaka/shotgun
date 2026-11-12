shotgun
=======

For the times you need more than just a [gun](https://github.com/ninenines/gun).

![](http://lbsommer-author.yolasite.com/resources/Funny%20gun%20sign%2017.jpg)

## Rationale

After using the [gun](http://github.com/extend/gun) library on a project where
we needed to consume Server-sent Events (SSE) we found that it provided great
flexibility, at the cost of having to handle each raw message and data,
including the construction of the response body data.
Although this is great for a lot of scenarios, it can get cumbersome and
repetitive after implementing it a couple of times. This is why we ended up
creating **shotgun**, an HTTP client that uses **gun** behind the curtains but
provides a simple API that has out-of-the-box support for SSE.

## Usage

*shotgun* uses maps and hence requires Erlang 17 to compile and run.

*shotgun* is an OTP application, so before being able to use it, it has to
be started. Either add it as one of the applications in your
[`.app`](http://www.erlang.org/doc/man/app.html) file or run the following
code:

```erlang
application:ensure_all_started(shotgun).
```

### Regular Requests

Once the application is started a connection needs to be created in order to
start making requests:

```erlang
{ok, Conn} = shotgun:open("google.com", 80),
{ok, Response} = shotgun:get(Conn, "/"),
io:format("~p~n", [Response]),
shotgun:close(Conn).
```

Which results in:

```erlang
#{body => <<"<HTML><HEAD>"...>>,
  headers => [
     {<<"location">>,<<"http://www.google.com/adfs">>},
     {<<"content-type">>,<<"text/html; charset=UTF-8">>},
     {<<"x-content-type-options">>,<<"nosniff">>},
     {<<"date">>,<<"Fri, 17 Oct 2014 17:18:32 GMT">>},
     {<<"expires">>,<<"Sun, 16 Nov 2014 17:18:32 GMT">>},
     {<<"cache-control">>,<<"public, max-age=2592000">>},
     {<<"server">>,<<"sffe">>},
     {<<"content-length">>,<<"223">>},
     {<<"x-xss-protection">>,<<"1; mode=block">>},
     {<<"alternate-protocol">>,<<"80:quic,p=0.01">>}
   ],
   status_code => 302}
}

%= ok
```

Immediately after opening a connection we did a GET request, where we didn't
specify any headers or options. Every HTTP method has its own **shotgun**
function that takes a connection, a uri (which needs to include the slash),
a headers map or a proplist containing the headers, and an options map. 
Some of the functions (`post/5`, `put/5` and `patch/5`) also take a body 
argument.

Alternatively there's a generic `request/6` function in which the user can
specify the HTTP method as an argument in the form of an atom: `get`, `head`,
`options`, `delete`, `post`, `put` or `patch`.

**IMPORTANT:** When you are done using the shotgun connection remember to close
it with `shotgun:close/1`.

### HTTP Secure Requests

It is possible to tell shotgun to use SSL by providing the atom `https` as the
third argument when creating a connection with to the `open` function. Just
like when performing HTTP requests it is also necessary to specify
a port. HTTPS servers typically listen for connections on port 443 and this
will be the most likely value you'll need to use.

### Basic Authentication

If you need to provide basic authentication credentials in your requests, it is
as easy as specifying a `basic_auth` entry in the headers map:

```erlang
{ok, Conn} = shotgun:open("site.com", 80),
{ok, Response} = shotgun:get(Conn, "/user", #{basic_auth => {"user", "password"}}),
, or
{ok, Response} = shotgun:get(Conn, "/user", [{basic_auth, {"user", "password"}}]),
shotgun:close(Conn).
```

### Specifying a Timeout

The `timeout` option can be used to specify a value for all types of requests:

```erlang
{ok, Conn} = shotgun:open("google.com", 80).
{error, Error} = shotgun:get(Conn, "/", #{}, #{timeout => 10}).
io:format("~p~n", [Error]).
%%= {timeout,{gen_fsm,sync_send_event,[<0.368.0>,{get,{"/",[],[]}},10]}}
shotgun:close(Conn).
```

The default `timeout` value is 5000 if none is specified.

### Consuming Server-sent Events

To use **shotgun** with endpoints that generate SSE the request must be
configured using some values in the options map, which supports the following
entries:

- `async ::boolean()`: delivers the response body incrementally over HTTP/1 or
HTTP/2. HTTP/1 preserves its historical behavior: only responses with
`Transfer-Encoding: chunked` are streamed; other responses, including those with
`Content-Length`, return the complete `{ok, Response}` without invoking the
stream callback or adding events to the queue. HTTP/2 responses are streamed
regardless of `Content-Length`.
**It currently only works for GET requests.** Default value is `false`.
When a streaming response indicates more data will follow, the request returns
`{ok, StreamRef}` immediately. Responses completed by the headers (for example,
`204 No Content`) return `{ok, Response}` as usual. Streaming ends when Gun
reports the final body data or response trailers; trailers are not exposed as
body data. In `binary` mode, data boundaries depend on the transport and need
not match server writes. In `sse` mode, data is buffered into SSE events.

- `async_mode :: binary | sse`: when `async` is `true` the mode specifies
how the data received will be processed. `binary` mode treats each chunk received
as raw binary. `sse` mode buffers each chunk, splitting the data received into
SSE. Default value is `binary`.

- `handle_event :: fun((fin | nofin, reference(), binary()) -> any())`: this function
will be called each time either a chunk is received (`async_mode` = `binary`) or
an event is parsed (`async_mode` = `sse`). If no handle_event function is
provided the data received is added to a queue, whose values can be obtained
calling the `shotgun:events/1`. Default value is `undefined`.

- `allow_reconnect :: boolean()`: for async GET requests, controls what happens
when Gun reports that the underlying connection is down. Default value is `true`:
Shotgun keeps its PID alive in the `down` state, and requests made in that state
return `{error, gun_down}`. Call `shotgun:reopen` to reuse the PID, then issue a new
request. Reopening does not automatically resume the previous SSE stream.
With `false`, Shotgun terminates on `gun_down` with reason
`{shutdown, {gun_down, Reason}}`, where `Reason` is supplied by Gun. A process
monitoring the connection receives `DOWN` without waiting for Gun to exhaust its
retries or for a read timeout. The setting is retained after an async response
finishes until another async request supplies its own setting or the connection
is reopened. Unexpected transport failure is not reported as a successful `fin`
event through the data callback.

- `read_timeout :: timeout()`: when `async` is `true`, the maximum time in
milliseconds between two chunks of the response. When no chunk data is
delivered in that time the connection is closed and the connection process
exits with reason `{shutdown, read_timeout}`. Monitor the connection pid to be
notified, then open a new connection. Default value is `infinity`.

The following is an example of the usage of **shotgun** when consuming SSE.

```erlang
{ok, Conn} = shotgun:open("localhost", 8080).
%= {ok,<0.6003.0>}

Options = #{async => true, async_mode => sse},
{ok, Ref} = shotgun:get(Conn, "/events", #{}, Options).
%= {ok,#Ref<0.0.1.186238>}

% Some event are generated on the server...
Events = shotgun:events(Conn).
%= [{nofin, #Ref<0.0.1.186238>, <<"data: pong">>}, {nofin, #Ref<0.0.1.186238>, <<"data: pong">>}]

shotgun:events(Conn).
%= []
```

Notice how the second call to `shotgun:events/1` returns an empty list. This is
because events are stored in a queue and each call to `events` returns all
events queued so far and then removes these from the queue. So it's important
to understand that `shotgun:events/1` is a function with side-effects when using
it.

To manage SSE reconnection in your application, monitor the connection and set
`allow_reconnect => false`:

```erlang
{ok, Conn} = shotgun:open("localhost", 8080),
Monitor = erlang:monitor(process, Conn),
Options = #{async => true, async_mode => sse, allow_reconnect => false},
{ok, _StreamRef} = shotgun:get(Conn, "/events", #{}, Options),
receive
    {'DOWN', Monitor, process, Conn, Reason} ->
        io:format("SSE connection stopped: ~p~n", [Reason])
        %% Open a new connection and issue a new SSE request when ready.
end.
```

A transport disconnection produces `{shutdown, {gun_down, GunReason}}`; a configured
read timeout produces `{shutdown, read_timeout}`. The default
`allow_reconnect => true` keeps the PID available for explicit reopening after
`gun_down`, so a PID monitor alone does not signal that state transition.

Additionally **shotgun** provides a `parse_event/1` helper function that
turns a server-sent event binary into a map:

```erlang
shotgun:parse_event(<<"data: pong\ndata: ping\nid: 1\nevent: pinging">>).
%= #{data => [<<"pong">>,<<"ping">>],event => <<"pinging">>,id => <<"1">>}
```

## Building & Test-Driving

To build **shotgun** just run the following on your command shell:

```sh
rebar3 compile
```

To start up a shell where you can try things out run the following (after
building the project as described above):

```sh
rebar3 shell
```

Run the test suite and check the required 100% line coverage of the application:

```sh
rebar3 ct
rebar3 cover
```

The coverage report is written to `_build/test/cover/index.html`. Tests cover
HTTP/1, cleartext HTTP/2, and HTTPS with HTTP/2 negotiated through ALPN. Test TLS
credentials are generated in memory; no external server is required for these
protocol tests.

### Test shutdown timeout

The state callback tests wait up to **1000 milliseconds** for a test transport to
acknowledge shutdown. On slower CI runners, override this limit with the Common
Test configuration key `transport_shutdown_timeout`.

Create `test/ct.config` with the following **complete file contents**:

```erlang
%% Common Test configuration for Shotgun.
%% Maximum wait for a test transport to acknowledge shutdown, in milliseconds.
%% Default when omitted: 1000 ms. This example allows 5000 ms.
{transport_shutdown_timeout, 5000}.
```

This is a complete Common Test configuration file: no other keys are required.
Write each entry as an Erlang `{Key, Value}` term followed by a period; do not
wrap the entries in a list or add an application name. This file is separate
from `rebar.config` and OTP application environment configuration.

Run the full suite from the repository root:

```sh
rebar3 ct --config test/ct.config
```

The value is a timeout in milliseconds. If the key is omitted, the tests use
1000 ms. This setting controls only the shutdown acknowledgement waits in
`shotgun_state_SUITE`; it does not change Shotgun connection or read timeouts.

## Contact Us
If you find any **bugs** or have a **problem** while using this library, please
[open an issue](https://github.com/inaka/shotgun/issues/new) in this repo
(or a pull request :)).

And you can check all of our open-source projects at
[inaka.github.io](http://inaka.github.io)
