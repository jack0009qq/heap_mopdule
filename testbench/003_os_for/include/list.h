#ifndef    __LIST_H__ 
#define    __LIST_H__

#include "types.h"

//list的結構
typedef struct list {
    struct list *prev;
    struct list *next;
} list_t;

//double link list 所需的涵式
//???????????????????????????????????????????????????????????????????
static inline void list_init(list_t *l){
    l->next = l->prev = l;
}

static inline void list_insert_after(list_t *l, list_t *n){
    l->next->prev = n;
    n->next = l->next;
    l->next = n;
    n->prev = l;
}

static inline void list_insert_before(list_t *l, list_t *n)
{
    l->prev->next = n;
    n->prev = l->prev;
    l->prev = n;
    n->next = l;
}

static inline void list_remove(list_t *n)
{
    n->next->prev = n->prev;
    n->prev->next = n->next;

    n->next = n->prev = n;
}

static inline int list_isempty(list_t *l)
{
    return l->next == l; 
}

#endif
