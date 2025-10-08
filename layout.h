#ifndef LAYOUT_H
#define LAYOUT_H

typedef struct {
	const char *ROOT;	   /* workspace root (abs) */
	const char *OUT;	   /* .carbide/out */
	const char *BUILD_DIR; /* $(OUT)/build */
	const char *SPARK_DIR; /* $(ROOT)/spark */
	const char *IMG;	   /* $(BUILD_DIR)/a.img */
	const char *FBOOT_BIN; /* $(SPARK_OUT)/fboot.bin */
	const char *SPARK_HEX; /* $(SPARK_OUT)/spark.hex */
} layout_t;

#endif /* LAYOUT_H */
