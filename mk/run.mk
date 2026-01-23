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
		-device cirrus-vga \
		-audiodev pa,id=snd0 \
		-device sb16,irq=11,dma=1,audiodev=snd0 \
		-drive if=none,id=cd0,media=cdrom \
		-device ide-cd,drive=cd0,bus=ide.1,unit=0,model="SONY DVD-ROM" \
		-device "ne2k_pci,netdev=net0,addr=0x03" \
		-netdev "user,id=net0,hostfwd=tcp::2222-:22" \
		--no-reboot \
		--no-shutdown \
		-serial stdio \
		-d "int,guest_errors" \
		-M "pc-i440fx-7.2,acpi=off,accel=tcg,smm=off" \
		-D "$(QEMU_LOG)"
endef

# For MBR hard drives.
# -drive file=hdd.img,if=none,id=hd0,format=raw
# -device ide-hd,drive=hd0,bus=ide.0,unit=0

define bochs_run_floppy
	$(call require_tool,bochs)
	if [ ! -f "$(BOCHSRC_FLOPPY)" ]; then
		echo "error: missing $(BOCHSRC_FLOPPY) in project root" >&2
		exit 2
	fi
	bochs -q -f "$(BOCHSRC_FLOPPY)"
endef
