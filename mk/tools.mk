SHELL := /bin/sh
.ONESHELL:
.SHELLFLAGS := -eu -c

MKDIR_P := mkdir -p

define mkdir_p
	$(MKDIR_P) "$(1)"
endef

define rm_rf
	rm -rf "$(1)"
endef

define rm_f
	rm -f "$(1)"
endef

define require_tool
	command -v "$(1)" >/dev/null 2>&1 || { echo "error: missing tool: $(1)" >&2; exit 2; }
endef

define maybe_clear_screen
	if command -v clear >/dev/null 2>&1; then clear; fi
endef

define pick_mkfs_fat
	if command -v mkfs.fat >/dev/null 2>&1; then echo mkfs.fat; \
	elif command -v mkfs.vfat >/dev/null 2>&1; then echo mkfs.vfat; \
	else echo ""; fi
endef

define pick_qemu
	if command -v qemu-system-i386 >/dev/null 2>&1; then echo qemu-system-i386; \
	elif command -v qemu-system-x86_64 >/dev/null 2>&1; then echo qemu-system-x86_64; \
	else echo ""; fi
endef

define pick_downloader
	if command -v curl >/dev/null 2>&1; then echo curl; \
	elif command -v wget >/dev/null 2>&1; then echo wget; \
	else echo ""; fi
endef

define pick_fpc
	if command -v fpc >/dev/null 2>&1; then echo fpc; else echo ""; fi
endef

define pick_lua
	if command -v lua >/dev/null 2>&1; then echo lua; \
	elif command -v lua5.3 >/dev/null 2>&1; then echo lua5.3; \
	elif command -v lua5.4 >/dev/null 2>&1; then echo lua5.4; \
	else echo ""; fi
endef
