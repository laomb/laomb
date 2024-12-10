#include "proc/vfs.h"
#include <string.h>
#include <kheap.h>
#include <proc/devfs.h>

static struct devfs devfs_root;

static int devfs_mount(struct vfs* vfs, const char* path, void*) {
    vfs->block_size = 512;
    vfs->flags = 0;
    struct vnode* n = vfs_traverse_path(path);
    if (!n) {
        return -1;
    }
    vfs->covered_node = n;
    n->mount_point = vfs;
    devfs_root.vfs = *vfs;
    return 0;
}

static int devfs_unmount(struct vfs*) {
    struct devfs_entry* entry = devfs_root.root;
    while (entry) {
        struct devfs_entry* next = entry->next;
        kfree(entry);
        entry = next;
    }
    devfs_root.root = nullptr;
    return 0;
}

static int devfs_get_root(struct vfs*, struct vnode** root_node) {
    *root_node = (struct vnode*)devfs_root.root;
    return *root_node ? 0 : -1;
}

static int devfs_get_statfs(struct vfs* vfs, struct statfs* stat) {
    stat->fs_type = 0xDEFF;
    stat->block_size = 512;
    stat->total_blocks = 0;
    stat->free_blocks = 0;
    stat->avail_blocks = 0;
    stat->total_files = 0;
    stat->free_files = 0;
    stat->fs_id = (int64_t)vfs;
    return 0;
}

static int devfs_sync(struct vfs*) {
    return 0;  // Nothing to sync for `devfs`
}

static int devfs_get_fid(struct vfs* vfs, struct vnode* vnode, struct fid** file_id) {
    *file_id = kmalloc(sizeof(struct fid));
    if (!*file_id)
        return -1;
    (*file_id)->fs_id = (int32_t)vfs;
    (*file_id)->node_id = (int32_t)vnode;
    (*file_id)->gen = 0;
    return 0;
}

static int devfs_get_vnode(struct vfs*, struct vnode** vnode_out, struct fid* file_id) {
    *vnode_out = (struct vnode*)file_id->node_id;
    return *vnode_out ? 0 : -1;
}

struct vfs_ops devfs_ops = {
    .mount = devfs_mount,
    .unmount = devfs_unmount,
    .get_root = devfs_get_root,
    .get_statfs = devfs_get_statfs,
    .sync = devfs_sync,
    .get_fid = devfs_get_fid,
    .get_vnode = devfs_get_vnode,
};

int devfs_init() {
    int index = 0;
    struct vfs* curr = root_vfs;

    while (curr && curr->next) {
        curr = curr->next;
        index++;
    }

    devfs_root.root = nullptr;
    devfs_root.vfs.ops = &devfs_ops;
    curr->next = (struct vfs*)&devfs_root;
    return index;
}

int devfs_register_device(const char* name, enum vtype type, struct vnode_ops* ops) {
    struct devfs_entry* entry = kmalloc(sizeof(struct devfs_entry));
    if (!entry)
        return -1;

    strncpy(entry->name, name, NAME_MAX);
    entry->base.type = type;
    entry->base.ops = ops;
    entry->base.mount_point = nullptr;
    entry->base.ref_count = 1;

    entry->next = devfs_root.root;
    devfs_root.root = entry;
    return 0;
}

int devfs_unregister_device(const char* name) {
    struct devfs_entry** entry_ptr = &devfs_root.root;
    while (*entry_ptr) {
        if (strcmp((*entry_ptr)->name, name) == 0) {
            struct devfs_entry* to_free = *entry_ptr;
            *entry_ptr = (*entry_ptr)->next;
            kfree(to_free);
            return 0;
        }
        entry_ptr = &(*entry_ptr)->next;
    }
    return -1;  // Device not found
}

