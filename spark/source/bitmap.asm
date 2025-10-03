use32

MEMORY_TRACK_BASE = 0x7e00
CHUNK_SIZE = 32
BITMAP_SIZE = 255
MAX_CHUNKS = BITMAP_SIZE * 8

bitmap: times BITMAP_SIZE db 0
next_free_chunk: dd 0

; in EAX -> size (32 byte rounded) 
; out EAX -> pointer
allocate_memory:
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov ecx, eax
    add eax, CHUNK_SIZE - 1
    xor edx, edx

    mov ebx, CHUNK_SIZE
    div ebx

    mov ebx, eax
    mov esi, [next_free_chunk]

    mov edx, esi
    add edx, ebx
    cmp edx, MAX_CHUNKS
    ja .fail

.mark_loop:
    mov edi, esi
    mov eax, edi

    shr edi, 5
    and eax, 31
    bts dword [bitmap + edi * 4], eax

    inc esi
    dec ebx
    jnz .mark_loop

    mov eax, [next_free_chunk]
    imul eax, CHUNK_SIZE
    add eax, MEMORY_TRACK_BASE

    mov [next_free_chunk], esi

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

.fail:
    xor eax, eax

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret
