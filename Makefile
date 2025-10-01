override MAKEFLAGS += -rRs

CORES := $(shell nproc)
BUILD_DIR := $(abspath ./build)
SPARK_DIR := $(abspath ./spark)
FIXFMT ?= python3 tools/fixfmt.py
FIXFMT_INDENT ?= 4

include config.mk

all: spark floppy run-floppy

spark:
	@make -C $(SPARK_DIR)

floppy:
	@mkdir -p $(BUILD_DIR)
	@dd if=/dev/zero of=$(BUILD_DIR)/a.img bs=512 count=2880
	@mkfs.fat -F 12 -n LAOMB $(BUILD_DIR)/a.img

	@dd if=$(BUILD_DIR)/fboot.bin of=$(BUILD_DIR)/a.img bs=1 count=512 conv=notrunc

	@mcopy -i $(BUILD_DIR)/a.img test.txt ::TEST.TXT
	@mcopy -i $(BUILD_DIR)/a.img $(BUILD_DIR)/spark.hex ::SPARK.HEX
	#@mcopy -i $(BUILD_DIR)/a.img $(BUILD_DIR)/kernel.bin ::

disk:
	@mkdir -p $(BUILD_DIR)
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$(BUILD_DIR)/disk.hdd
	@parted $(BUILD_DIR)/disk.hdd mklabel msdos
	@parted $(BUILD_DIR)/disk.hdd mkpart primary fat32 1MiB 100%
	@mformat -i $(BUILD_DIR)/disk.hdd@@1M
# TODO Maybe shrink the reserved part (offset of first partition to ~64K as spark can't be larger?)
# TODO actually write spark onto the reserved sectors (both stages)

	@mcopy -i $(BUILD_DIR)/disk.hdd@@1M $(BUILD_DIR)/kernel.bin ::/

QEMU_COMMON_FLAGS := -m 64M -cpu pentium-v1,mmx=on,fpu=on \
		-machine pc-i440fx-7.2 \
		-device cirrus-vga \
		-device ne2k_pci,netdev=net0,addr=0x03 \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		--no-reboot --no-shutdown \
		-serial stdio \
		-d int,guest_errors \
		-M accel=tcg,smm=off \
		-D $(BUILD_DIR)/qemu_interrupt.log

run-floppy:
	@clear	
	@qemu-system-i386 -drive format=raw,file=$(BUILD_DIR)/a.img,if=floppy \
		$(QEMU_COMMON_FLAGS)

run-disk:
	@clear	
	@qemu-system-i386 -drive format=raw,file=$(BUILD_DIR)/disk.hdd,if=ide,index=0 \
		$(QEMU_COMMON_FLAGS)

run-bochs-floppy: $(BUILD_DIR)/a.img
	@bochs -qf bochsrc_floppy.txt

run-debug-floppy: $(BUILD_DIR)/a.img
	@clear
	@qemu-system-i386 \
		-drive format=raw,file=$(BUILD_DIR)/a.img,if=floppy \
		$(QEMU_COMMON_FLAGS) \
		-S -gdb tcp::1234 &
	@sleep 1
	@python3 tools/adbg/adbg.py

clean:
	@clear
	@rm -rf $(BUILD_DIR)/*

reset:
	@make clean
	@clear
	@make

docs: $(BUILD_DIR)/laomb.pdf

$(BUILD_DIR)/laomb.pdf: docs/laomb.tex
	@lualatex -output-directory=$(BUILD_DIR) $<

watch-docs:
	@while inotifywait -e close_write docs/laomb.tex; do make docs; done

format:
	@echo "Formatting .asm files (indent=$(FIXFMT_INDENT))..."
	@find . -type f \( -name '*.asm' \) \
		-not -path '$(BUILD_DIR)/*' -print0 \
	| xargs -0 -n1 -P $(CORES) sh -c '\
		f="$$1"; tmp="$$f.__fmt__"; \
		$(FIXFMT) --indent $(FIXFMT_INDENT) "$$f" "$$tmp"; \
		if ! cmp -s "$$f" "$$tmp"; then mv "$$tmp" "$$f"; else rm -f "$$tmp"; fi' sh

.PHONY: all loom disk run-disk run-floppy clean reset floppy spark run-bochs-floppy docs watch-docs format