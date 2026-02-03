unit test;

interface

procedure vga_print(str: PAnsiChar); external name 'vga$print';

implementation

procedure pascal_entry; public name 'pas$test';
begin
	vga_print('Hello from Pascal Segment!'#10);
end;

end.
