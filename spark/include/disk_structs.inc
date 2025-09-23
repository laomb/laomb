
struc drive_geometry_t {
    .cylinder_count dw 0
    .head_count db 0
    .sectors_per_track db 0
    .disk_drive_number db 0
    .edd_size dw 0
    .edd_flags dw 0
    .edd_physical_cylinders dd 0
    .edd_physical_heads dd 0
    .edd_phyisical_spt dd 0
    .edd_total_secs dq 0
    .edd_bps dw 0
}

struc edd_packet_t {
    .size db 0x10
    .reserved db 0
    .sector_count dw 0
    .buffer_offset dw 0
    .buffer_segment dw 0
    .lba dq 0
}