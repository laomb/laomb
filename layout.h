#ifndef LAYOUT_H
#define LAYOUT_H

typedef struct {
	const char *ROOT;		/* workspace root (abs) */
	const char *OUT;		/* .carbide/out */
	const char *BUILD_DIR;	/* $(OUT)/build */
	const char *BUILD_MODE; /* Debug or Release */
	const char *SPARK_DIR;	/* $(ROOT)/spark */
	const char *LOOM_DIR;	/* $(ROOT)/loom */
	const char *IMG;		/* $(BUILD_DIR)/a.img */
	const char *FBOOT_BIN;	/* $(BUILD_DIR)/fboot.bin */
	const char *SPARK_HEX;	/* $(BUILD_DIR)/spark.hex */
	const char *LOOM_BIN;	/* $(BUILD_DIR)/loom.bin */
} layout_t;

#endif /* LAYOUT_H */
