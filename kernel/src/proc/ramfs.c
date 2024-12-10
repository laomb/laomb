#include <proc/vfs.h>
#include <proc/ramfs.h>
#include <kprintf>
#include <spinlock.h>
#include <string.h>

static int ramfs_open(struct vnode**, int, void*);
static int ramfs_close(struct vnode*, int, void*);
static ssize_t ramfs_read_write(struct vnode* vnode, void* buffer, int op, int, void*);
static int ramfs_ioctl(struct vnode*,  int, void*, int, void*);
static int ramfs_select(struct vnode*, int, void*);
static int ramfs_get_attr(struct vnode* vnode, struct vattr* attr, void*);
static int ramfs_set_attr(struct vnode* vnode, struct vattr* attr, void*);
static int ramfs_check_access(struct vnode*, int, void*);
static int ramfs_lookup(struct vnode* node, const char* name, struct vnode** result_node, void*);
static int ramfs_create(struct vnode* vnode, const char* name, struct vattr* attr, int, int mode, struct vnode** result_node, void*);
static int ramfs_remove(struct vnode* vnode, const char* name, void*);
static int ramfs_make_dir(struct vnode* node, const char* name, struct vattr* attr, struct vnode** result_node, void* context);

static int ramfs_link(struct vnode* source_node, struct vnode* target_dir, const char* target_name, void*) {
    struct ramfs_node* dir = (struct ramfs_node*)target_dir;
    struct ramfs_node* src = (struct ramfs_node*)source_node;
    
    struct ramfs_node* new_node = kmalloc(sizeof(struct ramfs_node));
    if (!new_node) return -1;

    memcpy(new_node, src, sizeof(struct ramfs_node));
    new_node->name = strdup(target_name);
    new_node->parent = dir;
    new_node->next = dir->children;
    dir->children = new_node;

    return 0;
}

static int ramfs_rename(struct vnode* node, const char* old_name, struct vnode* target_dir, const char* new_name, void*) {
    struct ramfs_node* dir = (struct ramfs_node*)node;
    struct ramfs_node* target = (struct ramfs_node*)target_dir;
    struct ramfs_node* child = dir->children;
    
    while (child) {
        if (strcmp(child->name, old_name) == 0) {
            kfree(child->name);
            child->name = strdup(new_name);
            child->parent = target;
            return 0;
        }
        child = child->next;
    }
    return -1;
}

static int ramfs_remove_dir(struct vnode* node, const char* name, void*) {
    struct ramfs_node* parent = (struct ramfs_node*)node;
    struct ramfs_node* child = parent->children, *prev = NULL;

    while (child) {
        if (strcmp(child->name, name) == 0 && child->children == NULL) {
            if (prev) prev->next = child->next;
            else parent->children = child->next;
            
            kfree(child->name);
            kfree(child);
            return 0;
        }
        prev = child;
        child = child->next;
    }
    return -1;
}

static int ramfs_read_dir(struct vnode* node, void* buffer, void*) {
    struct ramfs_node* dir = (struct ramfs_node*)node;
    struct ramfs_node* child = dir->children;
    struct dirent* buf = (struct dirent*)buffer;

    while (child) {
        buf->d_ino = (uintptr_t)child;
        strncpy(buf->d_name, child->name, sizeof(buf->d_name));
        buf++;
        child = child->next;
    }
    return 0;
}

static int ramfs_make_symlink(struct vnode* node, const char* link_name, struct vattr*, const char* target_name, void*) {
    struct ramfs_node* parent = (struct ramfs_node*)node;
    struct ramfs_node* new_node = kmalloc(sizeof(struct ramfs_node));
    if (!new_node) return -1;

    new_node->name = strdup(link_name);
    new_node->data = strdup(target_name);
    new_node->size = strlen(target_name);
    new_node->base.type = VLNK;
    new_node->parent = parent;
    new_node->next = parent->children;
    parent->children = new_node;

    return 0;
}

static int ramfs_read_symlink(struct vnode* node, void* buffer, void*) {
    struct ramfs_node* link = (struct ramfs_node*)node;

    if (!link->data) return -1;

    strncpy((char*)buffer, link->data, link->size);
    return link->size;
}

static int ramfs_fsync(struct vnode*, void*) {
    return 0;
}

static int ramfs_mark_inactive(struct vnode*, void*) {
    return 0;
}

static int ramfs_block_map(struct vnode*, int, struct vnode**, int*) {
    return -1;
}

static int ramfs_strategy(void*) {
    return -1;
}

static int ramfs_read_block(struct vnode* node, int block_num, void** buffer_out) {
    struct ramfs_node* ram_node = (struct ramfs_node*)node;
    if (block_num != 0 || !ram_node->data) return -1;
    
    *buffer_out = ram_node->data;
    return 0;
}

static int ramfs_release_block(struct vnode*, void*) {
    return 0;
}

static struct vnode_ops ramfs_vnode_ops = {
    .open = ramfs_open,
    .close = ramfs_close,
    .read_write = ramfs_read_write,
    .ioctl = ramfs_ioctl,
    .select = ramfs_select,
    .get_attr = ramfs_get_attr,
    .set_attr = ramfs_set_attr,
    .check_access = ramfs_check_access,
    .lookup = ramfs_lookup,
    .create = ramfs_create,
    .remove = ramfs_remove,
    .link = ramfs_link,
    .rename = ramfs_rename,
    .make_dir = ramfs_make_dir,
    .remove_dir = ramfs_remove_dir,
    .read_dir = ramfs_read_dir,
    .make_symlink = ramfs_make_symlink,
    .read_symlink = ramfs_read_symlink,
    .fsync = ramfs_fsync,
    .mark_inactive = ramfs_mark_inactive,
    .block_map = ramfs_block_map,
    .strategy = ramfs_strategy,
    .read_block = ramfs_read_block,
    .release_block = ramfs_release_block,
};

static int ramfs_mount(struct vfs* vfs, const char*, void*);
static int ramfs_unmount(struct vfs* vfs);
static int ramfs_get_root(struct vfs* vfs, struct vnode** root_node);
static int ramfs_get_statfs(struct vfs* vfs, struct statfs* stat);
static int ramfs_sync(struct vfs* vfs);

static struct vfs_ops ramfs_vfs_ops = {
    .mount = ramfs_mount,
    .unmount = ramfs_unmount,
    .get_root = ramfs_get_root,
    .get_statfs = ramfs_get_statfs,
    .sync = ramfs_sync,
};

static int ramfs_open(struct vnode**, int, void*) {
    return 0;
}

static int ramfs_close(struct vnode*, int, void*) {
    return 0;
}

static int ramfs_make_dir(struct vnode* node, const char* name, struct vattr*, struct vnode** result_node, void*) {
    struct ramfs_node* parent = (struct ramfs_node*)node;
    
    struct ramfs_node* new_node = kmalloc(sizeof(struct ramfs_node));
    if (!new_node) return -1;

    new_node->name = strdup(name);
    new_node->parent = parent;
    new_node->children = NULL;
    new_node->size = 0;
    new_node->data = NULL;
    new_node->base.type = VDIR;
    new_node->base.ops = &ramfs_vnode_ops;

    new_node->next = parent->children;
    parent->children = new_node;

    *result_node = &new_node->base;
    return 0;
}

static ssize_t ramfs_read_write(struct vnode* vnode, void* buffer, int op, int size, void*) {
    struct ramfs_node* ram_node = (struct ramfs_node*)vnode;

    if (ram_node->base.type != VREG) {
        return -1;
    }

    if (op == 0) {
        size_t read_size = (size_t)(size < ram_node->size ? size : ram_node->size);
        memcpy(buffer, ram_node->data, read_size);
        return read_size;
    } else {
        ram_node->data = krealloc(ram_node->data, size);
        if (!ram_node->data) {
            return -1;
        }
        memcpy(ram_node->data, buffer, size);
        ram_node->size = size;
        return size;
    }
}

static int ramfs_ioctl(struct vnode*,  int, void*, int, void*) {
    return -1;
}

static int ramfs_select(struct vnode*, int, void*) {
    return -1;
}

static int ramfs_get_attr(struct vnode* vnode, struct vattr* attr, void*) {
    struct ramfs_node* ram_node = (struct ramfs_node*)vnode;
    *attr = (struct vattr){
        .type = ram_node->base.type,
        .mode = ram_node->base.flags,
        .size = ram_node->size,
    };
    return 0;
}

static int ramfs_set_attr(struct vnode* vnode, struct vattr* attr, void*) {
    struct ramfs_node* ram_node = (struct ramfs_node*)vnode;
    ram_node->size = attr->size;
    ram_node->base.flags = attr->mode;
    return 0;
}

static int ramfs_check_access(struct vnode*, int, void*) {
    return 0;
}

static int ramfs_lookup(struct vnode* node, const char* name, struct vnode** result_node, void*) {
    struct ramfs_node* ram_node = (struct ramfs_node*)node;

    if (strcmp(name, ".") == 0) {
        *result_node = &ram_node->base;
        return 0;
    }
    if (strcmp(name, "..") == 0) {
        if (ram_node->parent) {
            *result_node = &ram_node->parent->base;
            return 0;
        } else {
            return -1;
        }
    }

    struct ramfs_node* child = ram_node->children;
    while (child) {
        if (strcmp(child->name, name) == 0) {
            *result_node = &child->base;
            return 0;
        }
        child = child->next;
    }
    return -1;
}

static int ramfs_create(struct vnode* vnode, const char* name, struct vattr* attr, int, int mode, struct vnode** result_node, void*) {
    struct ramfs_node* parent = (struct ramfs_node*)vnode;

    if (!name || !attr) {
        return -1;
    }

    struct ramfs_node* new_node = kmalloc(sizeof(struct ramfs_node));
    if (!new_node) {
        return -1;
    }
    memset(new_node, 0, sizeof(struct ramfs_node));

    new_node->name = strdup(name);
    if (!new_node->name) {
        kfree(new_node);
        return -1;
    }

    new_node->base.type = attr->type;
    new_node->base.exclusive_lock_count = 0;
    new_node->base.shared_lock_count = 0;
    new_node->base.ref_count = 0;
    new_node->base.flags = mode;
    new_node->base.mount_point = nullptr;
    new_node->base.vfs = vnode->vfs;
    new_node->base.socket_data = nullptr;
    new_node->base.stream_data = nullptr;
    new_node->base.ops = &ramfs_vnode_ops;
    new_node->parent = parent;
    new_node->children = nullptr;
    new_node->size = 0;
    new_node->data = nullptr;

    new_node->next = parent->children;
    parent->children = new_node;

    *result_node = &new_node->base;
    return 0;
}

static int ramfs_remove(struct vnode* vnode, const char* name, void*) {
    struct ramfs_node* parent = (struct ramfs_node*)vnode;
    struct ramfs_node* child = parent->children;
    struct ramfs_node* prev = nullptr;

    while (child) {
        if (strcmp(child->name, name) == 0) {
            if (prev) {
                prev->next = child->next;
            } else {
                parent->children = child->next;
            }
            kfree(child->name);
            kfree(child->data);
            kfree(child);
            return 0;
        }
        prev = child;
        child = child->next;
    }
    return -1;
}

static int ramfs_mount(struct vfs* vfs, const char* path, void*) {
    struct ramfs_fs* root = (struct ramfs_fs*)vfs; // If this is not the case, most likely a #PF because something went to shit

    struct vnode* covered_node = vfs_traverse_path(path);
    if (!covered_node) {
        return -1;
    }
    vfs->covered_node = covered_node;
    kfree(root->root->name);
    root->root->name = strdup(path);
    
    return 0;
}

static void ramfs_free_node(struct ramfs_node* node) {
    if (!node) {
        return;
    }

    struct ramfs_node* child = node->children;
    while (child) {
        struct ramfs_node* next_child = child->next;
        ramfs_free_node(child);
        child = next_child;
    }

    if (node->name) {
        kfree(node->name);
    }
    if (node->data) {
        kfree(node->data);
    }
    kfree(node);
}


static int ramfs_unmount(struct vfs* vfs) {
    struct ramfs_fs* ramfs = (struct ramfs_fs*)vfs;

    if (ramfs && ramfs->root) {
        ramfs_free_node(ramfs->root);
        kfree(ramfs);
    }

    vfs->covered_node->vfs = nullptr;
    vfs->covered_node = nullptr;
    return 0;
}


static int ramfs_get_root(struct vfs* vfs, struct vnode** root_node) {
    if (!vfs || !root_node) {
        return -1;
    }

    struct ramfs_fs* ramfs = (struct ramfs_fs*)vfs;
    if (!ramfs || !ramfs->root) {
        return -1;  // No root node ???
    }

    *root_node = &ramfs->root->base;
    return 0;
}

static int ramfs_get_statfs(struct vfs*, struct statfs* stat) {
    memset(stat, 0, sizeof(struct statfs));
    stat->fs_type = 0x5241;  // 'RA' (RAMFS)
    stat->block_size = 4096;
    return 0;
}

static int ramfs_sync(struct vfs*) {
    return 0;
}

int ramfs_init() {
    int index = 0;
    struct vfs* curr = root_vfs;

    while (curr && curr->next) {
        curr = curr->next;
        index++;
    }

    struct ramfs_fs* ramfs = kmalloc(sizeof(struct ramfs_fs));
    if (!ramfs) {
        return -1;
    }
    memset(ramfs, 0, sizeof(struct ramfs_fs));

    ramfs->base.block_size = 4096;
    ramfs->base.covered_node = NULL;
    ramfs->base.flags = 0;
    ramfs->base.next = NULL;
    ramfs->base.ops = &ramfs_vfs_ops;

    struct ramfs_node* root = kmalloc(sizeof(struct ramfs_node));
    if (!root) {
        kfree(ramfs);
        return -1;
    }
    memset(root, 0, sizeof(struct ramfs_node));

    root->base.type = VDIR;
    root->base.exclusive_lock_count = 0;
    root->base.shared_lock_count = 0;
    root->base.ref_count = 0;
    root->base.flags = 0;
    root->base.mount_point = NULL;
    root->base.vfs = &ramfs->base;
    root->base.socket_data = NULL;
    root->base.stream_data = NULL;
    root->base.ops = &ramfs_vnode_ops;
    root->parent = NULL;
    root->children = NULL;
    root->name = strdup("/");
    root->size = 0;
    root->data = NULL;

    ramfs->root = root;

    if (!curr) {
        root_vfs = &ramfs->base;
    } else {
        curr->next = &ramfs->base;
        index++;
    }

    return index;
}
