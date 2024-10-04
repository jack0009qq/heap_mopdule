#ifndef __TASK_H__
#define __TASK_H__

#include "types.h"
#include "list.h"

#define TASK_INIT               0x00
#define TASK_READY              0x01
#define TASK_SUSPEND            0x02
#define TASK_RUNNING           0x03

//定義context的結構叫做ctx_t
typedef struct context {
    //reg_t zero;
    reg_t ra;   //return address
    reg_t sp;   //stack pointer
    reg_t gp;   //global pointer
    reg_t tp;   //thread pointer
    reg_t t0;   //temporary link register
    reg_t t1;   //temporaries
    reg_t t2;   //temporaries
    reg_t s0;   //saved regsiter
    reg_t s1;   //saved register
    reg_t a0;   //function arguments
    reg_t a1;   
    reg_t a2;
    reg_t a3;
    reg_t a4;
    reg_t a5;
    reg_t a6;
    reg_t a7;
    reg_t s2;
    reg_t s3;
    reg_t s4;
    reg_t s5;
    reg_t s6;
    reg_t s7;
    reg_t s8;
    reg_t s9;
    reg_t s10;
    reg_t s11;
    reg_t t3;
    reg_t t4;
    reg_t t5;
    reg_t t6;

    reg_t pc;
} ctx_t;

//taskCB_t 結構
typedef struct taskCB
{
    //node變數類型是雙鏈結串列
    list_t      node;
    char        name[10];
    uint32_t    taskID;

    //entry function 
    void        *entry;
    void        *parameter;

    //stack
    void        *stack_addr;
    uint32_t    stack_size;
    void        *sp;

    //context
    ctx_t       ctx;

    state_t     state;//task status

    //priority
    uint8_t     priority;
    uint8_t     number;
    uint8_t     high_mask;
    uint32_t    number_mask;

}  taskCB_t;

#endif
