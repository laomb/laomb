#include "../layout.h"
#include <Carbide/Recipe.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

static void set_env(const char *k, const char *v) {
	if (v && *v)
		setenv(k, v, 1);
	else
		unsetenv(k);
}

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

static const char *pick_fasmg(void) {
	if (have_tool("fasmg"))
		return "fasmg";

	return CB_NULL;
}

static const char *build_mode_asm(void) {
	const layout_t *L = (const layout_t *)cb_shared_current();
	if (L->BUILD_MODE && strcasecmp(L->BUILD_MODE, "Release") == 0)
		return "build.mode = build.mode.Release";

	return "build.mode = build.mode.Debug";
}

static void setup_fasmg_env(void) {
	const layout_t *L = (const layout_t *)cb_shared_current();
	const char *global_inc_root = cb_join(L->ROOT, "include");
	const char *spark_inc_root = cb_join(L->SPARK_DIR, "include");

	const char *old = getenv("INCLUDE");

	char merged[8192];
	if (old && *old) {
		snprintf(merged, sizeof(merged), "%s;%s;%s", global_inc_root, spark_inc_root, old);
	} else {
		snprintf(merged, sizeof(merged), "%s;%s", global_inc_root, spark_inc_root);
	}
	set_env("INCLUDE", merged);
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

static int build_one(const layout_t *L, const char *src_asm, const char *out_path) {
	const char *fasmg = pick_fasmg();
	if (!fasmg) {
		cb_log_error("missing fasmg");
		return 2;
	}

	cb_mkdir_p(L->OUT);

	cb_cmd *c = cb_cmd_new();
	cb_cmd_push_arg(c, fasmg);

	char ins[8192];
	snprintf(ins, sizeof(ins), "include \'%s\'", cb_join(L->ROOT, "include/core.inc"));

	cb_cmd_push_arg(c, "-i");
	cb_cmd_push_arg(c, ins);
	cb_cmd_push_arg(c, "-i");
	cb_cmd_push_arg(c, build_mode_asm());
	if (L->BUILD_MODE && strcasecmp(L->BUILD_MODE, "Trace") == 0) {
		cb_cmd_push_arg(c, "-i");
		cb_cmd_push_arg(c, "build.mode.Trace = 1");
	}

	cb_cmd_push_arg(c, "-n");

	cb_cmd_push_arg(c, src_asm);
	cb_cmd_push_arg(c, out_path);

	return run(c);
}

static int cmd_default(void) {
	const layout_t *L = (const layout_t *)cb_shared_current();
	if (!L) {
		cb_log_error("no shared layout handed to spark");
		return 2;
	}
	setup_fasmg_env();

	{
		const char *src = cb_join(L->SPARK_DIR, "fboot.asm");
		if (!cb_file_exists(src)) {
			cb_log_error("missing %s", src);
			return 2;
		}
		int rc = build_one(L, src, L->FBOOT_BIN);
		if (rc)
			return rc;
	}

	{
		const char *src = cb_join(L->SPARK_DIR, "spark.asm");
		if (!cb_file_exists(src)) {
			cb_log_warn("%s not found - skipping SPARK.HEX", src);
		} else {
			int rc = build_one(L, src, L->SPARK_HEX);
			if (rc)
				return rc;
		}
	}

	cb_log_info("spark build complete: %s, %s", L->FBOOT_BIN, L->SPARK_HEX);
	return 0;
}

CB_API void carbide_recipe_main(cb_context *ctx) {
	(void)ctx;
	cb_require_min_version(2, 1, 2);
	cb_register_cmd("build", cmd_default, "assemble fboot.bin and spark.hex");
	cb_set_default(cmd_default, "default = build");
}
