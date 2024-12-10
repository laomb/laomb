#include <proc/vfs.h>
#include <string.h>

struct vfs* root_vfs;

struct vnode* vfs_traverse_path(const char* path) {
    if (!path || !root_vfs) {
        return nullptr;
    }

    struct vnode* current = nullptr;
    if (root_vfs->ops->get_root(root_vfs, &current) != 0 || !current) {
        return nullptr;
    }

    if (*path == '/') {
        path++;
    }

    char component[256];

    while (*path) {
        const char* next = strchr(path, '/');
        size_t len = next ? (size_t)(next - path) : strlen(path);

        if (len == 0 || len >= sizeof(component)) {
            return nullptr;
        }

        memcpy(component, path, len);
        component[len] = '\0';

        if (strcmp(component, ".") == 0) {
            path += len + (next ? 1 : 0);
            continue;
        }

        if (strcmp(component, "..") == 0) {
            if (current->vfs->covered_node) {
                current = current->vfs->covered_node;
            }
            path += len + (next ? 1 : 0);
            continue;
        }

        struct vnode* next_node = nullptr;
        if (!current->ops || current->ops->lookup(current, component, &next_node, nullptr) != 0 || !next_node) {
            return nullptr;
        }

        current = next_node;

        if (!next) break;
        path = next + 1;
    }

    return current;
}