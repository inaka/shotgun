-module(shotgun_meta_SUITE).

-include_lib("mixer/include/mixer.hrl").
-mixin([{ktn_meta_SUITE, []}]).

-export([all/0
				,init_per_suite/1
				]).
-export([end_per_suite/1]).

init_per_suite(Config) -> [{application, shotgun} | Config].

end_per_suite(Config) ->
  Config.

all() -> shotgun_test_utils:all(?MODULE).
