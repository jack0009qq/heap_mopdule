#include "types.h"
//把ptr的區域一byte傳入value
void *memset(void *ptr, int value, uint32_t num){
    //p指向ptr,*p就是ptr地址裡的值
    unsigned char *p = (unsigned char *) ptr;
    while (num-- > 0){
        *p++ = (unsigned char) value;
    }
    return ptr;
}

char *memcpy(void *dest, const void *src, uint32_t num){
    //p指向dest
    char *p = (char *) dest;
    //s指向src
    const char *s =(const char *) src;
    //
    while (num-- > 0){
        *p++ = *s++;
    }
    return dest;
}