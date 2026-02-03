$(LOOM_BIN): $(LOOM_ASM)
	$(call fasmg_compile,$<,$@,$(LOOM_INC_DIR),)
