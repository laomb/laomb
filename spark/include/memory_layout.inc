
label stage2_base at 0x500

label root_dir_buffer at 0x7e00
label fat_buffer at 0x9a00

label heap_base at 0xc000
label heap_limit at 0xe800
heap_size = heap_limit - heap_base

label vbe_info:512 at 0xe800
label vbe_modeinfo:256 at 0xea00
label edid_buffer:256 at 0xeB00
label bios_dap:16 at 0xec00
label sector_buf:512 at 0xed00

label e820_buffer:4096 at 0xf000

kernel_bounce_buffer_offset = 0x2000
kernel_bounce_buffer_segment = 0x1000

stack_top = 0x4000
stack_segment = 0x7000

virtual at 0x7C00
	bootsector:
		.bdb_jump rb 3
		.bdb_oem rb 8
		.bdb_bytes_per_sector rw 1
		.bdb_sectors_per_cluster rb 1
		.bdb_reserved_sectors rw 1
		.bdb_fat_count rb 1
		.bdb_dir_entries_count rw 1
		.bdb_total_sectors rw 1
		.bdb_media_descriptor rb 1
		.bdb_sectors_per_fat rw 1
		.bdb_sectors_per_track rw 1
		.bdb_heads rw 1
		.bdb_hidden_sectors rd 1
		.bdb_large_sector_count rd 1

		.ebr_drive_number rb 1
		.ebr_windows_nt_flags rb 1
		.ebr_signature rb 1
		.ebr_volume_id rb 4
		.ebr_volume_label rb 11
		.ebr_system_id rb 8
end virtual
