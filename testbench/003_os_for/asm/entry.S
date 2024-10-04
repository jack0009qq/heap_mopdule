


# .marco 和 .endm是定義和結束marco
.macro reg_save base
    sw ra,0(\base)
    sw sp,4(\base)
    sw gp,8(\base)
    sw tp,12(\base)
    sw t0,16(\base)
    sw t1,20(\base)
    sw t2,24(\base)
    sw s0,28(\base)
    sw s1,32(\base)
    sw a0,36(\base)
    sw a1,40(\base)
    sw a2,44(\base)
    sw a3,48(\base)
    sw a4,52(\base)
    sw a5,56(\base)
    sw a6,60(\base)
    sw a7,64(\base)
    sw s2,68(\base)
    sw s3,72(\base)
    sw s4,76(\base)
    sw s5,80(\base)
    sw s6,84(\base)
    sw s7,88(\base)
    sw s8,92(\base)
    sw s9,96(\base)
    sw s10,100(\base)
    sw s11,104(\base)
    sw t3,108(\base)
    sw t4,112(\base)
    sw t5,116(\base)
    #不存t6因為會用到，所以要在不同的部分存t6
    # we don't save t6 here, due to we have used
	# it as base, we have to save t6 in an extra step
	# outside of reg_save
.endm




.macro reg_restore base
    lw ra,0(\base)
    lw sp,4(\base)
    lw gp,8(\base)
    lw tp,12(\base)
    lw t0,16(\base)
    lw t1,20(\base)
    lw t2,24(\base)
    lw s0,28(\base)
    lw s1,32(\base)
    lw a0,36(\base)
    lw a1,40(\base)
    lw a2,44(\base)
    lw a3,48(\base)
    lw a4,52(\base)
    lw a5,56(\base)
    lw a6,60(\base)
    lw a7,64(\base)
    lw s2,68(\base)
    lw s3,72(\base)
    lw s4,76(\base)
    lw s5,80(\base)
    lw s6,84(\base)
    lw s7,88(\base)
    lw s8,92(\base)
    lw s9,96(\base)
    lw s10,100(\base)
    lw s11,104(\base)
    lw t3,108(\base)
    lw t4,112(\base)
    lw t5,116(\base)
    lw t6, 120(\base)
.endm
#有lw t6暫存器

#.text接下來的指令放進text segment中
.text

# machine mode的interrupt和exceptions
.globl trap_vector

.align 4
trap_vector:
    csrrw t6, mscratch, t6 #swap t6 和 mscratch
    reg_save t6 //把目前任務的ctx存進記憶體

    mv t5, t6 #將t6複製到t5
    csrr t6, mscratch #復原原本t6
    sw t6, 120(t5) #存完整的ctx
    //以上存完目前ctx進記憶體

    csrw mscratch, t5 #將context的pointer放回mscratch

    #呼叫trap_handler 在trap.c
    //exception 會卡住
    //interrupt 會pc+4
    csrr a0, mepc 
    csrr a1, mcause
    call trap_handler

    # trap_handler will return the return address via a0.
    csrw mepc, a0

    # restore context(registers).
    csrr t6, mscratch
    reg_restore t6

    # return to whatever we were doing before trap.
    mret //退出中斷從mepc處開始執行


#聲明一個全局符號
.globl switch_to
#對其4byte的邊界
.align 4
switch_to:
	# switch mscratch to point to the context of the next task
	//csrw	mscratch, a0
	# set mepc to the pc of the next task
	lw	a1, 124(a0)
	csrw	mepc, a1

	ctxl a0
	# Restore all GP registers
	# Use t6 to point to the context of the new task
	//mv	t6, a0
	//reg_restore t6

	# Do actual context switching.
	# Notice this will enable global interrupt
	ret

.global switch_inst
.align 4
switch_inst :

	csrr a1, mscratch
	ctx a0, a1

	ret

.globl ctx_handler
.align 4
ctx_handler:
	NOP
	j 	switch_reserve
	j	switch_lw
	j 	switch_sw_ctxl
	j	switch_swlw
	j	switch_sw
    j   heap_full

.global switch_reserve
switch_reserve:
	ret
.global switch_lw
switch_lw:
	csrr t6 , mscratch

	reg_restore t6

	ctxret

.global switch_sw_ctxl
switch_sw_ctxl:
	reg_save t6
	csrr a0, mscratch
	ctxl a0

	ret

.global switch_swlw
switch_swlw:
	reg_save t6
	csrr t6, mscratch
	reg_restore t6

	ret

.global switch_sw
switch_sw:
	reg_save t6

	ctxret


.global heap_full
heap_full:
    csrr a0, mheapfullctx
    mv t6, ra
    call heap_handler
    mv ra, t6
    ctxret


.global task_clz
task_clz:
    # Initialize the mask to check the highest bit (bit 31)
    li a1, 1 << 31
    li a2, 0  # Counter for leading zeros
    
    li t0, 0               # 如果 value 为 0，返回 0
    beq a0, t0, return_zero

    neg t1, a0             # rsb x, value, #0 的等效操作，将 value 取反
    and t1, t1, a0         # 按位与数
    j clz_loop
    ret

return_zero:
    mv a0, t0              # 返回 0
    ret

clz_loop:
    # If the current bit is 1, exit the loop
    and t0, t1, a1
    bne t0, zero, clz_end

    # If the current bit is 0, increment the counter
    addi a2, a2, 1

    # Right shift the mask to check the next bit
    srli a1, a1, 1

    # Loop back to check the next bit
    j clz_loop

clz_end:
    # a2 now contains the count of leading zeros
    # Return or continue with your code
    mv a0, a2  # Move the result to a0
    li t0, 32              # 为了与 rsb x, x, #32 等效
    sub a0, t0, a0        # 32 - 前导零
    ret                    # 返回结果

.end

