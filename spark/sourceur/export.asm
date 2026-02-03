
spark_export_table:
	dd str_mem_map_sym
	dd final_memory_map
	dd 4098

	dd str_flat_seg_sym
	dd flat_segment_val
	dd 2

	dd 0

str_mem_map_sym: db 'boot$memory_map', 0
final_memory_map:
final_memory_map_entry_count:
	rw 1
	rb 4096

str_flat_seg_sym: db 'boot$flat_segment', 0
flat_segment_val:
	dw 0
