#include "os.h"
//void  readyQ_init() = 將TCBReady的list做初始化

//taskCB_t  getNewTCB(uint8_t index) = 回傳一個TCBTable[index]的起始位址

//task_init = 1.malloc一塊stack  2.把name、function、參數 放進tcb裡面
//            3.將stack設0  4.設ctx.ra和ctx.sp  5.設priority    6.將ptcb的list做初始化

//void  task_startup(taskCB_t *ptcb) =ptcb裡的state設suspend

//err_t task_resume(taskCB_t *ptcb) =

//err_t task_yield(void) = 

//產生task，接下來掛到ready queue步驟如下
//getNewTCB -> initial task(task_init) -> task_startup
//task 可在程式中呼叫 task_yield()來讓出cpu的使用權

//設定256個TCB
taskCB_t    TCBTable[MAX_USER_TASKS + SYS_TASK_NUM];
//stack of IDLE task
uint32_t    idle_stk[SYS_STACK_SIZE] = {0};
//TCBRdy: 一個 (circular double link list) ready Queue.
taskCB_t    TCBReady[PRIO_LEVEL];
//TCBRunning: 指標指向目前執行的 task。
uint32_t    priority_group;
uint8_t     ready_table[32];
taskCB_t    *TCBRunning = NULL;
taskCB_t    *FreeTCB    = NULL;
extern void heap_insert();

void InitTCBList(void)
{
    uint16_t i;
    taskCB_t * ptcb0;
    taskCB_t * ptcb1;

    //建立一個free TCB list
    FreeTCB = &TCBTable[0];
    FreeTCB ->node.prev = NULL;
    FreeTCB ->node.next = NULL;

    FreeTCB ->state = TASK_INIT;
    FreeTCB ->taskID = 0;
    ptcb1 = &TCBTable[1];

    for(i=1; i<MAX_USER_TASKS + SYS_TASK_NUM; i++){
        ptcb1 -> taskID = i;
        ptcb1 -> state  = TASK_INIT;
        ptcb1 -> node.next = NULL;
        ptcb1 -> node.prev =NULL;
        //建造一個單鏈的TCB list
        ptcb0 = ptcb1 - 1;
        ptcb0 -> node.next = (list_t *)ptcb1;
        ptcb1++;
    }

}

static taskCB_t * _getFreeTCB(void)
{
    taskCB_t * ptcb;

    spin_lock();
    if(FreeTCB == NULL)
    {
        spin_unlock();
        return NULL;
    }
    ptcb = FreeTCB;
    FreeTCB = (taskCB_t *)ptcb->node.next;
    ptcb->node.next = NULL;
    ptcb->node.prev = NULL;
    spin_unlock();
    return ptcb;
}


void readyQ_init(){
    for(int i = 0; i < PRIO_LEVEL; i++)
        list_init((list_t*)&TCBReady[i]);
}

taskCB_t    *getNewTCB(uint8_t index){
    return &TCBTable[index];
}

err_t task_init(taskCB_t *ptcb
                , const char *name
                , void(*taskFunc)(void *parameter)
                , void  *parameter
                , uint32_t  stack_size
                , uint16_t  priority)
{
    //1. ptcb = 傳進來的control block
    //2. name
    //3. task的工作
    //4. 參數
    //5. 堆疊大小
    //6. 優先級
    void *stack_start;
    stack_start = (void *)malloc(stack_size);
    if (stack_start == NULL){
        return ERROR;
        //ERROR = -1
    }
    //memcpy(要存的地方，要存的東西，存幾個)
    //entry指向task的工作
    memcpy(ptcb->name, name, sizeof(ptcb->name));
    ptcb->entry = (void *)taskFunc;
    ptcb->parameter = parameter;

    //init 堆疊
    memset(ptcb->stack_addr, 0, ptcb->stack_size);

    ptcb->ctx.ra = (reg_t)taskFunc;
    ptcb->ctx.sp = (reg_t)(stack_start + stack_size);

    ptcb->priority  = priority;
    ptcb->number = 0;
    ptcb->high_mask = 0;
    ptcb->number_mask = 0;
    //---------------------------------
    list_init((list_t*)ptcb);
    return 0;    
}

//先要一個tcb
//然後把藉由task_init填資料
taskCB_t * task_create(const char *name,
                        void (*taskFunc)(void *parameter),
                        void        *parameter,
                        uint32_t    stack_size,
                        uint16_t    priority)
{
    taskCB_t *ptcb = _getFreeTCB();
    if (ptcb == NULL) { return NULL; }
    err_t ret = task_init(ptcb, name, taskFunc, parameter, stack_size, priority);
    if (ret == 0)
        return ptcb;
    return NULL;
}
//--------------------------------------由這裡輸入給heap模組
void task_startup(taskCB_t *ptcb){
    ptcb->state = TASK_SUSPEND;
    //priority--------------------------------------------
    ptcb->number = ptcb->priority >> 3;
    ptcb->number_mask = 1L << ptcb->number;
    ptcb->high_mask = 1L << (ptcb->priority & 0x07);

    task_resume(ptcb);
}

// +

err_t task_resume(taskCB_t *ptcb){
    if (ptcb->state != TASK_SUSPEND){
        return ERROR;
    }
    //timer_stop??
    //because ready queue is global and share, it is critical.
    spin_lock();
    list_remove((list_t*)ptcb);
    list_insert_before((list_t*)&TCBReady[ptcb->priority], (list_t*)ptcb);
    //priority group
    ready_table[ptcb->number] |= ptcb->high_mask;
    priority_group |= ptcb->number_mask;

    spin_unlock();
    return 0;
}

err_t task_suspend(taskCB_t * ptcb)
{
    if (ptcb->state != TASK_READY)
    {
        return ERROR;
    }

    spin_lock();
    list_remove((list_t*)ptcb);
    ptcb->state = TASK_SUSPEND;
    spin_unlock();
    return 0 ;
}

err_t task_yield(void){
    taskCB_t *ptcb;

    spin_lock();

    ptcb =TCBRunning;
    if(ptcb->state == TASK_READY){
        list_remove((list_t*)ptcb);
        list_insert_before((list_t*)&TCBReady, (list_t*)ptcb);
        spin_unlock();
        schedule();
        return 0;
    }
    spin_unlock();
    schedule();
    return 0;
}

