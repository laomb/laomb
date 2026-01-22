$(LOOM_BIN): $(LOOM_ASM) $(CORE_INC)
	$(call fasmg_compile,$<,$@,$(LOOM_INC_DIR),)
