include 'fasm2/p5.asm'
include '@@.asm'
include 'struct.asm'
include 'format.asm'

build.mode.Debug = 1
build.mode.Release = 2
build.mode.Trace = 3

build.debug equ build.mode = build.mode.Debug
build.release equ build.mode = build.mode.Release
build.trace equ build.mode = build.mode.Trace

use16
