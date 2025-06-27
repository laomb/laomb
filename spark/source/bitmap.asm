use32

MEMORY_TRACK_BASE equ 0x7C00
CHUNK_SIZE        equ 32
BITMAP_SIZE       equ 255
MAX_CHUNKS        equ BITMAP_SIZE * 8

bitmap: times BITMAP_SIZE db 0
next_free_chunk: dd 0

allocate_memory:
    push ebx
    push ecx
    push edx

    mov ecx, eax
    add eax, CHUNK_SIZE - 1
    xor edx, edx
    push ecx
    mov ecx, CHUNK_SIZE
    div ecx
    pop ecx

    mov ebx, eax
    mov ecx, [next_free_chunk]

    mov edx, ecx
    add edx, ebx
    cmp edx, MAX_CHUNKS
    ja  .fail

.mark_loop:
    mov edi, ecx
    shr edi, 3
    and ecx, 7
    bts [bitmap + edi], ecx
    inc ecx
    dec ebx
    jnz .mark_loop

    mov eax, [next_free_chunk]
    imul eax, CHUNK_SIZE
    add eax, MEMORY_TRACK_BASE

    mov [next_free_chunk], ecx
    pop edx
    pop ecx
    pop ebx
    ret

.fail:
    xor eax, eax
    pop edx
    pop ecx
    pop ebx
    ret
