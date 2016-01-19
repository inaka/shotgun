PROJECT = shotgun

CONFIG = rel/sys.config

DEPS       = gun
BUILD_DEPS = inaka_mk hexer_mk
TEST_DEPS  = katana cowboy inaka_mixer lasse
SHELL_DEPS = sync

dep_katana = hex 0.2.19
dep_cowboy = git https://github.com/ninenines/cowboy.git 2.0.0-pre.2
dep_inaka_mixer = hex 0.1.5
dep_gun    = git https://github.com/ninenines/gun.git    427230d
dep_lasse  = git https://github.com/inaka/lasse.git      1.0.1
dep_sync   = git https://github.com/inaka/sync.git       0.1.3
dep_inaka_mk = git https://github.com/inaka/inaka.mk.git 1.0.0
dep_hexer_mk = git https://github.com/inaka/hexer.mk.git 1.0.2

DEP_PLUGINS = inaka_mk hexer_mk

include erlang.mk

ERLC_OPTS := +warn_unused_vars +warn_export_all +warn_shadow_vars +warn_unused_import +warn_unused_function
ERLC_OPTS += +warn_bif_clash +warn_unused_record +warn_deprecated_function +warn_obsolete_guard +strict_validation
ERLC_OPTS += +warn_export_vars +warn_exported_vars +warn_missing_spec +warn_untyped_record +debug_info

CT_OPTS = -cover test/cover.spec -erl_args -config ${CONFIG}

SHELL_OPTS = -name ${PROJECT}@`hostname` -s ${PROJECT} -config ${CONFIG} -s sync
