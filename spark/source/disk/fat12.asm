
first_data_sector: dw 0
root_dir_sectors: dw 0



fat12_init:
	pusha 

	mov ax, word [bootsector.bdb_dir_entries_count]
	shl ax, 5

	add ax, 511
	shr ax, 9
	mov word [root_dir_sectors], ax

	mov ax, word [bootsector.bdb_sectors_per_fat]
	xor dx, dx

	movzx bx, byte [bootsector.bdb_fat_count]
	mul bx

	add ax, word [bootsector.bdb_reserved_sectors]
	add ax, word [root_dir_sectors]
	mov word [first_data_sector], ax

	print_trace '[fat12_init] root dir sectors: 0x', word [root_dir_sectors], ' first data sector: 0x', word [first_data_sector], 10

	popa
	ret


; In: AX = cluster number
; Out: AX = LBA
cluster_to_lba:
	push dx bx

	sub ax, 2
	movzx bx, byte [bootsector.bdb_sectors_per_cluster]
	mul bx
	add ax, word [first_data_sector]

	pop bx dx
	ret


; In: AX = current cluster
; Out: AX = next cluster
fat12_next_cluster:
	push bx dx di

	mov bx, ax
	mov dx, ax

	add bx, bx
	add bx, ax
	shr bx, 1

	mov di, fat_buffer
	
	mov al, byte [di + bx]
	inc bx
	mov ah, byte [di + bx]

	test dx, 1
	jz .even
.odd:
	shr ax, 4
.even:
	and ax, 0xfff

	assert "[fat12_next_cluster] corrupted filesystem", ax ne 0xff7
	cmp ax, 0xff8
	jae .eof

	clc
	pop di dx bx
	ret

.eof:
	stc
	pop di dx bx
	ret


; In: SI = pointer to 83 name
; Out: AX = first cluster, EBX = file size
fat12_find_file:
	push di cx dx

	mov di, root_dir_buffer
	mov cx, word [root_dir_sectors]
	shl cx, 9
	print_trace '[fat12_find_file] Root dir buffer: ', &[root_dir_buffer], ' bytes to scan: 0x', cx, 10

.next_entry:
	cmp cx, 32
	jb .not_found

	mov al, byte [di]
	test al, al
	jz .not_found

	cmp al, 0xe5
	je .skip_entry

	mov al, [di + 11]
	cmp al, 0xf
	je .skip_entry

	test al, 0x8
	jnz .skip_entry

	test al, 0x10
	jnz .skip_entry

	print_trace '[fat12_find_file] Entry @ ', di, ' name: "', !cstr(di | 11)
	print_trace '" attr: 0x', byte [di + 11], 10

	push si
	mov dx, 11

	mov bx, di
.cmp_loop:
	mov al, byte [bx]

	cmp al, byte [si]
	jne .cmp_miss

	inc si
	inc bx
	dec dx
	jnz .cmp_loop

	pop si

	mov ax, word [di + 26]
	mov ebx, dword [di + 28]

	print_trace '[fat12_find_file] MATCH FOUND -> first cluster: 0x', ax, ' size: 0x', ebx, 10

	clc
	pop dx cx di
	ret

.cmp_miss:
	pop si
.skip_entry:
	add di, 32
	sub cx, 32

	jmp .next_entry

.not_found:
	stc
	pop dx cx di
	ret


; In: SI = pointer to 83 name, ECX = bytes to read, ES:DI = destination buffer
; Out: CF=0 -> ok ; CF=1 -> IO error or file not found
fat12_read_file:
	pusha

	print_trace '[fat12_read_file] request name: "', !cstr(si | 11)
	print_trace '" req_bytes: 0x', ecx, 10
	print_trace '[fat12_read_file] buffer target 0x', es, ':0x', di, 10

	assert "[fat12_read_file] di not sector aligned", di align 512
	assert "[fat12_read_file] cx not sector aligned", cx align 512

	call fat12_find_file
	jc .not_found

	test ecx, ecx
	jz .fix_bytes_to_read

	cmp ecx, ebx
	ja .fix_bytes_to_read

	test ax, ax
	jz .done

.align_size:
	add ecx, 511
	and ecx, 0xfffffe00
	print_trace '[fat12_read_file] size(aligned 512): 0x', ecx, 10

.next_cluster:
	cmp ax, 0xff8
	jae .done
	
	cmp ecx, 0
	jz .done

	push ax
	call cluster_to_lba
	mov si, ax
	pop ax

	movzx bx, byte [bootsector.bdb_sectors_per_cluster]
	print_trace '[fat12_read_file] cluster: 0x', ax, ' spc: 0x', bx, ' remaining: 0x', ecx, 10
.search_loop:
	test bx, bx
	jz .cluster_done

	test ecx, ecx
	jz .done

	push ax bx

	print_trace '  -> read LBA: 0x', si, ' -> 0x', es, ':0x', di, ' remain_before: 0x', ecx, 10

	mov dx, 1
	mov bx, di

	call volume_read
	jc .io_fail

	add di, 512

	jnz .no_wrap
	mov dx, es
	add dx, 0x1000
	mov es, dx
.no_wrap:
	inc si
	sub ecx, 512

	pop bx ax
	dec bx

	jmp .search_loop

.cluster_done:
	call fat12_next_cluster
	jc .done

	jmp .next_cluster

.io_fail:
	pop bx ax
	print_trace '[fat12_read_file] I/O Failure when reading file at LBA: 0x', si, ' DI: 0x', di, ' remaining: 0x', ecx, 10

	stc
	popa
	ret

.fix_bytes_to_read:
	mov ecx, ebx
	jmp .align_size

.not_found:
	print_trace '[fat12_read_file] File not found!', 10
	stc
	popa
	ret

.done:
	print_trace '[fat12_read_file] DONE, remaining: 0x', ecx, 10
	clc
	popa
	ret
