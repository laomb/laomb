ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

include config.mk
include mk/tools.mk
include mk/mode.mk
include mk/fasmg.mk
include mk/floppy.mk
include mk/run.mk
include mk/help.mk

include spark/module.mk
include loom/module.mk

.DEFAULT_GOAL := all

.PHONY: all spark loom floppy run-floppy run-bochs-floppy clean reset help

all: run-floppy

spark: $(FBOOT_BIN) $(SPARK_HEX_OPT)

loom: $(LOOM_BIN)

run-floppy: spark loom floppy
	$(call qemu_run_floppy)

run-bochs-floppy: spark loom floppy
	$(call bochs_run_floppy)

clean:
	$(call rm_rf,$(BUILD_DIR))

reset: clean
	$(call maybe_clear_screen)
	$(MAKE) all
