override MAKEFLAGS += -rRs

BUILD_DIR := $(abspath ../build)

FBOOT_SRC := fboot.asm
SPARK_SRC := spark.asm
FBOOT_BIN := $(BUILD_DIR)/fboot.bin
FBOOT_FAS := $(BUILD_DIR)/fboot.fas
SPARK_BIN := $(BUILD_DIR)/spark.hex
SPARK_FAS := $(BUILD_DIR)/spark.fas

ASM := fasm

all: $(FBOOT_BIN) $(SPARK_BIN)

$(BUILD_DIR):
	@mkdir -p $@

$(FBOOT_BIN): $(FBOOT_SRC) | $(BUILD_DIR)
	@$(ASM) $< $@

$(SPARK_BIN): $(SPARK_SRC) | $(BUILD_DIR)
	@$(ASM) $< $@ -s $(SPARK_FAS)

clean:
	@rm -rf $(FBOOT_BIN) $(SPARK_BIN) $(FBOOT_FAS) $(SPARK_FAS)

.PHONY: all clean
