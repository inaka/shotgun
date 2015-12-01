PROJECT = shotgun

CONFIG = rel/sys.config

DEPS       = cowlib gun
TEST_DEPS  = katana cowboy mixer lasse
SHELL_DEPS = sync

dep_cowlib = git https://github.com/ninenines/cowlib.git  1.0.2
dep_gun    = git https://github.com/ninenines/gun.git     427230d
dep_katana = git git://github.com/inaka/erlang-katana.git 0.2.14
dep_cowboy = git git://github.com/ninenines/cowboy.git    1.0.4
dep_mixer  = git git://github.com/inaka/mixer.git         0.1.4
dep_lasse  = git git://github.com/inaka/lasse.git         1.0.1
dep_sync   = git git://github.com/inaka/sync.git          0.1.3

include erlang.mk

ERLC_OPTS += +warn_missing_spec

CT_OPTS = -cover test/cover.spec -erl_args -config ${CONFIG}

SHELL_OPTS = -name ${PROJECT}@`hostname` -s ${PROJECT} -config ${CONFIG} -s sync

quicktests: app
	@$(MAKE) --no-print-directory app-build test-dir ERLC_OPTS="$(TEST_ERLC_OPTS)"
	$(verbose) mkdir -p $(CURDIR)/logs/
	$(gen_verbose) $(CT_RUN) -suite $(addsuffix _SUITE,$(CT_SUITES)) $(CT_OPTS)

test-build-plt: ERLC_OPTS=$(TEST_ERLC_OPTS)
test-build-plt:
	@$(MAKE) --no-print-directory test-dir ERLC_OPTS="$(TEST_ERLC_OPTS)"
	$(gen_verbose) touch ebin/test

plt-all: PLT_APPS := $(ALL_TEST_DEPS_DIRS)
plt-all: test-deps test-build-plt plt

dialyze-all: app test-build-plt dialyze

erldocs: all
	erldocs . -o docs
