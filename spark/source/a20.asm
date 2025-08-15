use32

KBD_CONTROLLER_DATA_PORT = 0x60
KBD_CONTROLLER_COMMAND_PORT = 0x64
KBD_CONTROLLER_DISABLE_KEYBOARD = 0xAD
KBD_CONTROLLER_ENABLE_KEYBOARD = 0xAE
KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT = 0xD0
KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT = 0xD1

bootstrap_enable_a20:
use16
    call _a20_wait_input
    mov al, KBD_CONTROLLER_DISABLE_KEYBOARD
    out KBD_CONTROLLER_COMMAND_PORT, al

    call _a20_wait_input
    mov al, KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT
    out KBD_CONTROLLER_COMMAND_PORT, al

    call _a20_wait_output
    in al, KBD_CONTROLLER_DATA_PORT
    push eax

    call _a20_wait_input
    mov al, KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT
    out KBD_CONTROLLER_COMMAND_PORT, al

    call _a20_wait_input
    pop eax
    or al, 2
    out KBD_CONTROLLER_DATA_PORT, al

    call _a20_wait_input
    mov al, KBD_CONTROLLER_ENABLE_KEYBOARD
    out KBD_CONTROLLER_COMMAND_PORT, al

    call _a20_wait_input
    ret

_a20_wait_input:
use16
    in al, KBD_CONTROLLER_COMMAND_PORT
    test al, 2
    jnz _a20_wait_input
    ret

_a20_wait_output:
use16
    in al, KBD_CONTROLLER_COMMAND_PORT
    test al, 1
    jz _a20_wait_output
    ret
