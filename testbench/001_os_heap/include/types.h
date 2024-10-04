#ifndef __TYPES_H__
#define __TYPES_H__

typedef unsigned char           uint8_t;
typedef unsigned char           state_t;
typedef char                    err_t;
typedef unsigned short          uint16_t;
typedef unsigned int            uint32_t;
//
//
typedef uint32_t reg_t;
typedef long                            base_t;      /**< Nbit CPU related date type */
typedef unsigned long                   ubase_t;     /**< Nbit unsigned CPU related data type */

//
//
typedef unsigned long long      uint64_t;
typedef unsigned char           u_char;
typedef unsigned long long      u_quad_t;
typedef short int               int16_t;

#define ERROR -1
#define TRUE 1
#define FALSE 0
#define OK 0
#define NULL (void *)0



#endif /* __TYPES_H__ */
