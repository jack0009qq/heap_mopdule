#include "os.h"

extern void uart_init(void);
extern void page_init(void);

void start_kernel(void)
{
	uart_init();
	uart_puts("os_started_heap_test!\n");
	
	page_init();
	trap_init();
	// timer_init();
	sched_init();
	InitTCBList();
	readyQ_init();
	int mcycleb = r_mcycle();
	kprintf ("%d\n",mcycleb);
	loadTasks(); //把TAsSK放進TCBReady之中
	int mcyclea = r_mcycle();
	kprintf ("%d\n",mcyclea);
	schedule();
	while (1) {}; // stop here!	

}

