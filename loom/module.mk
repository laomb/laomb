LOOM_SRC_DIR := $(LOOM_DIR)/source
LOOM_GEN_DIR := $(BUILD_DIR)/loom/gen
LOOM_GEN_PAS_DIR := $(LOOM_GEN_DIR)/pascal

LOOM_PAS_SRCS := $(shell find $(LOOM_SRC_DIR) -name '*.pas')
LOOM_PAS_INC := $(call pascal_get_inc,$(LOOM_PAS_SRCS),$(LOOM_SRC_DIR),$(LOOM_GEN_PAS_DIR))

$(eval $(call pascal_generate_rules,$(LOOM_SRC_DIR),$(LOOM_GEN_PAS_DIR),$(LOOM_INC_DIR)))

$(LOOM_BIN): $(LOOM_ASM) $(LOOM_PAS_INC)
	$(call fasmg_compile,$<,$@,$(LOOM_INC_DIR);$(LOOM_GEN_DIR),)
