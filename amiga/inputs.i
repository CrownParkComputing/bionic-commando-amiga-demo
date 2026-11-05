; CD32 / two-button pad on port 1.  Cache once per game tick so Start, the
; rifle and the arm see the same sample.  Native CD32 order is B,A,Y,X,R,L,Play.
ReadPad:
        movem.l d0-d5,-(sp)
        clr.b   PadButtons
        clr.b   PadIsCD32
        btst    #7,CIAAPRA
        bne.s   .fallback_blue
        bset    #1,PadButtons           ; ordinary joystick fire = A / rifle
.fallback_blue:
        move.w  CUSTOM+POTGOR,d0
        btst    #14,d0
        bne.s   .serial
        bset    #0,PadButtons           ; second button = B / arm
.serial:
        move.b  PadButtons(pc),d5
        move.b  CIAAPRA,d2
        move.b  CIAADDRA,d3
        move.w  #$3000,CUSTOM+POTGO     ; P5 high/output: reset shift register
        ori.b   #$80,CIAADDRA           ; P6 / CIA7 is the serial clock
        ; Establish a high clock after enabling output. DDRA writes alone do
        ; not update Amiberry's previous clock state; setting PRA first would
        ; duplicate Blue and shift every following sample by one bit.
        ori.b   #$80,CIAAPRA
        moveq   #3,d0
.reset_wait:
        move.w  CUSTOM+POTGOR,d4
        dbf     d0,.reset_wait
        move.w  #$2000,CUSTOM+POTGO     ; P5 low: enter serial mode
        moveq   #3,d0
.enter_wait:
        move.w  CUSTOM+POTGOR,d4
        dbf     d0,.enter_wait
        moveq   #0,d4
        moveq   #0,d1
.bit:
        move.w  CUSTOM+POTGOR,d0
        btst    #14,d0
        bne.s   .clock
        bset    d1,d4                   ; active-low pressed bits
.clock:
        bclr    #7,CIAAPRA
        move.w  CUSTOM+VHPOSR,d0
        bset    #7,CIAAPRA
        addq.w  #1,d1
        cmpi.w  #9,d1
        blt.s   .bit
        move.w  d4,PadSerialRaw
        move.w  d4,d0
        andi.w  #$0180,d0              ; trailing serial ID must be high, low
        cmpi.w  #$0100,d0
        bne.s   .restore
        move.b  d4,d5
        andi.b  #$7F,d5
        move.b  #1,PadIsCD32
.restore:
        move.w  #$3000,CUSTOM+POTGO
        move.b  d3,CIAADDRA
        move.b  d2,CIAAPRA
        move.b  d5,PadButtons
        movem.l (sp)+,d0-d5
        rts
