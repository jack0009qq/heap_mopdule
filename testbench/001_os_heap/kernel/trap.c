#include "os.h"

extern void trap_vector(void);
extern void ctx_handler(void);
extern taskCB_t  TCBReady[];

extern uint32_t priority_group;
extern uint8_t ready_table[32];

extern int fulldontinsert;

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
    
    //test
    taskCB_t *readyQ = NULL;
    taskCB_t *nextTask = NULL;
    //test
    
    
    reg_t ctx_ptr = ctx;
    size_t task_offset = offsetof(taskCB_t, ctx);
    taskCB_t *task = (taskCB_t *)((char *)ctx_ptr - task_offset);
    //kprintf("task_priority = %d \n",task->priority);
    list_insert_before((list_t*)&TCBReady[task->priority], (list_t*)task);
    
    //test
    readyQ = &TCBReady[task->priority];
    nextTask = (taskCB_t*)readyQ->node.next;
    //test


    //kprintf("TCB = %p \n",&TCBReady[task->priority]);
    //kprintf("TCB_next = %p \n",nextTask);

    ready_table[task->number] |= task->high_mask;
    priority_group |= task->number_mask;

    //fulldontinsert = 1;
    
    return 0;
}

reg_t heapempty_handler(){
    schedule2();      
    return 0;
}

