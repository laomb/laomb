# LAOMB Binary Format ("binfmt") v1.0 - Specification

**Target:** IA-32 protected mode
**Endianness:** Little-endian
**Alignment:** Natural power-of-two as specified per field
**Purpose:** Unified on-disk format for Laomb executables (`BIN`), drivers (`DRV`), and dynamic libraries (`DL`).

---

## 1. Conventions

* **Numbers** are little-endian unsigned unless noted.
* **Offsets** are file offsets from the start of the file or section (0-based).
* **Ordinals** start at 0.
* **"MUST/SHOULD/MAY"** follow RFC 2119.
* **Reserved fields** MUST be zero and ignored on read unless stated otherwise.

---

## 2. Abstract file layout

```
+-----------------------------+  0
| LBFHeader                   |  fixed
+-----------------------------+
| LBFDirEnt[n_tables]         |  fixed array (table directory)
+-----------------------------+
| Table payloads (any order)  |  SEGMENTS, SECTIONS, RELOCS, DEPS, IMPORTS...
|                             |
+-----------------------------+
| Raw section payloads        |  referenced by SECTIONS
+-----------------------------+
```

Tables MAY appear in any order and MUST NOT overlap. Each table is self-contained.

---

## 3. Header

```c
#define LBF_MAGIC 0x1A4C4246u /* 'FBL\x1A' little-endian */

enum lbf_kind    { LBF_EXE=1, LBF_DRV=2, LBF_DLL=3 };
enum lbf_machine { LBF_I386=3 };

typedef struct {
    uint32_t magic;        // LBF_MAGIC
    uint32_t version;      // producer's file/library version (opaque to loader)
    uint16_t abi_major;    // incompatible when bumped
    uint16_t abi_minor;    // backward-compatible bump
    uint16_t kind;         // lbf_kind
    uint16_t machine;      // LBF_I386
    uint32_t flags;        // LBF_F_* (see below)
    uint16_t entry_sel;    // ordinal of entry segment (not a selector)
    uint32_t entry;        // entry offset within entry_sel segment
    uint32_t n_tables;     // number of directory entries
    uint32_t dir_off;      // file offset to first LBFDirEnt
} LBFHeader;
```

### 4.1 Header flags `LBF_F_*`

|  Bit | Name         | Meaning                                                           |
| ---: | ------------ | ----------------------------------------------------------------- |
|    0 | NX_EMU       | Request NX emulation: materialize non-code segments as non-exec.  |
|    1 | RELRO        | After binding, make relocation stubs/slots read-only if possible. |
|    2 | SAFE_IMPORTS | Disallow binding to call/task gates unless explicitly requested.  |
| 31:3 | -            | Reserved (0).                                                     |

---

## 5. Table directory

```c
enum lbf_table_type {
  LBF_T_SEGMENTS=1, LBF_T_SECTIONS=2, LBF_T_RELOCS=3,
  LBF_T_EXPORTS=4,  LBF_T_DEPS=5,
  LBF_T_TLS=6,      LBF_T_SECURITY=7,
  LBF_T_STRTAB=8,   LBF_T_IMPORTS=9,
  LBF_T_SYMIDX=10, LBF_T_SYMSTR=11
};

typedef struct {
    uint16_t type;     // lbf_table_type
    uint16_t reserved; // zero
    uint32_t offset;   // file offset to table payload
    uint32_t size;     // total bytes of the table payload
    uint32_t count;    // element count where applicable (0 if not a flat array)
} LBFDirEnt;
```

If a table entry is not a flat array, `LBFDirEnt.count` MUST be 0.

**Loader MUST:**

* Validate each table's `(offset, size)` within file bounds and that tables do not overlap.
* MAY ignore unknown tables.

---

## 6. Segments & sections

### 6.1 Segment table (`LBF_T_SEGMENTS`, type=1)

A segment describes logical memory the loader will back and protect with a descriptor.

```c
enum lbf_seg_type {
  LBF_ST_CODE_RX=1,        // non-conforming code, readable
  LBF_ST_DATA_RW=3,        // data read/write
  LBF_ST_DATA_RO=4,        // data read-only
  LBF_ST_STACK_RW=5        // data RW, intended for stacks
};

typedef struct {
    uint16_t seg_index;   // ordinal
    uint8_t  type;        // lbf_seg_type
    uint8_t  reserved;    // zero
    uint32_t vlimit;      // logical limit in bytes (MUST be 4KiB-aligned)
    uint32_t alignment;   // required alignment for section packing (pow2)
    uint32_t sect_start;  // first section index in SECTIONS
    uint32_t sect_count;  // number of sections owned by this segment
    uint32_t flags;       // LBF_SF_* (below)
} LBFSegDesc;
```

**Segment flags `LBF_SF_*`:**

* `0x00000001` - SHAREABLE (loader MAY share across processes without CoW)
* `0x00000002` - INIT_ONCE (zero/init performed only on first map)
* `0xFFFFFFFC` - reserved

### 6.2 Section table (`LBF_T_SECTIONS`, type=2)

All virtual addresses are *(seg_index, offset)* within the owning segment.

```c
enum lbf_sect_kind {
  LBF_SK_TEXT=1,   // executable code
  LBF_SK_RODATA=2, // read-only data
  LBF_SK_DATA=3,   // writable data
  LBF_SK_BSS=4,    // zero-fill (file_off=0, file_sz=0)
  LBF_SK_TLS=5,    // reserved for future TLS template
  LBF_SK_STUB=6,   // import/plt/thunk code or fixup slots
  LBF_SK_OTHER=7   // producer-defined
};

typedef struct {
    uint32_t name;       // STRTAB offset
    uint16_t seg_index;  // owning segment
    uint16_t sect_kind;  // lbf_sect_kind (advisory)
    uint32_t file_off;   // 0 for BSS-like sections
    uint32_t file_sz;    // bytes present in file
    uint32_t mem_off;    // offset within the segment (MUST be multiple of align)
    uint32_t mem_sz;     // total memory size (>= file_sz)
    uint32_t align;      // power-of-two; MUST divide segment.alignment
    uint32_t flags;      // LBF_CF_* content/permission hints
} LBFSection;
```

**Content flags `LBF_CF_*`:** `0x1` DISCARDABLE, `0x2` ZERO_INIT; others reserved (0).

**Loader MUST:**

* Copy `file_sz` bytes from `file_off` to `(seg_base + mem_off)`; then zero `mem_sz - file_sz`.
* Ensure `mem_off + mem_sz - 1 <= vlimit - 1`.

---

## 7 Primary string table (`LBF_T_STRTAB`, type=8)

A contiguous blob of UTF-8, NUL-terminated strings. Offsets into this table are used wherever a **string pointer** is needed (e.g., section names, module names, export names). Offset `0` MUST be an empty string (`\0`). Consumers MUST bounds-check offsets.

---

## 8. Dependencies, imports, and exports

### 8.1 Dependencies (`LBF_T_DEPS`, type=5)

```c
typedef struct {
    uint32_t name_off; // STRTAB offset of logical module name ("core")
    uint32_t min_ver;  // optional ABI minor version (0 if none)
} LBFDependency;       // order is stable and used by IMPORTS
```

The loader MUST resolve the logical module names into on-disk paths and locate the requested dynamic libraries.

### 8.2 Import directory (`LBF_T_IMPORTS`, type=9)

Catalog of external symbols required. Binding occurs into slots described in `RELOCS`.

```c
enum lbf_import_flags {
    LBF_IF_BYORD   = 0x0001,   // 'hint' carries ordinal; name_off may be 0
    LBF_IF_GATE    = 0x0002,   // target is a call/task gate selector
    LBF_IF_PRIVATE = 0x0004    // visibility hint for loader policy
};

typedef struct {
    uint32_t dep_index; // index into LBF_T_DEPS
    uint32_t name_off;  // STRTAB offset of imported name (0 if BYORD)
    uint32_t hint;      // ordinal if BYORD; otherwise 0
    uint32_t flags;     // lbf_import_flags
} LBFImportDesc;        // unsorted catalog (unique by (dep_index, name/ord))
```

### 8.3 Relocation slots (`LBF_T_RELOCS`, type=3)

Loader-patched slots for dynamic binding.

```c
enum lbf_relocs_kind {
    LBF_RELOCS_FARPTR32 = 1, // write {off32, sel16} (6 bytes, little-endian)
    LBF_RELOCS_SEL16    = 2  // write selector16 only (2 bytes)
};

typedef struct {
    uint16_t seg_index;  // segment containing the slot
    uint16_t kind;       // lbf_relocs_kind
    uint32_t slot_off;   // offset within seg_index to patch
    uint32_t import_ix;  // index into LBF_T_IMPORTS
} LBFRELOCSEntry;        // order irrelevant
```

**Loader MUST:**

* Resolve `(dep_index, name/ordinal)` to an exported *(seg, off)* in the dependency.
* For `FARPTR32`, write `{off32, sel16(dep_seg)}` into the 6-byte slot.
* For `SEL16`, write the target selector.
* If `RELRO` is set, mark sections hosting these slots read-only afterwards (typically `STUB` sections).

### 8.4 Exports (`LBF_T_EXPORTS`, type=4)

Map names/ordinals to *(seg, off)*.

```c
typedef struct {
    uint32_t name_off;   // STRTAB offset (0 if exported-by-ordinal only)
    uint32_t ordinal;    // 0 if name-only; otherwise module-wide ordinal
    uint16_t seg_index;  // segment of export target
    uint16_t reserved;   // zero
    uint32_t value;      // offset within segment (off32)
    uint32_t flags;      // reserved (0)
} LBFExport;             // unsorted master list
```

---

## 9. Sorted Symbol Indexes (`LBF_T_SYMIDX`, type=10)

The `SYMIDX` table is logically split into a given number of parts up to the number of segments in the binary. Each of these parts has a `SIdxPHeader` which contains information about the segment this part is describing and a link to the next header for faster iterations (O(n)).

```c
typedef struct {
    uint16_t seg_index; // which segment's symbols is this section describing.
    uint16_t flags;     // reserved (0)
    uint32_t part_size; // number of bytes following this header which this part uses for symbols.
    uint32_t next_link; // offset from start of LBF_T_SYMIDX part table
} SIdxPHeader;
```

Following this header, the part contains at most `part_size` bytes, aligned to pointer size bytes. Each pointer size bytes contain a sorted address of the base of a symbol in the given segment. The offset from the end of the parts header divided by the pointer size is the "index" used in the `SYMSTR` table to lookup the corresponding symbol name.

---

## 10. Sorted Symbol Strings (`LBF_T_SYMSTR`, type=11)

The `SYMSTR` table is logically split into a given number of parts up to the number of segments in the binary. Each of these parts has a `SStrPHeader` which contains information about the segment this part is describing and a link to the next header for faster iterations.

```c
typedef struct {
    uint16_t seg_index; // which segment's symbols is this section describing.
    uint16_t flags;     // reserved (0)
    uint32_t part_size; // number of bytes following this header which this part uses for symbols.
    uint32_t next_link; // offset from start of LBF_T_SYMSTR part table
} SStrPHeader;
```

Following this header the part contains at most `part_size` bytes, aligned to 4 bytes. Each 4 bytes hold an offset into the `STRTAB` table corresponding to the name of the symbol of the given "index".

---

## 11. Thread-local storage (`LBF_T_TLS`, type=6)

* `LBF_T_TLS` (type=6) is reserved for a future revision.
* v1 images MUST omit this table. Loaders MUST ignore it if present in a future-minor image they otherwise accept.

---

## 12. Security (`LBF_T_SECURITY`, type=7)

A minimal signing container for OS components and trusted modules.
In LAOMB this will be further specified in further revisions of the specifications.

```c
typedef struct {
    uint32_t alg_id;     // algorithm identifier
    uint32_t data_off;   // offset to signature bytes (within this table region)
    uint32_t data_sz;    // signature length
    uint32_t flags;      // reserved (0)
    // signature payload follows within table bounds
} LBFSecurity;
```

**Coverage:** the signature MUST cover the entire file **except** the bytes `data_off..data_off + data_sz - 1` inside this table.
The loader MUST skip the `data_off..data_off + data_sz - 1` section when computing the signature.

---
