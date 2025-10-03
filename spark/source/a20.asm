use32

KBD_CONTROLLER_DATA_PORT = 0x60
KBD_CONTROLLER_COMMAND_PORT = 0x64
KBD_CONTROLLER_DISABLE_KEYBOARD = 0xAD
KBD_CONTROLLER_ENABLE_KEYBOARD = 0xAE
KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT = 0xD0
KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT = 0xD1

SYSTEM_CTRL_PORT_A = 0x92
SYSTEM_CTRL_A20_BIT = 1
SYSTEM_CTRL_INIT_BIT = 0

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

bootstrap_disable_a20:
    in al, SYSTEM_CTRL_PORT_A

    and al, not (1 shl SYSTEM_CTRL_A20_BIT)
    out SYSTEM_CTRL_PORT_A, al
    in al, 0x80 ; delay

    in al, SYSTEM_CTRL_PORT_A
    test al, (1 shl SYSTEM_CTRL_A20_BIT)
    jz .done


    call _a20_wait_input_pm
    mov al, KBD_CONTROLLER_DISABLE_KEYBOARD
    out KBD_CONTROLLER_COMMAND_PORT, al
    in al, 0x80

    call _a20_wait_input_pm
    mov al, KBD_CONTROLLER_READ_CTRL_OUTPUT_PORT
    out KBD_CONTROLLER_COMMAND_PORT, al
    in al, 0x80

    call _a20_wait_output_pm
    in al, KBD_CONTROLLER_DATA_PORT
    push eax

    call _a20_wait_input_pm
    mov al, KBD_CONTROLLER_WRITE_CTRL_OUTPUT_PORT
    out KBD_CONTROLLER_COMMAND_PORT, al
    in al, 0x80

    call _a20_wait_input_pm
    pop eax
    and al, not 2
    out KBD_CONTROLLER_DATA_PORT, al
    in al, 0x80

    call _a20_wait_input_pm
    mov al, KBD_CONTROLLER_ENABLE_KEYBOARD
    out KBD_CONTROLLER_COMMAND_PORT, al
    in al, 0x80

.done:
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

_a20_wait_input_pm:
use32
    in al, KBD_CONTROLLER_COMMAND_PORT
    test al, 2
    jnz _a20_wait_input_pm
    ret

_a20_wait_output_pm:
use32
    in al, KBD_CONTROLLER_COMMAND_PORT
    test al, 1
    jz _a20_wait_output_pm
    ret
