#pragma once

#include <stdint.h>
#include <stdbool.h>

void ata_init();
void read_sectors_ATA_PIO(uint32_t lba, uint8_t sector_count, uint8_t* buffer);
void write_sectors_ATA_PIO(uint32_t lba, uint8_t sector_count, uint8_t *buffer);