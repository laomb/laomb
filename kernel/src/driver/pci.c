#include <driver/pci.h>
#include <kprintf>
#include <kheap.h>
#include <io.h>
#include <video/print.h>

pci_device_t* devices = nullptr;
uint32_t device_count = 0;

void pci_write_config_address(uint32_t address) {
    outl(PCI_CONFIG_ADDRESS, address);
}

uint32_t pci_read_config_data(void) {
    return inl(PCI_CONFIG_DATA);
}

uint16_t pci_read_word(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset) {
    uint32_t address = (1 << 31) | (bus << 16) | (device << 11) | (func << 8) | (offset & 0xFC);
    pci_write_config_address(address);
    return (uint16_t)((pci_read_config_data() >> ((offset & 2) * 8)) & 0xFFFF);
}

uint8_t pci_get_version(uint8_t bus, uint8_t device, uint8_t func) {
    uint16_t status = pci_read_word(bus, device, func, PCI_STATUS);
    return (status & (1 << 4)) ? 2 : 1;  // Check Capabilities List bit
}

void pci_init(void) {
    _putchar('\n');
    for (uint16_t bus = 0; bus < 256; ++bus) {
        for (uint8_t device = 0; device < 32; ++device) {
            for (uint8_t func = 0; func < 8; ++func) {
                uint16_t vendor = pci_read_word(bus, device, func, PCI_VENDOR_ID);
                if (vendor == 0xFFFF) continue;

                uint16_t device_id_read = pci_read_word(bus, device, func, PCI_DEVICE_ID);

                devices = (pci_device_t*)krealloc(devices, sizeof(pci_device_t) * (++device_count));

                pci_device_t* dev = &devices[device_count - 1];
                dev->vendor_id = vendor;
                dev->device_id = device_id_read;
                dev->class_code = (pci_read_word(bus, device, func, PCI_CLASS_CODE) >> 8) & 0xFF;
                dev->subclass = pci_read_word(bus, device, func, PCI_CLASS_CODE) & 0xFF;
                dev->header_type = (pci_read_word(bus, device, func, PCI_HEADER_TYPE) >> 8) & 0xFF;
                dev->bus = bus;
                dev->device = device;
                dev->function = func;
                dev->version = pci_get_version(bus, device, func);

                pci_print_device_info(dev);
            }
        }
    }
}

pci_device_t* pci_find_device(uint16_t vendor_id, uint16_t device_id) {
    for (uint32_t i = 0; i < device_count; i++) {
        if (devices[i].vendor_id == vendor_id && devices[i].device_id == device_id) {
            return &devices[i];
        }
    }
    static pci_device_t null_dev = {0};
    return &null_dev;
}

void pci_enable_device(pci_device_t *dev) {
    uint16_t command = pci_read_word(dev->bus, dev->device, dev->function, PCI_COMMAND);
    command |= (1 << 2) | (1 << 1);
    pci_write_word(dev->bus, dev->device, dev->function, PCI_COMMAND, command);
}

void pci_print_device_info(pci_device_t *dev) {
    kprintf("PCI Device Found:\n");
    kprintf("  Vendor ID: 0x%04X, Device ID: 0x%04X\n", dev->vendor_id, dev->device_id);
    kprintf("  Class Code: 0x%02X, Subclass: 0x%02X\n", dev->class_code, dev->subclass);
    kprintf("  Header Type: 0x%02X\n", dev->header_type);
    kprintf("  Version: PCI %d.x\n", dev->version);
    kprintf("  Bus: %d, Device: %d, Function: %d\n", dev->bus, dev->device, dev->function);
    _putchar('\n');
}

void pci_write_word(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset, uint16_t value) {
    uint32_t address = (1 << 31) | (bus << 16) | (device << 11) | (func << 8) | (offset & 0xFC);
    pci_write_config_address(address);
    outw(PCI_CONFIG_DATA, value);
}

uint32_t pci_read_dword(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset) {
    uint32_t address = (1 << 31) | (bus << 16) | (device << 11) | (func << 8) | (offset & 0xFC);
    pci_write_config_address(address);
    return inl(PCI_CONFIG_DATA);
}

void pci_write_dword(uint8_t bus, uint8_t device, uint8_t func, uint8_t offset, uint32_t value) {
    uint32_t address = (1 << 31) | (bus << 16) | (device << 11) | (func << 8) | (offset & 0xFC);
    pci_write_config_address(address);
    outl(PCI_CONFIG_DATA, value);
}
