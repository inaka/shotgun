PROJECT = shotgun

DEPS = gun
dep_gun = git https://github.com/ninenines/gun.git 427230d6f

SHELL_DEPS = sync
dep_sync = git git://github.com/inaka/sync.git 0.1.3

include erlang.mk

ERLC_OPTS += +warn_missing_spec

CONFIG = rel/sys.config

SHELL_OPTS = -name ${PROJECT}@`hostname` -s ${PROJECT} -config ${CONFIG} -s sync

erldocs: all
	erldocs . -o docs
