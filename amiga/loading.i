; A separate sixteen-row display survives writes to every game framebuffer.
; Loading work services music DMA and serial input without advancing actors.
BeginLevelLoading:
        movem.l d0-d7/a0-a6,-(sp)
        addi.w  #'1',d0
        move.b  d0,LoadingLevelDigit
        lea     LoadingBuffer,a0
        move.w  #159,d7
.clear: clr.l   (a0)+
        dbf     d7,.clear
        lea     LoadingLabel(pc),a0
        lea     LoadingBuffer+12,a1
        jsr     DrawHudString
        move.w  #-1,LoadingBarLast
        clr.b   LoadingProgressPhase
        jsr     ReadGameClock
        move.w  d0,LoadingMusicClock
        move.b  #1,LoadingActive
        move.l  #LoadingBuffer,d0
        move.w  d0,LoadingBplPtr+6
        swap    d0
        move.w  d0,LoadingBplPtr+2
        move.w  #$0020,CUSTOM+DMACON    ;sprites remain hidden during loading
        move.l  #LoadingCopper,CUSTOM+COP1LCH
        clr.w   CUSTOM+COPJMP1
        move.w  #$8100,CUSTOM+DMACON
        movem.l (sp)+,d0-d7/a0-a6
        rts

EndLevelLoading:
        clr.b   LoadingActive
        clr.b   LoadingProgressPhase
        move.l  #CopperList,CUSTOM+COP1LCH
        clr.w   CUSTOM+COPJMP1
        move.w  #$8120,CUSTOM+DMACON
        rts

ServiceBackgroundTasks:
        tst.b   LoadingActive
        bne.s   .loading
        jmp     ServiceArcadeMusicDMA
.loading:
        movem.l d0-d7/a0-a6,-(sp)
        jsr     ServiceArcadeMusicDMA
        jsr     PollKeyboard
        ; Main-loop simulation is stopped during loading. Original Amiga
        ; music alone follows the live PAL clock until the game clock resets.
        tst.b   MusicInitialized
        beq.s   .progress
        tst.w   CurrentMusicTrack
        beq.s   .progress
        jsr     ReadGameClock
        move.w  d0,d1
        sub.w   LoadingMusicClock,d1
        move.w  d0,LoadingMusicClock
        tst.w   d1
        beq.s   .progress
        cmpi.w  #8,d1
        bls.s   .ticks
        moveq   #8,d1
.ticks:
        subq.w  #1,d1
.tick:
        move.w  d1,-(sp)
        jsr     TickSelectedMusic
        move.w  (sp)+,d1
        dbf     d1,.tick
.progress:
        ifne BUILD_GFX_PROFILE
        tst.b   LoadingProgressPhase
        beq.s   .done
        moveq   #0,d0
        move.w  d6,d0
        addq.w  #1,d0
        mulu.w  #32,d0
        divu.w  FullColourTileCount,d0
        cmp.w   LoadingBarLast,d0
        beq.s   .done
        move.w  d0,LoadingBarLast
        move.w  d0,d4
        lea     LoadingBuffer+8*40+4,a0
        moveq   #7,d7
.row:
        moveq   #0,d5
.column:
        cmp.w   d4,d5
        slt     d1
        move.b  d1,(a0)+
        addq.w  #1,d5
        cmpi.w  #32,d5
        blo.s   .column
        addq.l  #8,a0
        dbf     d7,.row
        endif
.done:
        movem.l (sp)+,d0-d7/a0-a6
        rts

LoadingActive: dc.b 0
LoadingProgressPhase: dc.b 0
        EVEN
LoadingMusicClock: dc.w 0
LoadingBarLast: dc.w -1
LoadingLabel: dc.b "LOADING LEVEL "
LoadingLevelDigit: dc.b "1",0
        EVEN
