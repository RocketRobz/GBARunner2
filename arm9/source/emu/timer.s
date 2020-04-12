.section .itcm

#include "consts.s"

#ifndef USE_GBA_ADJUSTED_SYNC
#define USE_ACTUAL_RATE
#endif

ADDRESS_TIMER_BASE = 0x04000100

.macro fix_timer_counter_read regb, rega
	mov \regb, \rega, lsl #16
	tst \rega, #(4 << 16)
	movne \regb, \regb, lsr #16 //if slave mode, don't divide by 2
	moveq \regb, \regb, lsr #17 //if normal mode, fix timer value
	orreq \regb, \regb, #0x8000 //set top bit as we assume this bit was 1 (we don't really have a proper way of fixing that)
.endm

.global read_address_timer_counter
read_address_timer_counter:
	ldr r10, [r9] //read full info
	fix_timer_counter_read r10, r10
	//ldrh r10, [r9]
	//mov r10, r10, lsr #1
	bx lr

.global read_address_timer
read_address_timer:
	ldr r10, [r9]
	fix_timer_counter_read r12, r10
	mov r10, r10, lsr #16
	orr r10, r12, r10, lsl #16
	//mov r12, r10, lsr #16
	//mov r12, r12, lsl #16
	//mov r13, r10, lsl #16
	//orr r10, r12, r13, lsr #17
	bx lr

.global write_address_timer_counter
write_address_timer_counter:
	//store value in shadowreg
	ldr r13,= timer_shadow_regs_dtcm
	ldr r12,= ADDRESS_TIMER_BASE
	sub r12, r9, r12
	add r13, r12, lsr #1
	strh r11, [r13]

	ldrh r12, [r9, #2]
	orr r11, r12, lsl #16
	tst r12, #4 //if slave mode, we don't have to fix the reload value
#ifdef USE_ACTUAL_RATE
	ldreq r12,= 16756991
	smulwbeq r12, r12, r11
	moveq r12, r12, asr #7
	moveq r12, r12, lsl #16
	moveq r12, r12, lsr #16
#else
	moveq r12, r11, lsl #17
	moveq r12, r12, lsr #16
#endif	
	movne r12, r11
	strh r12, [r9]

#ifdef USE_DSP_AUDIO
	ldr sp,= address_dtcm + (16 * 1024)
	push {r0-r3,lr}
1:
	bic r0, r9, #0xFF000000
	orr r0, #(2 << 16)
	mov r1, r11
	ldr r12,= dsp_sendIpcCommand
	blx r12
	cmp r0, #0
	beq 1b //loop if it failed
	pop {r0-r3,lr}
#else
	//send info to arm7
	ldr r13,= 0x04000188
1:
	ldr r10, [r13, #-4]
	tst r10, #1
	beq 1b
	ldr r12,= 0x04000188
	str r9, [r12]
	str r11, [r12]
#endif
	bx lr

.global write_address_timer_control
write_address_timer_control:
	tst r11, #0x80
	streqh r11, [r9] //if the timer is not set to run, we don't have to fix anything
	beq 1f

	ldrh r12, [r9]
	tst r12, #0x80
	strneh r11, [r9] //if the timer was already running, we don't have to fix anything
	bne 1f

	ldr r13,= timer_shadow_regs_dtcm
	ldr r12,= (ADDRESS_TIMER_BASE + 2)
	sub r12, r9, r12
	add r13, r12, lsr #1
	ldrh r12, [r13]
	
	tst r11, #4 //if slave mode, we don't have to fix the reload value
#ifdef USE_ACTUAL_RATE
	ldreq r13,= 16756991
	smulwbeq r12, r13, r12
	moveq r12, r12, asr #7
	moveq r12, r12, lsl #16
	moveq r12, r12, lsr #16
#else
	moveq r12, r12, lsl #17
	moveq r12, r12, lsr #16
#endif
	strh r12, [r9, #-2]
	strh r11, [r9]

1:
#ifdef USE_DSP_AUDIO
	ldr sp,= address_dtcm + (16 * 1024)
	push {r0-r3,lr}
2:
	bic r0, r9, #0xFF000000
	orr r0, #(2 << 16)
	mov r1, r11
	ldr r12,= dsp_sendIpcCommand
	blx r12
	cmp r0, #0
	beq 2b //loop if it failed
	pop {r0-r3,lr}
#else
	ldr r13,= 0x04000188
2:
	ldr r10, [r13, #-4]
	tst r10, #1
	beq 2b
	ldr r12,= 0x04000188
	str r9, [r12]
	str r11, [r12]
#endif
	bx lr

.global write_address_timer
write_address_timer:
	//store value in shadowreg
	ldr r13,= timer_shadow_regs_dtcm
	ldr r12,= ADDRESS_TIMER_BASE
	sub r12, r9, r12
	add r13, r12, lsr #1
	strh r11, [r13]

	tst r11, #(4 << 16) //if slave mode, we don't have to fix the reload value
	strne r11, [r9]
	bne 1f
#ifdef USE_ACTUAL_RATE
	ldr r13,= 16756991
	smulwb r12, r13, r11
	mov r12, r12, asr #7
	mov r12, r12, lsl #16
	mov r12, r12, lsr #16
#else
	mov r12, r11, lsl #17
	mov r12, r12, lsr #16
#endif
	mov r13, r11, lsr #16
	orr r13, r12, r13, lsl #16
	str r13, [r9]

1:
#ifdef USE_DSP_AUDIO
	ldr sp,= address_dtcm + (16 * 1024)
	push {r0-r3,lr}
2:
	bic r0, r9, #0xFF000000
	orr r0, #(4 << 16)
	mov r1, r11
	ldr r12,= dsp_sendIpcCommand
	blx r12
	cmp r0, #0
	beq 2b //loop if it failed
	pop {r0-r3,lr}
#else
	ldr r13,= 0x04000188
2:
	ldr r10, [r13, #-4]
	tst r10, #1
	beq 2b
	ldr r12,= 0x04000188
	str r9, [r12]
	str r11, [r12]
#endif
	bx lr