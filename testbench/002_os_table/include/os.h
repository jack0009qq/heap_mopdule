#ifndef __OS_H__
#define __OS_H__

#include "types.h"
#include "config.h"
#include "platform.h"
#include "task.h"
#include "list.h"
#include "riscv.h"

#include <stddef.h>
#include <stdarg.h>

/* uart */
void uart_init();
int uart_putc(char ch);
void uart_puts(char *s);
// char uart_getc();
// void uart_gets(char *buffer);


/* printf */
int  kprintf(const char* s, ...);
void panic(char *s);

/*scanf*/
// int scanf(const char *fmt, ...);

/* mem */
void *memset(void *ptr, int value, size_t num);
char* memcpy(void* dest,const void* src, size_t num); 

//lock
int spin_lock();
int spin_unlock();

//page
void page_init();
void *page_alloc(int npages);
void page_free(void *p);
void *malloc(size_t size);
void free(void *p);

//sched
void sched_init();
void schedule();

//trap
void trap_init();
reg_t trap_handler(reg_t epc, reg_t cause);
reg_t heap_handler(reg_t ctx, reg_t pc);
// void trap_test();

//timer
void timer_init();
void timer_load(int interval);
void timer_handler();

//task
void InitTCBList(void);
void readyQ_init();
void loadTasks(void);
err_t task_yield(void);
err_t task_resume(taskCB_t *ptcb);
taskCB_t * getNewTCB(uint8_t index);
err_t task_init(taskCB_t *ptcb, const char *name,
                  void (*taskFunc)(void *parameter),
                  void       *parameter,
                  uint32_t    stack_size,
                  uint16_t    priority);
void task_startup(taskCB_t * ptcb);
taskCB_t * task_create(const char *name,
                        void (*taskFunc)(void *parameter),
                        void        *parameter,
                        uint32_t    stack_size,
                        uint16_t    priority);


//user
void loadTasks(void);



#endif /* __OS_H__ */
