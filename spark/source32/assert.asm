


assert_fail_pmode:
    push esi

    mov esi, str_assert_fail
    call print_str_pmode

    pop esi
    jmp panic_pmode
