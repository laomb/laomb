unit system;

{$MODE FPC}

interface

type
	Void = Byte;

	AnsiChar = #0..#255;
	PAnsiChar = ^AnsiChar;

	HRESULT = LongInt;
	TResult = LongInt;

	TTypeKind = (tkUnknown, tkInteger, tkChar, tkEnumeration, tkFloat, tkSet,
	tkMethod, tkSString, tkLString, tkAString, tkWString, tkVariant, tkArray,
	tkRecord, tkInterface, tkClass, tkObject, tkWChar, tkBool, tkInt64, tkQWord,
	tkDynArray, tkInterfaceRaw, tkProcVar, tkUString, tkUChar, tkHelper, tkFile,
	tkClassRef, tkPointer);

	jmp_buf = packed record
		ebx, esi, edi, ebp, esp, eip: Cardinal;
	end;
	Pjmp_buf = ^jmp_buf;

	PExceptAddr = ^TExceptAddr;
	TExceptAddr = record
		buf: Pjmp_buf; 
		next: PExceptAddr;
		frame: Pointer;
	end;

	PGuid = ^TGuid;
	TGuid = packed record
		Data1: Cardinal;
		Data2: Word;
		Data3: Word;
		Data4: array[0..7] of Byte;
	end;

const
	LineEnding = #10;

implementation

end.
