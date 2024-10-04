#ifndef __RISCV_H__
#define __RISCV_H__

#include "types.h"
//以下中斷csr講解
//https://dingfen.github.io/risc-v/2020/08/05/riscv-privileged.html
//Machine Status Register , mstatus
#define MSTATUS_MIE (1 << 3) //mstatus第三個bit MIE
#define MSTATUS_SIE (1 << 1) //第一個bit SIE
#define MSTATUS_UIE (1 << 0) //第零個bit UIE

static inline reg_t r_mcycle()
{
	reg_t x;
	asm volatile("csrr %0, mcycle" : "=r" (x) );
	return x;
}


static inline reg_t r_mstatus()
{
    reg_t x;
    asm volatile("csrr %0, mstatus" : "=r" (x));
    return x;
}

static inline void w_mstatus(reg_t x)
{
    asm volatile("csrw mstatus, %0" : : "r" (x));
}

//MIE
#define MIE_MEIE (1 << 11) // external
#define MIE_MTIE (1 << 7) // timer
#define MIE_MSIE (1 << 3) // software

static inline  reg_t r_mie(){
    reg_t x;
    asm volatile("csrr %0, mie" : "=r" (x));
    return x;
}

static inline void w_mie(reg_t x){
    asm volatile("csrw mie, %0" : : "r" (x));
}

static inline void w_mscratch(reg_t x){
    //asm 告訴編譯器等下要用組語
    //volatile不要對程式碼優化
    //csrw mscratch, x
    asm volatile("csrw mscratch, %0"    :   :   "r" (x));
}

static inline void w_mtvec(reg_t x){
    asm volatile("csrw mtvec, %0" : : "r" (x));
}

static inline void w_mctxvec(reg_t x){
    asm volatile("csrw mctxvec, %0" : : "r" (x));
}


static inline  reg_t r_mhartid(){
    reg_t x;
    asm volatile("csrr %0, mhartid" : "=r" (x));
    return x;
}

#endif
