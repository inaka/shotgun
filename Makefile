PROJECT = shotgun

CONFIG = rel/sys.config

DEPS       = cowlib gun
TEST_DEPS  = katana cowboy inaka_mixer lasse
SHELL_DEPS = sync

dep_cowlib = hex 1.0.2
dep_katana = hex 0.2.18 
dep_cowboy = hex 1.0.4
dep_inaka_mixer = hex 0.1.5
dep_gun    = git https://github.com/ninenines/gun.git     427230d
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
