FASMG ?= fasmg

GLOBAL_INC_DIR := $(ROOT)/include
PRELUDE := $(GLOBAL_INC_DIR)/prelude.asm

IMG := $(BUILD_DIR)/a.img
FBOOT_BIN := $(BUILD_DIR)/fboot.bin
SPARK_HEX := $(BUILD_DIR)/spark.hex
LOOM_BIN := $(BUILD_DIR)/loom.bin

SPARK_DIR := $(ROOT)/spark
LOOM_DIR := $(ROOT)/loom

SPARK_INC_DIR := $(SPARK_DIR)/include
LOOM_INC_DIR := $(LOOM_DIR)/include

SPARK_FBOOT_ASM := $(SPARK_DIR)/fboot.asm
SPARK_ASM := $(wildcard $(SPARK_DIR)/spark.asm)
LOOM_ASM := $(LOOM_DIR)/loom.asm

SPARK_HEX_OPT := $(if $(strip $(SPARK_ASM)),$(SPARK_HEX),)

BOOT_INI := $(wildcard $(ROOT)/BOOT.INI)

define fasmg_compile
	$(call require_tool,$(FASMG))
	$(call mkdir_p,$(dir $(2)))
	INCLUDE="$(GLOBAL_INC_DIR);$(3);$$INCLUDE" \
	"$(FASMG)" \
		-i "include '$(PRELUDE)'" \
		-i "$(FASMG_MODE_LINE)" \
		$(if $(strip $(4)),-i "$(FASMG_TRACE_LINE)",) \
		-n \
		"$(1)" "$(2)"
endef
