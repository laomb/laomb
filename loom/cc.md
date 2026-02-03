# Loom Kernel Calling Convention (LoomCC)

## Overview
Loom uses a custom register-based calling convention optimized for 32-bit x86 protected mode. It prioritizes speed by passing the first three arguments in general-purpose registers, minimizing stack overhead.

## Register Assignment

| Type          	| Register(s)      | Notes                                    |
| :---------------: | :--------------: | :--------------------------------------: |
| **Argument 1**	| `EAX`            | Primary input / Accumulator              |
| **Argument 2**	| `EDX`            | Secondary input / Data                   |
| **Argument 3**	| `ECX`            | Third input / Counter                    |
| **Argument 4+**	| `Stack`          | Pushed Right-to-Left                     |
| **Return** 		| `EAX`            | Primary return value                     |
| **Error/Stat**	| `EFLAGS` (CF)    | Carry Flag: 0 = Success, 1 = Error       |

## Preservation Rules

### Caller-Saved (Volatile)
*The caller must save these if they need the values after the function returns.*
* `EAX`, `ECX`, `EDX`, `DS`
* `EFLAGS`, `ES`, `FS`, `GS`

### Callee-Saved (Non-Volatile)
*The function must preserve these values if it modifies them.*
* `EBX` (Base register)
* `ESI` (Source index)
* `EDI` (Destination index)
* `EBP` (Stack frame)
* `ESP` (Stack pointer)
* `CS`  (Code segment)
* `SS`  (Stack segment)
