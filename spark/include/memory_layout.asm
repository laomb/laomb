label spark_stage1_base at 0x7c00
label spark_stage2_base at 0x500

; MBR bootsector has to relocate partition data and it's code and load the VBR to this address.
label spark_vbr_base:512 at 0x7c00

label root_dir_buffer at 0x7e00
label fat_buffer at 0x9a00

stack_top = 0x4000
stack_segment = 0x7000

heap_base = 0xc000
heap_limit = 0xe800

label vbe_info:512 at 0xe800
label vbe_modeinfo:256 at 0xea00
label edid_buffer:256 at 0xeb00
label bios_dap:16 at 0xec00
label e820_buffer:4096 at 0xf000

loom_bounce_buffer_offset = 0x2000
loom_bounce_buffer_segment = 0x1000
loom_bounce_buffer_flat = (loom_bounce_buffer_segment shl 0x4) + loom_bounce_buffer_offset

virtual at spark_vbr_base
	rb 3

	label bdb_oem:8
		rw 4
	label bdb_bytes_per_sector:word
		rw 1
	label bdb_sectors_per_cluster:byte
		rb 1
	label bdb_reserved_sectors:word
		rw 1
	label bdb_fat_count:byte
		rb 1
	label bdb_dir_entries_count:word
		rw 1
	label bdb_total_sectors:word
		rw 1
	label bdb_media_descriptor:byte
		rb 1
	label bdb_sectors_per_fat:word
		rw 1
	label bdb_sectors_per_track:word
		rw 1
	label bdb_heads:word
		rw 1
	label bdb_hidden_sectors:dword
		rd 1
	label bdb_large_sector_count:dword
		rd 1

	label ebr_drive_number:byte
		rb 1
	label ebr_windows_nt_flags:byte
		rb 1
	label ebr_signature:byte
		rb 1
	label ebr_volume_id:dword
		rd 1
	label ebr_volume_label:11
		rb 11
	label ebr_system_id:8
		rb 8
end virtual
