#include <proc/vfs.h>
#include <proc/ramfs.h>
#include <kheap.h>
#include <string.h>
#include <io.h>
#include <kprintf>

/**
 * 
 * 
 *          RAMFS
 * 
 * 
 */
vfs_err_t ramfs_read(struct vfs_node *node, uint32_t offset, uint32_t size, uint8_t *buffer) {
    struct vfs_ramfs_node *ramfs_node = (struct vfs_ramfs_node *)node;
    if (node->type != VFS_RAMFS_FILE) return VFS_ERROR;
    memcpy(buffer, ramfs_node->data + offset, size);
    return VFS_SUCCESS;
}

vfs_err_t ramfs_write(struct vfs_node *node, uint32_t offset, uint32_t size, const uint8_t *buffer) {
    struct vfs_ramfs_node *ramfs_node = (struct vfs_ramfs_node *)node;
    if (node->type != VFS_RAMFS_FILE) return VFS_ERROR;

    if (ramfs_node->data == nullptr) {
        ramfs_node->data = (uint8_t *)kmalloc(size);
        ramfs_node->base.size = size;
    } else if (offset + size > ramfs_node->base.size) {
        ramfs_node->data = (uint8_t *)krealloc(ramfs_node->data, offset + size);
        ramfs_node->base.size = offset + size;
    } else if (offset + size < ramfs_node->base.size) {
        memset(ramfs_node->data + offset + size, 0, ramfs_node->base.size - offset - size);
    }

    memcpy(ramfs_node->data + offset, buffer, size);
    ramfs_node->base.modification_time = get_rtc_timestamp();
    return VFS_SUCCESS;
}

vfs_err_t ramfs_create(struct vfs_node *parent, const char *name, vfs_node_type_t type, struct vfs_node **new_node) {
    if (parent->type != VFS_RAMFS_FOLDER) return VFS_NOT_PERMITTED;

    *new_node = vfs_create_node(name, type, parent);
    struct vfs_ramfs_node *ramfs_node = (struct vfs_ramfs_node *)(*new_node);
    ramfs_node->data = nullptr;

    parent->modification_time = get_rtc_timestamp();            
    return VFS_SUCCESS;
}

vfs_err_t ramfs_remove(struct vfs_node *parent, struct vfs_node *node) {
    if (parent->type != VFS_RAMFS_FOLDER) return VFS_NOT_PERMITTED;

    vfs_remove_node(parent, node);

    struct vfs_ramfs_node *ramfs_node = (struct vfs_ramfs_node *)node;
    if (ramfs_node->data) kfree(ramfs_node->data);
    return VFS_SUCCESS;
}

/**
 * 
 * 
 *          VFS
 * 
 */
/**
 * Initialize the VFS tree with the root node.
 */
struct vfs_tree *vfs_initialize() {
    struct vfs_tree *vfs = (struct vfs_tree *)kmalloc(sizeof(struct vfs_tree));
    
    struct vfs_ramfs_node *ramfs_root = (struct vfs_ramfs_node *)kmalloc(sizeof(struct vfs_ramfs_node));
    struct vfs_node *root = &ramfs_root->base;

    root->name = strdup("/");
    root->type = VFS_RAMFS_FOLDER;
    root->size = 0;
    root->permissions = VFS_READ | VFS_WRITE;
    root->creation_time = root->modification_time = get_rtc_timestamp();
    root->parent = nullptr;
    root->children = nullptr;
    root->next = nullptr;

    root->read = ramfs_read;
    root->write = ramfs_write;
    root->create = ramfs_create;
    root->remove = ramfs_remove;

    ramfs_root->data = nullptr;

    vfs->root = root;
    return vfs;
}

struct vfs_node *vfs_create_node(const char *name, vfs_node_type_t type, struct vfs_node *parent) {
    struct vfs_node *node;

    if (type == VFS_RAMFS_FILE || type == VFS_RAMFS_FOLDER) {
        struct vfs_ramfs_node *ramfs_node = (struct vfs_ramfs_node *)kmalloc(sizeof(struct vfs_ramfs_node));
        node = &ramfs_node->base;
        ramfs_node->data = nullptr;
    } else {
        return nullptr;
    }

    node->name = strdup(name);
    node->type = type;
    node->size = 0;
    node->permissions = VFS_READ | VFS_WRITE;
    node->creation_time = node->modification_time = get_rtc_timestamp();
    node->parent = parent;
    node->children = nullptr;
    node->next = nullptr;

    if (type == VFS_RAMFS_FILE || type == VFS_RAMFS_FOLDER) {
        node->read = ramfs_read;
        node->write = ramfs_write;
        node->create = ramfs_create;
        node->remove = ramfs_remove;
    }

    vfs_insert_node(parent, node);
    return node;
}

void vfs_insert_node(struct vfs_node *parent, struct vfs_node *node) {
    if (!parent->children) {
        parent->children = node;
    } else {
        struct vfs_node *sibling = parent->children;
        while (sibling->next) {
            sibling = sibling->next;
        }
        sibling->next = node;
    }
}

void vfs_remove_node(struct vfs_node *parent, struct vfs_node *node) {
    if (parent->children == node) {
        parent->children = node->next;
    } else {
        struct vfs_node *prev = parent->children;
        while (prev && prev->next != node) {
            prev = prev->next;
        }
        if (prev) prev->next = node->next;  
    }

    if (node->children) {
        struct vfs_node *child = node->children;
        while (child) {
            struct vfs_node *next_child = child->next;
            vfs_remove_node(node, child);
            child = next_child;
        }   
    }

    memset(node, 0, sizeof(struct vfs_node));
    kfree(node->name);
    kfree(node);
}

struct vfs_node *vfs_search_node(struct vfs_node *parent, const char *name) {
    struct vfs_node *current = parent->children;
    while (current) {
        if (strcmp(current->name, name) == 0) return current;
        current = current->next;
    }
    return nullptr;
}

int vfs_read(struct vfs_node *file, uint32_t offset, uint32_t size, uint8_t *buffer) {
    if (file->read) return file->read(file, offset, size, buffer);
    return VFS_NOT_PERMITTED;
}

int vfs_write(struct vfs_node *file, uint32_t offset, uint32_t size, const uint8_t *buffer) {
    if (file->write) return file->write(file, offset, size, buffer);
    return VFS_NOT_PERMITTED;
}

struct vfs_node *vfs_traverse_path(struct vfs_tree *vfs, const char *path) {
    if (!path || *path == '\0') return nullptr;

    char *path_copy = strdup(path);
    if (!path_copy) return nullptr;

    char *token = strtok(path_copy, "/");
    struct vfs_node *current = vfs->root;

    while (token) {
        struct vfs_mount *mount = g_mounts;
        while (mount) {
            if (mount->mount_point == current) {
                current = mount->mounted_root;
                break;
            }
            mount = mount->next;
        }

        current = vfs_search_node(current, token);
        if (!current) {
            kfree(path_copy);
            return nullptr;
        }
        token = strtok(nullptr, "/");
    }

    kfree(path_copy);
    return current;
}


/*
 * 
 * 
 *          ABSTEACTED FUNCTIONS
 * 
 */

vfs_err_t remove_p(const char* path) {
    struct vfs_node *node = vfs_traverse_path(g_Vfs, path);
    if (!node || !node->parent) return VFS_NOT_FOUND;
    return node->parent->remove(node->parent, node);
}

vfs_err_t remove(HANDLE handle) {
    if (!handle || !handle->parent) return VFS_NOT_FOUND;
    return handle->parent->remove(handle->parent, handle);
}

vfs_err_t create(const char* path, vfs_node_type_t type) {
    char parent_path[256];
    const char *name = strrchr(path, '/');

    if (name == nullptr) return VFS_ERROR;
    
    size_t parent_len = name - path;
    if (parent_len == 0) {
        strcpy(parent_path, "/");
    } else {
        strncpy(parent_path, path, parent_len);
        parent_path[parent_len] = '\0';
    }
    
    struct vfs_node *parent_node = vfs_traverse_path(g_Vfs, parent_path);
    if (!parent_node) return VFS_NOT_FOUND;

    struct vfs_node *new_node = NULL;
    return parent_node->create(parent_node, name + 1, type, &new_node);
}

HANDLE open(const char* path) {
    return vfs_traverse_path(g_Vfs, path);
}

vfs_err_t close(HANDLE handle) {
    return handle ? VFS_SUCCESS : VFS_ERROR;
}

vfs_err_t read(HANDLE handle, uint32_t offset, uint32_t size, uint8_t* buffer) {
    if (!handle || !handle->read) return VFS_ERROR;
    return handle->read(handle, offset, size, buffer);
}

vfs_err_t write(HANDLE handle, uint32_t offset, uint32_t size, const uint8_t* buffer) {
    if (!handle || !handle->write) return VFS_ERROR;
    return handle->write(handle, offset, size, buffer);
}

/**
 * 
 *          MOUNTING
 * 
 * 
 */

struct vfs_mount *g_mounts = nullptr;

vfs_err_t vfs_mount(const char *target_path, struct vfs_node *filesystem_root) {
    if (!g_Vfs || !target_path || !filesystem_root) return VFS_ERROR;
    struct vfs_node *mount_point = vfs_traverse_path(g_Vfs, target_path);
    if (!mount_point) return VFS_NOT_FOUND;

    if (mount_point->type != VFS_RAMFS_FOLDER) return VFS_NOT_PERMITTED;

    struct vfs_mount *new_mount = (struct vfs_mount *)kmalloc(sizeof(struct vfs_mount));
    new_mount->mount_point = mount_point;
    new_mount->mounted_root = filesystem_root;
    new_mount->next = g_mounts;
    g_mounts = new_mount;

    filesystem_root->parent = mount_point;
    if (!mount_point->children) {
        mount_point->children = filesystem_root;
    } else {
        struct vfs_node *child = mount_point->children;
        while (child->next) child = child->next;
        child->next = filesystem_root;
    }

    return VFS_SUCCESS;
}

vfs_err_t vfs_unmount(const char *target_path) {
    if (!g_Vfs || !target_path) return VFS_ERROR;

    struct vfs_node *mount_point = vfs_traverse_path(g_Vfs, target_path);
    if (!mount_point) return VFS_NOT_FOUND;

    struct vfs_mount **prev_mount = &g_mounts;
    struct vfs_mount *mount = g_mounts;

    while (mount) {
        if (mount->mount_point == mount_point) {
            *prev_mount = mount->next;
            if (mount_point->children == mount->mounted_root) {
                mount_point->children = mount->mounted_root->next;
            } else {
                struct vfs_node *child = mount_point->children;
                while (child && child->next != mount->mounted_root) {
                    child = child->next;
                }
                if (child) child->next = mount->mounted_root->next;
            }

            kfree(mount);
            return VFS_SUCCESS;
        }
        prev_mount = &mount->next;
        mount = mount->next;
    }

    return VFS_NOT_FOUND;
}
