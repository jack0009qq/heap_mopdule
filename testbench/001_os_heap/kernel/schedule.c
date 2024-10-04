#include "os.h"

extern void switch_to2(struct context *next);
extern void switch_to();
extern int task_clz();
extern  taskCB_t TCBReady[];
extern  taskCB_t *TCBRunning;

extern uint32_t priority_group;
extern uint8_t ready_table[32];

void sched_init(){   
    //在riscv.h
    w_mscratch(0);
}

void schedule(){
    

    int mcycle = r_mcycle();
	  kprintf ("%d\n",mcycle);
    //kprintf ("schedele \n");
    switch_to();//next是下個task的ctx起始位置
  
}
/*
schedule2
當heap做完會進到這
這裡會把qeueue的task放進heap裡(heap_insert)
接這進到switch繼續執行
*/

void schedule2(){
    taskCB_t *nextTask = NULL;
    taskCB_t *switch_nextTask = NULL;
    // ctx_t *next;
    taskCB_t *readyQ = NULL;

    int max_heap = 254;

    register ubase_t highest_priority;
    register ubase_t number;

    int heap_task_count = 0;
    
      
    number = task_clz(priority_group) - 1;
    highest_priority = (number << 3) + task_clz(ready_table[number]) - 1;
    
    readyQ = &TCBReady[highest_priority];
    nextTask = (taskCB_t*)readyQ->node.next;
    switch_nextTask = &nextTask->ctx;    
    list_remove((list_t*)nextTask);


    if(list_isempty((list_t*)&TCBReady[nextTask->priority])){
        ready_table[nextTask->number] &= ~nextTask->high_mask;
        if (ready_table[nextTask->number] == 0){
            priority_group &= ~nextTask->number_mask;
        }
      }
    
    //同個priorty塞到爆滿還沒解決
    while(nextTask != &TCBReady[highest_priority]){
      readyQ = &TCBReady[highest_priority];
      nextTask = (taskCB_t*)readyQ->node.next;
      task_resume(nextTask);        
      if(list_isempty((list_t*)&TCBReady[nextTask->priority])){
        ready_table[nextTask->number] &= ~nextTask->high_mask;
        if (ready_table[nextTask->number] == 0){
            priority_group &= ~nextTask->number_mask;
        }
      }
      heap_task_count ++ ;
      if(heap_task_count == max_heap)
        break;
    }
      
    switch_to2(switch_nextTask);//next是下個task的ctx起始位置

}
