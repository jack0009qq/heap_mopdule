#include "os.h"

extern void trap_vector(void);
extern void ctx_handler(void);
extern taskCB_t  TCBReady[];

// taskCB_t    TCBReady[PRIO_LEVEL];

void trap_init(){
    //當發生 interrupt 或是 exception 時，(PC 會根據該 mtvec 所指向的地址繼續執行，CPU做的)
    w_mtvec((reg_t)trap_vector);
    w_mctxvec((reg_t)ctx_handler);
}

reg_t trap_handler(reg_t epc, reg_t cause){
    reg_t return_pc = epc;
    reg_t cause_code = cause & 0xfff;//取低位12個bits

    if (cause & 0x80000000) {
        switch (cause_code) {
            //Machine software interrupt
            case 3:
                uart_puts("software interruption\n");
                break;
            //Machine timer interrupt
            case 7:
                uart_puts("timer interruption\n");
                timer_handler();
                break;
            //Machine external interrupt
            case 11:
                uart_puts("external interruption\n");
                break;
            default :
                uart_puts("unknown async exception!\n");
                break;
        }
    } else {
        kprintf("Sync exceptions!, code = %d\n" , cause_code);
        while (1)
        {
            int mcycle = r_mcycle();
            kprintf ("finshedddddddddddd %d\n",mcycle);
        }

        panic("OOPS!");
        //在panic卡住
        
        
        //return_pc += 4;
    }

    return return_pc;
}

reg_t heap_handler(reg_t ctx, reg_t pc){
    reg_t ctx_ptr = ctx;
    size_t task_offset = offsetof(taskCB_t, ctx);
    taskCB_t *task = (taskCB_t *)((char *)ctx_ptr - task_offset);
    list_insert_before((list_t*)&TCBReady[task->priority], (list_t*)task);
    return ;
}

void trap_test(){
    int a = *(int *)0x00000000;

    a = 100;

    uart_puts("I divide 0");

    //為何除以零無法觸發exception?

}
