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

struct vnode;
struct vfs;

struct vfsops {
    int (*mount)(struct vfs* vfsp, const char* path, void* data);
    int (*unmount)(struct vfs* vfsp);
    int (*root)(struct vfs* vfsp, struct vnode** vpp);
    int (*statfs)(struct vfs* vfsp, struct statfs* sbp);
    int (*sync)(struct vfs* vfsp);
    int (*fid)(struct vfs* vfsp, struct vnode* vp, struct fid** fidpp);
    int (*vget)(struct vfs* vfsp, struct vnode** vpp, struct fid* fidp);
};

struct vfs {
    struct vfs* vfs_next;               // Next vfs in list
    struct vfsops* vfs_op;              // VFS operations
    struct vnode* vfs_vnodecovered;     // Vnode that this VFS covers
    int vfs_flag;                       // VFS flags
    int vfs_bsize;                      // Native block size
    void* vfs_data;                     // Private data for specific file system
};

struct vnodeops {
    int (*open)(struct vnode** vpp, int f, void* c);
    int (*close)(struct vnode* vp, int f, void* c);
    ssize_t (*rdwr)(struct vnode* vp, void* uiop, int rw, int f, void* c);
    int (*ioctl)(struct vnode* vp, int com, void* d, int f, void* c);
    int (*select)(struct vnode* vp, int w, void* c);
    int (*getattr)(struct vnode* vp, struct vattr* va, void* c);
    int (*setattr)(struct vnode* vp, struct vattr* va, void* c);
    int (*access)(struct vnode* vp, int m, void* c);
    int (*lookup)(struct vnode* vp, const char* nm, struct vnode** vpp, void* c);
    int (*create)(struct vnode* vp, const char* nm, struct vattr* va, int e, int m, struct vnode** vpp, void* c);
    int (*remove)(struct vnode* vp, const char* nm, void* c);
    int (*link)(struct vnode* vp, struct vnode* tdvp, const char* tnm, void* c);
    int (*rename)(struct vnode* vp, const char* nm, struct vnode* tdvp, const char* tnm, void* c);
    int (*mkdir)(struct vnode* vp, const char* nm, struct vattr* va, struct vnode** vpp, void* c);
    int (*rmdir)(struct vnode* vp, const char* nm, void* c);
    int (*readdir)(struct vnode* vp, void* uiop, void* c);
    int (*symlink)(struct vnode* vp, const char* lnm, struct vattr* va, const char* tnm, void* c);
    int (*readlink)(struct vnode* vp, void* uiop, void* c);
    int (*fsync)(struct vnode* vp, void* c);
    int (*inactive)(struct vnode* vp, void* c);
    int (*bmap)(struct vnode* vp, int bn, struct vnode** vpp, int* bnp);
    int (*strategy)(void* bp);
    int (*bread)(struct vnode* vp, int bn, void** bpp);
    int (*brelse)(struct vnode* vp, void* bp);
};

struct vnode {
    uint16_t v_flag;                 // Vnode flags
    uint16_t v_count;                // Reference count
    uint16_t v_shlockc;              // Shared lock count
    uint16_t v_exlockc;              // Exclusive lock count
    struct vfs* v_vfsmountedhere;    // If mount point, VFS mounted here
    struct vnodeops v_op;            // Vnode operations
    union {
        void* v_socket;              // IPC socket
        void* v_stream;              // Stream
    };
    struct vfs* v_vfsp;              // VFS this vnode belongs to
    enum vtype v_type;               // Type of vnode
    void* v_data;                    // Private data (e.g., inode or network data)
};

struct vattr {
    enum vtype va_type;              // Vnode type
    uint16_t va_mode;                // Access mode
    uint16_t va_uid;                 // Owner user ID
    uint16_t va_gid;                 // Owner group ID
    int32_t va_fsid;                 // File system ID
    int32_t va_nodeid;               // Node ID
    uint16_t va_nlink;               // Link count
    uint32_t va_size;                // File size in bytes
    int32_t va_blocksize;            // Block size
    int64_t va_rdev;                 // Device ID (if applicable)
    int32_t va_blocks;               // Space used in blocks
};

struct statfs {
    int32_t f_type;                  // Type of file system
    int32_t f_bsize;                 // Block size
    int32_t f_blocks;                // Total blocks
    int32_t f_bfree;                 // Free blocks
    int32_t f_bavail;                // Free blocks for non-superuser
    int32_t f_files;                 // Total number of file nodes
    int32_t f_ffree;                 // Free file nodes
    int64_t f_fsid;                  // File system ID
    int32_t f_spare[7];              // Spare for future use
};

extern struct vfs* root_vfs;