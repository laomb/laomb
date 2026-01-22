FLOPPY_VARIANT := $(if $(strip $(DOS_DISK)),dos,plain)

DOS_URL := https://www.allbootdisks.com/disk_images/Dos6.22.img
DOS_IMG := $(BUILD_DIR)/dos622.img
DOS_BOOT_HEX := $(BUILD_DIR)/MSDOS.HEX

$(DOS_IMG):
	$(call mkdir_p,$(dir $@))
	dl="$$( $(call pick_downloader) )"
	if [ -z "$$dl" ]; then
		echo "error: missing curl/wget for download" >&2
		exit 2
	fi
	echo "downloading: $(DOS_URL) -> $@"
	if [ "$$dl" = "curl" ]; then
		curl -L --fail -o "$@" "$(DOS_URL)"
	else
		wget -O "$@" "$(DOS_URL)"
	fi

define make_plain_floppy
	$(call require_tool,dd)
	mkfs="$$( $(call pick_mkfs_fat) )"
	if [ -z "$$mkfs" ]; then
		echo "error: missing mkfs.fat/mkfs.vfat" >&2
		exit 2
	fi
	$(call require_tool,mcopy)

	$(call mkdir_p,$(BUILD_DIR))

	dd if=/dev/zero of="$(IMG)" bs=512 count=2880 status=none
	"$$mkfs" -F 12 "$(IMG)"

	dd if="$(FBOOT_BIN)" of="$(IMG)" bs=1 count=512 conv=notrunc status=none

	if [ -f "$(SPARK_HEX)" ]; then
		mcopy -i "$(IMG)" "$(SPARK_HEX)" ::SPARK.HEX
	else
		echo "warn: missing $(SPARK_HEX) - skipping copy" >&2
	fi

	if [ -f "$(LOOM_BIN)" ]; then
		mcopy -i "$(IMG)" "$(LOOM_BIN)" ::LOOM.BIN
	else
		echo "warn: missing $(LOOM_BIN) - skipping copy" >&2
	fi

	if [ -f "$(ROOT)/BOOT.INI" ]; then
		mcopy -i "$(IMG)" "$(ROOT)/BOOT.INI" ::BOOT.INI
	else
		echo "warn: missing $(ROOT)/BOOT.INI - skipping copy" >&2
	fi

	echo "floppy image ready: $(IMG)"
endef

define make_dos_floppy
	$(call require_tool,dd)
	mkfs="$$( $(call pick_mkfs_fat) )"
	if [ -z "$$mkfs" ]; then
		echo "error: missing mkfs.fat/mkfs.vfat" >&2
		exit 2
	fi
	$(call require_tool,mcopy)
	$(call require_tool,mattrib)

	$(call mkdir_p,$(BUILD_DIR))

	dd if=/dev/zero of="$(IMG)" bs=512 count=2880 status=none
	"$$mkfs" -F 12 "$(IMG)"

	dd if="$(DOS_IMG)" of="$(DOS_BOOT_HEX)" bs=512 count=1 status=none
	dd if="$(FBOOT_BIN)" of="$(IMG)" bs=1 count=512 conv=notrunc status=none

	tmp_io="$(BUILD_DIR)/IO.SYS"
	tmp_ms="$(BUILD_DIR)/MSDOS.SYS"
	tmp_cc="$(BUILD_DIR)/COMMAND.COM"
	rm -f "$$tmp_io" "$$tmp_ms" "$$tmp_cc"

	mcopy -i "$(DOS_IMG)" ::IO.SYS "$$tmp_io"
	mcopy -i "$(DOS_IMG)" ::MSDOS.SYS "$$tmp_ms"
	mcopy -i "$(DOS_IMG)" ::COMMAND.COM "$$tmp_cc"

	mcopy -i "$(IMG)" "$$tmp_io" ::IO.SYS
	mcopy -i "$(IMG)" "$$tmp_ms" ::MSDOS.SYS
	mattrib -i "$(IMG)" +s +h +r ::IO.SYS
	mattrib -i "$(IMG)" +s +h +r ::MSDOS.SYS
	mcopy -i "$(IMG)" "$$tmp_cc" ::COMMAND.COM

	cfg="$(BUILD_DIR)/CONFIG.SYS"
	bat="$(BUILD_DIR)/AUTOEXEC.BAT"
	printf 'FILES=30\r\nBUFFERS=20\r\n' > "$$cfg"
	printf '@ECHO OFF\r\nPROMPT $$P$$G\r\n' > "$$bat"
	mcopy -i "$(IMG)" "$$cfg" ::CONFIG.SYS
	mcopy -i "$(IMG)" "$$bat" ::AUTOEXEC.BAT

	if [ -f "$(SPARK_HEX)" ]; then
		mcopy -i "$(IMG)" "$(SPARK_HEX)" ::SPARK.HEX
	else
		echo "warn: missing $(SPARK_HEX) - skipping copy" >&2
	fi

	if [ -f "$(LOOM_BIN)" ]; then
		mcopy -i "$(IMG)" "$(LOOM_BIN)" ::LOOM.BIN
	else
		echo "warn: missing $(LOOM_BIN) - skipping copy" >&2
	fi

	mcopy -i "$(IMG)" "$(DOS_BOOT_HEX)" ::MSDOS.HEX

	if [ -f "$(ROOT)/BOOT.INI" ]; then
		mcopy -i "$(IMG)" "$(ROOT)/BOOT.INI" ::BOOT.INI
	else
		echo "warn: missing $(ROOT)/BOOT.INI - skipping copy" >&2
	fi

	echo "DOS floppy image ready: $(IMG)"
endef

floppy: $(FBOOT_BIN) $(SPARK_HEX_OPT) $(LOOM_BIN) $(BOOT_INI) $(if $(strip $(DOS_DISK)),$(DOS_IMG),)
	$(call mkdir_p,$(BUILD_DIR))

	if [ "$(FLOPPY_VARIANT)" = "dos" ]; then
		$(make_dos_floppy)
	else
		$(make_plain_floppy)
	fi
