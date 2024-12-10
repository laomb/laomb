#ifndef PCI_H
#define PCI_H

#include <stdint.h>

#define PCI_CONFIG_ADDRESS   0xCF8
#define PCI_CONFIG_DATA      0xCFC

#define PCI_VENDOR_ID        0x00
#define PCI_DEVICE_ID        0x02
#define PCI_COMMAND          0x04
#define PCI_STATUS           0x06
#define PCI_CLASS_CODE       0x08
#define PCI_HEADER_TYPE      0x0C
#define PCI_BAR0             0x10
#define PCI_CAPABILITY_LIST  0x34
#define PCI_INTERRUPT_LINE   0x3C

#define PCI_BAR_MEMORY_MASK  0xFFFFFFF0
#define PCI_BAR_IO_MASK      0xFFFFFFFC

typedef struct {
    uint16_t vendor_id;
    uint16_t device_id;
    uint8_t class_code;
    uint8_t subclass;
    uint8_t prog_if;
    uint8_t header_type;
    uint8_t bus;
    uint8_t device;
    uint8_t function;
    uint8_t version;  // 1 = PCI 1.x, 2 = PCI 2.0+
} pci_device_t;

void pci_init(void);

void pci_write_config_address(uint32_t address);
uint32_t pci_read_config_data(void);
void pci_write_config_data(uint32_t value);

uint16_t pci_read_word(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset);
void pci_write_word(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset, uint16_t value);
uint32_t pci_read_dword(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset);
void pci_write_dword(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset, uint32_t value);

pci_device_t* pci_find_device(uint16_t vendor_id, uint16_t device_id);
void pci_enable_device(pci_device_t *dev);
uint32_t pci_read_bar(pci_device_t *dev, uint8_t bar);

uint8_t pci_get_version(uint8_t bus, uint8_t device, uint8_t func);
uint8_t pci_get_header_type(uint8_t bus, uint8_t device, uint8_t func);
uint8_t pci_get_interrupt_line(uint8_t bus, uint8_t device, uint8_t func);
void pci_print_device_info(pci_device_t *dev);

#endif // PCI_H
