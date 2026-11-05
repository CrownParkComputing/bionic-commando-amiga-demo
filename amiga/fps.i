; Count completed presentations against the PAL vertical-sync TOD clock.
; Simulation catch-up steps never count as extra displayed frames.
DetectMachineProfile:
        move.b  #BUILD_GFX_PROFILE,MachineProfile
        rts

ResetFPS:
        jsr     ReadGameClock
        move.w  d0,FPSClockLast
        clr.w   FPSFrameCount
        clr.w   FPSValue10
        rts

CountPresentedFrame:
        movem.l d0-d2,-(sp)
        addq.w  #1,FPSFrameCount
        jsr     ReadGameClock
        move.w  d0,d2
        sub.w   FPSClockLast,d0
        cmpi.w  #50,d0
        blo.s   .done
        moveq   #0,d1
        move.w  FPSFrameCount,d1
        mulu.w  #500,d1
        divu.w  d0,d1
        move.w  d1,FPSValue10
        move.w  d2,FPSClockLast
        clr.w   FPSFrameCount
        tst.b   ShowFPS
        beq.s   .done
        move.b  #1,HudDirty
.done:  movem.l (sp)+,d0-d2
        rts

RenderFPS:
        tst.b   ShowFPS
        beq.s   .done
        movem.l d0-d7/a0-a2,-(sp)
        lea     FPSLabel(pc),a0
        lea     HudBuffer+8*40+32,a1
        jsr     DrawHudString
        moveq   #0,d0
        move.w  FPSValue10,d0
        divu.w  #10,d0
        swap    d0
        move.w  d0,-(sp)
        clr.w   d0
        swap    d0
        divu.w  #10,d0
        move.l  d0,d1
        addi.w  #'0',d0
        jsr     DrawHudChar
        swap    d1
        move.w  d1,d0
        addi.w  #'0',d0
        jsr     DrawHudChar
        moveq   #'.',d0
        jsr     DrawHudChar
        move.w  (sp)+,d0
        addi.w  #'0',d0
        jsr     DrawHudChar
        movem.l (sp)+,d0-d7/a0-a2
.done:  rts

MachineProfile: dc.b 0
        EVEN
FPSClockLast: dc.w 0
FPSFrameCount: dc.w 0
FPSValue10: dc.w 0
FPSLabel: dc.b "FPS ",0
        EVEN
