#include "os.h"
/*
時間中斷流程
1.把mstatus的中斷打開,把mie的時間中斷打開
2.設定mtimecmp的大小
3.硬體->mtime會自己跑然後與mtimecmp比較
4.兩者相等候發生時間中斷
5.進入mtvec(traphandler)的位置
6.根據mcause(case 7)進入timer_handler
7.進入timeload把mtimecmp + 時間已進行下次時間中斷

mtime與mtimecmp發生中斷後並不會reset
*/
uint32_t _tick = 0;//_全域變數命名

void timer_init(){
    timer_load(SYSTEM_TICK);
    w_mie(r_mie() | MIE_MTIE);//把timer interrupt enable打開
    //mtie = (1 << 7)
    //MEIE  MTIE  MSIE  
    //11    7     3
    //External timer software
    w_mstatus(r_mstatus() | MSTATUS_MIE);//把interrupt enable打開
    //mie  = (1 << 3) 
    //MIE
    //3
    // uart_puts("here stuck");
}

//load timer interval(in ticks) for next timer interrupt.
void timer_load(int interval){
    int id = r_mhartid();
    //設定mtimecmp 也就是timer中斷的時間 
    *(uint64_t*)CLINT_MTIMECMP(id) = *(uint64_t*)CLINT_MTIME + interval;
}

void  timer_handler(){
    _tick++;
    kprintf("ticktock: %d\n", _tick);

    timer_load(SYSTEM_TICK);
}

