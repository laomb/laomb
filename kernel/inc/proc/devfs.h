#pragma once
#include <proc/vfs.h>
#include <proc/sched.h>
#include <kheap.h>

struct devfs_entry {
    struct vnode base;
    char name[NAME_MAX + 1];
    struct devfs_entry* next;  // Next entry in list
};

struct devfs {
    struct vfs vfs;            // VFS structure
    struct devfs_entry* root;  // Linked list of devices
};

int devfs_init();
int devfs_register_device(const char* name, enum vtype type, struct vnode_ops* ops);
int devfs_unregister_device(const char* name);