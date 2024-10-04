#include "os.h"

extern void switch_to(struct context *next);
extern int task_clz();
extern  taskCB_t TCBReady[];
extern  taskCB_t *TCBRunning;
extern uint32_t priority_group;
extern uint8_t ready_table[32];

void sched_init(){   
    //在riscv.h
    w_mscratch(0);
}
/*
流程
schedule => task0 => task_yeld => schedule                         
1.把ReadyQ的next task 拿出來放進Running   
2.依靠 task0的ctx(32個暫存器) swtich to task0 (ra暫存器)
3.做完task0 依靠task_yield 再次呼叫schedule

*/
//-------------------------------------不需要READYQ 直接switch
//-------------------------------------新建一個CSR放heap的第一位
void schedule(){
    taskCB_t *nextTask;
    ctx_t *next;
    taskCB_t *readyQ = NULL;
    
    for(int i = 0; i<PRIO_LEVEL; i++){
        if (!list_isempty((list_t*)&TCBReady[i])){
            readyQ = &TCBReady[i];
            break;
        }
    }



    

    //register 用意?
    register ubase_t highest_priority;
    register ubase_t number;

    // number = task_clz(priority_group) - 1;
    // highest_priority = (number << 3) + task_clz(ready_table[number]) - 1;
    // readyQ = &TCBReady[highest_priority];
    if (readyQ == NULL) return;

    //因為 ready queue (TCBRdy)是串了所有ready的TCB
    //nextTask = ready裡面的next Task
    nextTask = (taskCB_t*)readyQ->node.next;
    //->访问运算符，*next = nextTask結構裡的ctx
    //点号“.”用于直接访问结构体或联合体变量的成员。
    //箭头符号“->”用于通过指针访问指向结构体或联合体的成员。
    next = &nextTask->ctx;
    list_remove((list_t*)nextTask); //把nextTask前後接自己

    //------------------------------------------------
    // if(list_isempty((list_t*)&TCBReady[nextTask->priority])){
    //     ready_table[nextTask->number] &= ~nextTask->high_mask;
    //     if (ready_table[nextTask->number] == 0){
    //         priority_group &= ~nextTask->number_mask;
    //     }
    // }
    //------------------------------------------------
    //current task into ready queue
    //把目前執行完的running task放進readyQ裡
    // if (TCBRunning != NULL){
    //     taskCB_t *currentTask = TCBRunning;
    //     if (currentTask -> priority < nextTask -> priority)
    //         return;
    //     currentTask->state = TASK_READY;
    //            list_insert_before((list_t*)&TCBReady[currentTask->priority], (list_t*)currentTask);
    // } 
    TCBRunning = nextTask;
    nextTask->state = TASK_RUNNING;
    
    int mcycle = r_mcycle();
	kprintf ("%d\n",mcycle);

    switch_to(next);//next是下個task的ctx起始位置
}
