#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

typedef signed long ssize_t;

enum vtype {
    VNON,   // No type
    VREG,   // Regular file
    VDIR,   // Directory
    VBLK,   // Block device
    VCHR,   // Character device
    VLNK,   // Symbolic link
    VSOCK,  // Socket
    VBAD    // Bad type
};

struct vattr {
    enum vtype type;              // Vnode type
    uint16_t mode;                // Access mode
    uint16_t uid;                 // Owner user ID
    uint16_t gid;                 // Owner group ID
    int32_t fs_id;                // File system ID
    int32_t node_id;              // Node ID
    uint16_t link_count;          // Link count
    uint32_t size;                // File size in bytes
    int32_t block_size;           // Block size
    int64_t device_id;            // Device ID (if applicable)
    int32_t blocks;               // Space used in blocks
};

struct statfs {
    int32_t fs_type;              // File system type
    int32_t block_size;           // Block size
    int32_t total_blocks;         // Total blocks
    int32_t free_blocks;          // Free blocks
    int32_t avail_blocks;         // Free blocks for non-superuser
    int32_t total_files;          // Total number of file nodes
    int32_t free_files;           // Free file nodes
    int64_t fs_id;                // File system ID
    int32_t reserved[7];          // Reserved for future use
};

struct fid {
    int32_t fs_id;               // Filesystem ID
    int32_t node_id;             // Node ID
    int32_t gen;                 // Generation number
};

struct vnode;
struct vfs;

struct vfs_ops {
    int (*mount)(struct vfs* vfs, const char* path, void* data);
    int (*unmount)(struct vfs* vfs);
    int (*get_root)(struct vfs* vfs, struct vnode** root_node);
    int (*get_statfs)(struct vfs* vfs, struct statfs* stat);
    int (*sync)(struct vfs* vfs);
    int (*get_fid)(struct vfs* vfs, struct vnode* vnode, struct fid** file_id);
    int (*get_vnode)(struct vfs* vfs, struct vnode** vnode_out, struct fid* file_id);
};

struct vfs {
    struct vfs* next;              // Next vfs in list
    struct vfs_ops* ops;           // VFS operations
    struct vnode* covered_node;    // Vnode that this VFS covers
    int flags;                     // VFS flags
    int block_size;                // Native block size
};

struct vnode_ops {
    int (*open)(struct vnode** node, int flags, void* context);
    int (*close)(struct vnode* node, int flags, void* context);
    ssize_t (*read_write)(struct vnode* node, void* buffer, int op, int flags, void* context);
    int (*ioctl)(struct vnode* node, int command, void* data, int flags, void* context);
    int (*select)(struct vnode* node, int mode, void* context);
    int (*get_attr)(struct vnode* node, struct vattr* attr, void* context);
    int (*set_attr)(struct vnode* node, struct vattr* attr, void* context);
    int (*check_access)(struct vnode* node, int mode, void* context);
    int (*lookup)(struct vnode* node, const char* name, struct vnode** result_node, void* context);
    int (*create)(struct vnode* node, const char* name, struct vattr* attr, int excl, int mode, struct vnode** result_node, void* context);
    int (*remove)(struct vnode* node, const char* name, void* context);
    int (*link)(struct vnode* source_node, struct vnode* target_dir, const char* target_name, void* context);
    int (*rename)(struct vnode* node, const char* old_name, struct vnode* target_dir, const char* new_name, void* context);
    int (*make_dir)(struct vnode* node, const char* name, struct vattr* attr, struct vnode** result_node, void* context);
    int (*remove_dir)(struct vnode* node, const char* name, void* context);
    int (*read_dir)(struct vnode* node, void* buffer, void* context);
    int (*make_symlink)(struct vnode* node, const char* link_name, struct vattr* attr, const char* target_name, void* context);
    int (*read_symlink)(struct vnode* node, void* buffer, void* context);
    int (*fsync)(struct vnode* node, void* context);
    int (*mark_inactive)(struct vnode* node, void* context);
    int (*block_map)(struct vnode* node, int block_num, struct vnode** block_node, int* mapped_block_num);
    int (*strategy)(void* buffer);
    int (*read_block)(struct vnode* node, int block_num, void** buffer_out);
    int (*release_block)(struct vnode* node, void* buffer);
};

struct vnode {
    uint16_t flags;                   // Vnode flags
    uint16_t ref_count;               // Reference count
    uint16_t shared_lock_count;       // Shared lock count
    uint16_t exclusive_lock_count;    // Exclusive lock count
    struct vfs* mount_point;          // Mounted VFS, if this vnode is a mount point
    struct vnode_ops ops;             // Vnode operations
    union {
        void* socket_data;            // IPC socket
        void* stream_data;            // Stream data
    };
    struct vfs* vfs;                  // Parent VFS
    enum vtype type;                  // Type of vnode
};

extern struct vfs* root_vfs;