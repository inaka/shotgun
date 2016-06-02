PROJECT = shotgun

CONFIG = rel/sys.config

DEPS       = gun
BUILD_DEPS = inaka_mk hexer_mk
TEST_DEPS  = katana_test cowboy mixer lasse
SHELL_DEPS = sync


dep_gun         = git https://github.com/ninenines/gun.git     d88f3675d
dep_katana_test = git https://github.com/inaka/katana-test.git 0.0.3
dep_mixer       = git https://github.com/inaka/mixer.git       0.1.5
dep_cowboy      = git https://github.com/ninenines/cowboy.git  2.0.0-pre.3
dep_lasse       = git https://github.com/inaka/lasse.git       cowboy2
dep_sync        = git https://github.com/rustyio/sync.git      11df81d
dep_inaka_mk    = git https://github.com/inaka/inaka.mk.git    1.0.0
dep_hexer_mk    = git https://github.com/inaka/hexer.mk.git    1.1.0

DEP_PLUGINS = inaka_mk hexer_mk

include erlang.mk

ERLC_OPTS := +warn_unused_vars +warn_export_all +warn_shadow_vars +warn_unused_import +warn_unused_function
ERLC_OPTS += +warn_bif_clash +warn_unused_record +warn_deprecated_function +warn_obsolete_guard +strict_validation
ERLC_OPTS += +warn_export_vars +warn_exported_vars +warn_missing_spec +warn_untyped_record +debug_info

CT_OPTS = -cover test/cover.spec -erl_args -config ${CONFIG}

SHELL_OPTS = -name ${PROJECT}@`hostname` -s ${PROJECT} -config ${CONFIG} -s sync
