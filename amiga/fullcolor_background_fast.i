; Exact native full-colour composition with horizontal spans. The old path
; reads44 words per plane row (22 overlapping width2 blits); this reads23
; without a wrap, or at most25 at the native31/0 seam. Right-to-left span
; ordering overwrites each first B-shift priming word before display.
; Root owns BLITHOG enable/disable around composition plus the BOB pass.
; Requires fullcolor_render.i constants/globals and its background-state API.
ComposeFullBackgroundFast:
        tst.w   CurrentStage
        bne.w   CopyFullFlatBackground
        movem.l d0-d7/a0-a6,-(sp)
        bsr.w   ComputeFullBackgroundCoords
        bra.w   FullFastComposePrepared

; Root's clean-scene cache may call ComputeFullBackgroundCoords before its
; cache-key comparison, then this entry after substituting FrameDrawPtr.
ComposeFullBackgroundFastPrepared:
        tst.w   CurrentStage
        bne.w   CopyFullFlatBackground
        movem.l d0-d7/a0-a6,-(sp)
FullFastComposePrepared:
        clr.w   FullFastTileRow
        bra.w   FullFastCoverageRow

ComputeFullBackgroundCoords:
        movem.l d0-d7/a0-a6,-(sp)
        jsr     UpdateFullBackgroundState
        move.l  ParallaxXFP,d0
        asr.l   #8,d0
        moveq   #0,d1
        tst.b   ChuteMode
        bne.s   .fine_x
        move.w  CamX,d1
        andi.w  #15,d1
        addq.w  #1,d1
.fine_x:
        sub.w   d1,d0
        move.w  d0,d1
        andi.w  #15,d1
        move.w  d1,FullBGFine
        asr.w   #4,d0
        tst.w   d1
        bne.s   .word
        subq.w  #1,d0
.word:
        move.w  d0,FullBGLeftWord
        andi.w  #31,d0
        move.w  d0,FullFastSourceWord
        move.w  #31,d1
        sub.w   d0,d1
        move.w  d1,FullFastLeftCount
        move.l  ParallaxYFP,d0
        asr.l   #8,d0
        move.w  #272,d1
        sub.w   d0,d1
        move.w  CamY,d0
        andi.w  #15,d0
        sub.w   d0,d1
        andi.w  #511,d1
        move.w  d1,FullBGTop
        movem.l (sp)+,d0-d7/a0-a6
        rts
FullFastCoverageRow:
        clr.w   FullFastScanCol
.next_run:
        move.w  FullFastTileRow,d0
        mulu.w  #22,d0
        lea     FullTileCoverage,a0
        adda.l  d0,a0
        move.w  FullFastScanCol,d1
.scan:
        cmpi.w  #22,d1
        bhs.w   .next_row
        tst.b   (a0,d1.w)
        bne.s   .begin
        addq.w  #1,d1
        bra.s   .scan
.begin:
        move.w  d1,FullFastRunStart
        move.b  #1,FullFastRunType
.run:
        cmpi.b  #2,(a0,d1.w)
        bne.s   .advance
        move.b  #2,FullFastRunType
.advance:
        addq.w  #1,d1
        cmpi.w  #22,d1
        bhs.s   .run_ready
        tst.b   (a0,d1.w)
        bne.s   .run
.run_ready:
        move.w  d1,FullFastScanCol
        sub.w   FullFastRunStart,d1
        move.w  d1,FullFastRunCount
        move.w  FullFastTileRow,d0
        lsl.w   #4,d0
        move.w  d0,FullComposeY
        addi.w  #16,d0
        move.w  d0,FullFastRunEndY
        bsr.w   FullFastCoverageChunk
        bra.w   .next_run
.next_row:
        addq.w  #1,FullFastTileRow
        cmpi.w  #16,FullFastTileRow
        blo.w   FullFastCoverageRow
        jsr     WaitBlitter
        movem.l (sp)+,d0-d7/a0-a6
        rts

FullFastCoverageChunk:
        moveq   #0,d0
        move.w  FullBGTop,d0
        add.w   FullComposeY,d0
        andi.w  #511,d0
        move.w  d0,FullFastSourceY
        move.w  d0,d2
        andi.w  #255,d2
        move.w  #256,d3
        sub.w   d2,d3
        move.w  FullFastRunEndY,d4
        sub.w   FullComposeY,d4
        cmp.w   d4,d3
        bls.s   .height_ready
        move.w  d4,d3
.height_ready:
        move.w  d3,FullComposeHeight
        lea     ParallaxBank4,a1
        btst    #8,d0
        beq.s   .bank
        lea     ParallaxBank5,a1
.bank:
        mulu.w  #512,d2
        adda.l  d2,a1
        move.l  a1,FullFastNativeRow
        move.w  FullBGLeftWord,d0
        add.w   FullFastRunStart,d0
        andi.w  #31,d0
        move.w  d0,FullFastSourceWord
        move.w  #31,d1
        sub.w   d0,d1
        move.w  d1,FullFastLeftCount
        cmp.w   FullFastRunCount,d1
        blo.s   .split
        add.w   d0,d0
        adda.w  d0,a1
        move.w  FullFastRunStart,d0
        subq.w  #1,d0
        move.w  FullFastRunCount,d1
        addq.w  #1,d1
        moveq   #64,d5
        bsr.w   FullFastBlitSpan
        bra.w   .next_chunk
.split:
        move.w  FullFastRunStart,d0
        add.w   FullFastLeftCount,d0
        move.w  FullFastRunCount,d1
        sub.w   FullFastLeftCount,d1
        cmpi.w  #1,d1
        beq.s   .seam
        moveq   #64,d5
        bsr.w   FullFastBlitSpan
.seam:
        moveq   #0,d0
        move.w  FullFastSourceY,d0
        lsl.l   #5,d0
        lea     ActiveTileSheet,a1
        adda.l  d0,a1
        move.w  FullFastRunStart,d0
        add.w   FullFastLeftCount,d0
        subq.w  #1,d0
        moveq   #2,d1
        moveq   #4,d5
        bsr.w   FullFastBlitSpan
        move.w  FullFastLeftCount,d1
        beq.s   .next_chunk
        addq.w  #1,d1
        movea.l FullFastNativeRow,a1
        move.w  FullFastSourceWord,d0
        add.w   d0,d0
        adda.w  d0,a1
        move.w  FullFastRunStart,d0
        subq.w  #1,d0
        moveq   #64,d5
        bsr.w   FullFastBlitSpan
.next_chunk:
        move.w  FullComposeHeight,d0
        add.w   d0,FullComposeY
        move.w  FullComposeY,d0
        cmp.w   FullFastRunEndY,d0
        blo.w   FullFastCoverageChunk
        rts

; d0.w=prefetch destination column(-1allowed),d1.w=width inwords,
; a1=nativeBG/seam source,d5.w=source bytes per plane row(64or4).
FullFastBlitSpan:
        movem.l d0-d7/a0-a4,-(sp)
        ext.l   d0
        add.l   d0,d0
        moveq   #0,d2
        move.w  FullComposeY,d2
        mulu.w  #FC_ROW,d2
        add.l   d0,d2
        lea     ScreenBuffer+FC_ORIGIN,a2
        adda.l  d2,a2
        movea.l a2,a0
        adda.l  #FC_BYTES,a0
        movea.l FrameDrawPtr,a3
        adda.l  #FC_ORIGIN,a3
        adda.l  d2,a3
        jsr     WaitBlitter
        move.w  #$0FAC,CUSTOM+BLTCON0
        move.l  #$FFFFFFFF,CUSTOM+BLTAFWM
        cmpi.b  #1,FullFastRunType
        bne.s   .mixed
        ; Transparent spans copy B, retaining the left priming word from D.
        move.w  #$07CA,CUSTOM+BLTCON0
        move.w  #$FFFF,CUSTOM+$074     ;BLTADAT, A DMA disabled
        move.l  #$0000FFFF,CUSTOM+BLTAFWM
        movea.l a3,a2
.mixed:
        move.w  FullBGFine,d0
        beq.s   .shift
        neg.w   d0
        addi.w  #16,d0
        ror.w   #4,d0
.shift:
        move.w  d0,CUSTOM+BLTCON1
        move.w  d1,d4
        add.w   d4,d4
        moveq   #52,d3
        sub.w   d4,d3
        move.w  d3,CUSTOM+BLTAMOD
        move.w  d3,CUSTOM+BLTCMOD
        move.w  d3,CUSTOM+BLTDMOD
        sub.w   d4,d5
        move.w  d5,CUSTOM+BLTBMOD
        move.l  a0,CUSTOM+BLTAPTH
        move.l  a1,CUSTOM+BLTBPTH
        move.l  a2,CUSTOM+BLTCPTH
        move.l  a3,CUSTOM+BLTDPTH
        move.w  FullComposeHeight,d0
        lsl.w   #8,d0
        add.w   d0,d0
        or.w    d1,d0
        move.w  d0,CUSTOM+BLTSIZE
        movem.l (sp)+,d0-d7/a0-a4
        rts

FullFastSourceWord: dc.w 0
FullFastLeftCount:  dc.w 0
FullFastSourceY:    dc.w 0
FullFastNativeRow:  dc.l 0

FullFastTileRow: dc.w 0
FullFastScanCol: dc.w 0
FullFastRunStart: dc.w 0
FullFastRunCount: dc.w 0
FullFastRunEndY: dc.w 0
FullFastRunType: dc.b 0
        EVEN
