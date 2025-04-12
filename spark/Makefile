override MAKEFLAGS += -rRs

BUILD_DIR := $(abspath ../build)

FBOOT_SRC := fboot.asm
SPARK_SRC := spark.asm
FBOOT_BIN := $(BUILD_DIR)/fboot.bin
SPARK_BIN := $(BUILD_DIR)/spark.sys

all: $(FBOOT_BIN) $(SPARK_BIN)

$(FBOOT_BIN): $(FBOOT_SRC)
	@mkdir -p $(BUILD_DIR)
	@nasm -f bin -Xvc $< -o $@ 2> $(BUILD_DIR)/fboot.rawmap
	@grep 'warning: LABEL:' $(BUILD_DIR)/fboot.rawmap | \
	sed -E 's/.*warning: LABEL: ([^ ]+) @ ([0-9]+).*/\2 \1/' | \
	awk '{ printf "LABEL: %s @ 0x%04X\n", $$2, $$1 }' > $(BUILD_DIR)/fboot.map
	@rm -rf $(BUILD_DIR)/fboot.rawmap


$(SPARK_BIN): $(SPARK_SRC)
	@mkdir -p $(BUILD_DIR)
	@nasm -f bin $< -o $@

clean:
	@rm -rf $(BUILD_DIR)/fboot.bin $(BUILD_DIR)/spark.sys

.PHONY: all clean
