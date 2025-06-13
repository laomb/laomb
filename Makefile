override MAKEFLAGS += -rRs

CORES := $(shell nproc)
BUILD_DIR := $(abspath ./build)
SPARK_DIR := $(abspath ./spark)

include config.mk

all: spark floppy run-floppy

spark:
	@make -C $(SPARK_DIR)

floppy:
	@mkdir -p $(BUILD_DIR)
	@dd if=/dev/zero of=$(BUILD_DIR)/a.img bs=512 count=2880
	@mkfs.fat -F 12 -n LAOMB $(BUILD_DIR)/a.img

	@dd if=$(BUILD_DIR)/fboot.bin of=$(BUILD_DIR)/a.img bs=1 skip=60 seek=60 count=452 conv=notrunc

	@mcopy -i $(BUILD_DIR)/a.img $(BUILD_DIR)/spark.hex ::SPARK.HEX
	#@mcopy -i $(BUILD_DIR)/a.img $(BUILD_DIR)/kernel.bin ::

disk:
	@mkdir -p $(BUILD_DIR)
	@dd if=/dev/zero bs=1M count=0 seek=64 of=$(BUILD_DIR)/disk.hdd
	@parted $(BUILD_DIR)/disk.hdd mklabel msdos
	@parted $(BUILD_DIR)/disk.hdd mkpart primary fat32 1MiB 100%
	@mformat -i $(BUILD_DIR)/disk.hdd@@1M

	@mcopy -i $(BUILD_DIR)/disk.hdd@@1M $(BUILD_DIR)/kernel.bin ::/

QEMU_COMMON_FLAGS := -m 64M -cpu pentium \
		-machine pc-i440fx-2.9 \
		-device cirrus-vga \
		-device ne2k_pci,netdev=net0 \
		-netdev user,id=net0,hostfwd=tcp::2222-:22 \
		--no-reboot --no-shutdown \
		-serial stdio \
		-d int \
		-M smm=off \
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

clean:
	@clear
	@make -C spark clean
	@rm -rf $(BUILD_DIR)/a.img $(BUILD_DIR)/qemu_interrupt.log
	@rm -f $(BUILD_DIR)/laomb.{aux,log,pdf,tex}

reset:
	@make clean
	@clear
	@make

docs: $(BUILD_DIR)/laomb.pdf

$(BUILD_DIR)/laomb.pdf: docs/laomb.tex
	@lualatex -output-directory=$(BUILD_DIR) $<

watch-docs:
	@while inotifywait -e close_write docs/laomb.tex; do make docs; done

.PHONY: all loom disk run-disk run-floppy clean reset floppy spark run-bochs-floppy docs watch-docs