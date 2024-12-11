#pragma once
#include <stdint.h>

#define MBR_SIGNATURE 0xAA55

struct __attribute__((packed)) mbr_partition_entry {
    uint8_t boot_indicator;
    uint8_t start_head;
    uint8_t start_sector;
    uint8_t start_cylinder;
    uint8_t partition_type;
    uint8_t end_head;
    uint8_t end_sector;
    uint8_t end_cylinder;
    uint32_t start_sector_lba;
    uint32_t num_sectors;
};

struct master_boot_rectord_t {
    uint8_t bootcode[446];
    uint16_t partition_table_offsets[4];
    uint16_t mbr_magic;
};

struct mbr_relevant_information {
    uint32_t lba_offset;
    uint32_t lba_size;
};

extern struct mbr_relevant_information master_boot_records[4];
extern uint8_t boot_mbr_index;

void mbr_init();
bool mbr_read_sectors(struct mbr_relevant_information* disk, uint32_t lba, uint8_t count, uint8_t* buffer);
bool mbr_write_sectors(struct mbr_relevant_information* disk, uint32_t lba, uint8_t count, uint8_t* buffer);