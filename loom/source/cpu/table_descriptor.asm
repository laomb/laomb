
struct TableDescriptor
	limit dw ?
	base dd ?
end struct

macro cpu$PUSH_TABLE_DESCRIPTOR lim*, ptr*
	sub esp, sizeof.TableDescriptor

	mov word [esp + TableDescriptor.limit], lim
	mov dword [esp + TableDescriptor.base], ptr

	macro cpu$POP_TABLE_DESCRIPTOR
		add esp, sizeof.TableDescriptor

		purge cpu$POP_TABLE_DESCRIPTOR
	end macro
end macro
