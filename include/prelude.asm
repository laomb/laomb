include 'fasm2/xcalm.asm'
include 'fasm2/p5.asm'
include 'fasm2/inlinemacro.asm'
include '@@.asm'
include 'struct.asm'
include 'format.asm'

define build

build.mode.Debug = 1
build.mode.Release = 2
build.mode.Trace = 3

build.debug equ build.mode = build.mode.Debug
build.release equ build.mode = build.mode.Release
build.trace equ build.mode = build.mode.Trace

struct FarPointer
	offset dd ?
	selector dw ?
end struct

use16
