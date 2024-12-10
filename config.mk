# config.mk

export ANSI_GREEN := \033[0;32m
export ANSI_RESET := \033[0m

TOOLCHAIN_DIR := toolchain-i586
export DEFAULT_CC := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-gcc
export DEFAULT_LD := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-ld
export DEFAULT_AS := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-as
export DEFAULT_AR := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-ar
export DEFAULT_CXX := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-g++
export OBJDUMP := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-objdump
export OBJCOPY := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-objcopy
export STRIP = $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-strip
export NM := $(HOME)/$(TOOLCHAIN_DIR)/i586-elf/bin/i586-elf-nm

export DEFAULT_CFLAGS := -std=c23
export DEFAULT_CXXFLAGS := -std=c++23

export DEFAULT_CCFLAGS := -O2 -pipe -Wall -Wextra -Werror -fno-stack-protector -ffreestanding -march=pentium -mtune=pentium -g

export DEFAULT_NASMFLAGS := -Wall -g
export DEFAULT_LDFLAGS := -O2 -g

export KERNEL_CFLAGS := $(DEFAULT_CFLAGS) $(DEFAULT_CCFLAGS) -fPIE -m32 -march=i586 -mno-80387 -mno-mmx -mno-sse -mno-sse2 -mno-red-zone -ffreestanding \
	-fno-omit-frame-pointer -fno-lto -nostdlib -nostartfiles \
	-I . -I ./inc -I ./cfg -Wno-array-bounds
 
export KERNEL_CXXFLAGS := $(DEFAULT_CXXFLAGS) $(DEFAULT_CCFLAGS) -fPIE -m32 -march=i586 -mno-80387 -mno-mmx -mno-sse -mno-sse2 -mno-red-zone -ffreestanding \
	-Wno-delete-non-virtual-dtor -nostdinc++ -fno-omit-frame-pointer -fno-use-cxa-atexit -fno-exceptions -fno-rtti \
	-I . -I ./inc -I ./cfg

export KERNEL_LDFLAGS := $(DEFAULT_LDFLAGS) -ffreestanding -nostdlib -nostartfiles -T cfg/linker.ld -static -lgcc
export KERNEL_NASMFLAGS := $(DEFAULT_NASMFLAGS) -f elf32 -w-reloc-rel-dword -w-reloc-abs-dword

export QEMU_BASE := qemu-system-i386 \
	-m 64M -cpu pentium \
	-machine pc-i440fx-2.9,acpi=off \
	-device cirrus-vga \
	-device ne2k_pci,netdev=net0 \
	-netdev user,id=net0,hostfwd=tcp::2222-:22 \
	-debugcon stdio \
	--no-reboot --no-shutdown \
	-serial file:$(BUILD_DIR)/serial_output.txt \
	-d int \
	-D $(BUILD_DIR)/qemu_interrupt.log

export QEMU_RUN_HDD := $(QEMU_BASE) -drive format=raw,file=$(BUILD_DIR)/image.hdd,if=ide,index=0
export QEMU_RUN_ISO := $(QEMU_BASE) -cdrom $(BUILD_DIR)/image.iso
export QEMU_DEBUG := $(QEMU_BASE) -drive format=raw,file=$(BUILD_DIR)/image.hdd,if=ide,index=0 -s -S & \
	sleep 2 && \
	gdb -ex "file $(BUILD_DIR)/kernel.bin" -ex "target remote localhost:1234"