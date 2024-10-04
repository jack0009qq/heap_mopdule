#define MAX_USER_TASKS      520
#define SYS_TASK_NUM        1
#define SYS_STACK_SIZE      256
#define USER_STACK_SIZE     1024
#define PRIO_LEVEL          256

#define SYSTEM_TICK CLINT_TIMEBASE_FREQ
//CLINT_TIMEBASE_FREQ 在platform.h定義