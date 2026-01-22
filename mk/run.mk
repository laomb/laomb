# TODO switch beetween emulating the two target devices.

QEMU_LOG := $(BUILD_DIR)/qemu_interrupt.log
BOCHSRC_FLOPPY := $(ROOT)/bochsrc_floppy.txt

define qemu_run_floppy
	qemu="$$( $(call pick_qemu) )"
	if [ -z "$$qemu" ]; then
		echo "error: missing qemu-system-i386/x86_64" >&2
		exit 2
	fi
	if [ ! -f "$(IMG)" ]; then
		echo "error: missing image: $(IMG) (run 'make floppy')" >&2
		exit 2
	fi
	$(call mkdir_p,$(BUILD_DIR))

	drive_opts="file=$(IMG),format=raw,if=floppy"
	echo "exec: $$qemu -drive $$drive_opts ..."
	"$$qemu" \
		-display sdl \
		-drive "$$drive_opts" \
		-m 64M \
		-cpu "pentium-v1,mmx=on,fpu=on" \
		-machine "pc-i440fx-7.2" \
		-device cirrus-vga \
		-device "ne2k_pci,netdev=net0,addr=0x03" \
		-netdev "user,id=net0,hostfwd=tcp::2222-:22" \
		--no-reboot \
		--no-shutdown \
		-serial stdio \
		-d "int,guest_errors" \
		-M "accel=tcg,smm=off" \
		-D "$(QEMU_LOG)"
endef

define bochs_run_floppy
	$(call require_tool,bochs)
	if [ ! -f "$(BOCHSRC_FLOPPY)" ]; then
		echo "error: missing $(BOCHSRC_FLOPPY) in project root" >&2
		exit 2
	fi
	bochs -q -f "$(BOCHSRC_FLOPPY)"
endef
