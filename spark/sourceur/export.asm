
spark_export_table:
    dd str_TestStr
    dd ptr_TestStr
    dd 2
    dd 0

ptr_TestStr: dw 0x1234
str_TestStr: db 'boot$test_str', 0
