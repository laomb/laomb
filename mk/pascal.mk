FPC ?= fpc
LUA ?= lua

FPC_FLAGS ?= -n -Mfpc -Anasm -Si -O2 -an -al -Xd \
			 -Sc -Sg -Rintel \
			 -CpPENTIUM \
			 -CfX87 \
			 -O3 \
			 -Pi386

FPC2FASMG_SCRIPT ?= mk/fpc2fasmg.lua

pascal_get_inc = $(patsubst $(2)/%.pas, $(3)/%.inc, $(1))

define pascal_generate_rules
$(2)/%.s: $(1)/%.pas
	$$(call mkdir_p,$$(dir $$@))
	$$(FPC) $$(FPC_FLAGS) \
		$$(addprefix -Fi,$(3)) \
		$$(addprefix -Fu,$(3)) \
		-FE$$(dir $$@) \
		-o$$(basename $$@).o \
		$$<

$(2)/%.inc: $(2)/%.s
	$$(call mkdir_p,$$(dir $$@))
	$$(LUA) $$(FPC2FASMG_SCRIPT) $$< $$@
endef
