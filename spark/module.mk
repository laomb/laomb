$(FBOOT_BIN): $(SPARK_FBOOT_ASM) $(CORE_INC)
	$(call fasmg_compile,$<,$@,$(SPARK_INC_DIR),1)

ifneq ($(strip $(SPARK_ASM)),)
$(SPARK_HEX): $(SPARK_ASM) $(CORE_INC)
	$(call fasmg_compile,$<,$@,$(SPARK_INC_DIR),1)
else
$(info note: $(SPARK_DIR)/spark.asm not found)
endif
