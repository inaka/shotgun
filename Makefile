PROJECT = shotgun

DEPS = lager gun
dep_lager = git git://github.com/basho/lager.git 2.1.1
dep_gun = git https://github.com/ninenines/gun.git f618634b

SHELL_DEPS = sync
dep_sync = git git://github.com/inaka/sync.git 0.1.3

include erlang.mk

ERLC_OPTS += +'{parse_transform, lager_transform}' +warn_missing_spec
TEST_ERLC_OPTS += +'{parse_transform, lager_transform}'

CONFIG = rel/sys.config

SHELL_OPTS = -name ${PROJECT}@`hostname` -s ${PROJECT} -config ${CONFIG} -s sync

erldocs: all
	erldocs . -o docs
