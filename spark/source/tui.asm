use32

SCREEN_WIDTH = 80
SCREEN_HEIGHT = 25

CH_UL_SINGLE = 0xDA ; ┌
CH_UR_SINGLE = 0xBF ; ┐
CH_LL_SINGLE = 0xC0 ; └
CH_LR_SINGLE = 0xD9 ; ┘
CH_H_SINGLE = 0xC4 ; ─
CH_V_SINGLE = 0xB3 ; │

CH_UL_DOUBLE = 0xC9 ; ╔
CH_UR_DOUBLE = 0xBB ; ╗
CH_LL_DOUBLE = 0xC8 ; ╚
CH_LR_DOUBLE = 0xBC ; ╝
CH_H_DOUBLE = 0xCD ; ═
CH_V_DOUBLE = 0xBA ; ║

CH_T_LEFT_SINGLE = 0xC3 ; ├
CH_T_RIGHT_SINGLE = 0xB4 ; ┤
CH_T_TOP_SINGLE = 0xC2 ; ┬
CH_T_BOTTOM_SINGLE = 0xC1 ; ┴
CH_CROSS_SINGLE = 0xC5 ; ┼

MENU_W = 46
MENU_H = 9
MENU_X = ((SCREEN_WIDTH - MENU_W) / 2)
MENU_Y = ((SCREEN_HEIGHT - MENU_H) / 2)

TITLE_Y = MENU_Y
TITLE_TEXT_X = MENU_X + 2

ITEMS_TOP_Y = MENU_Y + 3
ITEMS_LEFT_X = MENU_X + 3

ITEM_COUNT = 2

SC_UP = 0x48
SC_DOWN = 0x50

tui_title: db 'Spark Boot Manager', 0
item0_text: db 'Boot LAOMB', 0
item1_text: db 'Chainboot MS-DOS', 0

items_table:
    dd item0_text
    dd item1_text

sel_index: dd 0

ch_space: db ' ', 0
ch_gt: db '>', 0
ch_dash: db '-', 0

ch_ul_single: db CH_UL_SINGLE, 0
ch_ur_single: db CH_UR_SINGLE, 0
ch_ll_single: db CH_LL_SINGLE, 0
ch_lr_single: db CH_LR_SINGLE, 0
ch_h_single: db CH_H_SINGLE, 0
ch_v_single: db CH_V_SINGLE, 0
ch_t_top: db CH_T_TOP_SINGLE, 0
ch_t_left: db CH_T_LEFT_SINGLE, 0
ch_t_right: db CH_T_RIGHT_SINGLE, 0

tui_enter:
    mov esi, debug_tui_enter
    call serial_puts
    call serial_crlf

    xor al, al
    call print_set_serial_mirror

    mov dword [sel_index], 0

    call tui_cursor_hide
    call tui_clear_screen
    call tui_draw_frame
    call tui_draw_title
    call tui_draw_menu

.tui_loop:
    call tui_get_key
    cmp ah, SC_UP
    je .key_up
    cmp ah, SC_DOWN
    je .key_down
    cmp al, 0x0D
    je .key_enter
    jmp .tui_loop

.key_up:
    mov eax, [sel_index]
    test eax, eax
    jz .no_up
    dec eax
    mov [sel_index], eax
    call tui_draw_menu
.no_up:
    jmp .tui_loop

.key_down:
    mov eax, [sel_index]
    cmp eax, (ITEM_COUNT - 1)
    jae .no_down
    inc eax
    mov [sel_index], eax
    call tui_draw_menu
.no_down:
    jmp .tui_loop

.key_enter:
    mov eax, [sel_index]
    test eax, eax
    jz .launch_laomb
    jmp .launch_msdos

.launch_laomb:
    call tui_clear_screen
    call tui_cursor_show
    jmp boot_laomb

.launch_msdos:
    call tui_clear_screen
    call tui_cursor_show
    jmp chainboot_msdos

tui_clear_screen:
    pushad
    enter_real_mode

    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, ((SCREEN_HEIGHT-1) shl 8) or (SCREEN_WIDTH-1)
    int 0x10

    mov ah, 0x02
    mov bh, 0x00
    mov dh, 0
    mov dl, 0
    int 0x10

    enter_protected_mode
    popad
    ret

tui_gotoxy:
    pushad
    enter_real_mode
    mov ah, 0x02
    mov bh, 0x00
    int 0x10
    enter_protected_mode
    popad
    ret

tui_print_at:
    pushad
    call tui_gotoxy
    push esi
.print_loop:
    mov al, [esi]
    test al, al
    jz .done
    call print_char
    inc esi
    jmp .print_loop
.done:
    pop esi
    popad
    ret

tui_putc_at:
    pushad
    movzx eax, al
    push eax
    call tui_gotoxy
    pop eax
    call print_char
    popad
    ret

tui_draw_frame:
    pushad

    mov dl, MENU_X
    mov dh, MENU_Y
    mov al, CH_UL_SINGLE
    call tui_putc_at

    mov dl, MENU_X + MENU_W - 1
    mov dh, MENU_Y
    mov al, CH_UR_SINGLE
    call tui_putc_at

    mov dl, MENU_X
    mov dh, MENU_Y + MENU_H - 1
    mov al, CH_LL_SINGLE
    call tui_putc_at

    mov dl, MENU_X + MENU_W - 1
    mov dh, MENU_Y + MENU_H - 1
    mov al, CH_LR_SINGLE
    call tui_putc_at

    mov ecx, MENU_W - 2

    mov dl, MENU_X + 1
    mov dh, MENU_Y
.top_h_loop:
    mov al, CH_H_SINGLE
    call tui_putc_at
    inc dl
    loop .top_h_loop

    mov ecx, MENU_W - 2
    mov dl, MENU_X + 1
    mov dh, MENU_Y + MENU_H - 1
.bot_h_loop:
    mov al, CH_H_SINGLE
    call tui_putc_at
    inc dl
    loop .bot_h_loop

    mov ecx, MENU_H - 2

    mov dl, MENU_X
    mov dh, MENU_Y + 1
.left_v_loop:
    mov al, CH_V_SINGLE
    call tui_putc_at
    inc dh
    loop .left_v_loop

    mov ecx, MENU_H - 2
    mov dl, MENU_X + MENU_W - 1
    mov dh, MENU_Y + 1
.right_v_loop:
    mov al, CH_V_SINGLE
    call tui_putc_at
    inc dh
    loop .right_v_loop

    mov dl, MENU_X
    mov dh, MENU_Y + 2
    mov al, CH_T_LEFT_SINGLE
    call tui_putc_at

    mov ecx, MENU_W - 2
    mov dl, MENU_X + 1
    mov dh, MENU_Y + 2
.sep_h_loop:
    mov al, CH_H_SINGLE
    call tui_putc_at
    inc dl
    loop .sep_h_loop

    mov dl, MENU_X + MENU_W - 1
    mov dh, MENU_Y + 2
    mov al, CH_T_RIGHT_SINGLE
    call tui_putc_at

    popad
    ret

tui_draw_title:
    pushad
    mov esi, tui_title
    mov dl, TITLE_TEXT_X
    mov dh, TITLE_Y + 1
    call tui_print_at
    popad
    ret

tui_draw_menu:
    pushad

    mov ebx, [sel_index]
    xor edi, edi

.draw_each:
    cmp edi, ITEM_COUNT
    jae .done

    mov eax, edi
    shl eax, 1
    add eax, ITEMS_TOP_Y
    mov dh, al
    mov dl, ITEMS_LEFT_X

    cmp edi, ebx
    jne .prefix_space

    mov al, '>'
    call tui_putc_at
    jmp .after_prefix
.prefix_space:
    mov al, ' '
    call tui_putc_at
.after_prefix:
    mov dl, ITEMS_LEFT_X + 1
    mov al, ' '
    call tui_putc_at

    mov esi, [items_table + edi * 4]
    mov dl, ITEMS_LEFT_X + 3
    call tui_print_at

    inc edi
    jmp .draw_each

.done:
    popad
    ret

tui_cursor_hide:
    pushad
    enter_real_mode

    mov ah, 0x01
    mov ch, 0x20
    mov cl, 0x00
    int 0x10

    enter_protected_mode
    popad
    ret

tui_cursor_show:
    pushad
    enter_real_mode

    mov ah, 0x01
    mov ch, 0x06
    mov cl, 0x07
    int 0x10

    enter_protected_mode
    popad
    ret

tui_get_key:
    pushad
    sub esp, 4

    enter_real_mode

    xor ah, ah
    int 0x16

    mov [esp], ax
    enter_protected_mode

    mov esi, debug_k_hdr
    call serial_puts

    movzx eax, word [esp]
    mov al, ah
    call serial_put_hex8
    mov al, ' '
    call serial_write_char
    mov al, 'A'
    call serial_write_char
    mov al, 'L'
    call serial_write_char
    mov al, '='
    call serial_write_char

    movzx eax, word [esp]
    call serial_put_hex8
    call serial_crlf

    movzx eax, word [esp]
    add esp, 4
    mov [esp + 28], eax
    popad
    ret

debug_k_hdr: db '[K] AH=', 0
debug_tui_enter: db '[DEBUG] Entering TUI main loop', 0
