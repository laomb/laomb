
label stage2_base at 0x500

label root_dir_buffer at 0x7e00
label fat_buffer at 0x9A00

label heap_base at 0xC000
label heap_limit at 0xE800
heap_size = heap_limit - heap_base

label vbe_info:512 at 0xE800
label vbe_modeinfo:256 at 0xEA00
label edid_buffer:256 at 0xEB00

label e820_buffer:4096 at 0xF000

kernel_bounce_buffer_offset = 0x2000
kernel_bounce_buffer_segment = 0x1000

stack_top = 0x4000
stack_segment = 0x7000

virtual at 0x7c00
	label bootsector_bdb_jump:3
	label bootsector_bdb_oem:8
	label bootsector_bdb_bytes_per_sector:word
	label bootsector_bdb_sectors_per_cluster:byte
	label bootsector_bdb_reserved_sectors:word
	label bootsector_bdb_fat_count:byte
	label bootsector_bdb_dir_entries_count:word
	label bootsector_bdb_total_sectors:word
	label bootsector_bdb_media_descriptor:byte
	label bootsector_bdb_sectors_per_fat:word
	label bootsector_bdb_sectors_per_track:word
	label bootsector_bdb_heads:word
	label bootsector_bdb_hidden_sectors:dword
	label bootsector_bdb_large_sector_count:dword
	
	label bootsector_ebr_drive_number:byte
	label bootsector_ebr_windows_nt_flags:byte
	label bootsector_ebr_signature:byte
	label bootsector_ebr_volume_id:4
	label bootsector_ebr_volume_label:11
	label bootsector_ebr_system_id:8
end virtual
