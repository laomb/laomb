help:
	@printf '%s\n' \
		'Targets:' \
		'  all               build the full suite and run the floppy disk' \
		'  spark             assemble the bootloader' \
		'  loom              assemble the supervisor' \
		'  floppy            create FAT12 bootable image' \
		'  run-floppy        run the floppy in QEMU' \
		'  run-bochs-floppy  run the floppy in Bochs' \
		'  clean             clean build outputs' \
		'  reset             clean and rebuild' \
		'' \
		'Variables:' \
		'  BUILD_MODE=Debug|Release|Trace   (default: Debug)' \
		'  DOS_DISK=1                       enable DOS floppy flow'
