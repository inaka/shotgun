-module(shotgun_meta_SUITE).

-include_lib("mixer/include/mixer.hrl").

-mixin([{ktn_meta_SUITE, []}]).

-export([all/0, init_per_suite/1]).
-export([end_per_suite/1]).

-spec init_per_suite(shotgun_test_utils:config()) -> shotgun_test_utils:config().
init_per_suite(Config) ->
    [{application, shotgun} | Config].

-spec end_per_suite(shotgun_test_utils:config()) -> shotgun_test_utils:config().
end_per_suite(Config) ->
    Config.

-spec all() -> [atom()].
all() ->
    shotgun_test_utils:all(?MODULE).
