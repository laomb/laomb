#include "layout.h"
#include <Carbide/Recipe.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

static int have_tool(const char *exe) {
	const char *PATH = getenv("PATH");
	if (!PATH)
		return 0;

	char tmp[8192];
	strncpy(tmp, PATH, sizeof(tmp));
	tmp[sizeof(tmp) - 1] = 0;
	for (char *tok = strtok(tmp, ":"); tok; tok = strtok(CB_NULL, ":")) {
		const char *p = cb_join(tok, exe);
		if (cb_file_exists(p))
			return 1;
	}

	return 0;
}

static layout_t L;

static const char *normalize_mode(const char *in) {
	if (!in || !*in)
		return "Debug";

	if (strcasecmp(in, "Debug") == 0)
		return "Debug";

	if (strcasecmp(in, "Release") == 0)
		return "Release";

	cb_log_warn("unknown BUILD_MODE='%s', defaulting to Debug", in);
	return "Debug";
}

static int want_dos(void) {
	const char *v = getenv("DOS_DISK");
	int on = (v && *v) ? 1 : 0;
	cb_log_verbose("[CFG] DOS_DISK present: %s", on ? "yes" : "no");
	return on;
}

static void init_layout(void) {
	const char *root = cb_workspace_root();
	L.ROOT = cb_norm(root);
	L.OUT = cb_norm(cb_out_root());
	L.BUILD_DIR = cb_join(L.OUT, "build");
	L.BUILD_MODE = normalize_mode(getenv("BUILD_MODE"));
	L.SPARK_DIR = cb_join(L.ROOT, "spark");
	L.IMG = cb_join(L.BUILD_DIR, "a.img");
	L.FBOOT_BIN = cb_join(L.BUILD_DIR, "fboot.bin");
	L.SPARK_HEX = cb_join(L.BUILD_DIR, "spark.hex");
	cb_mkdir_p(L.BUILD_DIR);
}

static int run(cb_cmd *c) {
	int exit_code = -1;
	int rc = cb_cmd_run(c, &exit_code);
	cb_cmd_free(c);

	if (rc != 0 || exit_code != 0) {
		cb_log_error("command failed (rc=%d exit=%d)", rc, exit_code);
		return (rc != 0) ? rc : exit_code;
	}

	return 0;
}

static int run_simple(const char *prog, const char *const *argv, size_t argc) {
	cb_cmd *c = cb_cmd_new();
	cb_cmd_push_arg(c, prog);

	for (size_t i = 0; i < argc; i++)
		cb_cmd_push_arg(c, argv[i]);

	return run(c);
}

static int run_shell(const char *shline) {
	cb_cmd *c = cb_cmd_new();
	cb_cmd_push_arg(c, "/bin/sh");
	cb_cmd_push_arg(c, "-c");
	cb_cmd_push_arg(c, shline);
	cb_log_verbose("[SH] /bin/sh -c -- %s", shline);
	return run(c);
}

static const char *pick_mkfs_fat(void) {
	if (have_tool("mkfs.fat"))
		return "mkfs.fat";

	if (have_tool("mkfs.vfat"))
		return "mkfs.vfat";

	return CB_NULL;
}

static const char *pick_qemu(void) {
	if (have_tool("qemu-system-i386"))
		return "qemu-system-i386";

	if (have_tool("qemu-system-x86_64"))
		return "qemu-system-x86_64";

	return CB_NULL;
}

static int ensure_file_downloaded(const char *url, const char *dest) {
	if (cb_file_exists(dest))
		return 0;

	cb_log_info("downloading: %s -> %s", url, dest);
	if (have_tool("curl")) {
		const char *args[] = {"-L", "--fail", "-o", dest, url};
		cb_log_verbose("[DL] curl %s %s -o %s %s", "-L", "--fail", dest, url);
		return run_simple("curl", args, 5);
	} else if (have_tool("wget")) {
		const char *args[] = {"-o", dest, url};
		cb_log_verbose("[DL] wget -o %s %s", dest, url);
		return run_simple("wget", args, 3);
	} else {
		cb_log_error("missing curl/wget for download");
		return 2;
	}
}

static int cmd_spark(void) {
	if (!cb_is_dir(L.SPARK_DIR)) {
		cb_log_error("missing spark dir: %s", L.SPARK_DIR);
		return 2;
	}

	if (cb_subrecipe_push(L.SPARK_DIR) != 0) {
		cb_log_error("failed to load spark/Carbidefile.c");
		return 2;
	}
	cb_subrecipe_set_handoff((void *)&L, CB_OWN_PARENT, CB_NULL);

	int rc = cb_subrecipe_run("build", CB_NULL, 0);

	cb_subrecipe_pop();
	return rc;
}

static int plain_floppy_flow(void) {
	/* dd if=/dev/zero of=$(BUILD_DIR)/a.img bs=512 count=2880 */
	{
		char dd_of[512];
		snprintf(dd_of, sizeof dd_of, "of=%s", L.IMG);
		const char *args[] = {"if=/dev/zero", dd_of, "bs=512", "count=2880"};
		if (!have_tool("dd")) {
			cb_log_error("missing dd");
			return 2;
		}
		cb_log_verbose("exec: dd %s %s %s %s", args[0], args[1], args[2], args[3]);
		if (run_simple("dd", args, 4) != 0)
			return 2;
	}

	/* mkfs.fat -F 12 $(BUILD_DIR)/a.img */
	{
		const char *mkfs = pick_mkfs_fat();
		if (!mkfs) {
			cb_log_error("missing mkfs.fat/mkfs.vfat");
			return 2;
		}
		const char *args[] = {"-F", "12", L.IMG};
		if (run_simple(mkfs, args, 3) != 0)
			return 2;
	}

	/* dd if=$(BUILD_DIR)/fboot.bin of=$(BUILD_DIR)/a.img bs=1 count=512 conv=notrunc */
	if (!cb_file_exists(L.FBOOT_BIN)) {
		cb_log_error("missing boot sector (fboot.bin) at %s - run 'spark' first", L.FBOOT_BIN);
		return 2;
	}
	{
		char dd_of[512];
		snprintf(dd_of, sizeof dd_of, "of=%s", L.IMG);
		char dd_if[512];
		snprintf(dd_if, sizeof dd_if, "if=%s", L.FBOOT_BIN);

		const char *args[] = {dd_if, dd_of, "bs=1", "count=512", "conv=notrunc"};
		if (run_simple("dd", args, 5) != 0)
			return 2;
	}

	/* mcopy -i $(BUILD_DIR)/a.img $(SPARK_OUT)/spark.hex ::SPARK.HEX */
	if (!have_tool("mcopy")) {
		cb_log_error("missing mcopy (mtools)");
		return 2;
	}
	if (!cb_file_exists(L.SPARK_HEX)) {
		cb_log_warn("missing %s - skipping copy", L.SPARK_HEX);
	} else {
		cb_cmd *c = cb_cmd_new();
		cb_cmd_push_arg(c, "mcopy");
		cb_cmd_push_arg(c, "-i");
		cb_cmd_push_arg(c, L.IMG);
		cb_cmd_push_arg(c, L.SPARK_HEX);
		cb_cmd_push_arg(c, "::SPARK.HEX");
		if (run(c) != 0)
			return 2;
	}

	cb_log_info("floppy image ready: %s", L.IMG);
	return 0;
}

static int dos_floppy_flow(void) {
	const char *DOS_IMG_URL = "https://www.allbootdisks.com/disk_images/Dos6.22.img";
	const char *dos_img = cb_join(L.BUILD_DIR, "dos622.img");
	const char *dos_boot_hex = cb_join(L.BUILD_DIR, "MSDOS.HEX");

	if (ensure_file_downloaded(DOS_IMG_URL, dos_img) != 0)
		return 2;

	{
		char dd_of[512];
		snprintf(dd_of, sizeof dd_of, "of=%s", L.IMG);
		const char *args[] = {"if=/dev/zero", dd_of, "bs=512", "count=2880"};
		if (!have_tool("dd")) {
			cb_log_error("missing dd");
			return 2;
		}
		if (run_simple("dd", args, 4) != 0)
			return 2;
	}
	{
		const char *mkfs = pick_mkfs_fat();
		if (!mkfs) {
			cb_log_error("missing mkfs.fat/mkfs.vfat");
			return 2;
		}
		const char *args[] = {"-F", "12", L.IMG};
		if (run_simple(mkfs, args, 3) != 0)
			return 2;
	}

	{
		char dd_if[512], dd_of[512];
		snprintf(dd_if, sizeof dd_if, "if=%s", dos_img);
		snprintf(dd_of, sizeof dd_of, "of=%s", dos_boot_hex);
		const char *args[] = {dd_if, dd_of, "bs=512", "count=1"};
		if (run_simple("dd", args, 4) != 0)
			return 2;
	}

	if (!cb_file_exists(L.FBOOT_BIN)) {
		cb_log_error("missing boot sector (fboot.bin) at %s - run 'spark' first", L.FBOOT_BIN);
		return 2;
	}
	{
		char dd_if[512], dd_of[512];
		snprintf(dd_if, sizeof dd_if, "if=%s", L.FBOOT_BIN);
		snprintf(dd_of, sizeof dd_of, "of=%s", L.IMG);
		const char *args[] = {dd_if, dd_of, "bs=1", "count=512", "conv=notrunc"};
		if (run_simple("dd", args, 5) != 0)
			return 2;
	}

	if (!have_tool("mcopy") || !have_tool("mattrib")) {
		cb_log_error("missing mtools (mcopy/mattrib)");
		return 2;
	}
	{
		const char *tmp_io = cb_join(L.BUILD_DIR, "IO.SYS");
		const char *tmp_ms = cb_join(L.BUILD_DIR, "MSDOS.SYS");
		const char *tmp_cc = cb_join(L.BUILD_DIR, "COMMAND.COM");

		remove(tmp_io);
		remove(tmp_ms);
		remove(tmp_cc);

		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, dos_img);
			cb_cmd_push_arg(c, "::IO.SYS");
			cb_cmd_push_arg(c, tmp_io);
			if (run(c) != 0)
				return 2;
		}
		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, dos_img);
			cb_cmd_push_arg(c, "::MSDOS.SYS");
			cb_cmd_push_arg(c, tmp_ms);
			if (run(c) != 0)
				return 2;
		}
		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, dos_img);
			cb_cmd_push_arg(c, "::COMMAND.COM");
			cb_cmd_push_arg(c, tmp_cc);
			if (run(c) != 0)
				return 2;
		}

		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, L.IMG);
			cb_cmd_push_arg(c, tmp_io);
			cb_cmd_push_arg(c, "::IO.SYS");
			if (run(c) != 0)
				return 2;
		}
		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, L.IMG);
			cb_cmd_push_arg(c, tmp_ms);
			cb_cmd_push_arg(c, "::MSDOS.SYS");
			if (run(c) != 0)
				return 2;
		}

		{
			const char *args[] = {"-i", L.IMG, "+s", "+h", "+r", "::IO.SYS"};
			if (run_simple("mattrib", args, 6) != 0)
				return 2;
		}
		{
			const char *args[] = {"-i", L.IMG, "+s", "+h", "+r", "::MSDOS.SYS"};
			if (run_simple("mattrib", args, 6) != 0)
				return 2;
		}

		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, L.IMG);
			cb_cmd_push_arg(c, tmp_cc);
			cb_cmd_push_arg(c, "::COMMAND.COM");
			if (run(c) != 0)
				return 2;
		}
	}

	{
		const char *cfg = cb_join(L.BUILD_DIR, "CONFIG.SYS");
		const char *bat = cb_join(L.BUILD_DIR, "AUTOEXEC.BAT");
		char line[1024];
		snprintf(line, sizeof line, "printf 'FILES=30\r\nBUFFERS=20\r\n' > %s", cfg);
		if (run_shell(line) != 0)
			return 2;
		snprintf(line, sizeof line, "printf '@ECHO OFF\r\nPROMPT $P$G\r\n' > %s", bat);
		if (run_shell(line) != 0)
			return 2;
		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, L.IMG);
			cb_cmd_push_arg(c, cfg);
			cb_cmd_push_arg(c, "::CONFIG.SYS");
			if (run(c) != 0)
				return 2;
		}
		{
			cb_cmd *c = cb_cmd_new();
			cb_cmd_push_arg(c, "mcopy");
			cb_cmd_push_arg(c, "-i");
			cb_cmd_push_arg(c, L.IMG);
			cb_cmd_push_arg(c, bat);
			cb_cmd_push_arg(c, "::AUTOEXEC.BAT");
			if (run(c) != 0)
				return 2;
		}
	}

	if (cb_file_exists(L.SPARK_HEX)) {
		cb_cmd *c = cb_cmd_new();
		cb_cmd_push_arg(c, "mcopy");
		cb_cmd_push_arg(c, "-i");
		cb_cmd_push_arg(c, L.IMG);
		cb_cmd_push_arg(c, L.SPARK_HEX);
		cb_cmd_push_arg(c, "::SPARK.HEX");
		if (run(c) != 0)
			return 2;
	} else {
		cb_log_warn("missing %s - skipping copy", L.SPARK_HEX);
	}
	{
		cb_cmd *c = cb_cmd_new();
		cb_cmd_push_arg(c, "mcopy");
		cb_cmd_push_arg(c, "-i");
		cb_cmd_push_arg(c, L.IMG);
		cb_cmd_push_arg(c, dos_boot_hex);
		cb_cmd_push_arg(c, "::MSDOS.HEX");
		if (run(c) != 0)
			return 2;
	}

	cb_log_info("DOS floppy image ready: %s", L.IMG);
	return 0;
}

static int cmd_floppy(void) {
	if (want_dos())
		return dos_floppy_flow();

	return plain_floppy_flow();
}

static int cmd_run_floppy(void) {
	const char *qemu = pick_qemu();
	if (!qemu) {
		cb_log_error("missing qemu-system-i386/x86_64");
		return 2;
	}
	if (!cb_file_exists(L.IMG)) {
		cb_log_error("missing image: %s (run 'floppy')", L.IMG);
		return 2;
	}

	const char *log = cb_join(L.OUT, "qemu_interrupt.log");
	cb_cmd *c = cb_cmd_new();
	cb_cmd_push_arg(c, qemu);
	char drive_opts[768];
	snprintf(drive_opts, sizeof drive_opts, "file=%s,format=raw,if=floppy", L.IMG);
	cb_log_verbose("exec: %s -drive %s", qemu, drive_opts);
	cb_cmd_push_arg(c, "-drive");
	cb_cmd_push_arg(c, drive_opts);

	cb_cmd_push_arg(c, "-m");
	cb_cmd_push_arg(c, "64M");
	cb_cmd_push_arg(c, "-cpu");
	cb_cmd_push_arg(c, "pentium-v1,mmx=on,fpu=on");
	cb_cmd_push_arg(c, "-machine");
	cb_cmd_push_arg(c, "pc-i440fx-7.2");
	cb_cmd_push_arg(c, "-device");
	cb_cmd_push_arg(c, "cirrus-vga");
	cb_cmd_push_arg(c, "-device");
	cb_cmd_push_arg(c, "ne2k_pci,netdev=net0,addr=0x03");
	cb_cmd_push_arg(c, "-netdev");
	cb_cmd_push_arg(c, "user,id=net0,hostfwd=tcp::2222-:22");
	cb_cmd_push_arg(c, "--no-reboot");
	cb_cmd_push_arg(c, "--no-shutdown");
	cb_cmd_push_arg(c, "-serial");
	cb_cmd_push_arg(c, "stdio");
	cb_cmd_push_arg(c, "-d");
	cb_cmd_push_arg(c, "int,guest_errors");
	cb_cmd_push_arg(c, "-M");
	cb_cmd_push_arg(c, "accel=tcg,smm=off");
	cb_cmd_push_arg(c, "-D");
	cb_cmd_push_arg(c, log);

	return run(c);
}

static int cmd_run_bochs_floppy(void) {
	if (!have_tool("bochs")) {
		cb_log_error("missing bochs");
		return 2;
	}
	if (!cb_file_exists(cb_join(cb_workspace_root(), "bochsrc_floppy.txt"))) {
		cb_log_error("missing bochsrc_floppy.txt in project root");
		return 2;
	}
	const char *args[] = {"-qf", "bochsrc_floppy.txt"};
	return run_simple("bochs", args, 2);
}

static int cmd_clean(void) {
	if (!cb_is_dir(L.BUILD_DIR))
		return 0;

	cb_strlist files;
	cb_strlist_init(&files);
	cb_rglob(L.BUILD_DIR, "", &files);

	cb_cmd *c = cb_cmd_new();
	cb_cmd_push_arg(c, "rm");
	cb_cmd_push_arg(c, "-rf");
	cb_cmd_push_arg(c, cb_join(L.BUILD_DIR, "*"));
	(void)run(c);

	cb_strlist_free(&files);
	return 0;
}

static int cmd_reset(void) {
	int rc = cmd_clean();
	if (rc)
		return rc;

	if (have_tool("clear")) {
		const char *args[] = {};
		run_simple("clear", args, 0);
	}
	rc = cmd_spark();
	if (rc)
		return rc;

	rc = cmd_floppy();
	if (rc)
		return rc;

	return 0;
}

static int cmd_all(void) {
	int rc = cmd_spark();
	if (rc)
		return rc;

	rc = cmd_floppy();
	if (rc)
		return rc;

	return cmd_run_floppy();
}

static int top_default(void) { return cmd_all(); }

void carbide_recipe_main(cb_context *ctx) {
	(void)ctx;
	init_layout();

	cb_register_cmd("all", cmd_all, "build the full suite and run the floppy disk");
	cb_register_cmd("spark", cmd_spark, "build SPARK");
	cb_register_cmd("floppy", cmd_floppy, "create FAT12 image with boot sector & SPARK.HEX");
	cb_register_cmd("run-floppy", cmd_run_floppy, "run the floppy in QEMU");
	cb_register_cmd("run-bochs-floppy", cmd_run_bochs_floppy, "run the floppy in Bochs");
	cb_register_cmd("clean", cmd_clean, "clean build outputs");
	cb_register_cmd("reset", cmd_reset, "clean and rebuild");

	cb_set_default(top_default, "default = all");
}
