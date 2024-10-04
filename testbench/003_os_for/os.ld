OUTPUT_ARCH("riscv")
/* 指定產生的輸出檔案的架構*/
ENTRY(_start)
 /* 指定程式的入口點，這裡設定為 _start */
MEMORY
{
    ram  (wxa!ri): ORIGIN = 0x80000000 , LENGTH = 128M
}
/*  0x80000000根據memmap的內存起始位置
    0x08000000大約等於128mb 
    W(可寫),X(可執行),A(可分配)
    不 R唯獨 I初始化*/
SECTIONS
{
    /*text=放程式碼*/
    .text : {
        PROVIDE(_text_start = .);
        *(.text .text.*)
        PROVIDE(_text_end = .);
    }   >ram
    /* .text是code 
        .就是現在的位址
         PROVIDE(_text_start = .); ==0x80000000
    */
    /*rodata=放如字符串常量、只读变量*/
    .rodata : {
        PROVIDE(_rodata_start = .);
        *(.rodata .rodata.*)
        PROVIDE(_rodata_end = .);
    }   >ram
    /*data=放變數*/
    .data : {
        . = ALIGN(4096);
        PROVIDE(_data_start = .);
        *(.sdata .sdata.*)
        *(.data .data.*)
        PROVIDE(_data_end = .);
    } >ram
    /* 可以修改的data 
         . = ALIGN(4096); 對齊
    */
    /*bss=放變數*/
    .bss :{
        PROVIDE(_bss_start = .);
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        PROVIDE(_bss_end = .);
    } >ram

    PROVIDE(_memory_start = ORIGIN(ram));
    PROVIDE(_memory_end = ORIGIN(ram) + LENGTH(ram));

    PROVIDE(_heap_start = _bss_end);
    PROVIDE(_heap_size = _memory_end - _heap_start);
    
}