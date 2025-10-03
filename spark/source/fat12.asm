use32

include 'include/fat12_structs.inc'

fat_data_ptr: dd 0
root_dir_ptr: dd 0
data_section_lba: dd 0

fat12_initialize:
    movzx eax, word [bdb_bytes_per_sector]

    movzx ecx, word [bdb_sectors_per_fat]
    mul ecx

    call allocate_memory

    mov dword [fat_data_ptr], eax

    mov edi, eax
    mov cx, word [bdb_sectors_per_fat]
    movzx eax, word [bdb_reserved_sectors]

    call partition_read

    mov eax, FILE_STRUCT_SIZE
    call allocate_memory

    mov dword [root_dir_ptr], eax
    mov edi, eax

    mov dword [edi + FILE_POS_OFF], 0

    movzx eax, word [bdb_dir_entries_count]
    mov ecx, FAT_DIR_ENTRY_SIZE
    mul ecx
    mov dword [edi + FILE_SIZE_OFF], eax

    mov byte [edi + FILE_DIR_OFF], 1

    movzx eax, word [bdb_sectors_per_fat]
    movzx ecx, word [bdb_fat_count]
    mul ecx
    movzx esi, word [bdb_reserved_sectors]
    add eax, esi

    mov dword [edi + FILE_CURRENT_CLUSTER_OFF], eax ; for the root dir, this doesn't hold the cluster# but lba
    mov dword [edi + FILE_FIRST_CLUSTER_OFF], eax
    mov dword [edi + FILE_SECTOR_IN_CLUSTER_OFF], 0

    lea edi, [edi + FILE_BUFFER_OFF]
    mov cx, 1
    call partition_read

    mov edi, dword [root_dir_ptr]

    mov eax, dword [edi + FILE_SIZE_OFF]

    movzx ecx, word [bdb_bytes_per_sector]
    add eax, ecx
    dec eax

    movzx ecx, word [bdb_bytes_per_sector]
    xor edx, edx
    div ecx

    add eax, dword [edi + FILE_CURRENT_CLUSTER_OFF]

    mov dword [data_section_lba], eax

    ret

; in eax -> cluster number
; out eax -> lba
fat12_cluster_to_lba:
    push ecx

    sub eax, 2

    movzx ecx, byte [bdb_sectors_per_cluster]
    mul ecx

    add eax, dword [data_section_lba]

    pop ecx
    ret

; in edi -> FAT_DIR_ENTRY pointer
; out eax -> FILE_STRUCT pointer
fat_open_entry:
    mov eax, FILE_STRUCT_SIZE
    call allocate_memory

    mov esi, eax

    mov eax, dword [edi + FAT_SIZE_OFF]
    mov dword [esi + FILE_SIZE_OFF], eax

    mov al, [edi + FAT_ATTRIBUTES_OFF]
    test al, FAT_ATTRIBUTE_DIRECTORY
    setnz al
    mov [esi + FILE_DIR_OFF], al

    mov dword [esi + FILE_POS_OFF], 0

    movzx eax, word [edi + FAT_FIRST_CLUSTER_LO_OFF]
    movzx ecx, word [edi + FAT_FIRST_CLUSTER_HI_OFF]
    shl ecx, 16
    or eax, ecx

    mov dword [esi + FILE_FIRST_CLUSTER_OFF], eax
    mov dword [esi + FILE_CURRENT_CLUSTER_OFF], eax

    mov dword [esi + FILE_SECTOR_IN_CLUSTER_OFF], 0

    cmp dword [esi + FILE_SIZE_OFF], 0
    jne .load_first_sector

    mov dword [esi + FILE_CURRENT_CLUSTER_OFF], 0xFFF
    jmp .done_open

.load_first_sector:
    call fat12_cluster_to_lba

    lea edi, [esi + FILE_BUFFER_OFF]
    mov cx, 1
    call partition_read

.done_open:
    mov eax, esi

    ret

; in eax -> current cluster
; out eax -> next cluster
fat_next_cluster:
    push ecx
    push esi

    mov esi, dword [fat_data_ptr]

    mov ecx, eax
    shr ecx, 1
    lea eax, [eax + ecx]
    lea eax, [eax + esi]
    movzx eax, word [eax]

    jnc .even ; flag still set based on shr

.odd:
    shr eax, 4

.even:
    and eax, 0x0FFF

.end:
    pop esi
    pop ecx
    ret

; in esi -> FAT_FILE pointer
;    ecx -> byte out count
;    edi -> buffer out pointer
fat_read:
    pushad

    mov al, byte [esi + FILE_DIR_OFF]
    test al, al
    jnz .is_dir

    mov eax, [esi + FILE_SIZE_OFF]
    sub eax, [esi + FILE_POS_OFF]
    cmp ecx, eax
    jbe .after_min

    mov ecx, eax
.is_dir:
.after_min:
    push esi ; [esp + 8]
    push edi ; [esp + 4]
    push ecx ; [esp]
.loop:
    mov esi, [esp + 8]
    mov edi, [esp + 4]
    mov ecx, [esp]

    mov eax, [esi + FILE_POS_OFF]

    movzx ebx, word [bdb_bytes_per_sector]
    dec ebx
    and eax, ebx ; eax = [esi + FILE_POS_OFF] % SECTOR_SIZE
    inc ebx

    sub ebx, eax ; ebx = SECTOR_SIZE - eax

    cmp ecx, ebx
    jbe @f

    mov ecx, ebx
    @@: ; ecx = bytes_to_take = min(ecx, ebx)

    push ecx

    lea esi, [esi + FILE_BUFFER_OFF]
    add esi, eax ; esi = buffer + eax
    rep movsb

    pop ecx

    mov esi, [esp + 8]

    add [esp + 4], ecx
    add [esi + FILE_POS_OFF], ecx
    sub [esp], ecx

    cmp ecx, ebx
    jne .no_more

    mov edx, dword [root_dir_ptr]
    cmp edx, esi
    jne .not_root_dir

    inc dword [esi + FILE_CURRENT_CLUSTER_OFF]
    mov eax, dword [esi + FILE_CURRENT_CLUSTER_OFF]
    mov cx, 1
    lea edi, [esi + FILE_BUFFER_OFF]
    call partition_read

    jmp .no_more

.not_root_dir:
    mov eax, dword [esi + FILE_SECTOR_IN_CLUSTER_OFF]
    inc eax
    movzx ebx, byte [bdb_sectors_per_cluster]

    cmp eax, ebx
    jb .not_next_cluster

    mov dword [esi + FILE_SECTOR_IN_CLUSTER_OFF], 0

    mov eax, dword [esi + FILE_CURRENT_CLUSTER_OFF]
    call fat_next_cluster
    mov dword [esi + FILE_CURRENT_CLUSTER_OFF], eax

    jmp .after_sector_advance
.not_next_cluster:
    mov [esi + FILE_SECTOR_IN_CLUSTER_OFF], eax

.after_sector_advance:
    mov eax, dword [esi + FILE_CURRENT_CLUSTER_OFF]
    cmp eax, 0xFF7
    je filesystem_corrupt

    cmp eax, 0xFF8
    jnae .not_end_of_chain

    mov eax, dword [esi + FILE_POS_OFF]
    mov dword [esi + FILE_SIZE_OFF], eax
    mov dword [esp], 0
    jmp .no_more

.not_end_of_chain:
    lea edi, [esi + FILE_BUFFER_OFF]
    mov cx, 1

    mov eax, [esi + FILE_CURRENT_CLUSTER_OFF]
    call fat12_cluster_to_lba
    add eax, [esi + FILE_SECTOR_IN_CLUSTER_OFF]

    call partition_read

.no_more:
    mov ecx, [esp]
    cmp ecx, 0
    jg .loop

.end:
    mov eax, [esp + 36]
    sub eax, [esp]
    mov [esp + 40], eax

    pop ecx
    pop edi
    pop esi

    popad
    ret

; in esi -> FAT_FILE pointer
;    edi -> FAT_DIR_ENTRY pointer
; out CF -> set on fail
fat_read_entry:
    push ecx

    mov ecx, FAT_DIR_ENTRY_SIZE
    call fat_read

    pop ecx

    cmp eax, FAT_DIR_ENTRY_SIZE
    jnz .fail

    clc
    ret
.fail:
    stc
    ret

; in esi -> FAT_FILE pointer
; 	 edi -> 8.3 name
; out eax -> FAT_DIR_ENTRY pointer
; 	  CF -> set on fail
fat_find_file:
    pushad

    mov eax, FAT_DIR_ENTRY_SIZE
    call allocate_memory

    mov edx, edi
.search_entries_loop:
    mov edi, eax

    call fat_read_entry
    jc .fail

    mov al, byte [edi + FAT_NAME_OFF]
    cmp al, 0
    je .fail

    cmp al, 0xE5
    je .search_entries_loop

    mov al, byte [edi + FAT_ATTRIBUTES_OFF]
    and al, FAT_ATTRIBUTE_LFN_MASK
    cmp al, FAT_ATTRIBUTE_LFN_MASK
    je .search_entries_loop

    mov al, byte [edi + FAT_ATTRIBUTES_OFF]
    test al, FAT_ATTRIBUTE_VOLUME_ID
    jnz .search_entries_loop

    mov ecx, 11
.compare_8_3_name:
    mov al, [edx + ecx - 1]

    cmp al, [edi + FAT_NAME_OFF + ecx - 1]
    jne .search_entries_loop

    dec ecx
    jnz .compare_8_3_name

    call fat_open_entry
    mov [esp + 28], eax

    popad
    clc

    ret
.fail:
    popad
    stc

    ret

filesystem_corrupt:
    mov esi, msg_filesystem_corrupt
    call print_str

    enter_real_mode

    xor ah, ah
    int 0x16

    int 0x19

use32
msg_filesystem_corrupt: db 'BAD Sector in FAT Chain!', endl
    db 'Filesystem is corrupted, reboot from a recovery media and run chkfs.', endl
    db 'Press any key to enter firmware setup', endl, 0
