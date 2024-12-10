#pragma once
#include <proc/vfs.h>
#include <proc/sched.h>
#include <kheap.h>

struct ramfs_node {
    struct vnode base;           // Embedded vnode structure
    struct ramfs_node* parent;   // Parent node
    struct ramfs_node* children; // Child nodes (if directory)
    struct ramfs_node* next;     // Sibling nodes
    char* name;                  // Name of the file or directory
    int size;                    // Size of the file
    void* data;                  // File data (for files)
};

struct ramfs_fs {
    struct vfs base;             // Base VFS structure
    struct ramfs_node* root;     // Root node
};

int ramfs_init();                // Initialises a new ramfs, returns index of the vfs in the root_vfs's linked list, 0 if root