FAT_ATTRIBUTE_READ_ONLY = 0x01
FAT_ATTRIBUTE_HIDDEN = 0x02
FAT_ATTRIBUTE_SYSTEM = 0x04
FAT_ATTRIBUTE_VOLUME_ID = 0x08
FAT_ATTRIBUTE_DIRECTORY = 0x10
FAT_ATTRIBUTE_ARCHIVE = 0x20
FAT_ATTRIBUTE_LFN_MASK = 0x0F 

virtual at 0x7C00
	rb 3
	bdb_oem rb 8

	bdb_bytes_per_sector rw 1
	bdb_sectors_per_cluster rb 1
	bdb_reserved_sectors rw 1
	bdb_fat_count rb 1
	bdb_dir_entries_count rw 1
	bdb_total_sectors rw 1
	bdb_media_descriptor rb 1
	bdb_sectors_per_fat rw 1
	bdb_sectors_per_track rw 1
	bdb_heads rw 1
	bdb_hidden_sectors rd 1
	bdb_large_sector_count rd 1

	ebr_drive_number rb 1
	ebr_signature rb 1
	ebr_volume_id rd 1
	ebr_volume_label rb 11
	ebr_system_id rb 8
end virtual

FILE_POS_OFF = 0
FILE_SIZE_OFF = 4
FILE_FIRST_CLUSTER_OFF = 8
FILE_CURRENT_CLUSTER_OFF = 12
FILE_SECTOR_IN_CLUSTER_OFF = 16
FILE_DIR_OFF = 20
FILE_PAD_OFF = 21
FILE_BUFFER_OFF = 24

FILE_STRUCT_SIZE = 536

FAT_NAME_OFF = 0
FAT_ATTRIBUTES_OFF = 11
FAT_RESERVED_OFF = 12
FAT_CREATED_TENTHS_OFF = 13
FAT_CREATED_TIME_OFF = 14
FAT_CREATED_DATE_OFF = 16
FAT_ACCESSED_DATE_OFF = 18
FAT_FIRST_CLUSTER_HI_OFF = 20
FAT_MODIFIED_TIME_OFF = 22
FAT_MODIFIED_DATE_OFF = 24
FAT_FIRST_CLUSTER_LO_OFF = 26
FAT_SIZE_OFF = 28

FAT_DIR_ENTRY_SIZE = 32
