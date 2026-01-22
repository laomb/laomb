BUILD_MODE_LC := $(shell printf '%s' '$(BUILD_MODE)' | tr '[:upper:]' '[:lower:]')

ifeq ($(BUILD_MODE_LC),release)
  BUILD_MODE_CANON := Release
  FASMG_MODE_LINE := build.mode = build.mode.Release
  FASMG_TRACE_LINE :=
else ifeq ($(BUILD_MODE_LC),trace)
  BUILD_MODE_CANON := Trace
  FASMG_MODE_LINE := build.mode = build.mode.Debug
  FASMG_TRACE_LINE := build.mode.Trace = 1
else ifeq ($(BUILD_MODE_LC),debug)
  BUILD_MODE_CANON := Debug
  FASMG_MODE_LINE := build.mode = build.mode.Debug
  FASMG_TRACE_LINE :=
else
  $(warning unknown BUILD_MODE='$(BUILD_MODE)', defaulting to Debug)
  BUILD_MODE_CANON := Debug
  FASMG_MODE_LINE := build.mode = build.mode.Debug
  FASMG_TRACE_LINE :=
endif
