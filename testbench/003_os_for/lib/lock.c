#include "os.h"

int spin_lock()
{
    w_mstatus(r_mstatus() & ~MSTATUS_MIE); //關閉中斷開關，MSTATUS_MIE (1 << 3) 
    return 0;
}

int spin_unlock()
{
    w_mstatus(r_mstatus() | MSTATUS_MIE); //打開中斷
    return 0;
}