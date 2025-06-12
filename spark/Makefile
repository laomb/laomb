override MAKEFLAGS += -rRs

BUILD_DIR := $(abspath ../build)

FBOOT_SRC := fboot.asm
SPARK_SRC := spark.asm
FBOOT_BIN := $(BUILD_DIR)/fboot.bin
SPARK_BIN := $(BUILD_DIR)/spark.hex
SPARK_MAP := $(BUILD_DIR)/spark.map

ASM := fasm

all: $(FBOOT_BIN) $(SPARK_BIN)

$(BUILD_DIR):
	@mkdir -p $@

$(FBOOT_BIN): $(FBOOT_SRC) | $(BUILD_DIR)
	@$(ASM) $< $@

$(SPARK_BIN): $(SPARK_SRC) | $(BUILD_DIR)
	@rm -f $(SPARK_MAP)
	@$(ASM) $< $@ 2>&1 | awk -v mapfile="$(SPARK_MAP)" '\
		index($$0, "flat assembler ") == 1 { next } \
		$$0 ~ /LABEL / { sub("^~LABEL ", "", $$0); print > mapfile; next } \
		sub(/[0-9]+ passes, [0-9]+ bytes\./, "") { next } \
		{ print }'

clean:
	@rm -rf $(BUILD_DIR)/fboot.bin $(BUILD_DIR)/spark.hex $(SPARK_MAP)

.PHONY: all clean
