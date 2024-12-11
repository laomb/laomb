#include "sys/pic.h"
#include <driver/ata.h>
#include <sys/idt.h>
#include <sys/pic.h>
#include <io.h>
#include <kprintf>

#define STATUS_BSY 0x80
#define STATUS_RDY 0x40
#define STATUS_DRQ 0x08
#define STATUS_DF 0x20
#define STATUS_ERR 0x01

static void wait_busy()
{
	while (inb(0x1F7) & STATUS_BSY)
	;
}
static void wait_datareq()
{
	while (!(inb(0x1F7) & STATUS_RDY))
	;
}

#define ATA_MASTER_BASE 0x1F0
#define ATA_SLAVE_BASE 0x170

#define ATA_MASTER 0xE0
#define ATA_SLAVE 0xF0

#define ATA_REG_DATA 0x00
#define ATA_REG_ERROR 0x01
#define ATA_REG_FEATURES 0x01
#define ATA_REG_SECCOUNT0 0x02
#define ATA_REG_LBA0 0x03
#define ATA_REG_LBA1 0x04
#define ATA_REG_LBA2 0x05
#define ATA_REG_HDDEVSEL 0x06
#define ATA_REG_COMMAND 0x07
#define ATA_REG_STATUS 0x07
#define ATA_REG_SECCOUNT1 0x08
#define ATA_REG_LBA3 0x09
#define ATA_REG_LBA4 0x0A
#define ATA_REG_LBA5 0x0B
#define ATA_REG_CONTROL 0x0C
#define ATA_REG_ALTSTATUS 0x0C
#define ATA_REG_DEVADDRESS 0x0D


void read_sectors_ATA_PIO(uint32_t lba, uint8_t sector_count, uint8_t* buffer) {
	wait_busy();
	outb(ATA_MASTER_BASE + ATA_REG_HDDEVSEL, ATA_MASTER | ((lba >> 24) & 0xF));
	outb(ATA_MASTER_BASE + ATA_REG_SECCOUNT0, sector_count);
	outb(ATA_MASTER_BASE + ATA_REG_LBA0, (uint8_t)lba);
	outb(ATA_MASTER_BASE + ATA_REG_LBA1, (uint8_t)(lba >> 8));
	outb(ATA_MASTER_BASE + ATA_REG_LBA2, (uint8_t)(lba >> 16));
	outb(ATA_MASTER_BASE + ATA_REG_COMMAND, 0x20);

	uint16_t *target = (uint16_t *)buffer;

	for (int j = 0; j < sector_count; j++) {
		wait_busy();
		wait_datareq();
		for (int i = 0; i < 256; i++)
			target[i] = inw(0x1F0);
		target += 256;
	}
}

void write_sectors_ATA_PIO(uint32_t lba, uint8_t sector_count, uint8_t *buffer) {
	wait_busy();
	outb(0x1F6, 0xE0 | ((lba >> 24) & 0xF));
	outb(0x1F2, sector_count);
	outb(0x1F3, (uint8_t)lba);
	outb(0x1F4, (uint8_t)(lba >> 8));
	outb(0x1F5, (uint8_t)(lba >> 16));
	outb(0x1F7, 0x30);

	uint32_t *bytes = (uint32_t *)buffer;

	for (int j = 0; j < sector_count; j++) {
		wait_busy();
		wait_datareq();
		for (int i = 0; i < 256; i++) {
			outl(0x1F0, bytes[i]);
		}
		bytes += 256;
	}
}

void ata_interrupt_handler(registers_t*)
{
    kprintf("ATA interrupt\n");
    pic_sendeoi(14);
}

void ata_init()
{
	idt_register_handler(0x20 + 14, ata_interrupt_handler);
}