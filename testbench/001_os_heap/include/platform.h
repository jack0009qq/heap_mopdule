#ifndef __PLATFORM_H__
#define __PLATFORM_H__

/*
 * QEMU RISC-V Virt machine with 16550a UART and VirtIO MMIO
 */

/* 
 * maximum number of CPUs
 * see https://github.com/qemu/qemu/blob/master/include/hw/riscv/virt.h
 * #define VIRT_CPUS_MAX 8
 */
#define MAXNUM_CPU 1

//uart會用到
#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr, val) (*((volatile uint32_t *)(addr)))

#define CTRL_BASE 0x1000000
#define CTRL_OUT  0x4
#define CTRL_CTRL 0x8

/*
 * MemoryMap
 * see https://github.com/qemu/qemu/blob/master/hw/riscv/virt.c, virt_memmap[] 
 * 0x00001000 -- boot ROM, provided by qemu
 * 0x02000000 -- CLINT
 * 0x0C000000 -- PLIC
 * 0x10000000 -- UART0
 * 0x10001000 -- virtio disk
 * 0x80000000 -- boot ROM jumps here in machine mode, where we load our kernel
 */

/* This machine puts UART registers here in physical memory. */
#define UART0 0x10000000L

#define CLINT_BASE 0x2000000L
//在宏定义中，不需要使用等号将整个表达式赋值给宏
//只需指定宏的名称和其替换文本
#define CLINT_MSIP(hartid) (CLINT_BASE + 4 * (hartid))
//定义 CLINT 的定时器比较寄存器偏移量 固定的
#define CLINT_MTIMECMP(hartid) (CLINT_BASE + 0x4000 + 8 * (hartid))
//MTIME暫存器會自己隨著時間變化
//MTIME暫存器的映射位置
#define CLINT_MTIME (CLINT_BASE + 0xBFF8)

#define CLINT_TIMEBASE_FREQ 10000000

#endif /* __PLATFORM_H__ */
