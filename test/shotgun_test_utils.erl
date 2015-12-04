-module(shotgun_test_utils).

-type config() :: [{atom(), term()}].
-export_type([config/0]).

-export([all/1]).

-export([ auto_send/1
        , wait_receive/2
        ]).

-spec all(atom()) -> [atom()].
all(Module) ->
  ExcludedFuns = [module_info, init_per_suite, end_per_suite],
  [F || {F, 1} <- Module:module_info(exports)] -- ExcludedFuns.

-spec auto_send(any()) -> reference().
auto_send(Msg) ->
  erlang:send_after(100, self(), Msg).

-spec wait_receive(any(), timeout()) -> ok | timeout.
wait_receive(Value, Timeout) ->
  receive Value -> ok
  after   Timeout -> timeout
  end.
